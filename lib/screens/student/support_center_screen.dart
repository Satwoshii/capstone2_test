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

class _SupportCenterScreenState extends State<SupportCenterScreen>
    with TickerProviderStateMixin {
  Timer? _timer;
  List<SupportIssue> _conversations = const [];
  bool _loading = true;
  bool _refreshing = false;
  String? _error;

  late final AnimationController _entryCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  static const Color _accA = Color(0xFF4FACFE);
  static const Color _accB = Color(0xFF7C5CFF);

  bool get _dark => Theme.of(context).brightness == Brightness.dark;

  Color get _bgColor    => _dark ? const Color(0xFF090A0E) : const Color(0xFFF0F2F5);
  Color get _cardColor  => _dark ? const Color(0xFF13141A) : Colors.white;
  Color get _fieldColor => _dark ? const Color(0xFF1C1E26) : const Color(0xFFEDF0F5);
  Color get _textColor  => _dark ? Colors.white : const Color(0xFF1A1C1E);
  Color get _borderCol  =>
      _dark ? const Color(0x12FFFFFF) : Colors.black.withOpacity(0.09);

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => _refresh());

    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    _fadeAnim  = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _entryCtrl.dispose();
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
      backgroundColor: _bgColor,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      floatingActionButton: _buildFab(),
      body: Stack(
        children: [
          _buildAmbientOrbs(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: _buildBody(),
              ),
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
          tooltip: 'Refresh',
          onPressed: _refreshing ? null : _refresh,
          icon: _refreshing
              ? SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: _textColor.withOpacity(0.6)),
          )
              : const Icon(Icons.refresh_rounded),
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

  Widget _buildFab() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_accA, _accB]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: _accA.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: FloatingActionButton.extended(
        onPressed: _newRequest,
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: const Icon(Icons.add_comment_rounded),
        label: const Text('New Request', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: _accA.withOpacity(0.8)),
      );
    }
    if (_error != null) {
      return Center(
        child: _buildStateCard(
          icon: Icons.wifi_off_rounded,
          title: 'ITSO Support is unavailable',
          message: _error!,
          actionLabel: 'Retry',
          onAction: _refresh,
        ),
      );
    }
    if (_conversations.isEmpty) {
      return Center(
        child: _buildStateCard(
          icon: Icons.support_agent_rounded,
          title: 'How can ITSO help?',
          message: 'Create a support request for hardware, software, network, '
              'account, or general laboratory assistance.',
          actionLabel: 'Start a Conversation',
          onAction: _newRequest,
        ),
      );
    }

    return RefreshIndicator(
      color: _accA,
      backgroundColor: _cardColor,
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _conversations.length,
        itemBuilder: (context, index) => _buildConversationTile(_conversations[index]),
      ),
    );
  }

  Widget _buildStateCard({
    required IconData icon,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 480),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_dark ? 0.55 : 0.10),
            blurRadius: 64,
            offset: const Offset(0, 28),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84, height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_accA.withOpacity(0.18), _accB.withOpacity(0.12)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              border: Border.all(color: _accA.withOpacity(0.45), width: 2),
            ),
            child: ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                colors: [_accA, _accB],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ).createShader(b),
              child: Icon(icon, color: Colors.white, size: 38),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(color: _textColor, fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: _textColor.withOpacity(0.65), fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 48,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_accA, _accB]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: _accA.withOpacity(0.28), blurRadius: 16, offset: const Offset(0, 5))],
              ),
              child: ElevatedButton.icon(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: Icon(actionLabel == 'Retry' ? Icons.refresh_rounded : Icons.add_comment_rounded, size: 18),
                label: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationTile(SupportIssue item) {
    final hasUnread = item.unreadCount > 0;
    final statusText = _statusLabel(item.conversationStatus ?? 'open');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _open(item),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: hasUnread ? _accA.withOpacity(0.35) : _borderCol,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    gradient: LinearGradient(
                      colors: [_accA.withOpacity(0.16), _accB.withOpacity(0.10)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                  ),
                  child: Icon(_categoryIcon(item.category), color: _accA, size: 21),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.subject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _textColor, fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${_categoryLabel(item.category)} · ${item.roomName} - ${item.pcId}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _textColor.withOpacity(0.55), fontSize: 12.5),
                      ),
                      const SizedBox(height: 7),
                      _buildStatusPill(statusText),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (hasUnread)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_accA, _accB]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${item.unreadCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  )
                else
                  Icon(Icons.chevron_right_rounded, color: _textColor.withOpacity(0.30)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(String statusText) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: _fieldColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderCol),
      ),
      child: Text(
        statusText.toUpperCase(),
        style: TextStyle(color: _textColor.withOpacity(0.55), fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.6),
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
      .split('_')
      .map((word) => word.isEmpty
      ? ''
      : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}