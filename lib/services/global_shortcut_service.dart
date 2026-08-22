import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/staff/pc_config_admin_login_screen.dart';
import '../screens/student/support_center_screen.dart';
import 'app_config_service.dart';
import 'app_navigator.dart';
import 'pc_monitor_service.dart';
import 'pre_login_kiosk_service.dart';
import 'tray_service.dart';

class GlobalShortcutService {
  GlobalShortcutService._();

  static final GlobalShortcutService instance = GlobalShortcutService._();

  static const MethodChannel _channel =
      MethodChannel('syswatch/global_shortcut');

  bool _initialized = false;
  bool _configurationOpen = false;
  bool _supportOpen = false;
  int _deletePressCount = 0;
  DateTime? _deleteSequenceStartedAt;

  Future<void> init() async {
    if (_initialized || !Platform.isWindows) return;

    _initialized = true;

    HardwareKeyboard.instance.addHandler(_handleFailsafeKeyEvent);

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openPcConfiguration') {
        await openPcConfiguration();
      } else if (call.method == 'openStudentSupport') {
        await openStudentSupport();
      }
    });
  }

  bool _handleFailsafeKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final supportShortcut =
        (event.logicalKey == LogicalKeyboardKey.keyS &&
            HardwareKeyboard.instance.isControlPressed &&
            HardwareKeyboard.instance.isAltPressed) ||
        (event.logicalKey == LogicalKeyboardKey.keyH &&
            HardwareKeyboard.instance.isControlPressed &&
            HardwareKeyboard.instance.isShiftPressed);
    if (supportShortcut) {
      _resetDeleteSequence();
      unawaited(openStudentSupport());
      return true;
    }

    if (!PreLoginKioskService.instance.isLocked) {
      _resetDeleteSequence();
      return false;
    }

    if (event.logicalKey != LogicalKeyboardKey.delete) {
      _resetDeleteSequence();
      return false;
    }

    final now = DateTime.now();
    final startedAt = _deleteSequenceStartedAt;
    if (startedAt == null ||
        now.difference(startedAt) > const Duration(seconds: 2)) {
      _deleteSequenceStartedAt = now;
      _deletePressCount = 1;
      return false;
    }

    _deletePressCount++;
    if (_deletePressCount < 3) return false;

    _resetDeleteSequence();
    unawaited(
      PreLoginKioskService.instance.cancelFullscreenWithFailsafe(),
    );
    return true;
  }

  void _resetDeleteSequence() {
    _deletePressCount = 0;
    _deleteSequenceStartedAt = null;
  }

  Future<void> openPcConfiguration() async {
    if (_configurationOpen) return;

    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    _configurationOpen = true;

    try {
      await PreLoginKioskService.instance.showWindow();

      await navigator.push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => const PcConfigAdminLoginScreen(),
        ),
      );
    } finally {
      _configurationOpen = false;
    }
  }

  Future<void> openStudentSupport() async {
    if (_supportOpen) {
      await TrayService.instance.showFromTray();
      return;
    }

    _supportOpen = true;
    try {
      final hasActiveSession =
          PcMonitorService.instance.hasActiveStudentSession;
      final hasValidApiSession = hasActiveSession &&
          await AppConfigService.instance.hasValidStudentApiSession();

      if (!hasValidApiSession) {
        await PreLoginKioskService.instance.showWindow();
        return;
      }

      await TrayService.instance.showFromTray();

      final navigator = appNavigatorKey.currentState;
      if (navigator == null) return;

      await navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const SupportCenterScreen(),
        ),
      );
    } finally {
      _supportOpen = false;
    }
  }
}
