enum AppRole {
  studentPc,
  studentPhone,
  teacher,
  itso,
  admin,
}

extension AppRoleLabel on AppRole {
  String get label {
    switch (this) {
      case AppRole.studentPc:
        return 'Student PC';
      case AppRole.studentPhone:
        return 'Student Phone';
      case AppRole.teacher:
        return 'Teacher';
      case AppRole.itso:
        return 'ITSO';
      case AppRole.admin:
        return 'Administrator';
    }
  }
}
