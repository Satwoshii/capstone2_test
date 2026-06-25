import 'package:flutter/material.dart';

import '../../services/firebase_user_service.dart';
import '../itso/pc_config_screen.dart';

class PcConfigAdminLoginScreen extends StatefulWidget {
  const PcConfigAdminLoginScreen({super.key});

  @override
  State<PcConfigAdminLoginScreen> createState() => _PcConfigAdminLoginScreenState();
}

class _PcConfigAdminLoginScreenState extends State<PcConfigAdminLoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginForPcConfig() async {
    if (loading) return;

    setState(() {
      loading = true;
    });

    try {
      final user = await FirebaseUserService.loginStaff(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final role = user.role.trim().toLowerCase();

      if (role != 'admin') {
        throw Exception('Access denied. PC configuration requires an admin account.');
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PcConfigScreen()),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin PC Configuration Login'),
      ),
      body: Center(
        child: SizedBox(
          width: 430,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.settings_applications, size: 64),
                  const SizedBox(height: 14),
                  const Text(
                    'PC Configuration Access',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This hidden login is only for configuring the local laboratory PC.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Admin Email',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _loginForPcConfig(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _loginForPcConfig(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: loading ? null : _loginForPcConfig,
                      icon: const Icon(Icons.login),
                      label: Text(loading ? 'Checking...' : 'Open PC Configuration'),
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
