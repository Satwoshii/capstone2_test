import 'package:flutter/material.dart';

import 'staff_portal_screen.dart';

/// Compatibility wrapper.
/// Staff access is now separated into StaffPortalScreen.
class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const StaffPortalScreen();
  }
}
