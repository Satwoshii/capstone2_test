class StudentLog {
  final String id;
  final String studentEmail;
  final String windowsUsername;
  final String pcNumber;
  final String room;
  final DateTime loginTime;
  final bool formSubmitted;
  final String syncStatus;

  const StudentLog({
    required this.id,
    required this.studentEmail,
    required this.windowsUsername,
    required this.pcNumber,
    required this.room,
    required this.loginTime,
    this.formSubmitted = true,
    this.syncStatus = 'pending',
  });

  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'studentEmail': studentEmail,
      'windowsUsername': windowsUsername,
      'pcNumber': pcNumber,
      'room': room,
      'loginTime': loginTime.toIso8601String(),
      'formSubmitted': formSubmitted ? 1 : 0,
      'syncStatus': syncStatus,
    };
  }
}
