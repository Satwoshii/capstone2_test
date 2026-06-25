import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../models/hardware_status.dart';
import '../models/pc_identity.dart';
import '../screens/student/pc_broken_screen.dart';
import 'app_config_service.dart';
import 'app_navigator.dart';
import 'local_db_service.dart';
import 'sync_service.dart';
import 'windows_hardware_service.dart';

class PcMonitorService {
  PcMonitorService._();

  static final PcMonitorService instance = PcMonitorService._();

  Timer? _timer;
  bool _checking = false;
  bool _warningShown = false;
  DateTime? _lastReportAt;
  List<String> _lastIssues = [];

  void clearWarningState() {
    _warningShown = false;
    _lastIssues = [];
    _lastReportAt = null;
  }

  Future<void> start() async {
    await checkNow();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await checkNow();
    });
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> checkNow() async {
    if (_checking) return;

    _checking = true;

    try {
      final pc = await AppConfigService.instance.getPcIdentity();
      final hardware = await WindowsHardwareService.checkHardware();

      await LocalDbService.instance.upsertPcStatus(
        pc: pc,
        status: hardware.hasIssue ? 'broken' : 'online',
        details: jsonEncode({
          ...hardware.toMap(),
          'checkedAt': DateTime.now().toIso8601String(),
          'source': 'background_pc_monitor',
        }),
      );

      if (!hardware.hasIssue) {
        _warningShown = false;
        await SyncService.instance.syncPendingData();
        return;
      }

      final issues = hardware.failedComponents.isNotEmpty
          ? hardware.failedComponents
          : hardware.issues;

      await _saveFaultIfNeeded(
        pc: pc,
        issues: issues,
        details: _detailsForIssue(hardware),
      );

      await SyncService.instance.syncPendingData();

      if (!_warningShown) {
        _warningShown = true;
        await _showPcBrokenWarning(pc: pc, hardware: hardware);
      }
    } catch (_) {
      // Keep monitor alive even if a single scan fails.
    } finally {
      _checking = false;
    }
  }

  String _detailsForIssue(HardwareStatus hardware) {
    if (hardware.hasPcHealthIssue) {
      return 'PC health issue detected automatically. Student should use another workstation and contact ITSO. Issues: ${hardware.pcHealthIssues.join(', ')}';
    }

    return 'Peripheral issue detected automatically. Suggested checks may be shown to the student. Issues: ${hardware.peripheralIssues.join(', ')}';
  }

  Future<void> _saveFaultIfNeeded({
    required PcIdentity pc,
    required List<String> issues,
    required String details,
  }) async {
    if (issues.isEmpty) return;

    final now = DateTime.now();
    final sameIssue = _sameList(_lastIssues, issues);
    final recentlyReported = _lastReportAt != null &&
        now.difference(_lastReportAt!) < const Duration(minutes: 10);

    if (sameIssue && recentlyReported) {
      return;
    }

    await LocalDbService.instance.insertFaultReport(
      pc: pc,
      issue: issues.join(', '),
      details: details,
    );

    _lastIssues = List<String>.from(issues);
    _lastReportAt = now;
  }

  Future<void> _showPcBrokenWarning({
    required PcIdentity pc,
    required HardwareStatus hardware,
  }) async {
    try {
      await windowManager.show();
      await windowManager.restore();
      await windowManager.setFullScreen(true);
      await windowManager.focus();
    } catch (_) {}

    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => PcBrokenScreen(
          pc: pc,
          hardware: hardware,
        ),
      ),
      (route) => false,
    );
  }

  bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;

    final sortedA = List<String>.from(a)..sort();
    final sortedB = List<String>.from(b)..sort();

    for (int i = 0; i < sortedA.length; i++) {
      if (sortedA[i] != sortedB[i]) return false;
    }

    return true;
  }
}
