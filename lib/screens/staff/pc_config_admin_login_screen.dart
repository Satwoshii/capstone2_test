import 'package:flutter/material.dart';

import '../../services/app_config_service.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../itso/pc_config_screen.dart';

class PcConfigAdminLoginScreen extends StatefulWidget {
  const PcConfigAdminLoginScreen({super.key});

  @override
  State<PcConfigAdminLoginScreen> createState() =>
      _PcConfigAdminLoginScreenState();
}

class _PcConfigAdminLoginScreenState
    extends State<PcConfigAdminLoginScreen> {
  final serverUrlController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadServerUrl();
  }

  Future<void> _loadServerUrl() async {
    serverUrlController.text = await AppConfigService.instance.getServerUrl();
  }

  @override
  void dispose() {
    serverUrlController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginForPcConfig() async {
    if (loading) return;
    setState(() => loading = true);

    try {
      await AppConfigService.instance.saveServerUrl(
        serverUrlController.text,
      );

      final user = await AuthService.loginStaff(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      if (user.role != 'admin') {
        throw Exception(
          'Access denied. PC configuration requires an admin account.',
        );
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PcConfigScreen()),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception:', '').trim(),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin PC Configuration Login'),
        actions: [
          IconButton(
            onPressed: () => ThemeService.instance.toggleTheme(),
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            tooltip: 'Toggle Theme',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 500,
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
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Connect to the local Syswatch server, then sign in with '
                      'an administrator account.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: serverUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Syswatch server URL',
                        hintText: 'http://192.168.1.10/syswatch_api',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
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
                        label: Text(
                          loading ? 'Connecting...' : 'Open PC Configuration',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
