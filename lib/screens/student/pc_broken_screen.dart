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
  static const Color _errorRed = Color(0xFFFF4D57);
  static const Color _errorPink = Color(0xFFFF2D6E);
  static const Color _diagnosticBlue = Color(0xFF69A7FF);

  late final AnimationController _entryController;
  late final AnimationController _pulseController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _pulseAnimation;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _backgroundColor =>
      _isDark ? const Color(0xFF360506) : const Color(0xFFF9E7E8);

  Color get _cardColor =>
      _isDark ? const Color(0xFF111419) : const Color(0xFFFFFFFF);

  Color get _fieldColor =>
      _isDark ? const Color(0xFF1A1E25) : const Color(0xFFF2F4F7);

  Color get _textColor =>
      _isDark ? const Color(0xFFF5F7FA) : const Color(0xFF1A1C20);

  Color get _borderColor => _isDark
      ? Colors.white.withOpacity(0.09)
      : Colors.black.withOpacity(0.09);

  List<String> get _blockingIssues {
    final issues = <String>{
      ...widget.hardware.criticalIssues,
      ...widget.hardware.highIssues,
    }.toList();

    if (issues.isNotEmpty) return issues;
    if (widget.hardware.issues.isNotEmpty) {
      return widget.hardware.issues;
    }
    return const ['Unknown issue'];
  }

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: Curves.easeOutCubic,
      ),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.90, end: 1.08).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _backgroundColor,
        body: Stack(
          children: [
            _buildAmbientBackground(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: _buildCard(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 22,
              bottom: 22,
              child: _buildThemeToggle(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmbientBackground() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -130,
            left: -100,
            child: _ambientOrb(430, _errorRed.withOpacity(0.10)),
          ),
          Positioned(
            right: -110,
            bottom: -160,
            child: _ambientOrb(470, _errorPink.withOpacity(0.08)),
          ),
        ],
      ),
    );
  }

  Widget _ambientOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
        ),
      ),
    );
  }

  Widget _buildThemeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        shape: BoxShape.circle,
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.35 : 0.10),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: IconButton(
        onPressed: () => ThemeService.instance.toggleTheme(),
        tooltip: 'Toggle theme',
        icon: Icon(
          _isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          color: _isDark ? Colors.amber : const Color(0xFF3C73D9),
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(40, 42, 40, 36),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.52 : 0.14),
            blurRadius: 60,
            offset: const Offset(0, 28),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildErrorBadge(),
          const SizedBox(height: 22),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [_errorRed, _errorPink],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(bounds),
            child: const Text(
              'PC BROKEN',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.hardware.hasCriticalIssue
                ? 'A critical workstation problem was detected.'
                : 'A high-severity workstation problem was detected.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textColor.withOpacity(0.54),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          _buildIssuePills(),
          const SizedBox(height: 20),
          _buildGuidanceTile(),
          if (widget.sessionActive) ...[
            const SizedBox(height: 12),
            _buildSessionPreservedTile(),
          ],
          const SizedBox(height: 14),
          _buildRecoveryBadge(),
          if (widget.hardware.eventViewerScanSucceeded) ...[
            const SizedBox(height: 10),
            _buildDiagnosticsBadge(),
          ],
          const SizedBox(height: 26),
          ..._buildTroubleshootingSections(),
          Text(
            '${widget.pc.roomName}  ·  ${widget.pc.pcId}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textColor.withOpacity(0.38),
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
          if (widget.sessionActive) ...[
            const SizedBox(height: 16),
            const IssueSupportLauncher(compact: true),
          ],
          const SizedBox(height: 22),
          Divider(color: _textColor.withOpacity(0.09)),
          const SizedBox(height: 18),
          _buildAdminButton(),
        ],
      ),
    );
  }

  Widget _buildErrorBadge() {
    return SizedBox(
      width: 112,
      height: 112,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _errorRed.withOpacity(0.30),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _errorRed.withOpacity(0.20),
                        blurRadius: 30,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      _errorRed.withOpacity(0.20),
                      _errorPink.withOpacity(0.12),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: _errorRed.withOpacity(0.58),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: _errorRed,
                  size: 48,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildIssuePills() {
    return Column(
      children: [
        Text(
          'ISSUE DETECTED',
          style: TextStyle(
            color: _textColor.withOpacity(0.48),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: _blockingIssues.map((issue) {
            final isCritical = widget.hardware.criticalIssues.contains(issue);
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: _errorRed.withOpacity(0.10),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: _errorRed.withOpacity(isCritical ? 0.60 : 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _iconForIssue(issue),
                    color: _errorRed,
                    size: 16,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    _issueLabel(issue).toUpperCase(),
                    style: const TextStyle(
                      color: _errorRed,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.9,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGuidanceTile() {
    return _messageTile(
      icon: Icons.info_outline_rounded,
      color: _errorRed,
      text: 'Please stop using this workstation, use another PC, and '
          'contact ITSO for assistance.',
    );
  }

  Widget _buildSessionPreservedTile() {
    return _messageTile(
      icon: Icons.shield_outlined,
      color: _diagnosticBlue,
      text: 'Your active student session is preserved and will resume '
          'automatically after the workstation recovers.',
    );
  }

  Widget _messageTile({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color.withOpacity(0.86), size: 19),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: _textColor.withOpacity(0.82),
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecoveryBadge() {
    return _statusBadge(
      icon: Icons.monitor_heart_rounded,
      color: _errorRed,
      text: 'Syswatch automatically rechecks every 5 seconds',
    );
  }

  Widget _buildDiagnosticsBadge() {
    return _statusBadge(
      icon: Icons.fact_check_outlined,
      color: _diagnosticBlue,
      text: 'Windows Event Viewer diagnostics recorded for ITSO',
    );
  }

  Widget _statusBadge({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: _fieldColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: color.withOpacity(0.80), size: 17),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textColor.withOpacity(0.58),
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTroubleshootingSections() {
    final sections = <Widget>[];
    final seen = <String>{};

    for (final issue in _blockingIssues) {
      final key = _tipKey(issue);
      if (!seen.add(key)) continue;

      final tips = _tipsForIssue(issue);
      sections.add(_buildSectionLabel('${_issueLabel(issue)} checks'));
      sections.add(const SizedBox(height: 9));
      sections.addAll(tips.map(_buildTipTile));
      sections.add(const SizedBox(height: 12));
    }

    return sections;
  }

  Widget _buildSectionLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: _textColor.withOpacity(0.40),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildTipTile(_Tip tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: _fieldColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _errorRed.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(tip.icon, color: _errorRed, size: 18),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                tip.text,
                style: TextStyle(
                  color: _textColor.withOpacity(0.80),
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PcConfigAdminLoginScreen(),
            ),
          );
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: _errorRed,
          backgroundColor: _errorRed.withOpacity(0.06),
          side: BorderSide(
            color: _errorRed.withOpacity(0.38),
            width: 1.4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.admin_panel_settings_rounded, size: 19),
        label: const Text(
          'Admin PC Config Override',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  IconData _iconForIssue(String issue) {
    final value = issue.toLowerCase();
    if (value.contains('ethernet') || value.contains('network')) {
      return Icons.lan_rounded;
    }
    if (value.contains('cpu')) return Icons.memory_rounded;
    if (value.contains('ram') || value.contains('memory')) {
      return Icons.developer_board_rounded;
    }
    if (value.contains('disk') || value.contains('storage')) {
      return Icons.storage_rounded;
    }
    if (value.contains('monitor') || value.contains('display')) {
      return Icons.monitor_rounded;
    }
    if (value.contains('keyboard')) return Icons.keyboard_rounded;
    if (value.contains('mouse')) return Icons.mouse_rounded;
    return Icons.report_problem_outlined;
  }

  String _tipKey(String issue) {
    final value = issue.toLowerCase();
    if (value.contains('storage') || value.contains('disk')) return 'storage';
    if (value.contains('ethernet') || value.contains('network')) {
      return 'ethernet';
    }
    if (value.contains('ram') || value.contains('memory')) return 'ram';
    if (value.contains('cpu')) return 'cpu';
    return value;
  }

  List<_Tip> _tipsForIssue(String issue) {
    switch (_tipKey(issue)) {
      case 'ethernet':
        return const [
          _Tip(
            Icons.cable_rounded,
            'Confirm that the Ethernet/LAN cable is securely connected.',
          ),
          _Tip(
            Icons.lan_rounded,
            'Check whether the Ethernet port link light is on or blinking.',
          ),
          _Tip(
            Icons.support_agent_rounded,
            'Try another LAN cable or contact ITSO if the cable is damaged.',
          ),
        ];
      case 'cpu':
        return const [
          _Tip(
            Icons.power_settings_new_rounded,
            'Do not continue using the workstation or repeatedly restart it.',
          ),
          _Tip(
            Icons.support_agent_rounded,
            'Contact ITSO so the processor and motherboard can be inspected.',
          ),
        ];
      case 'ram':
        return const [
          _Tip(
            Icons.apps_rounded,
            'Do not open more applications or attempt to open the PC case.',
          ),
          _Tip(
            Icons.support_agent_rounded,
            'Contact ITSO to inspect or reseat the physical memory modules.',
          ),
        ];
      case 'storage':
        return const [
          _Tip(
            Icons.warning_amber_rounded,
            'Stop using the workstation to reduce the risk of data loss.',
          ),
          _Tip(
            Icons.storage_rounded,
            'ITSO should inspect disk health and available system-drive space.',
          ),
          _Tip(
            Icons.backup_rounded,
            'Back up required data before any disk repair or replacement.',
          ),
        ];
      default:
        return const [
          _Tip(
            Icons.support_agent_rounded,
            'Contact ITSO and provide the room and PC identifier shown below.',
          ),
        ];
    }
  }

  String _issueLabel(String issue) {
    return issue
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map(
          (word) => '${word.substring(0, 1).toUpperCase()}'
              '${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}

class _Tip {
  final IconData icon;
  final String text;

  const _Tip(this.icon, this.text);
}
