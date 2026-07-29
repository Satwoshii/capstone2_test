import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'app_config_service.dart';
import 'firebase_user_service.dart';
import 'local_db_service.dart';
import 'workstation_registry_service.dart';

class SyncService {
  SyncService._();

  static final SyncService instance = SyncService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final ValueNotifier<int> pendingItems = ValueNotifier<int>(0);
  final ValueNotifier<String?> lastError = ValueNotifier<String?>(null);

  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

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
          (_) async {
        await refreshPendingCount();
        await syncNow();
      },
    );

    await _connectivitySubscription?.cancel();

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
          if (!results.contains(ConnectivityResult.none)) {
            unawaited(syncNow());
          }
        });
  }

  Future<bool> hasInternet() async {
    try {
      final results = await Connectivity().checkConnectivity();

      if (results.contains(ConnectivityResult.none)) {
        return false;
      }

      final lookup = await InternetAddress.lookup('google.com').timeout(
        const Duration(seconds: 3),
      );

      return lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty;
    } catch (_) {
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

  Future<void> syncPendingData() async {
    await syncNow();
  }

  Future<void> syncNow() async {
    if (_syncing) return;

    _syncing = true;

    try {
      final online = await hasInternet();

      if (!online) {
        await refreshPendingCount();
        return;
      }

      await WorkstationRegistryService.instance
          .ensureDevelopmentWorkstationSession();

      await _syncTable(
        localTable: 'login_logs',
        firestoreCollection: 'login_logs',
      );

      await _syncTable(
        localTable: 'fault_reports',
        firestoreCollection: 'fault_reports',
      );

      await _syncTable(
        localTable: 'maintenance_logs',
        firestoreCollection: 'maintenance_logs',
      );

      await _syncTable(
        localTable: 'pc_status',
        firestoreCollection: 'pc_status',
      );

      final pc = await AppConfigService.instance.getPcIdentity();

      final registrationConfirmed =
      await AppConfigService.instance.isRegistrationConfirmed();

      if (pc.isConfigured && registrationConfirmed) {
        final status =
        await LocalDbService.instance.getCurrentPcStatus(
          pc.workstationId,
        );

        await WorkstationRegistryService.instance.updateHeartbeat(
          pc,
          status,
        );
      }

      String? refreshError;

      try {
        await FirebaseUserService.downloadUsersToSQLite();
      } catch (error) {
        refreshError = 'Student account refresh delayed: $error';
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
    required String firestoreCollection,
  }) async {
    final rows = await LocalDbService.instance.getUnsyncedRows(
      localTable,
    );

    for (final row in rows) {
      final id = row['id'].toString();
      final data = Map<String, dynamic>.from(row);

      data.remove('synced');

      await _firestore
          .collection(firestoreCollection)
          .doc(id)
          .set(
        data,
        SetOptions(merge: true),
      );

      await LocalDbService.instance.markSynced(
        localTable,
        id,
      );
    }
  }

  Future<void> seedDefaultRoomsAndPcs() async {
    const rooms = [
      '706',
      '707',
      '708',
      '709',
      '710',
      '723',
    ];

    const pcCount = 40;

    final batch = _firestore.batch();

    for (final room in rooms) {
      final roomReference = _firestore.collection('rooms').doc(room);

      batch.set(
        roomReference,
        {
          'roomName': room,
          'capacity': pcCount,
          'pcCount': pcCount,
          'active': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      for (int number = 1; number <= pcCount; number++) {
        final pcId = 'PC-${number.toString().padLeft(2, '0')}';
        final pcDocumentId = '${room}_$pcId';

        final pcReference = _firestore
            .collection('pcs')
            .doc(pcDocumentId);

        batch.set(
          pcReference,
          {
            'roomName': room,
            'room': room,
            'pcId': pcId,
            'pc': pcId,
            'code': pcDocumentId,
            'status': 'unknown',
            'active': true,
            'workstationId': null,
            'lastStudentEmail': null,
            'lastCheck': null,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    }

    final systemConfigReference = _firestore
        .collection('system_config')
        .doc('default');

    batch.set(
      systemConfigReference,
      {
        'appName': 'Syswatch',
        'offlineFirst': true,
        'roomCount': rooms.length,
        'pcCountPerRoom': pcCount,
        'totalPcCount': rooms.length * pcCount,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;

    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;

    _started = false;
  }
}