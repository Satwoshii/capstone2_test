import 'package:flutter/material.dart';

import '../services/firebase_user_service.dart';
import '../widgets/simple_app_bar.dart';
import 'admin_dashboard_screen.dart';
import 'itso_dashboard_screen.dart';

class StaffLoginScreen extends StatefulWidget {
  final String requiredRole;

  const StaffLoginScreen({
    super.key,
    required this.requiredRole,
  });

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      loading = true;
    });

    try {
      final user = await FirebaseUserService.loginStaff(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (user.role != widget.requiredRole && user.role != 'admin') {
        throw Exception('Access denied. This account is not allowed here.');
      }

      if (!mounted) return;

      if (widget.requiredRole == 'itso') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ItsoDashboardScreen(user: user),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AdminDashboardScreen(user: user),
          ),
        );
      }
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
    final title =
        widget.requiredRole == 'itso' ? 'ITSO Login' : 'Admin Login';

    return Scaffold(
      appBar: simpleAppBar(title),
      body: Center(
        child: SizedBox(
          width: 430,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.requiredRole == 'itso'
                        ? Icons.computer
                        : Icons.admin_panel_settings,
                    size: 64,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
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
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: loading ? null : _login,
                      icon: const Icon(Icons.login),
                      label: Text(loading ? 'Logging in...' : 'Login'),
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
