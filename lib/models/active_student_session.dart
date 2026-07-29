import 'app_user.dart';
import 'pc_identity.dart';

class ActiveStudentSession {
  final String loginLogId;
  final AppUser user;
  final PcIdentity pc;
  final String stage;
  final DateTime startedAt;
  final DateTime lastHeartbeatAt;

  const ActiveStudentSession({
    required this.loginLogId,
    required this.user,
    required this.pc,
    required this.stage,
    required this.startedAt,
    required this.lastHeartbeatAt,
  });

  bool get needsPeripheralForm => stage == 'peripheral_form';
}