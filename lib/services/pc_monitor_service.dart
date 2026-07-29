import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../models/hardware_status.dart';
import '../models/pc_identity.dart';
import '../screens/student/minor_peripheral_warning_screen.dart';
import '../screens/student/pc_broken_screen.dart';
import 'app_config_service.dart';
import 'app_navigator.dart';
import 'local_db_service.dart';
import 'sync_service.dart';
import 'tray_service.dart';
import 'windows_hardware_service.dart';

class PcMonitorService {
  PcMonitorService._();

  static final PcMonitorService instance = PcMonitorService._();

  Timer? _timer;
  bool _checking = false;
  bool _started = false;
  HardwareStatus _latestHardware = HardwareStatus.normal();
  String _currentIssueSignature = '';
  String _lastPresentedSignature = '';
  Route<void>? _activeWarningRoute;
  String? _activeStudentEmail;

  HardwareStatus get latestHardware => _latestHardware;
  String? get activeStudentEmail => _activeStudentEmail;
  bool get hasActiveStudentSession => _activeStudentEmail != null;

  void beginStudentSession(String studentEmail) {
    _activeStudentEmail = studentEmail.trim().isEmpty ? null : studentEmail;
  }

  void endStudentSession() {
    _activeStudentEmail = null;
  }

  // Kept for compatibility with old screens that may still call this method.
  void clearWarningState() {
    _lastPresentedSignature = '';
  }

