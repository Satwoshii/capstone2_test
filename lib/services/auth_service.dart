import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/app_user.dart';
import 'api_client.dart';
import 'api_endpoints.dart';
import 'app_config_service.dart';
import 'local_db_service.dart';

class AuthService {
  AuthService._();

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

    try {
      final response = await ApiClient.instance.postJson(
        ApiEndpoints.studentLogin,
        body: {
          'student_id': normalizedStudentId,
          'password': password,
        },
      );

      final userMap = _extractUserMap(response);
      final user = AppUser.fromJson(userMap).copyWith(
        passwordHash: hashPassword(password),
      );

      final apiToken = (response['api_token'] ?? '').toString();
      if (apiToken.isEmpty) {
        throw Exception('The server did not return a student access token.');
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
        expiresAt: response['token_expires_at']?.toString(),
      );
      return user;
    } on ApiUnavailableException {
      return loginOffline(studentId: normalizedStudentId, password: password);
    } on ApiRequestException catch (error) {
      if (error.statusCode >= 500) {
        return loginOffline(
          studentId: normalizedStudentId,
          password: password,
        );
      }
      rethrow;
    }
  }

  static Future<AppUser> loginOffline({
    required String studentId,
    required String password,
  }) async {
    // An offline login must not reuse another student's server token.
    await AppConfigService.instance.clearStudentApiSession();
    final user = await LocalDbService.instance.findUserByStudentId(studentId);

    if (user == null) {
      throw Exception(
        'The intranet server is unavailable and this student account is not '
        'saved for offline login.',
      );
    }

    if (user.role != 'student') {
      throw Exception('Only student accounts can use this login.');
    }

    final passwordHash = hashPassword(password);
    if (user.passwordHash == null || user.passwordHash != passwordHash) {
      throw Exception('Invalid student ID or password.');
    }

    return user;
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

  static Future<int> refreshOfflineStudents() async {
    final response = await ApiClient.instance.getJson(
      ApiEndpoints.offlineStudents,
    );

    final rawUsers = response['users'] ?? response['data'];
    if (rawUsers is! List) {
      throw Exception(
        'The server response does not contain an offline student list.',
      );
    }

    final users = <AppUser>[];
    for (final item in rawUsers) {
      if (item is! Map) continue;
      final mapped = item.map((key, value) => MapEntry(key.toString(), value));
      final user = AppUser.fromJson(mapped);

      if (user.role != 'student' || !user.active) continue;
      if (user.studentId == null || user.studentId!.trim().isEmpty) continue;
      if (user.passwordHash == null || user.passwordHash!.trim().isEmpty) {
        continue;
      }

      users.add(user);
    }

    await LocalDbService.instance.upsertUsers(users);
    await LocalDbService.instance.setConfig(
      'lastUserSyncAt',
      DateTime.now().toUtc().toIso8601String(),
    );
    return users.length;
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
