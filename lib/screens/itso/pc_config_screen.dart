import 'package:flutter/material.dart';

import '../../services/app_config_service.dart';
import '../../services/sync_service.dart';
import '../../services/theme_service.dart';
import '../../services/workstation_registry_service.dart';

class PcConfigScreen extends StatefulWidget {
  const PcConfigScreen({super.key});

  @override
  State<PcConfigScreen> createState() => _PcConfigScreenState();
}

class _PcConfigScreenState extends State<PcConfigScreen>
    with SingleTickerProviderStateMixin {
  final _serverUrlCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  final _pcCtrl = TextEditingController();
  final _workstationIdCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _obscureToken = true;
  bool _serverOnline = false;

  String _serverStatus = '';

  late final AnimationController _entryCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  bool get _dark =>
      Theme.of(context).brightness == Brightness.dark;

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

  Color get _borderColor => _dark
      ? const Color(0x12FFFFFF)
      : Colors.black.withValues(alpha: 0.09);

  static const Color _accentA = Color(0xFF2EE6C5);
  static const Color _accentB = Color(0xFF4F8EF7);

  @override
  void initState() {
    super.initState();

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

    _loadConfig();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _serverUrlCtrl.dispose();
    _roomCtrl.dispose();
    _pcCtrl.dispose();
    _workstationIdCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final identity =
      await AppConfigService.instance.getPcIdentity();

      final serverUrl =
      await AppConfigService.instance.getServerUrl();

      final token =
      await AppConfigService.instance.getWorkstationToken();

      if (!mounted) return;

      setState(() {
        _workstationIdCtrl.text = identity.workstationId;
        _roomCtrl.text = identity.roomName;
        _pcCtrl.text = identity.pcId;
        _serverUrlCtrl.text = serverUrl;
        _tokenCtrl.text = token;
        _loading = false;
      });

      _entryCtrl.forward();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _serverOnline = false;
        _serverStatus = 'Failed to load configuration';
      });

      _entryCtrl.forward();

      _showSnack(
        error.toString().replaceFirst('Exception:', '').trim(),
      );
    }
  }

  Future<void> _testServer() async {
    if (_saving || _serverStatus == 'Checking...') return;

    final serverUrl = _serverUrlCtrl.text.trim();

    if (serverUrl.isEmpty) {
      _showSnack('Enter the Syswatch server URL.');
      return;
    }

    setState(() {
      _serverStatus = 'Checking...';
      _serverOnline = false;
    });

    try {
      await AppConfigService.instance.saveServerUrl(serverUrl);

      final online =
      await SyncService.instance.isServerReachable();

      if (!mounted) return;

      setState(() {
        _serverOnline = online;
        _serverStatus =
        online ? 'Server online' : 'Server unreachable';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _serverOnline = false;
        _serverStatus = error
            .toString()
            .replaceFirst('Exception:', '')
            .trim();
      });
    }
  }

  Future<void> _saveAndRegister() async {
    if (_saving) return;

    final serverUrl = _serverUrlCtrl.text.trim();
    final roomName = _roomCtrl.text.trim();
    final pcId = _pcCtrl.text.trim();

    if (serverUrl.isEmpty) {
      _showSnack('Enter the Syswatch server URL.');
      return;
    }

    if (roomName.isEmpty) {
      _showSnack('Enter the room name.');
      return;
    }

    if (pcId.isEmpty) {
      _showSnack('Enter the PC ID.');
      return;
    }

    setState(() {
      _saving = true;
      _serverOnline = false;
      _serverStatus = 'Registering workstation...';
    });

    try {
      await AppConfigService.instance.saveServerUrl(serverUrl);

      final current =
      await AppConfigService.instance.getPcIdentity();

      final identity = current.copyWith(
        roomName: roomName,
        pcId: pcId,
      );

      await WorkstationRegistryService.instance
          .registerOrUpdate(identity);

      await AppConfigService.instance.savePcIdentity(identity);

      await AppConfigService.instance
          .setRegistrationConfirmed(true);

      await SyncService.instance.syncPendingData();

      if (!mounted) return;

      setState(() {
        _serverOnline = true;
        _serverStatus = 'Registered and connected';
      });

      _showSnack(
        'Workstation registered on the intranet server.',
        success: true,
      );
    } on DuplicateWorkstationLocationException catch (error) {
      if (!mounted) return;

      setState(() {
        _serverOnline = false;
        _serverStatus = 'Registration failed';
      });

      _showSnack(error.toString());
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _serverOnline = false;
        _serverStatus = 'Registration failed';
      });

      _showSnack(
        error.toString().replaceFirst('Exception:', '').trim(),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showSnack(
      String message, {
        bool success = false,
      }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success
            ? const Color(0xFF1A3A2E)
            : Colors.red.shade700,
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
          if (_loading)
            Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor:
                  const AlwaysStoppedAnimation(_accentA),
                  backgroundColor: _fieldColor,
                ),
              ),
            )
          else
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
      width: 580,
      padding: const EdgeInsets.fromLTRB(40, 44, 40, 40),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _borderColor),
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
          _buildHeader(),
          const SizedBox(height: 32),

          _sectionLabel('Server Connection'),
          const SizedBox(height: 10),

          _buildField(
            controller: _serverUrlCtrl,
            icon: Icons.dns_rounded,
            label: 'Syswatch Server URL',
            hint: 'http://192.168.1.10/syswatch_api',
            keyboardType: TextInputType.url,
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              _buildTestButton(),
              const SizedBox(width: 14),
              if (_serverStatus.isNotEmpty)
                _buildStatusChip(),
            ],
          ),

          const SizedBox(height: 28),

          Divider(
            color: _textColor.withValues(alpha: 0.07),
            thickness: 1,
          ),

          const SizedBox(height: 24),

          _sectionLabel('Workstation Identity'),
          const SizedBox(height: 10),

          _buildField(
            controller: _workstationIdCtrl,
            icon: Icons.fingerprint_rounded,
            label: 'Permanent Workstation ID',
            readOnly: true,
          ),

          const SizedBox(height: 12),

          _buildTokenField(),

          const SizedBox(height: 28),

          Divider(
            color: _textColor.withValues(alpha: 0.07),
            thickness: 1,
          ),

          const SizedBox(height: 24),

          _sectionLabel('Location'),
          const SizedBox(height: 10),

          _buildField(
            controller: _roomCtrl,
            icon: Icons.meeting_room_rounded,
            label: 'Room Name',
            hint: '706',
          ),

          const SizedBox(height: 12),

          _buildField(
            controller: _pcCtrl,
            icon: Icons.computer_rounded,
            label: 'PC ID',
            hint: 'PC-01',
          ),

          const SizedBox(height: 28),

          _buildSaveButton(),

          const SizedBox(height: 16),

          TextButton.icon(
            onPressed: _saving
                ? null
                : () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.arrow_back_rounded,
              size: 16,
              color: _textColor.withValues(alpha: 0.30),
            ),
            label: Text(
              'Back to admin login',
              style: TextStyle(
                color: _textColor.withValues(alpha: 0.30),
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
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: _dark ? 0.30 : 0.08,
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

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
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
              Icons.lan_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
        ),

        const SizedBox(height: 16),

        ShaderMask(
          shaderCallback: (bounds) {
            return const LinearGradient(
              colors: [
                _accentA,
                _accentB,
              ],
            ).createShader(bounds);
          },
          child: const Text(
            'WORKSTATION IDENTITY',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
        ),

        const SizedBox(height: 6),

        Text(
          'Register this PC on the intranet and assign its room identity.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _textColor.withValues(alpha: 0.40),
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: _textColor.withValues(alpha: 0.35),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    String? hint,
    bool readOnly = false,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _fieldColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Icon(
              icon,
              color: readOnly
                  ? _textColor.withValues(alpha: 0.25)
                  : _accentA.withValues(alpha: 0.75),
              size: 18,
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: readOnly,
              enabled: readOnly || !_saving,
              keyboardType: keyboardType,
              style: TextStyle(
                color: readOnly
                    ? _textColor.withValues(alpha: 0.40)
                    : _textColor,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: hint ?? label,
                hintStyle: TextStyle(
                  color: _hintColor,
                  fontSize: 13.5,
                ),
                labelText: label,
                labelStyle: TextStyle(
                  color: _textColor.withValues(
                    alpha: readOnly ? 0.25 : 0.40,
                  ),
                  fontSize: 13,
                ),
                floatingLabelStyle: TextStyle(
                  color: readOnly
                      ? _textColor.withValues(alpha: 0.30)
                      : _accentA.withValues(alpha: 0.80),
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
          if (readOnly)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 14,
                color: _textColor.withValues(alpha: 0.20),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTokenField() {
    return Container(
      decoration: BoxDecoration(
        color: _fieldColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Icon(
              Icons.key_rounded,
              color: _textColor.withValues(alpha: 0.25),
              size: 18,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _tokenCtrl,
              readOnly: true,
              obscureText: _obscureToken,
              style: TextStyle(
                color: _textColor.withValues(alpha: 0.40),
                fontSize: 14,
              ),
              decoration: InputDecoration(
                labelText: 'Workstation Token',
                labelStyle: TextStyle(
                  color: _textColor.withValues(alpha: 0.25),
                  fontSize: 13,
                ),
                floatingLabelStyle: TextStyle(
                  color: _textColor.withValues(alpha: 0.30),
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
                _obscureToken = !_obscureToken;
              });
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Icon(
                _obscureToken
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: _textColor.withValues(alpha: 0.25),
                size: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton() {
    final checking =
        _serverStatus == 'Checking...';

    return SizedBox(
      height: 42,
      child: OutlinedButton.icon(
        onPressed:
        (_saving || checking) ? null : _testServer,
        style: OutlinedButton.styleFrom(
          foregroundColor: _accentA,
          side: BorderSide(
            color: _accentA.withValues(alpha: 0.35),
            width: 1.5,
          ),
          backgroundColor:
          _accentA.withValues(alpha: 0.06),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
          ),
        ),
        icon: checking
            ? SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: _accentA.withValues(alpha: 0.60),
          ),
        )
            : const Icon(
          Icons.wifi_tethering_rounded,
          size: 17,
        ),
        label: Text(
          checking ? 'Checking...' : 'Test Server',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    final checking =
        _serverStatus == 'Checking...';

    final color = checking
        ? _accentB
        : _serverOnline
        ? _accentA
        : Colors.redAccent;

    final icon = checking
        ? Icons.cloud_sync_outlined
        : _serverOnline
        ? Icons.cloud_done_outlined
        : Icons.cloud_off_outlined;

    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withValues(alpha: 0.30),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 14,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _serverStatus,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _saving
              ? null
              : const LinearGradient(
            colors: [
              _accentA,
              _accentB,
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: _saving
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
          onPressed:
          _saving ? null : _saveAndRegister,
          style: ElevatedButton.styleFrom(
            backgroundColor:
            _saving ? _fieldColor : Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: _saving
                ? _textColor.withValues(alpha: 0.40)
                : const Color(0xFF080A0E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: _saving
              ? SizedBox(
            width: 17,
            height: 17,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color:
              _textColor.withValues(alpha: 0.40),
            ),
          )
              : const Icon(
            Icons.app_registration_rounded,
            size: 19,
          ),
          label: Text(
            _saving
                ? 'Registering...'
                : 'Save & Register Workstation',
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