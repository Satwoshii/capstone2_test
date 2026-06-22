import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/app_config_service.dart';
import '../services/local_db_service.dart';
import '../services/sync_service.dart';
import '../services/windows_hardware_service.dart';
import 'pc_broken_screen.dart';
import 'role_select_screen.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  String message = 'Starting system...';

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() {
      message = 'Checking workstation configuration...';
    });

    final pc = await AppConfigService.instance.getPcIdentity();

    setState(() {
      message = 'Checking hardware and peripherals...';
    });

    final hardware = await WindowsHardwareService.checkHardware();

    await LocalDbService.instance.upsertPcStatus(
      pc: pc,
      status: hardware.hasIssue ? 'broken' : 'online',
      details: jsonEncode(hardware.toMap()),
    );

    if (hardware.hasIssue) {
      await LocalDbService.instance.insertFaultReport(
        pc: pc,
        issue: hardware.issues.first,
        details: hardware.issues.join(', '),
      );

      await SyncService.instance.syncNow();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PcBrokenScreen(
            pc: pc,
            hardware: hardware,
          ),
        ),
      );

      return;
    }

    await SyncService.instance.syncNow();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const RoleSelectScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  message,
                  style: const TextStyle(fontSize: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
