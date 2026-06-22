import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/issue_report.dart';
import '../services/local_db_service.dart';
import '../services/sync_service.dart';
import '../services/windows_hardware_service.dart';

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
  final _uuid = const Uuid();

  Timer? _monitorTimer;
  bool _checking = false;
  bool _dialogVisible = false;
  DateTime? _lastReportAt;

  @override
  void initState() {
    super.initState();

    _monitorTimer = Timer.periodic(
      const Duration(minutes: 2),
          (_) => _backgroundCheck(),
    );
  }

  Future<void> _backgroundCheck() async {
    if (_checking || _dialogVisible) return;

    _checking = true;

    try {
      final result = await WindowsHardwareService.checkHardware();
      final issues = result.failedComponents;

      if (issues.isEmpty || !mounted) return;

      if (_lastReportAt != null &&
          DateTime.now().difference(_lastReportAt!) <
              const Duration(minutes: 10)) {
        return;
      }

      _dialogVisible = true;

      final shouldSendReport = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          Timer(const Duration(seconds: 30), () {
            if (Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).pop(true);
            }
          });

          return AlertDialog(
            title: const Text('Hardware problem detected'),
            content: Text(
              'Detected: ${issues.join(', ')}.\n\n'
                  'Choose “Already fixed” if the device is working. '
                  'If there is no response within 30 seconds, the report is sent automatically.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Already fixed'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Send report'),
              ),
            ],
          );
        },
      );

      _dialogVisible = false;

      if (shouldSendReport == true) {
        await _saveAutoReport(issues);
      }
    } finally {
      _checking = false;
      _dialogVisible = false;
    }
  }

  Future<void> _saveAutoReport(List<String> issues) async {
    final report = IssueReport(
      id: _uuid.v4(),
      studentEmail: widget.studentEmail,
      pcNumber: widget.pcNumber,
      room: widget.room,
      issueType: issues.join(', '),
      description: 'Hardware problem detected during an active student session.',
      severity: 'high',
      source: 'background_hardware_check',
      detectedBySystem: true,
      createdAt: DateTime.now(),
    );

    await LocalDbService.instance.insertIssueReport(report.toLocalMap());

    _lastReportAt = DateTime.now();

    await SyncService.instance.syncPendingData();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('The issue report was saved.')),
    );
  }

  Future<void> _endSession() async {
    await LocalDbService.instance.markStudentSessionEnded(widget.logId);
    await SyncService.instance.syncPendingData();

    if (!mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  void dispose() {
    _monitorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Active Laboratory Session'),
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
                      'Hardware monitoring continues in the background. '
                          'Problems are saved locally first and synchronized to Firebase when available.',
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
                      onPressed: _endSession,
                      icon: const Icon(Icons.logout),
                      label: const Text('End Session'),
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