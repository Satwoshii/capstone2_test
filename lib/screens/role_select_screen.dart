import 'package:flutter/material.dart';

import '../services/sync_service.dart';
import '../widgets/role_card.dart';
import 'pc_config_screen.dart';
import 'staff_login_screen.dart';
import 'student_login_screen.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cards = [
      RoleCard(
        title: 'Student Login',
        subtitle: 'Login before using this PC',
        icon: Icons.school,
        color: Colors.blue,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StudentLoginScreen()),
          );
        },
      ),
      RoleCard(
        title: 'ITSO Dashboard',
        subtitle: 'View PC status and repair reports',
        icon: Icons.computer,
        color: Colors.green,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const StaffLoginScreen(requiredRole: 'itso'),
            ),
          );
        },
      ),
      RoleCard(
        title: 'Admin Module',
        subtitle: 'Manage users, rooms, and PCs',
        icon: Icons.admin_panel_settings,
        color: Colors.deepPurple,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const StaffLoginScreen(requiredRole: 'admin'),
            ),
          );
        },
      ),
      RoleCard(
        title: 'PC Configuration',
        subtitle: 'Set room name and PC ID',
        icon: Icons.settings,
        color: Colors.orange,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PcConfigScreen()),
          );
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hybrid PC Monitoring System'),
        actions: [
          IconButton(
            onPressed: () async {
              await SyncService.instance.syncNow();

              if (!context.mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sync finished')),
              );
            },
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      body: Center(
        child: SizedBox(
          width: 900,
          child: GridView.count(
            padding: const EdgeInsets.all(24),
            crossAxisCount: 2,
            childAspectRatio: 2.2,
            crossAxisSpacing: 18,
            mainAxisSpacing: 18,
            children: cards,
          ),
        ),
      ),
    );
  }
}
