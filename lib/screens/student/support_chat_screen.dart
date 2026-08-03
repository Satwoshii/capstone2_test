import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/chat_message.dart';
import '../../models/support_issue.dart';
import '../../services/app_config_service.dart';
import '../../services/support_chat_service.dart';

class SupportChatScreen extends StatefulWidget {
  final SupportIssue issue;

  const SupportChatScreen({
    super.key,
    required this.issue,
  });

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _timer;
  List<ChatMessage> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  String _studentUid = '';
  late String _conversationStatus;
  late bool _canChat;

  int get _conversationId => widget.issue.conversationId ?? 0;

  @override
  void initState() {
    super.initState();
    _conversationStatus = widget.issue.conversationStatus ?? 'open';
    _canChat = widget.issue.canChat;
    _initialize();
  }

  Future<void> _initialize() async {
    _studentUid = await AppConfigService.instance.getStudentTokenUid();
    await _loadMessages(scrollToBottom: true);
    if (!mounted) return;
    _timer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _loadMessages(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool scrollToBottom = false}) async {
    if (_conversationId <= 0 || _studentUid.isEmpty) return;
    try {
      final snapshot = await SupportChatService.instance.listMessages(
        conversationId: _conversationId,
        currentStudentUid: _studentUid,
      );
      await SupportChatService.instance.markRead(_conversationId);
      if (!mounted) return;
      final previousLength = _messages.length;
      setState(() {
        _messages = snapshot.messages;
        _conversationStatus = snapshot.status;
        _canChat = snapshot.canChat;
        _error = null;
        _loading = false;
      });
      if (scrollToBottom || snapshot.messages.length != previousLength) {
        _scrollAfterBuild();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _cleanError(error);
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    if (_sending || !_canChat) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      final sent = await SupportChatService.instance.sendMessage(
        conversationId: _conversationId,
        faultReportId: widget.issue.faultReportId,
        senderUserUid: _studentUid,
        message: text,
      );
      _messageController.clear();
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, sent];
        _error = sent.pending
            ? 'Server unavailable. The message is pending and will sync automatically.'
            : null;
      });
      _scrollAfterBuild();
      if (!sent.pending) await _loadMessages(scrollToBottom: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cleanError(error))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollAfterBuild() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ITSO Support'),
        actions: [
          IconButton(
            tooltip: 'Refresh messages',
            onPressed: () => _loadMessages(scrollToBottom: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    child: Icon(
                      widget.issue.linkedFault
                          ? Icons.report_problem
                          : Icons.support_agent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.issue.subject,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_categoryLabel(widget.issue.category)} • '
                          '${widget.issue.roomName} - ${widget.issue.pcId}',
                        ),
                        if (widget.issue.linkedFault)
                          Text(
                            'Linked issue: ${widget.issue.issue} '
                            '(${widget.issue.severity.toUpperCase()})',
                          ),
                      ],
                    ),
                  ),
                  Chip(
                    label: Text(
                      _conversationStatus
                          .replaceAll('_', ' ')
                          .toUpperCase(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              leading: const Icon(Icons.info_outline),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _error = null),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text(
                          'Send a message to ITSO Support.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          return _MessageBubble(message: _messages[index]);
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: _canChat && !_sending,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 4000,
                      decoration: InputDecoration(
                        hintText: _canChat
                            ? 'Type your message...'
                            : 'This request is resolved. Start a new request for more help.',
                        border: const OutlineInputBorder(),
                        counterText: '',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    tooltip: 'Send message',
                    onPressed: _canChat && !_sending ? _send : null,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception:', '').trim();
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isMine = message.isStudent;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMine
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isMine ? 'You' : message.senderName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            SelectableText(message.message),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _timeText(message.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (message.pending) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.schedule, size: 14),
                  const SizedBox(width: 2),
                  const Text('Pending'),
                ] else if (isMine) ...[
                  const SizedBox(width: 6),
                  Icon(
                    message.read ? Icons.done_all : Icons.done,
                    size: 15,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _timeText(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.month}/${local.day} $hour:$minute';
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
