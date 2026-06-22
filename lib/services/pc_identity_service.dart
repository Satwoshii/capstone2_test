import 'dart:io';

class PcIdentityService {
  PcIdentityService._();

  static String getWindowsUsername() {
    return Platform.environment['USERNAME'] ??
        Platform.environment['USER'] ??
        'unknown_user';
  }

  static String getComputerName() {
    return Platform.environment['COMPUTERNAME'] ??
        Platform.environment['HOSTNAME'] ??
        'UNKNOWN-PC';
  }

  static String getDomainName() {
    return Platform.environment['USERDOMAIN'] ?? 'LOCAL';
  }

  static String getPcNumberFromComputerName() {
    final name = getComputerName().trim();
    final match = RegExp(r'(?:PC[-_ ]?)?(\d{1,3})$', caseSensitive: false)
        .firstMatch(name);
    if (match != null) {
      return 'PC${match.group(1)!.padLeft(2, '0')}';
    }
    return name;
  }

  static String getRoomFromComputerName() {
    final name = getComputerName();
    final labMatch = RegExp(
      r'(?:LAB|ROOM)[-_ ]?(\d{3,4})',
      caseSensitive: false,
    ).firstMatch(name);
    if (labMatch != null) return labMatch.group(1)!;

    final anyRoom = RegExp(r'\b(\d{3,4})\b').firstMatch(name);
    return anyRoom?.group(1) ?? 'UNASSIGNED';
  }
}
