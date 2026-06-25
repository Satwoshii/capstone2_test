import 'package:flutter/material.dart';

import 'staff_login_screen.dart';
import '../student/student_login_screen.dart';

class StaffPortalScreen extends StatelessWidget {
  const StaffPortalScreen({super.key});

  void _backToStudentKiosk(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const StudentLoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StaffLoginScreen(
      onBackToStudentKiosk: () => _backToStudentKiosk(context),
    );
  }
}
