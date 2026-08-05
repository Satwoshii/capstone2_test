import 'package:flutter/material.dart';

import '../../services/pc_monitor_service.dart';
import '../student/student_login_screen.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen>
    with SingleTickerProviderStateMixin {
  String message = 'Starting SysWatch...';

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  static const Color _bgColor = Color(0xFF0E0F12);
  static const Color _cardColor = Color(0xFF17181D);
  static const Color _accent = Color(0xFF2EE6C5);

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _boot();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    setState(() {
      message = 'Checking hardware and peripherals...';
    });

    // This is the initial scan of the one global monitor. It records status
    // but waits until the login route exists before presenting a warning.
    await PcMonitorService.instance.checkNow(showWarnings: false);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const StudentLoginScreen(),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      PcMonitorService.instance.presentCurrentWarning();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _bgColor,
        body: Center(
          child: Container(
            width: 360,
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPulsingLogo(),
                const SizedBox(height: 28),
                const Text(
                  'SysWatch',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                _buildLoadingBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPulsingLogo() {
    return SizedBox(
      width: 110,
      height: 110,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow ring, pulsing
              Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _accent.withOpacity(0.35),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _accent.withOpacity(0.25),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
              // Static inner ring
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _accent, width: 2.5),
                ),
              ),
              // Chip icon
              Icon(
                Icons.memory_rounded,
                color: _accent,
                size: 34,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 6,
        width: 180,
        child: LinearProgressIndicator(
          backgroundColor: Colors.white.withOpacity(0.08),
          valueColor: const AlwaysStoppedAnimation<Color>(_accent),
        ),
      ),
    );
  }
}