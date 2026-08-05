import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/app_config_service.dart';
import '../../services/auth_service.dart';
import '../../services/local_db_service.dart';
import '../../services/pc_monitor_service.dart';
import '../../services/sync_service.dart';
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
  String syncMessage = 'Connecting to the Syswatch intranet server...';
  bool _isDarkMode = true;

  Color get _bgColor => _isDarkMode ? const Color(0xFF0E0F12) : const Color(0xFFF5F6F9);
  Color get _cardColor => _isDarkMode ? const Color(0xFF17181D) : Colors.white;
  Color get _fieldColor => _isDarkMode ? const Color(0xFF1F2127) : const Color(0xFFEFF1F5);
  Color get _accent => const Color(0xFF2EE6C5);
  Color get _textColor => _isDarkMode ? Colors.white : const Color(0xFF1A1C1E);
  Color get _subTextColor => _isDarkMode ? Colors.white.withOpacity(0.5) : Colors.black54;
  Color get _borderColor => _isDarkMode ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.08);

  @override
  void initState() {
    super.initState();
    _autoSyncUsers();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) shortcutFocusNode.requestFocus();
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
      syncMessage = 'Connecting to the Syswatch intranet server...';
    });

    try {
      final count = await AuthService.refreshOfflineStudents();
      await SyncService.instance.refreshPendingCount();

      if (!mounted) return;
      setState(() {
        syncMessage = '$count student account(s) available for offline login.';
      });
    } catch (_) {
      final count = await LocalDbService.instance.countCachedStudents();
      if (!mounted) return;

      setState(() {
        syncMessage = count > 0
            ? 'Intranet unavailable: using $count saved offline account(s).'
            : 'Intranet unavailable: no offline accounts are saved yet.';
      });
    } finally {
      if (mounted) {
        setState(() => syncingUsers = false);
        shortcutFocusNode.requestFocus();
      }
    }
  }

  Future<void> _login() async {
    if (loading) return;

    setState(() => loading = true);

    try {
      final pc = await AppConfigService.instance.getPcIdentity();
      final registered =
      await AppConfigService.instance.isRegistrationConfirmed();

      if (!pc.isConfigured || !registered) {
        throw Exception(
          'This workstation is not registered. Ask an administrator to press '
              'Ctrl + Shift + A and complete PC Configuration.',
        );
      }

      final user = await AuthService.loginStudent(
        studentId: studentIdController.text.trim(),
        password: passwordController.text,
      );

      final loginLogId = await LocalDbService.instance.insertLoginLog(
        user: user,
        pc: pc,
      );

      await SyncService.instance.syncPendingData();

      if (!mounted) return;

      PcMonitorService.instance.beginStudentSession(user.email);
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
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
        shortcutFocusNode.requestFocus();
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _isDarkMode ? const Color(0xFF23262B) : Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Text(
          message.replaceFirst('Exception:', '').trim(),
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  void _openPcConfigAdminLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PcConfigAdminLoginScreen()),
    ).then((_) {
      if (mounted) shortcutFocusNode.requestFocus();
    });
  }

  bool _isStaffShortcut(KeyEvent event) {
    return event is KeyDownEvent &&
        HardwareKeyboard.instance.isControlPressed &&
        HardwareKeyboard.instance.isShiftPressed &&
        event.logicalKey == LogicalKeyboardKey.keyA;
  }

  InputDecoration _fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: _subTextColor),
      prefixIcon: Icon(icon, color: _subTextColor.withOpacity(0.4), size: 20),
      filled: true,
      fillColor: _fieldColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _accent, width: 1.5),
      ),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: shortcutFocusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (_isStaffShortcut(event)) _openPcConfigAdminLogin();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: shortcutFocusNode.requestFocus,
        child: PopScope(
          canPop: false,
          child: Scaffold(
            backgroundColor: _bgColor,
            body: Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Container(
                      width: 420,
                      padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: _borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(_isDarkMode ? 0.4 : 0.08),
                            blurRadius: 40,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildLogoBadge(),
                          const SizedBox(height: 20),
                          Text(
                            'Login Before Using PC',
                            style: TextStyle(
                              color: _textColor,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildSyncStatus(),
                          const SizedBox(height: 28),
                          TextField(
                            controller: studentIdController,
                            style: TextStyle(color: _textColor),
                            cursorColor: _accent,
                            decoration:
                            _fieldDecoration('Student ID', Icons.badge_outlined),
                            onSubmitted: (_) => _login(),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: passwordController,
                            obscureText: true,
                            style: TextStyle(color: _textColor),
                            cursorColor: _accent,
                            decoration:
                            _fieldDecoration('Password', Icons.lock_outline),
                            onSubmitted: (_) => _login(),
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: loading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accent,
                                foregroundColor: const Color(0xFF0E0F12),
                                disabledBackgroundColor:
                                _accent.withOpacity(0.35),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: loading
                                  ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      valueColor:
                                      AlwaysStoppedAnimation<Color>(
                                        Color(0xFF0E0F12),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Checking...',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              )
                                  : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.login, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Login',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: syncingUsers ? null : _autoSyncUsers,
                            style: TextButton.styleFrom(
                              foregroundColor: _textColor.withOpacity(0.55),
                            ),
                            icon: const Icon(Icons.sync, size: 18),
                            label: const Text('Refresh intranet accounts'),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Administrator shortcut: Ctrl + Shift + A',
                            style: TextStyle(
                              fontSize: 12,
                              color: _textColor.withOpacity(0.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 24,
                  right: 24,
                  child: FloatingActionButton(
                    onPressed: () {
                      setState(() {
                        _isDarkMode = !_isDarkMode;
                      });
                    },
                    backgroundColor: _cardColor,
                    foregroundColor: _textColor,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: _borderColor),
                    ),
                    child: Icon(
                      _isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoBadge() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _accent, width: 2),
        boxShadow: [
          BoxShadow(
            color: _accent.withOpacity(0.25),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(Icons.memory_rounded, color: _accent, size: 30),
    );
  }

  Widget _buildSyncStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _fieldColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (syncingUsers) ...[
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(_accent),
              ),
            ),
            const SizedBox(width: 10),
          ] else
            Icon(
              Icons.check_circle_outline,
              size: 16,
              color: _accent.withOpacity(0.8),
            ),
          if (!syncingUsers) const SizedBox(width: 8),
          Flexible(
            child: Text(
              syncMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: syncingUsers
                    ? _accent.withOpacity(0.85)
                    : _textColor.withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}