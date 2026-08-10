import 'package:flutter/material.dart';

import '../../services/pc_monitor_service.dart';
import '../student/student_login_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SETUP NOTE
// Add the SysWatch logo to your pubspec.yaml under flutter > assets:
//   assets:
//     - assets/images/syswatch_logo.png
// Copy attached_assets/image_1785934598393.png → assets/images/syswatch_logo.png
// ─────────────────────────────────────────────────────────────────────────────

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

  late final Animation<double> _pulseAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _glowAnim;

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

    _entryCtrl.forward();
    _boot();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _entryCtrl.dispose();
    _progressCtrl.dispose();
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
          _buildProgressBar(),
          const SizedBox(height: 16),
          _buildChip(),
          const SizedBox(height: 14),

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

  // ── Top logo (original image-based, pulsing) ───────────────────────────────
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
                  child: Image.asset(
                    'assets/images/syswatch_logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => ShaderMask(
                      shaderCallback: (b) => LinearGradient(
                        colors: [_accentA, _accentB],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(b),
                      child: const Icon(
                        Icons.monitor_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
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

  // ── Chip fill indicator (replaces the step dots row) ───────────────────────
  Widget _buildChip() {
    return AnimatedBuilder(
      animation: _progressCtrl,
      builder: (context, _) {
        final fill = _progressCtrl.value.clamp(0.0, 1.0);
        const chipSize = 40.0;
        const pinLength = 6.0;
        const pinThickness = 3.2;
        final pinColor = _accentA.withOpacity(0.55 + 0.35 * fill);

        Widget pinsRow({required Axis axis}) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: axis == Axis.horizontal ? pinThickness : pinLength,
                height: axis == Axis.horizontal ? pinLength : pinThickness,
                decoration: BoxDecoration(
                  color: pinColor,
                  borderRadius: BorderRadius.circular(1.2),
                ),
              );
            }),
          );
        }

        return SizedBox(
          width: chipSize + pinLength * 2,
          height: chipSize + pinLength * 2,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(top: 0, child: pinsRow(axis: Axis.vertical)),
              Positioned(bottom: 0, child: pinsRow(axis: Axis.vertical)),
              Positioned(
                left: 0,
                child: RotatedBox(quarterTurns: 1, child: pinsRow(axis: Axis.horizontal)),
              ),
              Positioned(
                right: 0,
                child: RotatedBox(quarterTurns: 1, child: pinsRow(axis: Axis.horizontal)),
              ),

              // chip body
              Container(
                width: chipSize,
                height: chipSize,
                decoration: BoxDecoration(
                  color: _isDarkMode ? const Color(0xFF0D0F14) : Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: _accentA.withOpacity(0.45), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: _accentA.withOpacity(0.18 + 0.22 * fill),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Stack(
                    children: [
                      // rising fill
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: fill.clamp(0.02, 1.0),
                          widthFactor: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [_accentA, _accentB.withOpacity(0.85)],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // faint circuit etching
                      Opacity(
                        opacity: 0.35,
                        child: CustomPaint(
                          size: const Size(chipSize, chipSize),
                          painter: _CircuitPainter(
                            color: _isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      // percentage readout
                      Center(
                        child: Text(
                          '${(fill * 100).round()}%',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                            color: fill > 0.45
                                ? (_isDarkMode ? Colors.black87 : Colors.white)
                                : (_isDarkMode ? Colors.white70 : Colors.black87),
                          ),
                        ),
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

  Widget _buildProgressBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 5,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _progressCtrl,
          builder: (context, _) {
            return Stack(
              children: [
                Container(color: _isDarkMode ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.05)),
                FractionallySizedBox(
                  widthFactor: _progressCtrl.value,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_accentA, _accentB],
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x552EE6C5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Circuit etching painter for the chip body ─────────────────────────────────
class _CircuitPainter extends CustomPainter {
  final Color color;
  _CircuitPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color.withOpacity(0.5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final dot = Paint()..color = color.withOpacity(0.5);

    final w = size.width;
    final h = size.height;

    canvas.drawLine(Offset(w * 0.2, 0), Offset(w * 0.2, h * 0.3), line);
    canvas.drawLine(Offset(w * 0.8, h), Offset(w * 0.8, h * 0.7), line);
    canvas.drawLine(Offset(0, h * 0.65), Offset(w * 0.3, h * 0.65), line);
    canvas.drawLine(Offset(w * 0.7, h * 0.35), Offset(w, h * 0.35), line);

    canvas.drawCircle(Offset(w * 0.2, h * 0.3), 1.2, dot);
    canvas.drawCircle(Offset(w * 0.8, h * 0.7), 1.2, dot);
    canvas.drawCircle(Offset(w * 0.3, h * 0.65), 1.2, dot);
    canvas.drawCircle(Offset(w * 0.7, h * 0.35), 1.2, dot);
  }

  @override
  bool shouldRepaint(covariant _CircuitPainter oldDelegate) =>
      oldDelegate.color != color;
}