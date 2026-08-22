import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/local_db_service.dart';
import '../../services/pc_monitor_service.dart';
import '../../services/pre_login_kiosk_service.dart';
import '../../services/sync_service.dart';
import '../../services/theme_service.dart';
import 'student_login_screen.dart';

class StudentBlockScreen extends StatefulWidget {
  final String logId;
  final String studentEmail;
  final String pcNumber;
  final String room;

  const StudentBlockScreen({
    super.key,
    required this.logId,
    required this.studentEmail,
    required this.pcNumber,
    required this.room,
  });

  @override
  State<StudentBlockScreen> createState() => _StudentBlockScreenState();
}

class _StudentBlockScreenState extends State<StudentBlockScreen> {
  bool _endingSession = false;

  @override
  void initState() {
    super.initState();
    PcMonitorService.instance.beginStudentSession(widget.studentEmail);
    unawaited(PreLoginKioskService.instance.releaseAfterLogin());
  }

  Future<void> _endSession() async {
    if (_endingSession) return;
    setState(() => _endingSession = true);

    await LocalDbService.instance.markStudentSessionEnded(widget.logId);
    try {
      await SyncService.instance.syncPendingData();
    } catch (_) {
      // Pending records will synchronize when the intranet is available.
    }
    PcMonitorService.instance.endStudentSession();
    await PreLoginKioskService.instance.lockForLogin();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const StudentLoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Active Laboratory Session'),
          actions: [
            IconButton(
              onPressed: () => ThemeService.instance.toggleTheme(),
              icon: Icon(
                Theme.of(context).brightness == Brightness.dark
                    ? Icons.light_mode
                    : Icons.dark_mode,
              ),
              tooltip: 'Toggle Theme',
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_user, size: 72),
                    const SizedBox(height: 16),
                    Text(
                      'Authentication and form completed',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(widget.studentEmail),
                    Text('PC ${widget.pcNumber} • Room ${widget.room}'),
                    const SizedBox(height: 18),
                    const Text(
                      'The single Syswatch monitor continues in the '
                      'background. Minor peripheral problems do not end this '
                      'session.',
                      textAlign: TextAlign.center,
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
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _endingSession ? null : _endSession,
                      icon: const Icon(Icons.logout),
                      label: Text(
                        _endingSession ? 'Ending session...' : 'End Session',
                      ),
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
