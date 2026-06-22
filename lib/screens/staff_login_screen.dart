import 'package:flutter/material.dart';

import '../services/firebase_user_service.dart';
import 'admin_dashboard_screen.dart';
import 'itso_dashboard_screen.dart';

class StaffLoginScreen extends StatefulWidget {
  final VoidCallback? onBackToStudentKiosk;

  const StaffLoginScreen({
    super.key,
    this.onBackToStudentKiosk,
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

      if (!mounted) return;

      if (role == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AdminDashboardScreen(user: user),
          ),
        );
      } else if (role == 'itso') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ItsoDashboardScreen(user: user),
          ),
        );
      } else {
        throw Exception('Access denied. This account is not ITSO or Admin.');
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll('Exception:', '').trim(),
          ),
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
        title: const Text('Staff Portal'),
        leading: IconButton(
          tooltip: 'Back to Student Kiosk',
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBackToStudentKiosk ?? () => Navigator.pop(context),
        ),
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
                  const Icon(
                    Icons.admin_panel_settings,
                    size: 64,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Staff Login',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Admin and ITSO accounts are separated by role after login.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: loading ? null : _login,
                      icon: const Icon(Icons.login),
                      label: Text(
                        loading ? 'Logging in...' : 'Login',
                      ),
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
