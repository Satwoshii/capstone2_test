class ApiEndpoints {
  ApiEndpoints._();

  static const String health = 'health.php';

  static const String studentLogin = 'auth/student_login.php';
  static const String staffLogin = 'auth/staff_login.php';
  static const String offlineStudents = 'accounts/offline_students.php';

  static const String registerWorkstation = 'workstations/register.php';
  static const String workstationHeartbeat = 'workstations/heartbeat.php';

  static const String syncRecord = 'sync/record.php';

  static const String createAuthSession = 'auth_sessions/create.php';
  static const String authSessionStatus = 'auth_sessions/status.php';
  static const String approveAuthSession = 'auth_sessions/approve.php';
  static const String cancelAuthSession = 'auth_sessions/cancel.php';
  static const String expireAuthSession = 'auth_sessions/expire.php';
}
