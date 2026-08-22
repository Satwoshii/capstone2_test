import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/chat_message.dart';
import '../../models/support_issue.dart';
import '../../services/app_config_service.dart';
import '../../services/support_chat_service.dart';
import '../../services/theme_service.dart';

class SupportChatScreen extends StatefulWidget {
  final SupportIssue issue;
  final bool embedded;

  const SupportChatScreen({
    super.key,
    required this.issue,
    this.embedded = false,
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

  static const Color _messengerBlue = Color(0xFF168AFF);

  bool get _dark => Theme.of(context).brightness == Brightness.dark;

  Color get _background =>
      _dark ? const Color(0xFF0B0C10) : const Color(0xFFF0F2F5);
  Color get _surface => _dark ? const Color(0xFF17181E) : Colors.white;
  Color get _inputFill =>
      _dark ? const Color(0xFF24262E) : const Color(0xFFF0F2F5);
  Color get _text =>
      _dark ? const Color(0xFFF4F5F7) : const Color(0xFF16171A);
  Color get _muted =>
      _dark ? const Color(0xFFA6A9B2) : const Color(0xFF667085);
  Color get _divider =>
      _dark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08);

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
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() => _sending = true);
    try {
      final sent = await SupportChatService.instance.sendMessage(
        conversationId: _conversationId,
        faultReportId: widget.issue.faultReportId,
        senderUserUid: _studentUid,
        message: message,
      );
      _messageController.clear();
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, sent];
        _error = sent.pending
            ? 'You are offline. This message is queued and will send automatically.'
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
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildTopicBar(),
          if (_error != null) _buildErrorBanner(),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (widget.embedded) _buildChatBackdrop(),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: _buildMessageList(),
                  ),
                ),
              ],
            ),
          ),
          _buildComposer(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: !widget.embedded,
      toolbarHeight: 72,
      backgroundColor: _surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: Border(bottom: BorderSide(color: _divider)),
      iconTheme: IconThemeData(color: _text),
      titleSpacing: widget.embedded ? 18 : 4,
      title: Row(
        children: [
          const _SupportAvatar(size: 44, showOnlineDot: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ITSO Support',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _text,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF31C48D),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        _canChat
                            ? 'Support conversation'
                            : 'Conversation closed',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Conversation details',
          onPressed: _showConversationDetails,
          icon: const Icon(Icons.info_outline_rounded),
        ),
        IconButton(
          tooltip: 'Refresh messages',
          onPressed: () => _loadMessages(scrollToBottom: true),
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          tooltip: 'Toggle theme',
          onPressed: () => ThemeService.instance.toggleTheme(),
          icon: Icon(
            _dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildTopicBar() {
    final statusColor = _statusColor(_conversationStatus);
    return Material(
      color: _surface,
      child: InkWell(
        onTap: _showConversationDetails,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: _divider)),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Row(
                children: [
                  Icon(
                    widget.issue.linkedFault
                        ? Icons.report_problem_rounded
                        : _categoryIcon(widget.issue.category),
                    color: statusColor,
                    size: 19,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.issue.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _text,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel(_conversationStatus),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: _muted,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF59E0B).withOpacity(_dark ? 0.16 : 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Row(
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: Color(0xFFF59E0B),
                size: 18,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _error!,
                  style: TextStyle(color: _text, fontSize: 12.5),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _error = null),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatBackdrop() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.15, -0.10),
                  radius: 1.15,
                  colors: [
                    _messengerBlue.withOpacity(_dark ? 0.055 : 0.045),
                    _background,
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Icon(
              Icons.support_agent_rounded,
              size: 360,
              color: _text.withOpacity(_dark ? 0.018 : 0.022),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _messengerBlue),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SupportAvatar(size: 72, showOnlineDot: true),
              const SizedBox(height: 16),
              Text(
                'ITSO Support',
                style: TextStyle(
                  color: _text,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Send a message to begin this support conversation.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 13.5),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final previous = index > 0 ? _messages[index - 1] : null;
        final next =
            index < _messages.length - 1 ? _messages[index + 1] : null;
        final showDate = previous == null ||
            !_sameDay(previous.createdAt, message.createdAt);
        final joinsPrevious = previous != null &&
            !showDate &&
            _sameSender(previous, message) &&
            _closeInTime(previous.createdAt, message.createdAt);
        final joinsNext = next != null &&
            _sameDay(message.createdAt, next.createdAt) &&
            _sameSender(message, next) &&
            _closeInTime(message.createdAt, next.createdAt);

        return Column(
          children: [
            if (showDate)
              _DateSeparator(
                label: _dateLabel(message.createdAt),
                dark: _dark,
              ),
            _MessageBubble(
              message: message,
              joinsPrevious: joinsPrevious,
              joinsNext: joinsNext,
              dark: _dark,
            ),
          ],
        );
      },
    );
  }

  Widget _buildComposer() {
    return Material(
      color: _surface,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: _divider)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: _canChat
                  ? _buildActiveComposer()
                  : _buildClosedComposer(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveComposer() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 38,
          height: 38,
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            color: _messengerBlue.withOpacity(0.11),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.support_agent_rounded,
            color: _messengerBlue,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _inputFill,
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              controller: _messageController,
              enabled: !_sending,
              minLines: 1,
              maxLines: 5,
              maxLength: 4000,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                color: _text,
                fontSize: 14.5,
                height: 1.35,
              ),
              decoration: InputDecoration(
                hintText: 'Message ITSO Support',
                hintStyle: TextStyle(color: _muted, fontSize: 14),
                border: InputBorder.none,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 17,
                  vertical: 11,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _messageController,
          builder: (context, value, _) {
            final enabled = value.text.trim().isNotEmpty && !_sending;
            return SizedBox(
              width: 42,
              height: 42,
              child: IconButton(
                tooltip: 'Send message',
                onPressed: enabled ? _send : null,
                style: IconButton.styleFrom(
                  backgroundColor: _messengerBlue,
                  disabledBackgroundColor: _inputFill,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: _muted.withOpacity(0.55),
                ),
                icon: _sending
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 20),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildClosedComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: _inputFill,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline_rounded, color: _muted, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'This conversation is closed. Start a new request if you need more help.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showConversationDetails() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Icon(
                _categoryIcon(widget.issue.category),
                color: _messengerBlue,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Conversation details',
                  style: TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow(
                  label: 'Subject',
                  value: widget.issue.subject,
                  textColor: _text,
                  mutedColor: _muted,
                ),
                _DetailRow(
                  label: 'Category',
                  value: _categoryLabel(widget.issue.category),
                  textColor: _text,
                  mutedColor: _muted,
                ),
                _DetailRow(
                  label: 'Workstation',
                  value: '${widget.issue.roomName} - ${widget.issue.pcId}',
                  textColor: _text,
                  mutedColor: _muted,
                ),
                _DetailRow(
                  label: 'Status',
                  value: _statusLabel(_conversationStatus),
                  textColor: _text,
                  mutedColor: _muted,
                ),
                if (widget.issue.linkedFault)
                  _DetailRow(
                    label: 'Linked issue',
                    value:
                        '${widget.issue.issue} (${widget.issue.severity.toUpperCase()})',
                    textColor: _text,
                    mutedColor: _muted,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception:', '').trim();
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool joinsPrevious;
  final bool joinsNext;
  final bool dark;

  const _MessageBubble({
    required this.message,
    required this.joinsPrevious,
    required this.joinsNext,
    required this.dark,
  });

  static const Color _messengerBlue = Color(0xFF168AFF);

  @override
  Widget build(BuildContext context) {
    final mine = message.isStudent;
    final textColor =
        dark ? const Color(0xFFF4F5F7) : const Color(0xFF16171A);
    final muted =
        dark ? const Color(0xFFA6A9B2) : const Color(0xFF667085);
    final incoming =
        dark ? const Color(0xFF24262E) : const Color(0xFFE9EBEF);
    final showName = !mine && !joinsPrevious;
    final showAvatar = !mine && !joinsNext;
    final showMeta = !joinsNext || message.pending;

    return Padding(
      padding: EdgeInsets.only(top: joinsPrevious ? 2 : 9),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[
            SizedBox(
              width: 34,
              child: showAvatar
                  ? const _SupportAvatar(
                      size: 30,
                      showOnlineDot: false,
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: 7),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showName) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 11, bottom: 4),
                    child: Text(
                      message.senderName.trim().isEmpty
                          ? 'ITSO Support'
                          : message.senderName,
                      style: TextStyle(
                        color: muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                Container(
                  constraints: const BoxConstraints(maxWidth: 560),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: mine ? _messengerBlue : incoming,
                    borderRadius: _bubbleRadius(mine),
                  ),
                  child: SelectableText(
                    message.message,
                    style: TextStyle(
                      color: mine ? Colors.white : textColor,
                      fontSize: 14.5,
                      height: 1.38,
                    ),
                  ),
                ),
                if (showMeta) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: EdgeInsets.only(
                      left: mine ? 0 : 10,
                      right: mine ? 3 : 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _timeText(message.createdAt),
                          style: TextStyle(color: muted, fontSize: 10.5),
                        ),
                        if (mine) ...[
                          const SizedBox(width: 5),
                          if (message.pending)
                            Icon(
                              Icons.schedule_rounded,
                              size: 13,
                              color: muted,
                            )
                          else
                            Icon(
                              message.read
                                  ? Icons.done_all_rounded
                                  : Icons.done_rounded,
                              size: 14,
                              color: message.read
                                  ? _messengerBlue
                                  : muted,
                            ),
                          if (message.pending) ...[
                            const SizedBox(width: 3),
                            Text(
                              'Pending',
                              style: TextStyle(
                                color: muted,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (mine) const SizedBox(width: 4),
        ],
      ),
    );
  }

  BorderRadius _bubbleRadius(bool mine) {
    const large = Radius.circular(20);
    const small = Radius.circular(6);
    if (mine) {
      return BorderRadius.only(
        topLeft: large,
        bottomLeft: large,
        topRight: joinsPrevious ? small : large,
        bottomRight: joinsNext ? small : large,
      );
    }
    return BorderRadius.only(
      topRight: large,
      bottomRight: large,
      topLeft: joinsPrevious ? small : large,
      bottomLeft: joinsNext ? small : large,
    );
  }
}

class _SupportAvatar extends StatelessWidget {
  final double size;
  final bool showOnlineDot;

  const _SupportAvatar({required this.size, required this.showOnlineDot});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF168AFF), Color(0xFF7B61FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              Icons.support_agent_rounded,
              color: Colors.white,
              size: size * 0.52,
            ),
          ),
          if (showOnlineDot)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.27,
                height: size * 0.27,
                decoration: BoxDecoration(
                  color: const Color(0xFF31C48D),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  final String label;
  final bool dark;

  const _DateSeparator({required this.label, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        label,
        style: TextStyle(
          color: dark
              ? const Color(0xFFA6A9B2)
              : const Color(0xFF667085),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color textColor;
  final Color mutedColor;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: mutedColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

bool _sameSender(ChatMessage a, ChatMessage b) {
  if (a.senderUid.trim().isNotEmpty && b.senderUid.trim().isNotEmpty) {
    return a.senderUid == b.senderUid;
  }
  return a.senderRole.trim().toLowerCase() ==
      b.senderRole.trim().toLowerCase();
}

bool _closeInTime(DateTime a, DateTime b) {
  return b.difference(a).abs() <= const Duration(minutes: 5);
}

bool _sameDay(DateTime a, DateTime b) {
  final left = a.toLocal();
  final right = b.toLocal();
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

String _timeText(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

String _dateLabel(DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final difference = today.difference(day).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
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
      return Icons.memory_rounded;
    case 'peripheral':
      return Icons.keyboard_rounded;
    case 'network':
      return Icons.lan_rounded;
    case 'software':
      return Icons.apps_rounded;
    case 'account':
      return Icons.manage_accounts_rounded;
    case 'other':
      return Icons.help_outline_rounded;
    default:
      return Icons.support_agent_rounded;
  }
}

String _statusLabel(String value) {
  return value
      .trim()
      .split('_')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

Color _statusColor(String status) {
  switch (status.trim().toLowerCase()) {
    case 'resolved':
    case 'closed':
      return const Color(0xFF667085);
    case 'waiting_for_student':
      return const Color(0xFFF59E0B);
    case 'in_progress':
      return const Color(0xFF7B61FF);
    default:
      return const Color(0xFF31C48D);
  }
}
