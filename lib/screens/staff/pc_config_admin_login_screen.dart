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

class _PcConfigAdminLoginScreenState extends State<PcConfigAdminLoginScreen>
    with SingleTickerProviderStateMixin {
  final _serverUrlCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  bool _obscurePass = true;

  late final AnimationController _entryCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  bool get _dark => Theme.of(context).brightness == Brightness.dark;

  Color get _bgColor =>
      _dark ? const Color(0xFF090A0E) : const Color(0xFFF0F2F5);

  Color get _cardColor =>
      _dark ? const Color(0xFF13141A) : Colors.white;

  Color get _fieldColor =>
      _dark ? const Color(0xFF1C1E26) : const Color(0xFFEDF0F5);

  Color get _textColor =>
      _dark ? Colors.white : const Color(0xFF1A1C1E);

  Color get _hintColor =>
      _dark ? Colors.white38 : Colors.black38;

  Color get _borderCol => _dark
      ? const Color(0x12FFFFFF)
      : Colors.black.withValues(alpha: 0.09);

  static const Color _accentA = Color(0xFF2EE6C5);
  static const Color _accentB = Color(0xFF4F8EF7);

  @override
  void initState() {
    super.initState();

    _loadServerUrl();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnim = CurvedAnimation(
      parent: _entryCtrl,
      curve: Curves.easeOut,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: Curves.easeOutCubic,
      ),
    );

    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _serverUrlCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadServerUrl() async {
    _serverUrlCtrl.text =
    await AppConfigService.instance.getServerUrl();
  }

  Future<void> _login() async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      await AppConfigService.instance.saveServerUrl(
        _serverUrlCtrl.text.trim(),
      );

      final user = await AuthService.loginStaff(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      if (user.role != 'admin') {
        throw Exception(
          'Access denied. PC configuration requires an admin account.',
        );
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const PcConfigScreen(),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      _showError(
        error.toString().replaceFirst('Exception:', '').trim(),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          _buildAmbientOrbs(),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 32,
              ),
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
    );
  }

  Widget _buildAmbientOrbs() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -80,
            left: -80,
            child: _orb(
              300,
              _accentA.withValues(alpha: 0.07),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -60,
            child: _orb(
              340,
              _accentB.withValues(alpha: 0.06),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      width: 520,
      padding: const EdgeInsets.fromLTRB(40, 44, 40, 40),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: _dark ? 0.55 : 0.10,
            ),
            blurRadius: 64,
            offset: const Offset(0, 28),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAdminBadge(),
          const SizedBox(height: 18),
          ShaderMask(
            shaderCallback: (bounds) {
              return const LinearGradient(
                colors: [
                  _accentA,
                  _accentB,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ).createShader(bounds);
            },
            child: const Text(
              'PC CONFIGURATION',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Connect to the SysWatch server and sign in\n'
                'with an administrator account.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textColor.withValues(alpha: 0.45),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 30),
          _buildField(
            controller: _serverUrlCtrl,
            icon: Icons.dns_rounded,
            label: 'SysWatch Server URL',
            hint: 'http://192.168.1.10/syswatch_api',
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: _emailCtrl,
            icon: Icons.shield_outlined,
            label: 'Admin Email',
            hint: 'admin@school.edu',
            keyboardType: TextInputType.emailAddress,
            onSubmitted: (_) => _login(),
          ),
          const SizedBox(height: 14),
          _buildPasswordField(),
          const SizedBox(height: 28),
          _buildLoginButton(),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.arrow_back_rounded,
              size: 16,
              color: _textColor.withValues(alpha: 0.35),
            ),
            label: Text(
              'Go back',
              style: TextStyle(
                color: _textColor.withValues(alpha: 0.35),
                fontSize: 13,
              ),
            ),
            style: TextButton.styleFrom(
              splashFactory: NoSplash.splashFactory,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        shape: BoxShape.circle,
        border: Border.all(color: _borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: _dark ? 0.3 : 0.08,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        onPressed: () {
          ThemeService.instance.toggleTheme();
        },
        icon: Icon(
          _dark
              ? Icons.light_mode_rounded
              : Icons.dark_mode_rounded,
          color: _dark ? Colors.amber : _accentB,
        ),
        tooltip: 'Toggle Light/Dark Mode',
      ),
    );
  }

  Widget _buildAdminBadge() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            _accentA.withValues(alpha: 0.15),
            _accentB.withValues(alpha: 0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: _accentA.withValues(alpha: 0.40),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _accentA.withValues(alpha: 0.12),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ShaderMask(
        shaderCallback: (bounds) {
          return const LinearGradient(
            colors: [
              _accentA,
              _accentB,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds);
        },
        child: const Icon(
          Icons.admin_panel_settings_rounded,
          color: Colors.white,
          size: 34,
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    ValueChanged<String>? onSubmitted,
  }) {
    return _FieldShell(
      fieldColor: _fieldColor,
      borderCol: _borderCol,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Icon(
              icon,
              color: _accentA.withValues(alpha: 0.75),
              size: 18,
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: TextStyle(
                color: _textColor,
                fontSize: 14.5,
              ),
              onSubmitted: onSubmitted,
              decoration: InputDecoration(
                hintText: hint ?? label,
                hintStyle: TextStyle(
                  color: _hintColor,
                  fontSize: 14,
                ),
                labelText: label,
                labelStyle: TextStyle(
                  color: _textColor.withValues(alpha: 0.40),
                  fontSize: 13,
                ),
                floatingLabelStyle: TextStyle(
                  color: _accentA.withValues(alpha: 0.80),
                  fontSize: 12,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField() {
    return _FieldShell(
      fieldColor: _fieldColor,
      borderCol: _borderCol,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Icon(
              Icons.lock_outline_rounded,
              color: _accentA.withValues(alpha: 0.75),
              size: 18,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _passwordCtrl,
              obscureText: _obscurePass,
              style: TextStyle(
                color: _textColor,
                fontSize: 14.5,
              ),
              onSubmitted: (_) => _login(),
              decoration: InputDecoration(
                hintText: 'Password',
                hintStyle: TextStyle(
                  color: _hintColor,
                  fontSize: 14,
                ),
                labelText: 'Password',
                labelStyle: TextStyle(
                  color: _textColor.withValues(alpha: 0.40),
                  fontSize: 13,
                ),
                floatingLabelStyle: TextStyle(
                  color: _accentA.withValues(alpha: 0.80),
                  fontSize: 12,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 14,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _obscurePass = !_obscurePass;
              });
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Icon(
                _obscurePass
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: _textColor.withValues(alpha: 0.30),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _loading
              ? null
              : const LinearGradient(
            colors: [
              _accentA,
              _accentB,
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: _loading
              ? null
              : [
            BoxShadow(
              color: _accentA.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _loading ? null : _login,
          style: ElevatedButton.styleFrom(
            backgroundColor:
            _loading ? _fieldColor : Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: _loading
                ? _textColor.withValues(alpha: 0.40)
                : const Color(0xFF080A0E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: _loading
              ? SizedBox(
            width: 17,
            height: 17,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _textColor.withValues(alpha: 0.40),
            ),
          )
              : const Icon(
            Icons.settings_applications_rounded,
            size: 19,
          ),
          label: Text(
            _loading
                ? 'Connecting...'
                : 'Open PC Configuration',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldShell extends StatelessWidget {
  final Color fieldColor;
  final Color borderCol;
  final Widget child;

  const _FieldShell({
    required this.fieldColor,
    required this.borderCol,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: fieldColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol),
      ),
      child: child,
    );
  }
}