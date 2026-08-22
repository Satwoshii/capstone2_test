import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../../services/pc_monitor_service.dart';
import '../student/student_login_screen.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen>
    with TickerProviderStateMixin {

  // ── Boot steps ──────────────────────────────────────────────────────────
  static const _steps = [
    'Initialising SysWatch...',
    'Checking hardware and peripherals...',
    'Connecting to the local Syswatch server...',
    'Ready.',
  ];

  int _stepIndex = 0;
  String get _message => _steps[_stepIndex.clamp(0, _steps.length - 1)];

  // ── Animation controllers ────────────────────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final AnimationController _entryCtrl;
  late final AnimationController _progressCtrl;
  late final AnimationController _morphCtrl;

  late final Animation<double> _pulseAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _glowAnim;
  late final Animation<double> _morphAnim;

  // ── Palette ──────────────────────────────────────────────────────────────
  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  Color get _bgColor =>
      _isDarkMode ? const Color(0xFF090A0E) : const Color(0xFFF0F2F5);
  Color get _cardColor =>
      _isDarkMode ? const Color(0xFF13141A) : Colors.white;
  Color get _accentA => const Color(0xFF2EE6C5);
  Color get _accentB => const Color(0xFF4F8EF7);
  Color get _border =>
      _isDarkMode ? const Color(0x12FFFFFF) : Colors.black.withOpacity(0.09);

  // ── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.88, end: 1.14).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _glowAnim = Tween<double>(begin: 0.2, end: 0.5).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.07),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Continuously morphs the logo glyph back and forth: 0 = monitor, 1 = chip.
    _morphCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);
    _morphAnim = CurvedAnimation(parent: _morphCtrl, curve: Curves.easeInOutCubic);

    _entryCtrl.forward();
    _boot();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _entryCtrl.dispose();
    _progressCtrl.dispose();
    _morphCtrl.dispose();
    super.dispose();
  }

  // ── Boot sequence ─────────────────────────────────────────────────────────
  Future<void> _boot() async {
    await _advanceTo(1);
    await PcMonitorService.instance.checkNow(showWarnings: false);

    if (!mounted) return;
    await _advanceTo(2);
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;
    await _advanceTo(3);
    await Future.delayed(const Duration(milliseconds: 450));

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const StudentLoginScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      PcMonitorService.instance.presentCurrentWarning();
    });
  }

  Future<void> _advanceTo(int index) async {
    if (!mounted) return;
    setState(() => _stepIndex = index);
    await _progressCtrl.animateTo(
      index / (_steps.length - 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOut,
    );
    await Future.delayed(const Duration(milliseconds: 200));
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
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: _buildCard(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmbientOrbs() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -90,
            left: -90,
            child: _orb(300, _accentA.withOpacity(0.07)),
          ),
          Positioned(
            bottom: -110,
            right: -70,
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

  Widget _buildCard() {
    return Container(
      width: 380,
      padding: const EdgeInsets.fromLTRB(36, 44, 36, 40),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.55),
            blurRadius: 64,
            offset: const Offset(0, 28),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPulsingLogo(),
          const SizedBox(height: 26),

          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [_accentA, _accentB],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(bounds),
            child: const Text(
              'SysWatch',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'PC Access & Monitoring System',
            style: TextStyle(
              color: _isDarkMode ? const Color(0x66FFFFFF) : Colors.black45,
              fontSize: 13,
              letterSpacing: 0.2,
            ),
          ),

          const SizedBox(height: 36),
          _buildProgressLine(),
          const SizedBox(height: 10),
          _buildProgressPercent(),
          const SizedBox(height: 16),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: Text(
              _message,
              key: ValueKey(_stepIndex),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _isDarkMode ? const Color(0x80FFFFFF) : Colors.black54,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Top logo (pulsing ring + morphing monitor⇄chip glyph) ──────────────────
  Widget _buildPulsingLogo() {
    return SizedBox(
      width: 130,
      height: 130,
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: _pulseAnim.value,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _accentA.withOpacity(_glowAnim.value * 0.6),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _accentA.withOpacity(_glowAnim.value * 0.4),
                        blurRadius: 28,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      _accentA.withOpacity(0.12),
                      _accentB.withOpacity(0.10),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: _accentA.withOpacity(0.5),
                    width: 1.8,
                  ),
                ),
              ),
              ClipOval(
                child: SizedBox(
                  width: 78,
                  height: 78,
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _morphAnim,
                      builder: (context, _) {
                        return CustomPaint(
                          size: const Size(48, 48),
                          painter: _LogoMorphPainter(
                            t: _morphAnim.value,
                            colorA: _accentA,
                            colorB: _accentB,
                          ),
                        );
                      },
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

  // ── Progress line ───────────────────────────────────────────────────────
  Widget _buildProgressLine() {
    return AnimatedBuilder(
      animation: _progressCtrl,
      builder: (context, _) {
        final fill = _progressCtrl.value.clamp(0.0, 1.0);
        return SizedBox(
          height: 8,
          width: double.infinity,
          child: Stack(
            children: [
              // track
              Container(
                height: 6,
                margin: const EdgeInsets.symmetric(vertical: 1),
                decoration: BoxDecoration(
                  color: _isDarkMode
                      ? Colors.white.withOpacity(0.07)
                      : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // filled portion
              FractionallySizedBox(
                widthFactor: fill.clamp(0.015, 1.0),
                child: Container(
                  height: 6,
                  margin: const EdgeInsets.symmetric(vertical: 1),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(colors: [_accentA, _accentB]),
                    boxShadow: [
                      BoxShadow(
                        color: _accentA.withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressPercent() {
    return AnimatedBuilder(
      animation: _progressCtrl,
      builder: (context, _) {
        final fill = _progressCtrl.value.clamp(0.0, 1.0);
        return Text(
          '${(fill * 100).round()}%',
          style: TextStyle(
            color: _accentA,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        );
      },
    );
  }
}

// ── Morphing monitor⇄chip glyph painter ─────────────────────────────────────
//
// t = 0.0 → drawn as a monitor (screen + stand)
// t = 1.0 → drawn as a CPU chip (square body + pins)
//
// The body outline is a single RRect whose bounds/radius are lerped between
// the two shapes every frame, so it visually reshapes itself rather than
// cross-fading two separate icons. The monitor's stand shrinks/fades out
// while the chip's pins grow/fade in from the body edges at the same time.
class _LogoMorphPainter extends CustomPainter {
  final double t;
  final Color colorA;
  final Color colorB;

  _LogoMorphPainter({
    required this.t,
    required this.colorA,
    required this.colorB,
  });

  double _lerp(double a, double b) => ui.lerpDouble(a, b, t)!;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    final shader = LinearGradient(
      colors: [colorA, colorB],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(rect);

    Paint strokePaint({double opacity = 1.0, double? widthOverride}) => Paint()
      ..shader = shader
      ..color = Colors.white.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = widthOverride ?? w * 0.075
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    Paint fillPaint({double opacity = 1.0}) => Paint()
      ..shader = shader
      ..color = Colors.white.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    // ── Morphing body: monitor screen ⇄ chip square ──────────────────────
    final left = _lerp(w * 0.12, w * 0.27);
    final top = _lerp(h * 0.10, h * 0.26);
    final right = _lerp(w * 0.88, w * 0.73);
    final bottom = _lerp(h * 0.60, h * 0.74);
    final radius = _lerp(w * 0.16, w * 0.10);

    final bodyRect = Rect.fromLTRB(left, top, right, bottom);
    final bodyRRect = RRect.fromRectAndRadius(bodyRect, Radius.circular(radius));
    canvas.drawRRect(bodyRRect, strokePaint());

    // ── Monitor-only: stand neck + base — shrink & fade out as t → 1 ──────
    final monitorAmt = (1 - t).clamp(0.0, 1.0);
    if (monitorAmt > 0.01) {
      canvas.save();
      final standCenter = Offset(w * 0.5, h * 0.66);
      canvas.translate(standCenter.dx, standCenter.dy);
      canvas.scale(monitorAmt, monitorAmt);
      canvas.translate(-standCenter.dx, -standCenter.dy);

      // neck
      final neck = Rect.fromLTWH(w * 0.44, h * 0.60, w * 0.12, h * 0.10);
      canvas.drawRRect(
        RRect.fromRectAndRadius(neck, Radius.circular(w * 0.02)),
        fillPaint(opacity: monitorAmt),
      );
      // base
      final base = Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.74),
        width: w * 0.36,
        height: h * 0.055,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(base, Radius.circular(h * 0.03)),
        fillPaint(opacity: monitorAmt),
      );
      canvas.restore();

      // screen "signal" line
      final signalY = h * 0.30;
      canvas.drawLine(
        Offset(w * 0.28, signalY),
        Offset(w * 0.72, signalY),
        strokePaint(opacity: monitorAmt * 0.7, widthOverride: w * 0.035),
      );
    }

    // ── Chip-only: pins growing out from the body edges as t → 1 ──────────
    final chipAmt = t.clamp(0.0, 1.0);
    if (chipAmt > 0.01) {
      final pinLen = chipAmt * w * 0.11;
      final pinThickness = w * 0.045;

      void drawPin(Offset from, Offset direction) {
        final to = from + direction * pinLen;
        canvas.drawLine(
          from,
          to,
          strokePaint(opacity: chipAmt, widthOverride: pinThickness),
        );
      }

      // 3 evenly spaced pins per side, growing outward from the body edge.
      for (final frac in [0.28, 0.5, 0.72]) {
        // top
        drawPin(
          Offset(left + (right - left) * frac, top),
          const Offset(0, -1),
        );
        // bottom
        drawPin(
          Offset(left + (right - left) * frac, bottom),
          const Offset(0, 1),
        );
        // left
        drawPin(
          Offset(left, top + (bottom - top) * frac),
          const Offset(-1, 0),
        );
        // right
        drawPin(
          Offset(right, top + (bottom - top) * frac),
          const Offset(1, 0),
        );
      }

      // center circuit dot
      canvas.drawCircle(
        Offset(w * 0.5, h * 0.5),
        w * 0.035,
        fillPaint(opacity: chipAmt),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LogoMorphPainter oldDelegate) =>
      oldDelegate.t != t ||
          oldDelegate.colorA != colorA ||
          oldDelegate.colorB != colorB;
}