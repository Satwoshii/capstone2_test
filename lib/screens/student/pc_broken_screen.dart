import 'package:flutter/material.dart';

import '../../models/hardware_status.dart';
import '../../models/pc_identity.dart';
import '../../services/theme_service.dart';
import '../../widgets/issue_support_launcher.dart';
import '../staff/pc_config_admin_login_screen.dart';

class PcBrokenScreen extends StatefulWidget {
  final PcIdentity pc;
  final HardwareStatus hardware;
  final bool sessionActive;

  const PcBrokenScreen({
    super.key,
    required this.pc,
    required this.hardware,
    this.sessionActive = false,
  });

  @override
  State<PcBrokenScreen> createState() => _PcBrokenScreenState();
}

class _PcBrokenScreenState extends State<PcBrokenScreen>
    with TickerProviderStateMixin {

  late final AnimationController _entryCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _pulseAnim;

  bool get _dark => Theme.of(context).brightness == Brightness.dark;

  Color get _bgColor    => _dark ? const Color(0xFF090A0E) : const Color(0xFFF0F2F5);
  Color get _cardColor  => _dark ? const Color(0xFF13141A) : Colors.white;
  Color get _fieldColor => _dark ? const Color(0xFF1C1E26) : const Color(0xFFEDF0F5);
  Color get _textColor  => _dark ? Colors.white : const Color(0xFF1A1C1E);
  Color get _borderCol  =>
      _dark ? const Color(0x12FFFFFF) : Colors.black.withValues(alpha: 0.09);

  static const Color _errA = Color(0xFFFF3B30);
  static const Color _errB = Color(0xFFFF2D6E);

  List<String> get _blockingIssues {
    final issues = [
      ...widget.hardware.criticalIssues,
      ...widget.hardware.highIssues,
    ];
    if (issues.isNotEmpty) return issues;
    return widget.hardware.issues.isEmpty
        ? ['Unknown issue']
        : widget.hardware.issues;
  }

  List<_Tip> get _ethernetTips {
    if (!widget.hardware.highIssues.contains('ethernet')) return const [];
    return const [
      _Tip(Icons.cable_rounded,
          'Check whether the Ethernet/LAN cable is securely connected.'),
      _Tip(Icons.lan_rounded,
          'Check whether the Ethernet port link light is on or blinking.'),
      _Tip(Icons.support_agent_rounded,
          'Use another LAN cable or contact ITSO if the cable is damaged.'),
    ];
  }

  static const Map<String, IconData> _issueIcons = {
    'ethernet':  Icons.lan_rounded,
    'mouse':     Icons.mouse_rounded,
    'keyboard':  Icons.keyboard_rounded,
    'monitor':   Icons.monitor_rounded,
    'cpu':       Icons.memory_rounded,
    'storage':   Icons.storage_rounded,
    'ram':       Icons.developer_board_rounded,
    'gpu':       Icons.video_settings_rounded,
    'network':   Icons.wifi_off_rounded,
    'power':     Icons.power_off_rounded,
  };

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _fadeAnim  = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.86, end: 1.10)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _bgColor,
        body: Stack(
          children: [
            _buildAmbientOrbs(),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: _buildCard(),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 24,
              right: 24,
              child: _buildThemeToggle(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        shape: BoxShape.circle,
        border: Border.all(color: _borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_dark ? 0.3 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        onPressed: () => ThemeService.instance.toggleTheme(),
        icon: Icon(
          _dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          color: _dark ? Colors.amber : const Color(0xFF4F8EF7),
        ),
        tooltip: 'Toggle Theme',
      ),
    );
  }

  Widget _buildAmbientOrbs() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(top: -90,    left:  -70, child: _orb(340, _errA.withOpacity(0.07))),
          Positioned(bottom: -110, right: -60, child: _orb(380, _errB.withOpacity(0.06))),
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

  Widget _buildCard() {
    final ethernet = _ethernetTips;
    return Container(
      width: 620,
      padding: const EdgeInsets.fromLTRB(40, 44, 40, 40),
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
          _buildErrorBadge(),
          const SizedBox(height: 18),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [_errA, _errB],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(bounds),
            child: const Text(
              'PC BROKEN',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Critical issue detected — this workstation is unavailable.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textColor.withOpacity(0.50), fontSize: 13.5),
          ),
          const SizedBox(height: 22),
          _buildIssuePills(),
          const SizedBox(height: 20),
          _buildGuidanceTile(),
          const SizedBox(height: 12),
          if (widget.sessionActive) ...[
            _buildSessionPreservedTile(),
            const SizedBox(height: 12),
          ],
          if (!widget.hardware.hasCriticalIssue && ethernet.isNotEmpty) ...[
            _buildSectionLabel('Ethernet Checks'),
            const SizedBox(height: 8),
            ...ethernet.map(_buildTipTile),
            const SizedBox(height: 4),
          ],
          _buildRecoveryBadge(),
          const SizedBox(height: 20),
          Text(
            '${widget.pc.roomName}  ·  ${widget.pc.pcId}',
            style: TextStyle(color: _textColor.withOpacity(0.30), fontSize: 12, letterSpacing: 0.4),
          ),
          if (widget.sessionActive) ...[
            const SizedBox(height: 16),
            const IssueSupportLauncher(compact: true),
          ],
          const SizedBox(height: 24),
          Divider(color: _textColor.withOpacity(0.08), thickness: 1),
          const SizedBox(height: 20),
          _buildAdminButton(context),
        ],
      ),
    );
  }

  Widget _buildErrorBadge() {
    return SizedBox(
      width: 110, height: 110,
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (_, __) => Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: _pulseAnim.value,
              child: Container(
                width: 104, height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _errA.withOpacity(0.28), width: 1.5),
                  boxShadow: [BoxShadow(color: _errA.withOpacity(0.20), blurRadius: 28, spreadRadius: 4)],
                ),
              ),
            ),
            Container(
              width: 82, height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [_errA.withOpacity(0.18), _errB.withOpacity(0.12)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                border: Border.all(color: _errA.withOpacity(0.55), width: 2),
              ),
            ),
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                colors: [_errA, _errB],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ).createShader(b),
              child: const Icon(Icons.error_rounded, color: Colors.white, size: 40),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIssuePills() {
    return Wrap(
      spacing: 8, runSpacing: 8,
      alignment: WrapAlignment.center,
      children: _blockingIssues.map((issue) {
        final isCritical = widget.hardware.criticalIssues.contains(issue);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: _errA.withOpacity(0.10),
            border: Border.all(color: _errA.withOpacity(isCritical ? 0.55 : 0.30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCritical)
                Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: Icon(Icons.priority_high_rounded, color: _errA, size: 13),
                ),
              Icon(_issueIcons[issue.toLowerCase()] ?? Icons.device_unknown_rounded, color: _errA, size: 14),
              const SizedBox(width: 7),
              Text(
                issue.toUpperCase(),
                style: TextStyle(color: _errA, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.0),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGuidanceTile() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: _errA.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _errA.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: _errA.withOpacity(0.80), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Please use another workstation and contact ITSO.',
              style: TextStyle(color: _textColor.withOpacity(0.80), fontSize: 14, fontWeight: FontWeight.w500, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionPreservedTile() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: _fieldColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderCol),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: _errA.withOpacity(0.70), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your current student session has been preserved and will resume automatically after recovery.',
              style: TextStyle(color: _textColor.withOpacity(0.75), fontSize: 13.5, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: _textColor.withOpacity(0.35),
          fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildTipTile(_Tip tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _fieldColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderCol),
        ),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                gradient: LinearGradient(
                  colors: [_errA.withOpacity(0.15), _errB.withOpacity(0.10)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
              child: Icon(tip.icon, color: _errA, size: 17),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                tip.text,
                style: TextStyle(color: _textColor.withOpacity(0.80), fontSize: 13.5, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecoveryBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: _fieldColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderCol),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.monitor_heart_rounded, color: _errA.withOpacity(0.70), size: 16),
          const SizedBox(width: 9),
          Text(
            'SysWatch automatically rechecks every 10 seconds',
            style: TextStyle(color: _textColor.withOpacity(0.50), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminButton(BuildContext context) {
    return SizedBox(
      height: 50, width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PcConfigAdminLoginScreen()),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: _errA,
          side: BorderSide(color: _errA.withOpacity(0.35), width: 1.5),
          backgroundColor: _errA.withOpacity(0.06),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.admin_panel_settings_rounded, size: 19),
        label: const Text(
          'Admin PC Config Override',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
        ),
      ),
    );
  }
}

class _Tip {
  final IconData icon;
  final String text;
  const _Tip(this.icon, this.text);
}