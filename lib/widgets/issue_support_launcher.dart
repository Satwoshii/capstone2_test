import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/student/support_center_screen.dart';
import '../services/app_config_service.dart';
import '../services/support_chat_service.dart';

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
  bool _loading = true;
  bool _available = false;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final hasSession =
          await AppConfigService.instance.hasValidStudentApiSession();
      if (!hasSession) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _available = false;
          _unreadCount = 0;
        });
        return;
      }

      final conversations =
          await SupportChatService.instance.listConversations();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _available = true;
        _unreadCount = conversations.fold<int>(
          0,
          (total, item) => total + item.unreadCount,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _available = false;
      });
    }
  }

  Future<void> _openSupport() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SupportCenterScreen(),
      ),
    );
    await _refresh();
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
              title: Text('Connecting to ITSO Support...'),
            );
    }

    if (!_available) {
      return Tooltip(
        message: 'Log in online and connect to the intranet server to use chat.',
        child: OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.support_agent),
          label: Text(
            widget.compact
                ? 'ITSO Support offline'
                : 'ITSO Support requires an online Student login',
          ),
        ),
      );
    }

    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        padding: widget.compact
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
            : const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      ),
      onPressed: _openSupport,
      icon: const Icon(Icons.support_agent),
      label: Text(
        _unreadCount > 0
            ? 'ITSO Support ($_unreadCount new)'
            : 'Chat with ITSO Support',
      ),
    );
  }
}
