import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../services/auth_session_service.dart';
import '../../services/pc_identity_service.dart';
import 'peripheral_form_screen.dart';

class PcAuthScreen extends StatefulWidget {
  const PcAuthScreen({super.key});

  @override
  State<PcAuthScreen> createState() => _PcAuthScreenState();
}

class _PcAuthScreenState extends State<PcAuthScreen> {
  final Uuid _uuid = const Uuid();

  StreamSubscription<
      DocumentSnapshot<Map<String, dynamic>>>? _subscription;

  Timer? _expiryTimer;

  String _sessionId = '';
  String _pcNumber = '';
  String _room = '';

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

    final pcNumber =
    PcIdentityService.getPcNumberFromComputerName();

    final room =
    PcIdentityService.getRoomFromComputerName();

    if (!mounted) return;

    setState(() {
      _sessionId = sessionId;
      _pcNumber = pcNumber;
      _room = room;
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

      _expiryTimer = Timer(
        const Duration(minutes: 2),
            () async {
          if (_authenticationApproved) return;

          await AuthSessionService.instance.expireSession(
            _sessionId,
          );

          if (!mounted) return;

          setState(() {
            _errorMessage =
            'The QR code expired. Generate a new QR code.';
          });
        },
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage =
        'Unable to create authentication session.\n$error';
      });
    }
  }

  void _listenForApproval() {
    _subscription?.cancel();

    _subscription = AuthSessionService.instance
        .watchSession(_sessionId)
        .listen(
          (snapshot) {
        final data = snapshot.data();

        if (data == null) return;

        final status = data['status']?.toString();

        if (status == 'approved') {
          final email =
              data['studentEmail']?.toString() ?? '';

          if (email.isEmpty) {
            setState(() {
              _errorMessage =
              'Authentication was approved without a student email.';
            });

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
        }

        if (status == 'expired' && mounted) {
          setState(() {
            _errorMessage =
            'The QR authentication session expired.';
          });
        }

        if (status == 'cancelled' && mounted) {
          setState(() {
            _errorMessage =
            'The QR authentication session was cancelled.';
          });
        }
      },
      onError: (Object error) {
        if (!mounted) return;

        setState(() {
          _errorMessage =
          'Authentication listener failed.\n$error';
        });
      },
    );
  }

  Future<void> _generateNewQrCode() async {
    await _subscription?.cancel();
    _expiryTimer?.cancel();

    if (_sessionId.isNotEmpty) {
      await AuthSessionService.instance.cancelSession(
        _sessionId,
      );
    }

    _authenticationApproved = false;

    await _initializeAuthentication();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _expiryTimer?.cancel();

    if (!_authenticationApproved &&
        _sessionId.isNotEmpty) {
      unawaited(
        AuthSessionService.instance.cancelSession(
          _sessionId,
        ),
      );
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _sessionId.isEmpty) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final qrValue =
        'LABSCAN_AUTH|$_sessionId|$_pcNumber|$_room';

    return Scaffold(
      appBar: AppBar(
        title: const Text('PC Authentication'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 560,
          ),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.qr_code_2,
                    size: 64,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Authentication Required',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PC: $_pcNumber',
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Room: $_room',
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  QrImageView(
                    data: qrValue,
                    size: 260,
                    errorCorrectionLevel:
                    QrErrorCorrectLevel.M,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Scan this QR code using the LabScan phone application.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Waiting for phone approval...',
                      ),
                    ],
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .errorContainer,
                        borderRadius:
                        BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onErrorContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _generateNewQrCode,
                      icon: const Icon(Icons.refresh),
                      label: const Text(
                        'Generate New QR Code',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}