  Future<void> start({bool checkImmediately = true}) async {
    if (_started) return;
    _started = true;

    if (checkImmediately) {
      await checkNow();
    }

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      checkNow();
    });
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }

  Future<HardwareStatus> checkNow({bool showWarnings = true}) async {
    if (_checking) return _latestHardware;

    _checking = true;

    try {
      final pc = await AppConfigService.instance.getPcIdentity();
      final hardware = await WindowsHardwareService.checkHardware();
      final previousIssues =
          List<String>.from(_latestHardware.failedComponents);
      final currentIssues = List<String>.from(hardware.failedComponents);
      final previousSignature = _signature(previousIssues);
      final currentSignature = _signature(currentIssues);
      final stateChanged = previousSignature != currentSignature;

      final openLocalIssues =
          await LocalDbService.instance.getOpenAutomaticFaultIssues(pc);
      final recoveredIssues = {
        ...previousIssues.where((issue) => !currentIssues.contains(issue)),
        ...openLocalIssues.where((issue) => !currentIssues.contains(issue)),
      }.toList();
      final newIssues = currentIssues
          .where((issue) => !previousIssues.contains(issue))
          .toList();
      final recordsChanged =
          newIssues.isNotEmpty || recoveredIssues.isNotEmpty;

      _latestHardware = hardware;
      _currentIssueSignature = currentSignature;

      if (pc.isConfigured) {
        await LocalDbService.instance.upsertPcStatus(
          pc: pc,
          status: hardware.pcStatus,
          details: jsonEncode({
            ...hardware.toMap(),
            'checkedAt': DateTime.now().toIso8601String(),
            'source': 'global_pc_monitor',
            'studentEmail': _activeStudentEmail,
          }),
          lastStudentEmail: _activeStudentEmail,
        );
      }

      if (pc.isConfigured && newIssues.isNotEmpty) {
        await _saveFault(
          pc: pc,
          issues: newIssues,
          hardware: hardware,
        );
      }

      if (pc.isConfigured && recoveredIssues.isNotEmpty) {
        await _saveRecovery(pc: pc, recoveredIssues: recoveredIssues);
      }

      if (stateChanged) {
        _lastPresentedSignature = '';
        await _dismissActiveWarning();
      }

      if (currentIssues.isEmpty) {
        if (stateChanged || recoveredIssues.isNotEmpty) {
          _showRecoveryMessage();
        }
        if (stateChanged || recordsChanged) {
          await SyncService.instance.syncPendingData();
        }
        return hardware;
      }

      if (showWarnings) {
        await presentCurrentWarning();
      }

      if (stateChanged || recordsChanged) {
        await SyncService.instance.syncPendingData();
      }

      return hardware;
    } catch (_) {
      // Keep the monitor alive if one Windows scan or local write fails.
      return _latestHardware;
    } finally {
      _checking = false;
    }
  }

  Future<void> presentCurrentWarning() async {
    if (_currentIssueSignature.isEmpty) return;
    if (_lastPresentedSignature == _currentIssueSignature) return;

    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    await _bringWindowForward();

    final pc = await AppConfigService.instance.getPcIdentity();
    final hardware = _latestHardware;
    final sessionActive = hasActiveStudentSession;

    final Route<void> route;
    if (hardware.hasBlockingIssue) {
      route = MaterialPageRoute<void>(
        builder: (_) => PcBrokenScreen(
          pc: pc,
          hardware: hardware,
          sessionActive: sessionActive,
        ),
      );
    } else {
      route = MaterialPageRoute<void>(
        builder: (_) => MinorPeripheralWarningScreen(
          pc: pc,
          hardware: hardware,
          sessionActive: sessionActive,
          onContinueInBackground: sessionActive
              ? () => TrayService.instance.hideToTray()
              : null,
        ),
      );
    }

    _activeWarningRoute = route;
    _lastPresentedSignature = _currentIssueSignature;

    unawaited(
      navigator.push(route).whenComplete(() {
        if (identical(_activeWarningRoute, route)) {
          _activeWarningRoute = null;
        }
      }),
    );
  }

  Future<void> _saveFault({
    required PcIdentity pc,
    required List<String> issues,
    required HardwareStatus hardware,
  }) async {
    for (final issue in issues) {
      final alreadyOpen =
          await LocalDbService.instance.hasOpenAutomaticFault(
        pc: pc,
        issue: issue,
      );
      if (alreadyOpen) continue;

      await LocalDbService.instance.insertFaultReport(
        pc: pc,
        studentEmail: _activeStudentEmail,
        issue: issue,
        details: 'Automatically detected: $issue. '
            'Overall workstation severity: ${hardware.severity}.',
        severity: _severityFor([issue]),
        source: 'background_pc_monitor',
      );
    }
  }

  Future<void> _saveRecovery({
    required PcIdentity pc,
    required List<String> recoveredIssues,
  }) async {
    for (final issue in recoveredIssues) {
      await LocalDbService.instance.markAutomaticFaultRecovered(
        pc: pc,
        issue: issue,
      );
    }

    await LocalDbService.instance.insertFaultReport(
      pc: pc,
      studentEmail: _activeStudentEmail,
      issue: 'Recovered: ${recoveredIssues.join(', ')}',
      details: 'Syswatch automatically detected that the device or component '
          'is available again.',
      severity: 'info',
      source: 'automatic_recovery',
      recovered: true,
    );
  }

  String _severityFor(List<String> issues) {
    if (issues.any(
      (issue) =>
          issue == 'cpu' ||
          issue == 'ram' ||
          issue == 'disk' ||
          issue.startsWith('storage'),
    )) {
      return 'critical';
    }
    if (issues.contains('ethernet')) return 'high';
    return 'minor';
  }

  String _signature(List<String> issues) {
    final sorted = List<String>.from(issues)..sort();
    return sorted.join('|');
  }

  Future<bool> _dismissActiveWarning() async {
    final route = _activeWarningRoute;
    final navigator = appNavigatorKey.currentState;
    if (route == null || navigator == null || !route.isActive) {
      _activeWarningRoute = null;
      return false;
    }

    try {
      if (route.isCurrent) {
        navigator.pop();
      } else {
        navigator.removeRoute(route);
      }
      _activeWarningRoute = null;
      return true;
    } catch (_) {
      _activeWarningRoute = null;
      return false;
    }
  }

  Future<void> _bringWindowForward() async {
    try {
      await windowManager.show();
      await windowManager.restore();
      await windowManager.setFullScreen(true);
      await windowManager.focus();
    } catch (_) {}
  }

  void _showRecoveryMessage() {
    final context = appNavigatorKey.currentContext;
    if (context == null) return;

    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          hasActiveStudentSession
              ? 'Hardware recovered. The current student session is still active.'
              : 'Hardware recovered. This workstation is available again.',
        ),
      ),
    );
  }
}
