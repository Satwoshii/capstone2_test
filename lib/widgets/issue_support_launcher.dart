import 'dart:async';

import 'package:flutter/material.dart';

import '../models/support_issue.dart';
import '../screens/student/support_chat_screen.dart';
import '../services/app_config_service.dart';
import '../services/local_db_service.dart';
import '../services/support_chat_service.dart';
import '../services/sync_service.dart';

class IssueSupportLauncher extends StatefulWidget {
  final bool compact;

  const IssueSupportLauncher({
    super.key,
    this.compact = false,
  });

  @override
  State<IssueSupportLauncher> createState() => _IssueSupportLauncherState();
}

class _IssueSupportLauncherState extends State<IssueSupportLauncher> {
  Timer? _timer;
  List<SupportIssue> _issues = const [];
  bool _loading = true;
  bool _opening = false;
  bool _refreshing = false;
  bool _localIssueWaitingForSync = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted || _opening || _refreshing) return;
    _refreshing = true;

    try {
      final hasSession =
          await AppConfigService.instance.hasValidStudentApiSession();
      if (!hasSession) {
        final local = await LocalDbService.instance.getOpenFaultReports();
        if (!mounted) return;
        setState(() {
          _issues = const [];
          _localIssueWaitingForSync = local.isNotEmpty;
          _error = 'Online student login is required for ITSO Support Chat.';
          _loading = false;
        });
        return;
      }

      await SyncService.instance.syncPendingData();
      final issues = await SupportChatService.instance.listActiveIssues();
      if (!mounted) return;
      setState(() {
        _issues = issues;
        _localIssueWaitingForSync = false;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      final local = await LocalDbService.instance.getOpenFaultReports();
      if (!mounted) return;
      setState(() {
        _issues = const [];
        _localIssueWaitingForSync = local.isNotEmpty;
        _error = error.toString();
        _loading = false;
      });
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _openIssue(SupportIssue selected) async {
    if (_opening) return;
    setState(() => _opening = true);

    try {
      final issue = selected.hasConversation
          ? selected
          : await SupportChatService.instance.openConversation(
              selected.faultReportId,
            );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SupportChatScreen(issue: issue),
        ),
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cleanError(error))),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _chooseIssue() async {
    if (_issues.isEmpty) return;
    if (_issues.length == 1) {
      await _openIssue(_issues.first);
      return;
    }

    final selected = await showModalBottomSheet<SupportIssue>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              const ListTile(
                title: Text(
                  'Choose an active PC issue',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Each issue has its own support conversation.'),
              ),
              for (final issue in _issues)
                ListTile(
                  leading: CircleAvatar(
                    child: Text(issue.severity.trim().isEmpty ? '?' : issue.severity.trim()[0].toUpperCase()),
                  ),
                  title: Text(issue.issue),
                  subtitle: Text(
                    '${issue.roomName} - ${issue.pcId}\n'
                    '${issue.severity.toUpperCase()}',
                  ),
                  isThreeLine: true,
                  trailing: issue.unreadCount > 0
                      ? Badge(label: Text('${issue.unreadCount}'))
                      : const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, issue),
                ),
            ],
          ),
        );
      },
    );

    if (selected != null) await _openIssue(selected);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return widget.compact
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const ListTile(
              leading: CircularProgressIndicator(strokeWidth: 2),
              title: Text('Checking ITSO Support availability...'),
            );
    }

    final unread = _issues.fold<int>(
      0,
      (total, issue) => total + issue.unreadCount,
    );

    if (_issues.isNotEmpty) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          padding: widget.compact
              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
              : const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        ),
        onPressed: _opening ? null : _chooseIssue,
        icon: _opening
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.support_agent),
        label: Text(
          unread > 0
              ? 'Chat with ITSO Support ($unread new)'
              : 'Chat with ITSO Support (${_issues.length} issue${_issues.length == 1 ? '' : 's'})',
        ),
      );
    }

    final message = _localIssueWaitingForSync
        ? 'Issue saved locally. Chat will open after the issue synchronizes.'
        : (_error != null
            ? 'ITSO Support is unavailable until an active issue is online.'
            : 'ITSO Support opens only when this PC has an active issue.');

    return Tooltip(
      message: _error == null ? message : '$message\n${_cleanError(_error!)}',
      child: OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.support_agent),
        label: Text(widget.compact ? 'ITSO Support unavailable' : message),
      ),
    );
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception:', '').trim();
  }
}
