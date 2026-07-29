import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../models/app_user.dart';
import '../models/pc_identity.dart';
import '../services/local_db_service.dart';
import '../services/pc_monitor_service.dart';
import '../services/sync_service.dart';
import '../services/tray_service.dart';
import 'student_login_screen.dart';

class StudentAccessScreen extends StatefulWidget {
  final AppUser user;
  final PcIdentity pc;
  final String loginLogId;

  const StudentAccessScreen({
    super.key,
    required this.user,
    required this.pc,
    required this.loginLogId,
  });

  @override
  State<StudentAccessScreen> createState() => _StudentAccessScreenState();
}

class _StudentAccessScreenState extends State<StudentAccessScreen> {
  Timer? _autoMinimizeTimer;
  int _secondsLeft = 5;

  @override
  void initState() {
    super.initState();
    PcMonitorService.instance.beginStudentSession(widget.user.email);
    _startAutoMinimizeTimer();
  }

  void _startAutoMinimizeTimer() {
    _autoMinimizeTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;

      setState(() {
        _secondsLeft--;
      });

      if (_secondsLeft <= 0) {
        timer.cancel();
        await _minimizeToBackground();
      }
    });
  }

  Future<void> _minimizeToBackground() async {
    try {
      await TrayService.instance.hideToTray();
    } catch (_) {}
  }

  Future<void> _logout(BuildContext context) async {
    _autoMinimizeTimer?.cancel();

    await LocalDbService.instance.logout(widget.loginLogId);
    await SyncService.instance.syncPendingData();
    PcMonitorService.instance.endStudentSession();

    try {
      await windowManager.restore();
      await windowManager.focus();
    } catch (_) {}

    if (!context.mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const StudentLoginScreen()),
    );
  }

  @override
  void dispose() {
    _autoMinimizeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.green.shade50,
        body: Center(
          child: SizedBox(
            width: 620,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 90,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'ACCESS GRANTED',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.user.displayName,
                      style: const TextStyle(fontSize: 24),
                    ),
                    Text(
                      widget.user.studentId ?? widget.user.email,
                      style: const TextStyle(fontSize: 18),
                    ),
                    const Divider(height: 36),
                    Text(
                      '${widget.pc.roomName} - ${widget.pc.pcId}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'This window will minimize in $_secondsLeft second(s).',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Hardware monitoring will continue in the background.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    ValueListenableBuilder<int>(
                      valueListenable: SyncService.instance.pendingItems,
                      builder: (_, pending, __) {
                        return Chip(
                          avatar: const Icon(Icons.sync, size: 18),
                          label: Text('$pending pending sync item(s)'),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _minimizeToBackground,
                          icon: const Icon(Icons.minimize),
                          label: const Text('Minimize Now'),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _logout(context),
                          icon: const Icon(Icons.logout),
                          label: const Text('Logout'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
