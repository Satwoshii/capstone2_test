import 'package:flutter/material.dart';

import '../../models/hardware_status.dart';
import '../../models/pc_identity.dart';
import '../../widgets/issue_support_launcher.dart';

class MinorPeripheralWarningScreen extends StatelessWidget {
  final PcIdentity pc;
  final HardwareStatus hardware;
  final bool sessionActive;
  final Future<void> Function()? onContinueInBackground;

  const MinorPeripheralWarningScreen({
    super.key,
    required this.pc,
    required this.hardware,
    required this.sessionActive,
    this.onContinueInBackground,
  });

  List<String> get _suggestions {
    final tips = <String>[];

    for (final issue in hardware.minorIssues) {
      switch (issue) {
        case 'mouse':
          tips.add('Reconnect the mouse or try another USB port.');
          tips.add('Check whether the mouse sensor light turns on.');
          break;
        case 'keyboard':
          tips.add('Reconnect the keyboard or try another USB port.');
          tips.add('Check whether Caps Lock or Num Lock responds.');
          break;
        case 'monitor':
          tips.add('Check the monitor power and display cables.');
          tips.add('Make sure the monitor is turned on.');
          break;
      }
    }

    return tips.toSet().toList();
  }

  Future<void> _continue(BuildContext context) async {
    Navigator.of(context).pop();
    await onContinueInBackground?.call();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.amber.shade700,
        body: Center(
          child: Container(
            width: 760,
            constraints: const BoxConstraints(maxHeight: 720),
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.amber.shade800,
                    size: 88,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'MINOR PERIPHERAL WARNING',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    hardware.minorIssues.join(', ').toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    sessionActive
                        ? 'Your session remains active. Syswatch will keep '
                            'checking the device in the background.'
                        : 'You may continue to student authentication. '
                            'Syswatch will keep checking the device.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  ..._suggestions.map(
                    (tip) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.build_circle_outlined),
                      title: Text(tip),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Chip(
                    avatar: const Icon(Icons.monitor_heart, size: 18),
                    label: const Text(
                      'Automatic recovery check runs every 10 seconds',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${pc.roomName} - ${pc.pcId}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  if (sessionActive) ...[
                    const IssueSupportLauncher(compact: true),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _continue(context),
                    icon: Icon(
                      sessionActive
                          ? Icons.visibility_off
                          : Icons.arrow_forward,
                    ),
                    label: Text(
                      sessionActive
                          ? 'Continue in Background'
                          : 'Continue to Login',
                    ),
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
