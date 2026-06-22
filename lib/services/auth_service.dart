import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/app_user.dart';
import 'local_db_service.dart';

class AuthService {
  static String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  static Future<AppUser> loginOffline({
    required String studentId,
    required String password,
  }) async {
    final user = await LocalDbService.instance.findUserByStudentId(studentId);

    if (user == null) {
      throw Exception('Student account not found offline.');
    }

    final passwordHash = hashPassword(password);

    if (user.passwordHash == null || user.passwordHash != passwordHash) {
      throw Exception('Invalid student ID or password.');
    }

    return user;
  }
}
