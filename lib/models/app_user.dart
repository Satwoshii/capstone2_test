class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String role;
  final String? studentId;
  final String? passwordHash;
  final bool active;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.studentId,
    this.passwordHash,
    required this.active,
  });

  AppUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? role,
    String? studentId,
    String? passwordHash,
    bool? active,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      studentId: studentId ?? this.studentId,
      passwordHash: passwordHash ?? this.passwordHash,
      active: active ?? this.active,
    );
  }

  Map<String, dynamic> toLocalMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role,
      'studentId': studentId,
      'passwordHash': passwordHash,
      'active': active ? 1 : 0,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'display_name': displayName,
      'role': role,
      'student_id': studentId,
      'active': active,
    };
  }

  factory AppUser.fromLocalMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? '',
      role: (map['role'] ?? 'student').toString().trim().toLowerCase(),
      studentId: map['studentId']?.toString(),
      passwordHash: map['passwordHash']?.toString(),
      active: _toBool(map['active'], fallback: true),
    );
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final uid = _firstString(json, const ['uid', 'id', 'user_id']);
    final email = _firstString(json, const ['email', 'user_email']);
    final studentId = _nullableFirstString(
      json,
      const ['studentId', 'student_id', 'schoolId', 'school_id'],
    );
    final displayName = _firstString(
      json,
      const ['displayName', 'display_name', 'name', 'full_name'],
      fallback: email.isNotEmpty ? email : (studentId ?? ''),
    );
    final passwordHash = _nullableFirstString(
      json,
      const [
        'passwordHash',
        'password_hash',
        'offlinePasswordHash',
        'offline_password_hash',
      ],
    );

    return AppUser(
      uid: uid.isNotEmpty ? uid : (studentId ?? email),
      email: email,
      displayName: displayName,
      role: _firstString(json, const ['role'], fallback: 'student')
          .trim()
          .toLowerCase(),
      studentId: studentId,
      passwordHash: passwordHash,
      active: _toBool(json['active'], fallback: true),
    );
  }

  static String _firstString(
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

  static String? _nullableFirstString(
    Map<String, dynamic> source,
    List<String> keys,
  ) {
    final value = _firstString(source, keys);
    return value.isEmpty ? null : value;
  }

  static bool _toBool(dynamic value, {required bool fallback}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    return fallback;
  }
}
