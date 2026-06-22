import 'package:flutter/material.dart';

import '../models/hardware_status.dart';
import '../models/pc_identity.dart';
import 'role_select_screen.dart';

class PcBrokenScreen extends StatelessWidget {
  final PcIdentity pc;
  final HardwareStatus hardware;

  const PcBrokenScreen({
    super.key,
    required this.pc,
    required this.hardware,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade900,
      body: Center(
        child: Container(
          width: 750,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
                size: 90,
              ),
              const SizedBox(height: 20),
              const Text(
                'PC BROKEN',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 46,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${pc.roomName} - ${pc.pcId}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Issue Detected:',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hardware.issues.join('\n'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 28),
              const Text(
                'Please use another workstation and contact ITSO.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RoleSelectScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.admin_panel_settings),
                label: const Text('ITSO/Admin Override'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
