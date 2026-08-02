import 'dart:async';

import '../models/auth_session.dart';
import 'api_client.dart';
import 'api_endpoints.dart';
import 'app_config_service.dart';

class AuthSessionService {
  AuthSessionService._();

  static final AuthSessionService instance = AuthSessionService._();

  Future<AuthSession> createSession({
    required String sessionId,
    required String pcNumber,
    required String room,
  }) async {
    final now = DateTime.now();
    final pc = await AppConfigService.instance.getPcIdentity();

    final response = await ApiClient.instance.postJson(
      ApiEndpoints.createAuthSession,
      body: {
        'session_id': sessionId,
        'workstation_id': pc.workstationId,
        'pc_number': pcNumber,
        'room': room,
        'status': 'pending',
        'created_at': now.toUtc().toIso8601String(),
        'expires_at': now
            .add(const Duration(minutes: 2))
            .toUtc()
            .toIso8601String(),
      },
    );

    final sessionData = _extractSessionMap(response);
    return AuthSession.fromJson({
      'session_id': sessionId,
      'pc_number': pcNumber,
      'room': room,
      'status': 'pending',
      'created_at': now.toUtc().toIso8601String(),
      'expires_at': now
          .add(const Duration(minutes: 2))
          .toUtc()
          .toIso8601String(),
      ...sessionData,
    });
  }

  Stream<Map<String, dynamic>> watchSession(String sessionId) async* {
    while (true) {
      final response = await ApiClient.instance.getJson(
        ApiEndpoints.authSessionStatus,
        query: {'session_id': sessionId},
      );
      final session = _extractSessionMap(response);
      yield session;

      final status = session['status']?.toString().toLowerCase();
      if (status == 'approved' ||
          status == 'expired' ||
          status == 'cancelled') {
        return;
      }

      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  /// Used by the phone authentication app after student login.
  Future<void> approveSession({
    required String sessionId,
    required String apiToken,
  }) async {
    await ApiClient.instance.postJson(
      ApiEndpoints.approveAuthSession,
      body: {'session_id': sessionId},
      includeWorkstationToken: false,
      headers: {'Authorization': 'Bearer $apiToken'},
    );
  }

  Future<void> cancelSession(String sessionId) async {
    await ApiClient.instance.postJson(
      ApiEndpoints.cancelAuthSession,
      body: {'session_id': sessionId},
    );
  }

  Future<void> expireSession(String sessionId) async {
    await ApiClient.instance.postJson(
      ApiEndpoints.expireAuthSession,
      body: {'session_id': sessionId},
    );
  }

  Map<String, dynamic> _extractSessionMap(Map<String, dynamic> response) {
    final raw = response['session'] ?? response['data'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return response;
  }
}
