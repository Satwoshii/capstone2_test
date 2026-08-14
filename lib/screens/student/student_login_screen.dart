import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/app_config_service.dart';
import '../../services/auth_service.dart';
import '../../services/local_db_service.dart';
import '../../services/pc_monitor_service.dart';
import '../../services/theme_service.dart';
import '../staff/pc_config_admin_login_screen.dart';
import 'student_access_screen.dart';

class StudentLoginScreen extends StatefulWidget {
  const StudentLoginScreen({super.key});

  @override
  State<StudentLoginScreen> createState() => _StudentLoginScreenState();
}

class _StudentLoginScreenState extends State<StudentLoginScreen>
    with SingleTickerProviderStateMixin {
  final studentIdController = TextEditingController();
  final passwordController = TextEditingController();
  final FocusNode shortcutFocusNode = FocusNode();

  bool loading = false;
  bool _obscurePassword = true;

  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // ── Palette ──────────────────────────────────────────────────────────────
  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  Color get _bgColor =>
      _isDarkMode ? const Color(0xFF090A0E) : const Color(0xFFF0F2F5);
  Color get _cardColor =>
      _isDarkMode ? const Color(0xFF13141A) : Colors.white;
  Color get _fieldColor =>
      _isDarkMode ? const Color(0xFF1C1E26) : const Color(0xFFEDF0F5);
  Color get _accentA => const Color(0xFF2EE6C5);
  Color get _accentB => const Color(0xFF4F8EF7);
  Color get _textColor =>
      _isDarkMode ? Colors.white : const Color(0xFF1A1C1E);
  Color get _subTextColor =>
      _isDarkMode ? Colors.white54 : Colors.black45;
  Color get _borderColor =>
      _isDarkMode ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.09);

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        shortcutFocusNode.requestFocus();
        _entryController.forward();
      }
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    studentIdController.dispose();
    passwordController.dispose();
    shortcutFocusNode.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────
  Future<void> _login() async {
    if (loading) return;
    setState(() => loading = true);

    try {
      final pc = await AppConfigService.instance.getPcIdentity();
      final registered = await AppConfigService.instance.isRegistrationConfirmed();

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
    } on ActiveStudentSessionException catch (error) {
      if (mounted) {
        await _showActiveSessionAlert(error);
      }
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
        shortcutFocusNode.requestFocus();
      }
    }
  }

  Future<void> _showActiveSessionAlert(
    ActiveStudentSessionException error,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.phonelink_lock_rounded,
          color: Colors.orange,
          size: 36,
        ),
        title: const Text('Account Currently in Use'),
        content: Text(
          'This student account is already active on ${error.location}.\n\n'
          'Log out from that workstation before switching to this PC. If you '
          'did not start that session, contact your instructor or '
          'administrator.',
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor:
        _isDarkMode ? const Color(0xFF1E2028) : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message.replaceFirst('Exception:', '').trim(),
                style: const TextStyle(color: Colors.white, fontSize: 13.5),
              ),
            ),
          ],
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

  bool _isStaffShortcut(KeyEvent event) =>
      event is KeyDownEvent &&
          HardwareKeyboard.instance.isControlPressed &&
          HardwareKeyboard.instance.isShiftPressed &&
          event.logicalKey == LogicalKeyboardKey.keyA;

  // ── Input decoration ──────────────────────────────────────────────────────
  InputDecoration _fieldDecoration(String label, IconData icon,
      {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: _subTextColor, fontSize: 14),
      prefixIcon: Icon(icon, color: _subTextColor.withOpacity(0.45), size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _fieldColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _accentA, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: shortcutFocusNode,
      autofocus: true,
      onKeyEvent: (e) {
        if (_isStaffShortcut(e)) _openPcConfigAdminLogin();
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
                _buildAmbientOrbs(),
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: _buildCard(),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 24,
                  right: 24,
                  child: _buildThemeToggle(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        shape: BoxShape.circle,
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDarkMode ? 0.3 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        onPressed: () => ThemeService.instance.toggleTheme(),
        icon: Icon(
          _isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          color: _isDarkMode ? Colors.amber : _accentB,
        ),
        tooltip: 'Toggle Light/Dark Mode',
      ),
    );
  }

  Widget _buildAmbientOrbs() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -80,
            left: -80,
            child: _orb(280, _accentA.withOpacity(_isDarkMode ? 0.07 : 0.05)),
          ),
          Positioned(
            bottom: -100,
            right: -60,
            child: _orb(320, _accentB.withOpacity(_isDarkMode ? 0.06 : 0.04)),
          ),
        ],
      ),
    );
  }

  Widget _orb(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, Colors.transparent]),
    ),
  );

  Widget _buildCard() {
    return Container(
      width: 420,
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 36),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDarkMode ? 0.5 : 0.1),
            blurRadius: 60,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: _buildLogoBadge()),
          const SizedBox(height: 20),

          Text(
            'Syswatch Login',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textColor,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Student Access Portal',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _subTextColor,
              fontSize: 13.5,
              letterSpacing: 0.1,
            ),
          ),

          const SizedBox(height: 24),

          TextField(
            controller: studentIdController,
            style: TextStyle(color: _textColor, fontSize: 15),
            cursorColor: _accentA,
            decoration: _fieldDecoration('Student ID', Icons.badge_outlined),
            onSubmitted: (_) => _login(),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: passwordController,
            obscureText: _obscurePassword,
            style: TextStyle(color: _textColor, fontSize: 15),
            cursorColor: _accentA,
            decoration: _fieldDecoration(
              'Password',
              Icons.lock_outline_rounded,
              suffixIcon: GestureDetector(
                onTap: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    key: ValueKey(_obscurePassword),
                    color: _subTextColor.withOpacity(0.5),
                    size: 20,
                  ),
                ),
              ),
            ),
            onSubmitted: (_) => _login(),
          ),
          const SizedBox(height: 22),

          _buildLoginButton(),
          const SizedBox(height: 20),

          _buildThemeToggleRow(),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(child: Divider(color: _borderColor, thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Ctrl + Shift + A  ·  Admin',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: _textColor.withOpacity(0.25),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Expanded(child: Divider(color: _borderColor, thickness: 1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: loading
              ? null
              : LinearGradient(
            colors: [_accentA, _accentB],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          color: loading ? _accentA.withOpacity(0.25) : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: loading
              ? []
              : [
            BoxShadow(
              color: _accentA.withOpacity(0.3),
              blurRadius: 18,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: ElevatedButton(
          onPressed: loading ? null : _login,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: const Color(0xFF080A0E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: loading
                ? Row(
              key: const ValueKey('loading'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF080A0E),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Verifying…',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            )
                : Row(
              key: const ValueKey('idle'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.login_rounded, size: 20),
                SizedBox(width: 8),
                Text(
                  'Login',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15.5,
                    letterSpacing: 0.2,
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
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            _accentA.withOpacity(0.15),
            _accentB.withOpacity(0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: _accentA.withOpacity(0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _accentA.withOpacity(0.2),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          colors: [_accentA, _accentB],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
        child: const Icon(
          Icons.memory_rounded,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildThemeToggleRow() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _fieldColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          _themeOption(
            label: 'Light',
            icon: Icons.light_mode_outlined,
            selected: !_isDarkMode,
            onTap: () => ThemeService.instance.setThemeMode(ThemeMode.light),
          ),
          _themeOption(
            label: 'Dark',
            icon: Icons.dark_mode_outlined,
            selected: _isDarkMode,
            onTap: () => ThemeService.instance.setThemeMode(ThemeMode.dark),
          ),
        ],
      ),
    );
  }

  Widget _themeOption({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: selected
                ? LinearGradient(
              colors: [
                _accentA.withOpacity(0.18),
                _accentB.withOpacity(0.14),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            )
                : null,
            border: selected
                ? Border.all(color: _accentA.withOpacity(0.35), width: 1)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  icon,
                  key: ValueKey(selected),
                  size: 16,
                  color: selected ? _accentA : _subTextColor.withOpacity(0.5),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? _textColor : _subTextColor.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
