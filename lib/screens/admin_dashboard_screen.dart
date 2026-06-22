import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/firebase_user_service.dart';
import '../services/sync_service.dart';
import 'role_select_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final AppUser user;

  const AdminDashboardScreen({
    super.key,
    required this.user,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final studentIdController = TextEditingController();

  String selectedRole = 'student';
  bool loading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    studentIdController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    setState(() {
      loading = true;
    });

    try {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();
      final name = nameController.text.trim();
      final studentId = studentIdController.text.trim();

      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await FirebaseUserService.createUserProfile(
        uid: credential.user!.uid,
        email: email,
        displayName: name,
        role: selectedRole,
        studentId: selectedRole == 'student' ? studentId : null,
        plainPassword: selectedRole == 'student' ? password : null,
      );

      await FirebaseUserService.downloadUsersToSQLite();

      emailController.clear();
      passwordController.clear();
      nameController.clear();
      studentIdController.clear();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created successfully.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception:', '').trim()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _seedRoomsAndPcs() async {
    await SyncService.instance.seedDefaultRoomsAndPcs();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rooms and PCs created in Firestore.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = selectedRole == 'student';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Module'),
        actions: [
          IconButton(
            onPressed: _seedRoomsAndPcs,
            icon: const Icon(Icons.cloud_sync),
          ),
          IconButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Create Account',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 520,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'student',
                          child: Text('Student'),
                        ),
                        DropdownMenuItem(
                          value: 'itso',
                          child: Text('ITSO'),
                        ),
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text('Admin'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedRole = value ?? 'student';
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Display Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (isStudent) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: studentIdController,
                        decoration: const InputDecoration(
                          labelText: 'Student ID',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: loading ? null : _createAccount,
                        icon: const Icon(Icons.person_add),
                        label: Text(
                          loading ? 'Creating...' : 'Create Account',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Firestore Collections Used',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'users, rooms, pcs, login_logs, fault_reports, maintenance_logs, pc_status, system_config',
          ),
        ],
      ),
    );
  }
}
