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
  final _searchController = TextEditingController();
  Timer? _timer;
  List<SupportIssue> _conversations = const [];
  SupportIssue? _selectedConversation;
  bool _loading = true;
  bool _refreshing = false;
  bool _showUnreadOnly = false;
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

  List<SupportIssue> get _visibleConversations {
    final query = _searchController.text.trim().toLowerCase();
    return _conversations.where((item) {
      if (_showUnreadOnly && item.unreadCount <= 0) return false;
      if (query.isEmpty) return true;
      return item.subject.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query) ||
          item.details.toLowerCase().contains(query) ||
          item.issue.toLowerCase().contains(query) ||
          item.roomName.toLowerCase().contains(query) ||
          item.pcId.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
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
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
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
        if (rows.isEmpty) {
          _selectedConversation = null;
        } else if (_selectedConversation == null) {
          _selectedConversation = rows.first;
        } else {
          final selectedId = _selectedConversation!.conversationId;
          SupportIssue? refreshedSelection;
          for (final row in rows) {
            if (row.conversationId == selectedId) {
              refreshedSelection = row;
              break;
            }
          }
          _selectedConversation = refreshedSelection ?? rows.first;
        }
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
    if (_isDesktopLayout) {
      setState(() => _selectedConversation = conversation);
      await _refresh();
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupportChatScreen(issue: conversation),
      ),
    );
    await _refresh();
  }

  Future<void> _open(SupportIssue conversation) async {
    if (_isDesktopLayout) {
      setState(() => _selectedConversation = conversation);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupportChatScreen(issue: conversation),
      ),
    );
    await _refresh();
  }

  bool get _isDesktopLayout => MediaQuery.of(context).size.width >= 980;

  @override
  Widget build(BuildContext context) {
    final desktop = _isDesktopLayout;
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: desktop ? null : _buildAppBar(),
      floatingActionButton: desktop ? null : _buildFab(),
      body: desktop
          ? _buildDesktopLayout()
          : Stack(
              children: [
                _buildAmbientOrbs(),
                SafeArea(
                  top: false,
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

  Widget _buildDesktopLayout() {
    final selected = _selectedConversation;
    return Row(
      children: [
        SizedBox(
          width: 380,
          child: _buildDesktopSidebar(),
        ),
        VerticalDivider(width: 1, thickness: 1, color: _borderCol),
        Expanded(
          child: selected == null
              ? _buildDesktopEmptyConversation()
              : SupportChatScreen(
                  key: ValueKey(selected.conversationId),
                  issue: selected,
                  embedded: true,
                ),
        ),
      ],
    );
  }

  Widget _buildDesktopSidebar() {
    final visible = _visibleConversations;
    final unread = _conversations.fold<int>(
      0,
      (total, item) => total + item.unreadCount,
    );

    return Material(
      color: _cardColor,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.maybePop(context),
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: _textColor.withOpacity(0.88),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      'Chats',
                      style: TextStyle(
                        color: _textColor,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  _buildSidebarAction(
                    tooltip: 'Toggle theme',
                    icon: _dark
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    onPressed: () => ThemeService.instance.toggleTheme(),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _newRequest,
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text(
                      'Report Issue',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _accA.withOpacity(0.12),
                      foregroundColor: _accA,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, 36),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: _textColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search chats',
                  hintStyle: TextStyle(color: _textColor.withOpacity(0.45)),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: _textColor.withOpacity(0.55),
                  ),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: _searchController.clear,
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                  filled: true,
                  fillColor: _fieldColor,
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  _buildDesktopFilter(
                    label: 'All',
                    selected: !_showUnreadOnly,
                    onTap: () => setState(() => _showUnreadOnly = false),
                  ),
                  const SizedBox(width: 8),
                  _buildDesktopFilter(
                    label: unread > 0 ? 'Unread  $unread' : 'Unread',
                    selected: _showUnreadOnly,
                    onTap: () => setState(() => _showUnreadOnly = true),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Refresh conversations',
                    onPressed: _refreshing ? null : _refresh,
                    icon: _refreshing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.refresh_rounded,
                            color: _textColor.withOpacity(0.55),
                            size: 20,
                          ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: _borderCol),
            Expanded(
              child: _buildDesktopConversationList(visible),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarAction({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: _fieldColor,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: _textColor.withOpacity(0.82), size: 20),
      ),
    );
  }

  Widget _buildDesktopFilter({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? _accA.withOpacity(0.18) : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? _accA : _textColor.withOpacity(0.72),
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopConversationList(List<SupportIssue> visible) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _accA),
      );
    }
    if (_error != null && _conversations.isEmpty) {
      return _buildSidebarState(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load chats',
        message: _error!,
        actionLabel: 'Retry',
        onAction: _refresh,
      );
    }
    if (_conversations.isEmpty) {
      return _buildSidebarState(
        icon: Icons.forum_outlined,
        title: 'No conversations yet',
        message: 'Create a request to message ITSO Support.',
        actionLabel: 'Report Issue',
        onAction: _newRequest,
      );
    }
    if (visible.isEmpty) {
      return _buildSidebarState(
        icon: Icons.search_off_rounded,
        title: 'No chats found',
        message: _showUnreadOnly
            ? 'There are no unread conversations.'
            : 'Try another search term.',
        actionLabel: 'Show all',
        onAction: () {
          _searchController.clear();
          setState(() => _showUnreadOnly = false);
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      itemCount: visible.length,
      itemBuilder: (context, index) => _buildConversationTile(
        visible[index],
        desktop: true,
      ),
    );
  }

  Widget _buildSidebarState({
    required IconData icon,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _textColor.withOpacity(0.30), size: 42),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textColor,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _textColor.withOpacity(0.50),
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopEmptyConversation() {
    return Stack(
      children: [
        Positioned.fill(child: _buildAmbientOrbs()),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_accA, _accB],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.forum_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'ITSO Support Messages',
                style: TextStyle(
                  color: _textColor,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Select a chat or create a new support request.',
                style: TextStyle(
                  color: _textColor.withOpacity(0.52),
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _newRequest,
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('Report Issue'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _cardColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: Border(bottom: BorderSide(color: _borderCol)),
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_accA, _accB],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 21),
          ),
          const SizedBox(width: 11),
          Text(
            'Messages',
            style: TextStyle(
              color: _textColor,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
            ),
          ),
        ],
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
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Report Issue', style: TextStyle(fontWeight: FontWeight.w700)),
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
          actionLabel: 'Report Issue',
          onAction: _newRequest,
        ),
      );
    }

    final visible = _visibleConversations;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          children: [
            _buildInboxHeader(),
            Expanded(
              child: visible.isEmpty
                  ? _buildNoSearchResults()
                  : RefreshIndicator(
                      color: _accA,
                      backgroundColor: _cardColor,
                      onRefresh: _refresh,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                        itemCount: visible.length,
                        itemBuilder: (context, index) =>
                            _buildConversationTile(visible[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInboxHeader() {
    final unread = _conversations.fold<int>(
      0,
      (total, item) => total + item.unreadCount,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'ITSO Support',
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (unread > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _accA.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    '$unread unread',
                    style: const TextStyle(
                      color: _accA,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Your conversations with the ITSO team',
            style: TextStyle(color: _textColor.withOpacity(0.55), fontSize: 13),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            style: TextStyle(color: _textColor, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search conversations',
              hintStyle: TextStyle(color: _textColor.withOpacity(0.38)),
              prefixIcon: Icon(Icons.search_rounded, color: _textColor.withOpacity(0.45)),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: _searchController.clear,
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: _fieldColor,
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(24),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSearchResults() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, color: _textColor.withOpacity(0.35), size: 44),
          const SizedBox(height: 10),
          Text(
            'No matching conversations',
            style: TextStyle(color: _textColor, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          TextButton(onPressed: _searchController.clear, child: const Text('Clear search')),
        ],
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
                icon: Icon(actionLabel == 'Retry' ? Icons.refresh_rounded : Icons.edit_rounded, size: 18),
                label: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationTile(
    SupportIssue item, {
    bool desktop = false,
  }) {
    final hasUnread = item.unreadCount > 0;
    final isSelected = desktop &&
        _selectedConversation?.conversationId == item.conversationId;
    final statusText = _statusLabel(item.conversationStatus ?? 'open');
    final statusColor = _statusColor(item.conversationStatus ?? 'open');
    final preview = item.details.trim().isNotEmpty
        ? item.details.trim()
        : item.issue.trim();
    final activityTime = item.updatedAt ?? item.createdAt;

    return Padding(
      padding: EdgeInsets.only(bottom: desktop ? 2 : 6),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(desktop ? 12 : 16),
        child: InkWell(
          borderRadius: BorderRadius.circular(desktop ? 12 : 16),
          onTap: () => _open(item),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: isSelected
                  ? _accA.withOpacity(_dark ? 0.20 : 0.13)
                  : hasUnread
                      ? _accA.withOpacity(_dark ? 0.09 : 0.06)
                      : desktop
                          ? Colors.transparent
                          : _cardColor.withOpacity(_dark ? 0.86 : 0.92),
              borderRadius: BorderRadius.circular(desktop ? 12 : 16),
              border: Border.all(
                color: desktop
                    ? Colors.transparent
                    : hasUnread
                        ? _accA.withOpacity(0.24)
                        : _borderCol,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 54,
                  height: 54,
                  child: Stack(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [_accA, _accB],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Icon(
                          _categoryIcon(item.category),
                          color: Colors.white,
                          size: 23,
                        ),
                      ),
                      Positioned(
                        right: 1,
                        bottom: 1,
                        child: Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: _cardColor, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.subject,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _textColor,
                                fontSize: 14.5,
                                fontWeight: hasUnread
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                              ),
                            ),
                          ),
                          if (activityTime != null) ...[
                            const SizedBox(width: 10),
                            Text(
                              _conversationTime(activityTime),
                              style: TextStyle(
                                color: hasUnread
                                    ? _accA
                                    : _textColor.withOpacity(0.42),
                                fontSize: 11,
                                fontWeight: hasUnread
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              preview.isEmpty
                                  ? '${_categoryLabel(item.category)} · ${item.roomName} - ${item.pcId}'
                                  : preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _textColor.withOpacity(hasUnread ? 0.72 : 0.53),
                                fontSize: 12.5,
                                fontWeight: hasUnread
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (hasUnread) ...[
                            const SizedBox(width: 10),
                            Container(
                              constraints: const BoxConstraints(minWidth: 22),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: _accA,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                item.unreadCount > 99 ? '99+' : '${item.unreadCount}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          _buildStatusPill(statusText, statusColor),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              '${_categoryLabel(item.category)} · ${item.roomName} - ${item.pcId}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _textColor.withOpacity(0.40),
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(String statusText, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.11),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        statusText.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.45,
        ),
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

Color _statusColor(String value) {
  switch (value.trim().toLowerCase()) {
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

String _conversationTime(DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  final sameDay = local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  if (sameDay) {
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
  final yesterday = DateTime(now.year, now.month, now.day)
      .subtract(const Duration(days: 1));
  if (local.year == yesterday.year &&
      local.month == yesterday.month &&
      local.day == yesterday.day) {
    return 'Yesterday';
  }
  return '${local.month}/${local.day}/${local.year}';
}
