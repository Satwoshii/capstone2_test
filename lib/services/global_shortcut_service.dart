import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../screens/staff/pc_config_admin_login_screen.dart';
import 'app_navigator.dart';

class GlobalShortcutService {
  GlobalShortcutService._();

  static final GlobalShortcutService instance = GlobalShortcutService._();

  static const MethodChannel _channel =
      MethodChannel('syswatch/global_shortcut');

  bool _initialized = false;
  bool _configurationOpen = false;

  Future<void> init() async {
    if (_initialized || !Platform.isWindows) return;

    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openPcConfiguration') {
        await openPcConfiguration();
      }
    });
  }

  Future<void> openPcConfiguration() async {
    if (_configurationOpen) return;

    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    _configurationOpen = true;

    try {
      await windowManager.show();
      await windowManager.restore();
      await windowManager.setFullScreen(true);
      await windowManager.focus();

      await navigator.push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => const PcConfigAdminLoginScreen(),
        ),
      );
    } finally {
      _configurationOpen = false;
    }
  }
}
