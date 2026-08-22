import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/pc_identity.dart';
import '../../services/app_config_service.dart';
import '../../services/local_db_service.dart';
import '../../services/pc_monitor_service.dart';
import '../../services/pre_login_kiosk_service.dart';
import '../../services/student_session_service.dart';
import '../../services/sync_service.dart';
import '../../services/theme_service.dart';
import '../../services/tray_service.dart';
import '../../widgets/issue_support_launcher.dart';
import 'student_login_screen.dart';

class StudentAccessScreen extends StatefulWidget {
  final AppUser user;
  final PcIdentity pc;
  final String loginLogId;

  const StudentAccessScreen({
    super.key,
    required this.user,
    required this.pc,
    required this.loginLogId,
  });

  @override
  State<StudentAccessScreen> createState() => _StudentAccessScreenState();
}

class _StudentAccessScreenState extends State<StudentAccessScreen>
    with TickerProviderStateMixin {

  static const int _totalSeconds = 5;
  Timer? _autoMinimizeTimer;
  Timer? _sessionHeartbeatTimer;
  int _secondsLeft = _totalSeconds;
  bool _countdownDone = false;
  bool _heartbeatInProgress = false;
  bool _sessionEnding = false;
  bool _sessionConfirmed = false;

  // ── Animation controllers ─────────────────────────────────────────────────
  late final AnimationController _entryCtrl;
  late final AnimationController _checkCtrl;
  late final AnimationController _pulseCtrl;

  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _checkScaleAnim;
  late final Animation<double> _checkFadeAnim;
  late final Animation<double> _pulseAnim;

  // ── Palette ───────────────────────────────────────────────────────────────
  bool get _dark => Theme.of(context).brightness == Brightness.dark;

  Color get _bgColor    => _dark ? const Color(0xFF090A0E) : const Color(0xFFF0F2F5);
  Color get _cardColor  => _dark ? const Color(0xFF13141A) : Colors.white;
  Color get _fieldColor => _dark ? const Color(0xFF1C1E26) : const Color(0xFFEDF0F5);
  Color get _textColor  => _dark ? Colors.white : const Color(0xFF1A1C1E);
  Color get _subText    => _dark ? Colors.white54 : Colors.black45;
  Color get _borderCol  => _dark ? const Color(0x12FFFFFF) : Colors.black.withOpacity(0.09);

  static const Color _accentA = Color(0xFF2EE6C5);
  static const Color _accentB = Color(0xFF4F8EF7);

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    PcMonitorService.instance.beginStudentSession(widget.user.email);
    unawaited(PreLoginKioskService.instance.releaseAfterLogin());

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _checkScaleAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut),
    );
    _checkFadeAnim = CurvedAnimation(parent: _checkCtrl, curve: Curves.easeOut);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.9, end: 1.12).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _entryCtrl.forward().then((_) => _checkCtrl.forward());
    _startAutoMinimizeTimer();
    unawaited(_startSessionHeartbeat());
  }

  @override
  void dispose() {
    _autoMinimizeTimer?.cancel();
    _sessionHeartbeatTimer?.cancel();
    _entryCtrl.dispose();
    _checkCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Timer ─────────────────────────────────────────────────────────────────
  void _startAutoMinimizeTimer() {
    _autoMinimizeTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) async {
          if (!mounted) return;
          setState(() => _secondsLeft--);
          if (_secondsLeft <= 0) {
            timer.cancel();
            if (mounted) setState(() => _countdownDone = true);
            await _minimizeToBackground();
          }
        });
  }

  Future<void> _minimizeToBackground() async {
    try {
      await TrayService.instance.hideToTray();
    } catch (_) {}
  }

  Future<void> _startSessionHeartbeat() async {
    // Give the login request and local session save time to settle before the
    // first validation. Some MariaDB/XAMPP installations briefly expose the
    // previous active-session row immediately after login.
    await Future<void>.delayed(const Duration(milliseconds: 1200));

    for (var attempt = 0; attempt < 3 && mounted; attempt++) {
      final confirmed = await _sendSessionHeartbeat(
        allowInvalidRetry: attempt < 2,
      );
      if (confirmed || _sessionEnding) break;
      await Future<void>.delayed(const Duration(seconds: 2));
    }

    if (!mounted || _sessionEnding) return;

    // Sync the local login log only after the server has confirmed that this
    // exact session is active. This prevents login-log synchronization from
    // racing the initial active-session check.
    unawaited(SyncService.instance.syncPendingData());

    _sessionHeartbeatTimer?.cancel();
    _sessionHeartbeatTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(_sendSessionHeartbeat()),
    );
  }

  Future<bool> _sendSessionHeartbeat({bool allowInvalidRetry = false}) async {
    if (_heartbeatInProgress || _sessionEnding) return false;
    _heartbeatInProgress = true;

    try {
      await StudentSessionService.instance.heartbeat();
      _sessionConfirmed = true;
      return true;
    } on StudentSessionInvalidException catch (error) {
      if (!allowInvalidRetry || _sessionConfirmed) {
        await _endInvalidSession(error.message);
      }
      return false;
    } catch (_) {
      // A short LAN interruption is allowed. The server keeps the session for
      // 90 seconds and rejects it if another PC becomes the valid session.
      return false;
    } finally {
      _heartbeatInProgress = false;
    }
  }

  Future<void> _endInvalidSession(String reason) async {
    if (_sessionEnding) return;
    _sessionEnding = true;
    _autoMinimizeTimer?.cancel();
    _sessionHeartbeatTimer?.cancel();

    await LocalDbService.instance.logout(widget.loginLogId);
    try {
      await SyncService.instance.syncPendingData();
    } catch (_) {}
    try {
      await StudentSessionService.instance.logout();
    } catch (_) {}
    await AppConfigService.instance.clearStudentApiSession();
    PcMonitorService.instance.endStudentSession();

    await PreLoginKioskService.instance.lockForLogin();

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.security_update_warning_rounded,
          color: Colors.orange,
          size: 36,
        ),
        title: const Text('Student Session Ended'),
        content: Text(
          '$reason\n\nFor security, this PC returned to the login screen.',
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Return to Login'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const StudentLoginScreen()),
      (_) => false,
    );
  }

  Future<void> _logout(BuildContext context) async {
    if (_sessionEnding) return;
    _sessionEnding = true;
    _autoMinimizeTimer?.cancel();
    _sessionHeartbeatTimer?.cancel();

    await LocalDbService.instance.logout(widget.loginLogId);
    try {
      await SyncService.instance.syncPendingData();
    } catch (_) {
      // Pending records will synchronize when the intranet is available.
    }
    try {
      await StudentSessionService.instance.logout();
    } catch (_) {
      // If the LAN is down, the server releases the session automatically
      // after its 90-second heartbeat timeout.
    }
    await AppConfigService.instance.clearStudentApiSession();
    PcMonitorService.instance.endStudentSession();

    await PreLoginKioskService.instance.lockForLogin();

    if (!context.mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const StudentLoginScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
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
          color: _dark ? Colors.amber : _accentB,
        ),
        tooltip: 'Toggle Light/Dark Mode',
      ),
    );
  }

  // ── Ambient orbs ──────────────────────────────────────────────────────────
  Widget _buildAmbientOrbs() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -80,
            left: -80,
            child: _orb(300, _accentA.withOpacity(0.07)),
          ),
          Positioned(
            bottom: -100,
            right: -60,
            child: _orb(340, _accentB.withOpacity(0.06)),
          ),
        ],
      ),
    );
  }

  Widget _orb(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, Colors.transparent]),
    ),
  );

  // ── Main card ─────────────────────────────────────────────────────────────
  Widget _buildCard() {
    return Container(
      width: 580,
      padding: const EdgeInsets.fromLTRB(40, 44, 40, 40),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_dark ? 0.55 : 0.1),
            blurRadius: 64,
            offset: const Offset(0, 28),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSuccessBadge(),
          const SizedBox(height: 18),

          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [_accentA, _accentB],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(bounds),
            child: const Text(
              'ACCESS GRANTED',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
              ),
            ),
          ),
          const SizedBox(height: 28),

          _buildInfoRow(),
          const SizedBox(height: 24),

          // Countdown collapses when done; everything else stays visible
          AnimatedSize(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            child: _countdownDone
                ? const SizedBox.shrink()
                : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCountdownSection(),
                const SizedBox(height: 20),
              ],
            ),
          ),

          _buildSyncBadge(),
          const SizedBox(height: 20),

          Divider(color: _textColor.withOpacity(0.08), thickness: 1),
          const SizedBox(height: 20),

          const IssueSupportLauncher(),
          const SizedBox(height: 8),
          Text(
            'ITSO Support: Ctrl + Alt + S  •  Backup: Ctrl + Shift + H',
            style: TextStyle(
              color: _textColor.withOpacity(0.45),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          _buildActionButtons(),
        ],
      ),
    );
  }

  // ── Animated success badge ────────────────────────────────────────────────
  Widget _buildSuccessBadge() {
    return SizedBox(
      width: 110,
      height: 110,
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: _pulseAnim.value,
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _accentA.withOpacity(0.25),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _accentA.withOpacity(0.18),
                        blurRadius: 28,
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
                      _accentA.withOpacity(0.18),
                      _accentB.withOpacity(0.12),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: _accentA.withOpacity(0.55),
                    width: 2,
                  ),
                ),
              ),
              FadeTransition(
                opacity: _checkFadeAnim,
                child: ScaleTransition(
                  scale: _checkScaleAnim,
                  child: ShaderMask(
                    shaderCallback: (b) => const LinearGradient(
                      colors: [_accentA, _accentB],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(b),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── User + PC info ────────────────────────────────────────────────────────
  Widget _buildInfoRow() {
    return Row(
      children: [
        Expanded(
          child: _infoTile(
            icon: Icons.person_outline_rounded,
            label: 'Student',
            primary: widget.user.displayName,
            secondary: widget.user.studentId ?? widget.user.email,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _infoTile(
            icon: Icons.computer_rounded,
            label: 'Workstation',
            primary: widget.pc.roomName,
            secondary: widget.pc.pcId,
          ),
        ),
      ],
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String primary,
    required String secondary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _fieldColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderCol),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                colors: [
                  _accentA.withOpacity(0.15),
                  _accentB.withOpacity(0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(icon, color: _accentA, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: _textColor.withOpacity(0.35),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  primary,
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  secondary,
                  style: TextStyle(
                    color: _textColor.withOpacity(0.45),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Countdown ring ────────────────────────────────────────────────────────
  Widget _buildCountdownSection() {
    final progress = _secondsLeft / _totalSeconds;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: _fieldColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderCol),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: CustomPaint(
              painter: _ArcPainter(
                progress: progress,
                trackColor: _textColor.withOpacity(0.08),
                accentA: _accentA,
                accentB: _accentB,
              ),
              child: Center(
                child: Text(
                  '$_secondsLeft',
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Minimizing in $_secondsLeft second${_secondsLeft == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hardware monitoring continues in the background.',
                  style: TextStyle(
                    color: _textColor.withOpacity(0.45),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sync badge ────────────────────────────────────────────────────────────
  Widget _buildSyncBadge() {
    return ValueListenableBuilder<int>(
      valueListenable: SyncService.instance.pendingItems,
      builder: (_, pending, __) {
        final hasPending = pending > 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _fieldColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderCol),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasPending ? Icons.sync_rounded : Icons.cloud_done_outlined,
                color: hasPending ? _accentA : _accentA.withOpacity(0.6),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                hasPending
                    ? '$pending item${pending == 1 ? '' : 's'} pending sync'
                    : 'All data synced',
                style: TextStyle(
                  color: _textColor.withOpacity(0.55),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Action buttons ────────────────────────────────────────────────────────
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(child: _buildMinimizeButton()),
        const SizedBox(width: 12),
        Expanded(child: _buildLogoutButton()),
      ],
    );
  }

  Widget _buildMinimizeButton() {
    return SizedBox(
      height: 50,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_accentA, _accentB],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _accentA.withOpacity(0.28),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _minimizeToBackground,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: const Color(0xFF080A0E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.minimize_rounded, size: 20),
          label: const Text(
            'Minimize Now',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        onPressed: _sessionEnding ? null : () => _logout(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.redAccent.shade100,
          side: BorderSide(color: Colors.redAccent.withOpacity(0.35), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          backgroundColor: Colors.red.withOpacity(0.06),
        ),
        icon: const Icon(Icons.logout_rounded, size: 19),
        label: const Text(
          'Logout',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
        ),
      ),
    );
  }
}

// ── Arc countdown painter ──────────────────────────────────────────────────
class _ArcPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color accentA;
  final Color accentB;

  const _ArcPainter({
    required this.progress,
    required this.trackColor,
    required this.accentA,
    required this.accentB,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    const strokeWidth = 4.0;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = trackColor,
    );

    final rect = Rect.fromCircle(center: center, radius: radius);
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + 2 * math.pi * progress,
        colors: [accentA, accentB],
      ).createShader(rect);

    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress;
}
