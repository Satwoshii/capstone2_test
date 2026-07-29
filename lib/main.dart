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
import 'services/global_shortcut_service.dart';
import 'services/local_db_service.dart';
import 'services/pc_monitor_service.dart';
import 'services/startup_service.dart';
import 'services/sync_service.dart';
import 'services/tray_service.dart';
import 'services/workstation_registry_service.dart';

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
      title: 'Syswatch',
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.maximize();
      await windowManager.setFullScreen(true);
      await windowManager.show();
      await windowManager.focus();
      await windowManager.setPreventClose(true);
    });

    await TrayService.instance.init();
    await StartupService.enableStartup();
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await LocalDbService.instance.init();
  await AppConfigService.instance.init();

  try {
    await WorkstationRegistryService.instance
        .restoreDevelopmentWorkstationSession();
  } catch (_) {
    // Previously enrolled workstations remain usable offline.
  }

  runApp(const HybridPcMonitoringApp());

  await GlobalShortcutService.instance.init();

  SyncService.instance.start();

  PcMonitorService.instance.start(checkImmediately: false);
}

class HybridPcMonitoringApp extends StatelessWidget {
  const HybridPcMonitoringApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Syswatch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const StartupScreen(),
    );
  }
}