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

  bool get hasIssue => failedComponents.isNotEmpty || issues.isNotEmpty;

  // Compatibility getters used by PeripheralFormScreen.
  bool get mouseDetected => mouseOk;
  bool get keyboardDetected => keyboardOk;
  bool get monitorDetected => monitorOk;
  bool get networkDetected => networkOk;
  bool get storageHealthy => diskOk;
  List<String> get warnings => issues;

  // Student-fixable/checkable items.
  List<String> get peripheralIssues {
    final failed = <String>[];

    if (!mouseOk) failed.add('mouse');
    if (!keyboardOk) failed.add('keyboard');
    if (!monitorOk) failed.add('monitor');
    if (!networkOk) failed.add('ethernet');

    return failed;
  }

  // PC health items should be handled by ITSO only.
  List<String> get pcHealthIssues {
    final failed = <String>[];

    if (!cpuOk) failed.add('cpu');
    if (!ramOk) failed.add('ram');
    if (!diskOk) failed.add('disk');

    return failed;
  }

  List<String> get failedComponents {
    return [
      ...peripheralIssues,
      ...pcHealthIssues,
    ];
  }

  bool get hasPeripheralIssue => peripheralIssues.isNotEmpty;
  bool get hasPcHealthIssue => pcHealthIssues.isNotEmpty;

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
      'peripheralIssues': peripheralIssues,
      'pcHealthIssues': pcHealthIssues,
      'failedComponents': failedComponents,
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
