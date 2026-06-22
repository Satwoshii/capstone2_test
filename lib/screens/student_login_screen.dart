import 'package:flutter/material.dart';

import '../services/app_config_service.dart';
import '../services/auth_service.dart';
import '../services/firebase_user_service.dart';
import '../services/local_db_service.dart';
import '../services/sync_service.dart';
import '../widgets/simple_app_bar.dart';
import 'student_access_screen.dart';

class StudentLoginScreen extends StatefulWidget {
  const StudentLoginScreen({super.key});

  @override
  State<StudentLoginScreen> createState() => _StudentLoginScreenState();
}

class _StudentLoginScreenState extends State<StudentLoginScreen> {
  final studentIdController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool syncingUsers = true;
  String syncMessage = 'Syncing users from Firebase...';

  @override
  void initState() {
    super.initState();
    _autoSyncUsers();
  }

  Future<void> _autoSyncUsers() async {
    setState(() {
      syncingUsers = true;
      syncMessage = 'Syncing users from Firebase...';
    });

    try {
      await FirebaseUserService.downloadUsersToSQLite();
      await SyncService.instance.refreshPendingCount();

      if (!mounted) return;

      setState(() {
        syncMessage = 'Users synced. Offline login is ready.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        syncMessage = 'Offline mode. Using saved local accounts.';
      });
    } finally {
      if (mounted) {
        setState(() {
          syncingUsers = false;
        });
      }
    }
  }

  @override
  void dispose() {
    studentIdController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      loading = true;
    });

    try {
      final user = await AuthService.loginOffline(
        studentId: studentIdController.text.trim(),
        password: passwordController.text.trim(),
      );

      final pc = await AppConfigService.instance.getPcIdentity();

      final loginLogId = await LocalDbService.instance.insertLoginLog(
        user: user,
        pc: pc,
      );

      await SyncService.instance.syncPendingData();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => StudentAccessScreen(
            user: user,
            pc: pc,
            loginLogId: loginLogId,
          ),
        ),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _manualSyncUsers() async {
    setState(() {
      loading = true;
    });

    try {
      await FirebaseUserService.downloadUsersToSQLite();
      await SyncService.instance.refreshPendingCount();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student accounts synced from Firebase.'),
        ),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.replaceAll('Exception:', '').trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: simpleAppBar('Student Login'),
      body: Center(
        child: SizedBox(
          width: 430,
          child: Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock, size: 64),
                  const SizedBox(height: 12),
                  const Text(
                    'Login Before Using PC',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (syncingUsers) ...[
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          syncMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: syncingUsers
                                ? Colors.blue
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: studentIdController,
                    decoration: const InputDecoration(
                      labelText: 'Student ID',
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
                      onPressed: loading || syncingUsers ? null : _login,
                      icon: const Icon(Icons.login),
                      label: Text(
                        loading
                            ? 'Please wait...'
                            : syncingUsers
                            ? 'Syncing users...'
                            : 'Login',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: loading || syncingUsers ? null : _manualSyncUsers,
                    icon: const Icon(Icons.sync),
                    label: const Text('Sync Users Again'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Accounts are synced automatically when this screen opens.',
                    textAlign: TextAlign.center,
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