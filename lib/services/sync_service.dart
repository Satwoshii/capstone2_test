import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'api_endpoints.dart';
import 'app_config_service.dart';
import 'auth_service.dart';
import 'local_db_service.dart';
import 'workstation_registry_service.dart';

class SyncService {
  SyncService._();

  static final SyncService instance = SyncService._();

  final ValueNotifier<int> pendingItems = ValueNotifier<int>(0);
  final ValueNotifier<String?> lastError = ValueNotifier<String?>(null);
  final ValueNotifier<bool> serverOnline = ValueNotifier<bool>(false);

  Timer? _timer;
  bool _started = false;
  bool _syncing = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    await refreshPendingCount();
    unawaited(syncNow());

    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(syncNow()),
    );
  }

  Future<bool> hasInternet() => isServerReachable();

  Future<bool> isServerReachable() async {
    try {
      await ApiClient.instance.getJson(
        ApiEndpoints.health,
        includeWorkstationToken: false,
      );
      serverOnline.value = true;
      return true;
    } catch (_) {
      serverOnline.value = false;
      return false;
    }
  }

  Future<int> refreshPendingCount() async {
    final loginLogs = await LocalDbService.instance.getUnsyncedRows(
      'login_logs',
    );
    final faultReports = await LocalDbService.instance.getUnsyncedRows(
      'fault_reports',
    );
    final maintenanceLogs = await LocalDbService.instance.getUnsyncedRows(
      'maintenance_logs',
    );
    final pcStatus = await LocalDbService.instance.getUnsyncedRows(
      'pc_status',
    );

    final count = loginLogs.length +
        faultReports.length +
        maintenanceLogs.length +
        pcStatus.length;
    pendingItems.value = count;
    return count;
  }

  Future<void> syncPendingData() => syncNow();

  Future<void> syncNow() async {
    if (_syncing) return;
    _syncing = true;

    try {
      if (!await isServerReachable()) {
        lastError.value = 'Syswatch intranet server is unavailable.';
        await refreshPendingCount();
        return;
      }

      final pc = await AppConfigService.instance.getPcIdentity();
      final registrationConfirmed =
          await AppConfigService.instance.isRegistrationConfirmed();

      if (pc.isConfigured && registrationConfirmed) {
        await _syncTable(
          localTable: 'login_logs',
          recordType: 'login_log',
        );
        await _syncTable(
          localTable: 'fault_reports',
          recordType: 'fault_report',
        );
        await _syncTable(
          localTable: 'maintenance_logs',
          recordType: 'maintenance_log',
        );
        await _syncTable(
          localTable: 'pc_status',
          recordType: 'pc_status',
        );

        final status = await LocalDbService.instance.getCurrentPcStatus(
          pc.workstationId,
        );
        await WorkstationRegistryService.instance.updateHeartbeat(pc, status);
      }

      String? refreshError;
      try {
        await AuthService.refreshOfflineStudents();
      } catch (error) {
        refreshError = 'Offline account refresh delayed: $error';
      }

      lastError.value = refreshError;
      await refreshPendingCount();
    } catch (error) {
      lastError.value = error.toString();
      await refreshPendingCount();
    } finally {
      _syncing = false;
    }
  }

  Future<void> _syncTable({
    required String localTable,
    required String recordType,
  }) async {
    final rows = await LocalDbService.instance.getUnsyncedRows(localTable);

    for (final row in rows) {
      final id = row['id']?.toString() ?? '';
      if (id.isEmpty) continue;

      final data = Map<String, dynamic>.from(row)..remove('synced');
      await ApiClient.instance.postJson(
        ApiEndpoints.syncRecord,
        body: {
          'record_type': recordType,
          'record': data,
        },
      );
      await LocalDbService.instance.markSynced(localTable, id);
    }
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }
}
