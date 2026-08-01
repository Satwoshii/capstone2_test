class AuthSession {
  final String sessionId;
  final String pcNumber;
  final String room;
  final String status;
  final String? studentEmail;
  final String? studentUid;
  final DateTime createdAt;
  final DateTime expiresAt;

  const AuthSession({
    required this.sessionId,
    required this.pcNumber,
    required this.room,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.studentEmail,
    this.studentUid,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'pc_number': pcNumber,
      'room': room,
      'status': status,
      'student_email': studentEmail,
      'student_uid': studentUid,
      'created_at': createdAt.toUtc().toIso8601String(),
      'expires_at': expiresAt.toUtc().toIso8601String(),
    };
  }

  factory AuthSession.fromJson(Map<String, dynamic> data) {
    return AuthSession(
      sessionId: _read(data, const ['sessionId', 'session_id']),
      pcNumber: _read(data, const ['pcNumber', 'pc_number', 'pcId', 'pc_id']),
      room: _read(data, const ['room', 'roomName', 'room_name']),
      status: _read(data, const ['status'], fallback: 'pending'),
      studentEmail: _readNullable(
        data,
        const ['studentEmail', 'student_email'],
      ),
      studentUid: _readNullable(data, const ['studentUid', 'student_uid']),
      createdAt: _dateFromValue(
        data['createdAt'] ?? data['created_at'],
        fallback: DateTime.now(),
      ),
      expiresAt: _dateFromValue(
        data['expiresAt'] ?? data['expires_at'],
        fallback: DateTime.now().add(const Duration(minutes: 2)),
      ),
    );
  }

  static String _read(
    Map<String, dynamic> source,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = source[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return fallback;
  }

  static String? _readNullable(
    Map<String, dynamic> source,
    List<String> keys,
  ) {
    final value = _read(source, keys);
    return value.isEmpty ? null : value;
  }

  static DateTime _dateFromValue(
    dynamic value, {
    required DateTime fallback,
  }) {
    if (value is DateTime) return value;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true).toLocal();
    }
    return DateTime.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
