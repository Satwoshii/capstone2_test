import 'api_client.dart';
import 'api_endpoints.dart';
import 'app_config_service.dart';

class StudentSessionInvalidException implements Exception {
  final String message;

  const StudentSessionInvalidException(this.message);

  @override
  String toString() => message;
}

class StudentSessionService {
  StudentSessionService._();

  static final StudentSessionService instance = StudentSessionService._();

  Future<void> heartbeat() async {
    final sessionId = await AppConfigService.instance.getStudentSessionId();
    if (sessionId.trim().isEmpty) {
      throw const StudentSessionInvalidException(
        'The student session is missing. Sign in again.',
      );
    }

    try {
      await ApiClient.instance.postJson(
        ApiEndpoints.studentSessionHeartbeat,
        includeStudentToken: true,
        body: {'session_id': sessionId},
      );
    } on ApiRequestException catch (error) {
      if (error.statusCode == 401 ||
          error.statusCode == 409 ||
          error.code == 'student_session_not_active' ||
          error.code == 'invalid_user_token') {
        throw StudentSessionInvalidException(error.message);
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    final sessionId = await AppConfigService.instance.getStudentSessionId();
    final token = await AppConfigService.instance.getStudentApiToken();
    if (sessionId.trim().isEmpty || token.trim().isEmpty) return;

    await ApiClient.instance.postJson(
      ApiEndpoints.studentLogout,
      includeStudentToken: true,
      body: {'session_id': sessionId},
    );
  }
}
