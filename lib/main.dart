import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';

import 'screens/system/startup_screen.dart';
import 'services/app_config_service.dart';
import 'services/app_navigator.dart';
import 'services/global_shortcut_service.dart';
import 'services/local_db_service.dart';
import 'services/pc_monitor_service.dart';
import 'services/pre_login_kiosk_service.dart';
import 'services/startup_service.dart';
import 'services/sync_service.dart';
import 'services/theme_service.dart';
import 'services/tray_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final isDesktop =
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  if (isDesktop) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    await windowManager.ensureInitialized();
    await PreLoginKioskService.instance.initialize();

    const windowOptions = WindowOptions(
      size: Size(1100, 720),
      minimumSize: Size(900, 650),
      center: true,
      title: 'Syswatch',
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await PreLoginKioskService.instance.lockForLogin();
    });

    await TrayService.instance.init();
    await StartupService.enableStartup();
  }

  await LocalDbService.instance.init();
  await AppConfigService.instance.init();
  await ThemeService.instance.init();

  runApp(const HybridPcMonitoringApp());

  await GlobalShortcutService.instance.init();
  await SyncService.instance.start();
  PcMonitorService.instance.start(checkImmediately: false);
}

class HybridPcMonitoringApp extends StatelessWidget {
  const HybridPcMonitoringApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.instance.themeMode,
      builder: (context, mode, child) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'Syswatch',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: ThemeData(
            colorSchemeSeed: Colors.blue,
            useMaterial3: true,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            colorSchemeSeed: Colors.blue,
            useMaterial3: true,
            brightness: Brightness.dark,
          ),
          home: const StartupScreen(),
        );
      },
    );
  }
}
