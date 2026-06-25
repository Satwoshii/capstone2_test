import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../services/auth_session_service.dart';
import '../../services/firebase_service.dart';

class PhoneQrScanScreen extends StatefulWidget {
  const PhoneQrScanScreen({super.key});

  @override
  State<PhoneQrScanScreen> createState() => _PhoneQrScanScreenState();
}

class _PhoneQrScanScreenState extends State<PhoneQrScanScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _scannerController = MobileScannerController();

  bool _signedIn = FirebaseAuth.instance.currentUser != null;
  bool _working = false;
  bool _obscurePassword = true;

  Future<void> _signIn() async {
    if (_working) return;
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      _message('Enter your institutional email and password.');
      return;
    }
    setState(() => _working = true);
    try {
      await FirebaseService.instance.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
      await FirebaseService.instance.upsertCurrentUser(role: 'student');
      if (mounted) setState(() => _signedIn = true);
    } on FirebaseAuthException catch (error) {
      _message(error.message ?? error.code);
    } catch (error) {
      _message(error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _approve(String rawValue) async {
    if (_working) return;
    final user = FirebaseService.instance.currentUser;
    if (user == null || user.email == null) {
      _message('Sign in before scanning.');
      return;
    }

    final parts = rawValue.split('|');
    if (parts.length != 4 || parts[0] != 'LABSCAN_AUTH') {
      _message('This is not a valid LabScan authentication QR code.');
      return;
    }

    setState(() => _working = true);
    await _scannerController.stop();
    try {
      await AuthSessionService.instance.approveSession(
        sessionId: parts[1],
        studentEmail: user.email!,
        studentUid: user.uid,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Authentication approved'),
          content: Text('PC ${parts[2]} in room ${parts[3]} may now continue.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (error) {
      _message(error.toString().replaceFirst('Bad state: ', ''));
      await _scannerController.start();
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_signedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Student Sign In')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                const Icon(Icons.account_circle, size: 72),
                const SizedBox(height: 20),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Institutional email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _working ? null : _signIn,
                  child: _working
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sign In'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final user = FirebaseService.instance.currentUser!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan PC QR'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await FirebaseService.instance.signOut();
              if (mounted) setState(() => _signedIn = false);
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('Signed in as ${user.email}'),
          ),
          Expanded(
            child: MobileScanner(
              controller: _scannerController,
              onDetect: (capture) {
                if (capture.barcodes.isEmpty) return;
                final value = capture.barcodes.first.rawValue;
                if (value != null) _approve(value);
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Scan the QR shown on the laboratory computer.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
