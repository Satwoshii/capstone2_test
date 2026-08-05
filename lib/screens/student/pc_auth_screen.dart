import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../services/app_config_service.dart';
import '../../services/auth_session_service.dart';
import '../../services/theme_service.dart';
import 'peripheral_form_screen.dart';

class PcAuthScreen extends StatefulWidget {
  const PcAuthScreen({super.key});

  @override
  State<PcAuthScreen> createState() => _PcAuthScreenState();
}

class _PcAuthScreenState extends State<PcAuthScreen> {
  final Uuid _uuid = const Uuid();

  StreamSubscription<Map<String, dynamic>>? _subscription;
  Timer? _expiryTimer;

  String _sessionId = '';
  String _pcNumber = '';
  String _room = '';
  String _serverUrl = '';

  bool _loading = true;
  bool _authenticationApproved = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeAuthentication();
  }

  Future<void> _initializeAuthentication() async {
    final sessionId = _uuid.v4();
    final pc = await AppConfigService.instance.getPcIdentity();
    final registered =
        await AppConfigService.instance.isRegistrationConfirmed();
    final serverUrl = await AppConfigService.instance.getServerUrl();

    if (!pc.isConfigured || !registered) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage =
            'This workstation is not registered. Ask an administrator to '
            'press Ctrl + Shift + A and complete PC Configuration.';
      });
      return;
    }

    final pcNumber = pc.pcId;
    final room = pc.roomName;

    if (!mounted) return;
    setState(() {
      _sessionId = sessionId;
      _pcNumber = pcNumber;
      _room = room;
      _serverUrl = serverUrl;
      _loading = true;
      _errorMessage = null;
    });

    try {
      await AuthSessionService.instance.createSession(
        sessionId: sessionId,
        pcNumber: pcNumber,
        room: room,
      );

      _listenForApproval();
      _expiryTimer = Timer(const Duration(minutes: 2), () async {
        if (_authenticationApproved) return;

        try {
          await AuthSessionService.instance.expireSession(_sessionId);
        } catch (_) {}

        if (!mounted) return;
        setState(() {
          _errorMessage = 'The QR code expired. Generate a new QR code.';
        });
      });

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Unable to create an intranet authentication session.\n'
            '$error';
      });
    }
  }

  void _listenForApproval() {
    _subscription?.cancel();
    _subscription = AuthSessionService.instance.watchSession(_sessionId).listen(
      (data) {
        final status = data['status']?.toString().toLowerCase();

        if (status == 'approved') {
          final email = (data['student_email'] ?? data['studentEmail'])
                  ?.toString() ??
              '';

          if (email.isEmpty) {
            if (mounted) {
              setState(() {
                _errorMessage =
                    'Authentication was approved without a student email.';
              });
            }
            return;
          }

          _authenticationApproved = true;
          _subscription?.cancel();
          _expiryTimer?.cancel();

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PeripheralFormScreen(
                studentEmail: email,
                pcNumber: _pcNumber,
                room: _room,
              ),
            ),
          );
        } else if (status == 'expired' && mounted) {
          setState(() {
            _errorMessage = 'The QR authentication session expired.';
          });
        } else if (status == 'cancelled' && mounted) {
          setState(() {
            _errorMessage = 'The QR authentication session was cancelled.';
          });
        }
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Authentication status check failed.\n$error';
        });
      },
    );
  }

  Future<void> _generateNewQrCode() async {
    await _subscription?.cancel();
    _expiryTimer?.cancel();

    if (_sessionId.isNotEmpty) {
      try {
        await AuthSessionService.instance.cancelSession(_sessionId);
      } catch (_) {}
    }

    _authenticationApproved = false;
    await _initializeAuthentication();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _expiryTimer?.cancel();

    if (!_authenticationApproved && _sessionId.isNotEmpty) {
      unawaited(AuthSessionService.instance.cancelSession(_sessionId));
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _sessionId.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final qrValue =
        'SYSWATCH_AUTH|$_sessionId|$_pcNumber|$_room|$_serverUrl';

    return Scaffold(
      appBar: AppBar(
        title: const Text('PC Authentication'),
        automaticallyImplyLeading: false,
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.qr_code_2, size: 64),
                  const SizedBox(height: 12),
                  const Text(
                    'Authentication Required',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('PC: $_pcNumber'),
                  Text('Room: $_room'),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: QrImageView(
                      data: qrValue,
                      size: 250,
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Scan this code using the Syswatch authentication app '
                    'connected to the same intranet.',
                    textAlign: TextAlign.center,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _generateNewQrCode,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Generate New QR Code'),
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
