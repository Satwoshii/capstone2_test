import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/chat_message.dart';
import '../../models/support_issue.dart';
import '../../services/app_config_service.dart';
import '../../services/support_chat_service.dart';
import '../../services/theme_service.dart';

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

  static const Color _accA = Color(0xFF4FACFE);
  static const Color _accB = Color(0xFF7C5CFF);

  bool get _dark => Theme.of(context).brightness == Brightness.dark;

  Color get _bgColor    => _dark ? const Color(0xFF090A0E) : const Color(0xFFF0F2F5);
  Color get _cardColor  => _dark ? const Color(0xFF13141A) : Colors.white;
  Color get _fieldColor => _dark ? const Color(0xFF1C1E26) : const Color(0xFFEDF0F5);
  Color get _textColor  => _dark ? Colors.white : const Color(0xFF1A1C1E);
  Color get _borderCol  =>
      _dark ? const Color(0x12FFFFFF) : Colors.black.withOpacity(0.09);

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
      backgroundColor: _bgColor,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          _buildAmbientOrbs(),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 6),
                _buildHeaderCard(),
                if (_error != null) _buildErrorBanner(),
                Expanded(child: _buildMessageList()),
                _buildComposer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [_accA, _accB],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(bounds),
        child: const Text(
          'ITSO Support',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.3),
        ),
      ),
      iconTheme: IconThemeData(color: _textColor.withOpacity(0.85)),
      actions: [
        IconButton(
          onPressed: () => ThemeService.instance.toggleTheme(),
          icon: Icon(_dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
          tooltip: 'Toggle Theme',
        ),
        IconButton(
          tooltip: 'Refresh messages',
          onPressed: () => _loadMessages(scrollToBottom: true),
          icon: const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  Widget _buildAmbientOrbs() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(top: -90,  left:  -70, child: _orb(320, _accA.withOpacity(0.07))),
          Positioned(bottom: -110, right: -60, child: _orb(360, _accB.withOpacity(0.06))),
        ],
      ),
    );
  }

  Widget _orb(double size, Color color) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, Colors.transparent]),
    ),
  );

  Widget _buildHeaderCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _borderCol),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_dark ? 0.45 : 0.08),
              blurRadius: 32,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: LinearGradient(
                  colors: [_accA.withOpacity(0.18), _accB.withOpacity(0.12)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
              child: Icon(
                widget.issue.linkedFault
                    ? Icons.report_problem_rounded
                    : Icons.support_agent_rounded,
                color: _accA, size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.issue.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _textColor, fontSize: 15.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_categoryLabel(widget.issue.category)} · '
                        '${widget.issue.roomName} - ${widget.issue.pcId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _textColor.withOpacity(0.55), fontSize: 12.5),
                  ),
                  if (widget.issue.linkedFault) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Linked issue: ${widget.issue.issue} (${widget.issue.severity.toUpperCase()})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _textColor.withOpacity(0.45), fontSize: 11.5),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            _buildStatusPill(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _fieldColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderCol),
      ),
      child: Text(
        _conversationStatus.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(color: _textColor.withOpacity(0.60), fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.6),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5A623).withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF5A623).withOpacity(0.30)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: const Color(0xFFF5A623).withOpacity(0.85), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _error!,
                style: TextStyle(color: _textColor.withOpacity(0.80), fontSize: 13, height: 1.4),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _error = null),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFF5A623),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: _accA.withOpacity(0.8)));
    }
    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Send a message to ITSO Support.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textColor.withOpacity(0.45), fontSize: 14),
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _MessageBubble(
        message: _messages[index],
        dark: _dark,
        cardColor: _cardColor,
        textColor: _textColor,
        borderCol: _borderCol,
      ),
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _fieldColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _borderCol),
                ),
                child: TextField(
                  controller: _messageController,
                  enabled: _canChat && !_sending,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 4000,
                  style: TextStyle(color: _textColor, fontSize: 14.5),
                  decoration: InputDecoration(
                    hintText: _canChat
                        ? 'Type your message...'
                        : 'This request is resolved. Start a new request for more help.',
                    hintStyle: TextStyle(color: _textColor.withOpacity(0.35), fontSize: 13.5),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    counterText: '',
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _buildSendButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    final enabled = _canChat && !_sending;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: enabled
            ? const LinearGradient(colors: [_accA, _accB])
            : null,
        color: enabled ? null : _fieldColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: enabled
            ? [BoxShadow(color: _accA.withOpacity(0.30), blurRadius: 14, offset: const Offset(0, 5))]
            : null,
      ),
      child: IconButton(
        tooltip: 'Send message',
        onPressed: enabled ? _send : null,
        icon: _sending
            ? SizedBox(
          width: 18, height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white.withOpacity(0.9)),
        )
            : Icon(Icons.send_rounded, color: enabled ? Colors.white : _textColor.withOpacity(0.30)),
        style: IconButton.styleFrom(
          padding: const EdgeInsets.all(13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception:', '').trim();
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool dark;
  final Color cardColor;
  final Color textColor;
  final Color borderCol;

  const _MessageBubble({
    required this.message,
    required this.dark,
    required this.cardColor,
    required this.textColor,
    required this.borderCol,
  });

  static const Color _accA = Color(0xFF4FACFE);
  static const Color _accB = Color(0xFF7C5CFF);

  @override
  Widget build(BuildContext context) {
    final isMine = message.isStudent;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          gradient: isMine
              ? LinearGradient(
            colors: [_accA.withOpacity(0.85), _accB.withOpacity(0.85)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          )
              : null,
          color: isMine ? null : cardColor,
          borderRadius: BorderRadius.circular(16),
          border: isMine ? null : Border.all(color: borderCol),
          boxShadow: isMine
              ? [BoxShadow(color: _accA.withOpacity(0.22), blurRadius: 14, offset: const Offset(0, 6))]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isMine ? 'You' : message.senderName,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                color: isMine ? Colors.white.withOpacity(0.90) : textColor.withOpacity(0.75),
              ),
            ),
            const SizedBox(height: 5),
            SelectableText(
              message.message,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.4,
                color: isMine ? Colors.white : textColor.withOpacity(0.90),
              ),
            ),
            const SizedBox(height: 7),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _timeText(message.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: isMine ? Colors.white.withOpacity(0.70) : textColor.withOpacity(0.40),
                  ),
                ),
                if (message.pending) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.schedule_rounded, size: 13, color: isMine ? Colors.white.withOpacity(0.70) : textColor.withOpacity(0.40)),
                  const SizedBox(width: 2),
                  Text(
                    'Pending',
                    style: TextStyle(fontSize: 11, color: isMine ? Colors.white.withOpacity(0.70) : textColor.withOpacity(0.40)),
                  ),
                ] else if (isMine) ...[
                  const SizedBox(width: 6),
                  Icon(
                    message.read ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 14,
                    color: Colors.white.withOpacity(0.85),
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