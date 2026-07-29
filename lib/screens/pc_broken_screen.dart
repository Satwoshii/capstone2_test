import 'package:flutter/material.dart';

import '../models/hardware_status.dart';
import '../models/pc_identity.dart';
import 'staff/pc_config_admin_login_screen.dart';

class PcBrokenScreen extends StatelessWidget {
  final PcIdentity pc;
  final HardwareStatus hardware;
  final bool sessionActive;

  const PcBrokenScreen({
    super.key,
    required this.pc,
    required this.hardware,
    this.sessionActive = false,
  });

  String get issueText {
    final blocking = [
      ...hardware.highIssues,
      ...hardware.criticalIssues,
    ];
    if (blocking.isNotEmpty) return blocking.join('\n');
    return hardware.issues.isEmpty ? 'Unknown issue' : hardware.issues.join('\n');
  }

  List<String> get ethernetSuggestions {
    if (!hardware.highIssues.contains('ethernet')) return const [];
    return const [
      'Check whether the Ethernet/LAN cable is securely connected.',
      'Check whether the Ethernet port link light is on or blinking.',
      'Use another LAN cable or contact ITSO if the cable is damaged.',
    ];
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.red.shade900,
        body: Center(
          child: Container(
            width: 820,
            constraints: const BoxConstraints(maxHeight: 760),
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: SingleChildScrollView(
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
                  const SizedBox(height: 24),
                  const Text(
                    'Issue Detected:',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    issueText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Please use another workstation and contact ITSO.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20),
                  ),
                  if (sessionActive) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Your current student session has been preserved and '
                      'will resume automatically after recovery.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const Chip(
                    avatar: Icon(Icons.monitor_heart, size: 18),
                    label: Text(
                      'Syswatch automatically rechecks every 10 seconds',
                    ),
                  ),
                  if (!hardware.hasCriticalIssue &&
                      ethernetSuggestions.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Ethernet checks:',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...ethernetSuggestions.map(
                      (tip) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.cable),
                        title: Text(tip),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Text(
                    '${pc.roomName} - ${pc.pcId}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 22),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PcConfigAdminLoginScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.admin_panel_settings),
                    label: const Text('Admin PC Config Override'),
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
