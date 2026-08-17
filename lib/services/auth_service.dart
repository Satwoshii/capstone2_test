import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/app_user.dart';
import 'api_client.dart';
import 'api_endpoints.dart';
import 'app_config_service.dart';
import 'local_db_service.dart';

class ActiveStudentSessionException implements Exception {
  final String roomName;
  final String pcId;
  final String workstationId;

  const ActiveStudentSessionException({
    required this.roomName,
    required this.pcId,
    required this.workstationId,
  });

  String get location {
    final room = roomName.trim();
    final pc = pcId.trim();
    if (room.isNotEmpty && pc.isNotEmpty) return 'Room $room - $pc';
    if (pc.isNotEmpty) return pc;
    if (room.isNotEmpty) return 'Room $room';
    return workstationId.trim().isEmpty
        ? 'another workstation'
        : workstationId;
  }

  @override
  String toString() =>
      'This account is currently active on $location. Log out from that '
      'workstation before signing in here.';
}

class AuthService {
  AuthService._();

  static const int minimumStudentPasswordLength = 8;
  static const int maximumStudentPasswordLength = 64;

  static String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  static Future<AppUser> loginStudent({
    required String studentId,
    required String password,
  }) async {
    final normalizedStudentId = studentId.trim();

    if (normalizedStudentId.isEmpty || password.isEmpty) {
      throw Exception('Enter your student ID and password.');
    }

    final passwordLength = password.runes.length;
    if (passwordLength < minimumStudentPasswordLength ||
        passwordLength > maximumStudentPasswordLength) {
      throw Exception('Password must contain between 8 and 64 characters.');
    }

    try {
      final response = await ApiClient.instance.postJson(
        ApiEndpoints.studentLogin,
        body: {
          'student_id': normalizedStudentId,
          'password': password,
        },
      );

      final userMap = _extractUserMap(response);
      final user = AppUser.fromJson(userMap);

      final apiToken = (response['api_token'] ?? '').toString().trim();
      if (apiToken.isEmpty) {
        throw Exception('The server did not return a student access token.');
      }

      final sessionId = (response['session_id'] ?? '').toString().trim();
      if (sessionId.isEmpty) {
        throw Exception(
          'The server does not support secure single-session login. '
          'Install the Syswatch v2.7.0 server update.',
        );
      }

      if (!user.active) {
        throw Exception('This student account is inactive.');
      }
      if (user.role != 'student') {
        throw Exception('Only student accounts can use this login.');
      }

      await LocalDbService.instance.upsertUser(user);
      await AppConfigService.instance.saveStudentApiSession(
        user: user,
        apiToken: apiToken,
        sessionId: sessionId,
        expiresAt: response['token_expires_at']?.toString(),
      );
      return user;
    } on ApiUnavailableException catch (error) {
      throw Exception(
        '${error.message} Secure student login requires the local Syswatch '
        'server so the account can be checked for use on another PC. Internet '
        'access is not required.',
      );
    } on ApiRequestException catch (error) {
      if (error.code == 'active_student_session') {
        final rawSession = error.response?['active_session'];
        final session = rawSession is Map
            ? rawSession.map(
                (key, value) => MapEntry(key.toString(), value),
              )
            : const <String, dynamic>{};
        throw ActiveStudentSessionException(
          roomName: (session['room_name'] ?? '').toString(),
          pcId: (session['pc_id'] ?? '').toString(),
          workstationId: (session['workstation_id'] ?? '').toString(),
        );
      }
      rethrow;
    }
  }

  static Future<AppUser> loginStaff({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      throw Exception('Enter the staff email and password.');
    }

    final response = await ApiClient.instance.postJson(
      ApiEndpoints.staffLogin,
      body: {
        'email': normalizedEmail,
        'password': password,
      },
    );

    final user = AppUser.fromJson(_extractUserMap(response));
    if (!user.active) {
      throw Exception('This staff account is inactive.');
    }
    if (user.role != 'admin' && user.role != 'itso') {
      throw Exception('This account is not authorized for PC configuration.');
    }

    await LocalDbService.instance.upsertUser(
      user.copyWith(passwordHash: hashPassword(password)),
    );
    return user;
  }

  static Map<String, dynamic> _extractUserMap(
    Map<String, dynamic> response,
  ) {
    final rawUser = response['user'] ?? response['data'];
    if (rawUser is Map<String, dynamic>) return rawUser;
    if (rawUser is Map) {
      return rawUser.map((key, value) => MapEntry(key.toString(), value));
    }

    if (response.containsKey('uid') ||
        response.containsKey('id') ||
        response.containsKey('email')) {
      return response;
    }

    throw Exception('The Syswatch server did not return an account profile.');
  }
}
