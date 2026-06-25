import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';

import 'firebase_options.dart';
import 'screens/system/startup_screen.dart';
import 'services/app_config_service.dart';
import 'services/app_navigator.dart';
import 'services/local_db_service.dart';
import 'services/pc_monitor_service.dart';
import 'services/startup_service.dart';
import 'services/sync_service.dart';
import 'services/tray_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final isDesktop =
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  if (isDesktop) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1100, 720),
      minimumSize: Size(900, 650),
      center: true,
      title: 'Hybrid PC Monitoring System',
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.maximize();
      await windowManager.setFullScreen(true);
      await windowManager.show();
      await windowManager.focus();

      // Kiosk-like behavior: prevent closing with the X button.
      await windowManager.setPreventClose(true);
    });

    // System tray icon.
    await TrayService.instance.init();

    // Auto-start on Windows boot.
    // This may not work during flutter run, but should work better in release build.
    await StartupService.enableStartup();
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await LocalDbService.instance.init();
  await AppConfigService.instance.init();

  // Show UI first before syncing.
  runApp(const HybridPcMonitoringApp());

  // Start sync in background.
  SyncService.instance.start();

  // Start PC monitoring even before student login.
  PcMonitorService.instance.start();
}

class HybridPcMonitoringApp extends StatelessWidget {
  const HybridPcMonitoringApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Hybrid PC Monitoring System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const StartupScreen(),
    );
  }
}