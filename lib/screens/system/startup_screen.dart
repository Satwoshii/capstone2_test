import 'package:flutter/material.dart';

import '../../services/pc_monitor_service.dart';
import '../student/student_login_screen.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  String message = 'Starting Syswatch...';

  @override
  void initState() {
    super.initState();
    _boot();
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
        body: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    message,
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
