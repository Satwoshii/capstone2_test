class HardwareStatus {
  final bool cpuOk;
  final bool ramOk;
  final bool diskOk;
  final bool networkOk;
  final bool keyboardOk;
  final bool mouseOk;
  final bool monitorOk;
  final bool webcamOk;
  final bool printerOk;
  final bool headsetOk;
  final List<String> issues;

  HardwareStatus({
    required this.cpuOk,
    required this.ramOk,
    required this.diskOk,
    required this.networkOk,
    required this.keyboardOk,
    required this.mouseOk,
    required this.monitorOk,
    required this.webcamOk,
    required this.printerOk,
    required this.headsetOk,
    required this.issues,
  });

  bool get hasIssue => issues.isNotEmpty;

  // For PeripheralFormScreen compatibility
  bool get mouseDetected => mouseOk;
  bool get keyboardDetected => keyboardOk;
  bool get monitorDetected => monitorOk;
  bool get networkDetected => networkOk;
  bool get storageHealthy => diskOk;
  List<String> get warnings => issues;

  // For StudentBlockScreen background checking
  List<String> get failedComponents {
    final failed = <String>[];

    if (!mouseOk) failed.add('mouse');
    if (!keyboardOk) failed.add('keyboard');
    if (!monitorOk) failed.add('monitor');
    if (!networkOk) failed.add('network');
    if (!diskOk) failed.add('storage');

    return failed;
  }

  Map<String, dynamic> toMap() {
    return {
      'cpuOk': cpuOk,
      'ramOk': ramOk,
      'diskOk': diskOk,
      'networkOk': networkOk,
      'keyboardOk': keyboardOk,
      'mouseOk': mouseOk,
      'monitorOk': monitorOk,
      'webcamOk': webcamOk,
      'printerOk': printerOk,
      'headsetOk': headsetOk,
      'issues': issues,
    };
  }

  factory HardwareStatus.normal() {
    return HardwareStatus(
      cpuOk: true,
      ramOk: true,
      diskOk: true,
      networkOk: true,
      keyboardOk: true,
      mouseOk: true,
      monitorOk: true,
      webcamOk: true,
      printerOk: true,
      headsetOk: true,
      issues: [],
    );
  }
}