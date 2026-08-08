class ApiEndpoints {
  ApiEndpoints._();

  static const String health = 'health.php';

  static const String studentLogin = 'auth/student_login.php';
  static const String studentLogout = 'auth/student_logout.php';
  static const String staffLogin = 'auth/staff_login.php';
  static const String offlineStudents = 'accounts/offline_students.php';

  static const String studentSessionHeartbeat =
      'student_sessions/heartbeat.php';

  static const String registerWorkstation = 'workstations/register.php';
  static const String workstationHeartbeat = 'workstations/heartbeat.php';

  static const String syncRecord = 'sync/record.php';

  static const String createAuthSession = 'auth_sessions/create.php';
  static const String authSessionStatus = 'auth_sessions/status.php';
  static const String approveAuthSession = 'auth_sessions/approve.php';
  static const String cancelAuthSession = 'auth_sessions/cancel.php';
  static const String expireAuthSession = 'auth_sessions/expire.php';

  static const String supportConversations = 'chat/student_conversations.php';
  static const String supportActiveIssues = 'chat/student_active_issues.php';
  static const String supportCreate = 'chat/student_create.php';
  static const String supportOpenConversation = 'chat/student_open.php';
  static const String supportMessages = 'chat/student_messages.php';
  static const String supportSend = 'chat/student_send.php';
  static const String supportMarkRead = 'chat/student_mark_read.php';
}
