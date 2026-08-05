import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/support_issue.dart';
import '../../services/support_chat_service.dart';
import '../../services/theme_service.dart';
import 'new_support_request_screen.dart';
import 'support_chat_screen.dart';

class SupportCenterScreen extends StatefulWidget {
  const SupportCenterScreen({super.key});

  @override
  State<SupportCenterScreen> createState() => _SupportCenterScreenState();
}

class _SupportCenterScreenState extends State<SupportCenterScreen> {
  Timer? _timer;
  List<SupportIssue> _conversations = const [];
  bool _loading = true;
  bool _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final rows = await SupportChatService.instance.listConversations();
      rows.sort((a, b) {
        if (a.unreadCount != b.unreadCount) {
          return b.unreadCount.compareTo(a.unreadCount);
        }
        final aTime = a.updatedAt ?? a.createdAt;
        final bTime = b.updatedAt ?? b.createdAt;
        return (bTime ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
          aTime ?? DateTime.fromMillisecondsSinceEpoch(0),
        );
      });
      if (!mounted) return;
      setState(() {
        _conversations = rows;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _cleanError(error);
      });
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _newRequest() async {
    final conversation = await Navigator.push<SupportIssue>(
      context,
      MaterialPageRoute(
        builder: (_) => const NewSupportRequestScreen(),
      ),
    );
    if (!mounted || conversation == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupportChatScreen(issue: conversation),
      ),
    );
    await _refresh();
  }

  Future<void> _open(SupportIssue conversation) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupportChatScreen(issue: conversation),
      ),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ITSO Support'),
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
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshing ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newRequest,
        icon: const Icon(Icons.add_comment),
        label: const Text('New Request'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off, size: 50),
                  const SizedBox(height: 12),
                  const Text(
                    'ITSO Support is unavailable',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (_conversations.isEmpty) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.support_agent, size: 64),
                  const SizedBox(height: 14),
                  const Text(
                    'How can ITSO help?',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create a support request for hardware, software, network, '
                    'account, or general laboratory assistance.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _newRequest,
                    icon: const Icon(Icons.add_comment),
                    label: const Text('Start a Conversation'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _conversations.length,
        itemBuilder: (context, index) {
          final item = _conversations[index];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Icon(_categoryIcon(item.category)),
              ),
              title: Text(item.subject),
              subtitle: Text(
                '${_categoryLabel(item.category)} • '
                '${item.roomName} - ${item.pcId}\n'
                '${_statusLabel(item.conversationStatus ?? 'open')}',
              ),
              isThreeLine: true,
              trailing: item.unreadCount > 0
                  ? Badge(label: Text('${item.unreadCount}'))
                  : const Icon(Icons.chevron_right),
              onTap: () => _open(item),
            ),
          );
        },
      ),
    );
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception:', '').trim();
  }
}

String _categoryLabel(String value) {
  switch (value.trim().toLowerCase()) {
    case 'hardware':
      return 'Hardware';
    case 'peripheral':
      return 'Peripheral';
    case 'network':
      return 'Network';
    case 'software':
      return 'Software';
    case 'account':
      return 'Account or Login';
    case 'other':
      return 'Other';
    default:
      return 'General Assistance';
  }
}

IconData _categoryIcon(String value) {
  switch (value.trim().toLowerCase()) {
    case 'hardware':
      return Icons.memory;
    case 'peripheral':
      return Icons.keyboard;
    case 'network':
      return Icons.lan;
    case 'software':
      return Icons.apps;
    case 'account':
      return Icons.manage_accounts;
    case 'other':
      return Icons.help_outline;
    default:
      return Icons.support_agent;
  }
}

String _statusLabel(String value) {
  return value
      .split('_')
      .map((word) => word.isEmpty
          ? ''
          : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
