import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../models/hardware_status.dart';
import '../../models/pc_identity.dart';
import '../../services/app_config_service.dart';
import '../../services/local_db_service.dart';
import '../../services/pc_monitor_service.dart';
import '../../services/sync_service.dart';
import '../../services/windows_hardware_service.dart';
import '../staff/pc_config_admin_login_screen.dart';
import 'student_login_screen.dart';

class PcBrokenScreen extends StatefulWidget {
  final PcIdentity pc;
  final HardwareStatus hardware;

  const PcBrokenScreen({
    super.key,
    required this.pc,
    required this.hardware,
  });

  @override
  State<PcBrokenScreen> createState() => _PcBrokenScreenState();
}

class _PcBrokenScreenState extends State<PcBrokenScreen> {
  late HardwareStatus hardware;
  Timer? _autoRecheckTimer;
  bool checking = false;
  int secondsUntilNextCheck = 5;

  @override
  void initState() {
    super.initState();
    hardware = widget.hardware;
    _startAutoRecheck();
  }

  void _startAutoRecheck() {
    _autoRecheckTimer?.cancel();
    _autoRecheckTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      setState(() {
        secondsUntilNextCheck--;
      });

      if (secondsUntilNextCheck <= 0) {
        secondsUntilNextCheck = 5;
        _recheckHardware();
      }
    });
  }

  String get issueText {
    final failed = hardware.failedComponents;

    if (failed.isNotEmpty) {
      return failed.join('\n');
    }

    if (hardware.issues.isNotEmpty) {
      return hardware.issues.join('\n');
    }

    return 'Unknown issue';
  }

  List<String> get suggestions {
    final tips = <String>[];

    for (final issue in hardware.peripheralIssues) {
      switch (issue) {
        case 'mouse':
          tips.add('Check if the mouse USB cable is properly connected.');
          tips.add('Try plugging the mouse into another USB port.');
          tips.add('Check if the mouse sensor light is on.');
          break;

        case 'keyboard':
          tips.add('Check if the keyboard USB cable is properly connected.');
          tips.add('Try plugging the keyboard into another USB port.');
          tips.add('Check if Num Lock or Caps Lock responds.');
          break;

        case 'monitor':
          tips.add('Check if the monitor power cable is connected.');
          tips.add('Check the HDMI/VGA cable connection.');
          tips.add('Make sure the monitor is turned on.');
          break;

        case 'ethernet':
          tips.add('Check if the LAN cable is properly connected.');
          tips.add('Check if the Ethernet port light is blinking.');
          tips.add('Make sure the LAN cable is not damaged or loose.');
          break;
      }
    }

    return tips.toSet().toList();
  }

  bool get showSuggestions {
    return hardware.hasPeripheralIssue && !hardware.hasPcHealthIssue;
  }

  String get warningMessage {
    if (hardware.hasPcHealthIssue) {
      return 'Please use another workstation and contact ITSO.';
    }

    return 'Try the suggested checks below. The system will automatically recheck. If the issue still continues, use another workstation and contact ITSO.';
  }

  Future<void> _recheckHardware() async {
    if (checking) return;

    setState(() {
      checking = true;
    });

    try {
      final pc = await AppConfigService.instance.getPcIdentity();
      final newStatus = await WindowsHardwareService.checkHardware();

      await LocalDbService.instance.upsertPcStatus(
        pc: pc,
        status: newStatus.hasIssue ? 'broken' : 'online',
        details: jsonEncode({
          ...newStatus.toMap(),
          'checkedAt': DateTime.now().toIso8601String(),
          'source': 'pc_broken_auto_recheck',
        }),
      );

      await SyncService.instance.syncPendingData();

      if (!mounted) return;

      if (!newStatus.hasIssue) {
        _autoRecheckTimer?.cancel();
        PcMonitorService.instance.clearWarningState();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Problem fixed. PC is now available.'),
          ),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const StudentLoginScreen()),
          (route) => false,
        );

        return;
      }

      setState(() {
        hardware = newStatus;
      });
    } finally {
      if (mounted) {
        setState(() {
          checking = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _autoRecheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.red.shade900,
        body: Center(
          child: Container(
            width: 820,
            constraints: const BoxConstraints(maxHeight: 760),
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red,
                    size: 90,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'PC BROKEN',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 46,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Issue Detected:',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    issueText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    warningMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 18),
                  Chip(
                    avatar: checking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: Text(
                      checking
                          ? 'Rechecking hardware...'
                          : 'Auto recheck in $secondsUntilNextCheck second(s)',
                    ),
                  ),
                  if (showSuggestions && suggestions.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Suggested Checks:',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...suggestions.map(
                      (tip) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.tips_and_updates),
                        title: Text(
                          tip,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 26),
                  Text(
                    '${widget.pc.roomName} - ${widget.pc.pcId}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PcConfigAdminLoginScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.admin_panel_settings),
                    label: const Text('Admin PC Config Override'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
