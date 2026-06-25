import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/app_config_service.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_user_service.dart';
import '../../services/local_db_service.dart';
import '../../services/sync_service.dart';
import '../../widgets/simple_app_bar.dart';
import '../staff/pc_config_admin_login_screen.dart';
import 'student_access_screen.dart';

class StudentLoginScreen extends StatefulWidget {
  const StudentLoginScreen({super.key});

  @override
  State<StudentLoginScreen> createState() => _StudentLoginScreenState();
}

class _StudentLoginScreenState extends State<StudentLoginScreen> {
  final studentIdController = TextEditingController();
  final passwordController = TextEditingController();
  final FocusNode shortcutFocusNode = FocusNode();

  bool loading = false;
  bool syncingUsers = true;
  String syncMessage = 'Preparing offline login...';

  @override
  void initState() {
    super.initState();
    _autoSyncUsers();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        shortcutFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    studentIdController.dispose();
    passwordController.dispose();
    shortcutFocusNode.dispose();
    super.dispose();
  }

  Future<void> _autoSyncUsers() async {
    if (!mounted) return;

    setState(() {
      syncingUsers = true;
      syncMessage = 'Preparing offline login...';
    });

    try {
      await FirebaseUserService.downloadUsersToSQLite();
      await SyncService.instance.refreshPendingCount();

      if (!mounted) return;

      setState(() {
        syncMessage = 'Offline login is ready.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        syncMessage = 'Offline mode: using saved local accounts.';
      });
    } finally {
      if (mounted) {
        setState(() {
          syncingUsers = false;
        });
        shortcutFocusNode.requestFocus();
      }
    }
  }

  Future<void> _login() async {
    if (loading || syncingUsers) return;

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
        shortcutFocusNode.requestFocus();
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

  void _openPcConfigAdminLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PcConfigAdminLoginScreen()),
    ).then((_) {
      if (mounted) {
        shortcutFocusNode.requestFocus();
      }
    });
  }

  bool _isStaffShortcut(KeyEvent event) {
    return event is KeyDownEvent &&
        HardwareKeyboard.instance.isControlPressed &&
        HardwareKeyboard.instance.isShiftPressed &&
        event.logicalKey == LogicalKeyboardKey.keyA;
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: shortcutFocusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (_isStaffShortcut(event)) {
          _openPcConfigAdminLogin();
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          shortcutFocusNode.requestFocus();
        },
        child: PopScope(
          canPop: false,
          child: Scaffold(
            appBar: simpleAppBar('Student Authentication'),
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
                            onPressed: loading || syncingUsers ? null : _login,
                            icon: const Icon(Icons.login),
                            label: Text(
                              loading
                                  ? 'Please wait...'
                                  : syncingUsers
                                      ? 'Preparing...'
                                      : 'Login',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Syncing happens automatically in the background.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Admin PC config shortcut: Ctrl + Shift + A',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
