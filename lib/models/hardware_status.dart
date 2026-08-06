class HardwareStatus {
  final bool cpuOk;
  final bool ramOk;
  final bool diskOk;
  final bool storageHealthOk;
  final bool storageCapacityOk;
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
    required this.storageHealthOk,
    required this.storageCapacityOk,
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

  bool get mouseDetected => mouseOk;
  bool get keyboardDetected => keyboardOk;
  bool get monitorDetected => monitorOk;
  bool get networkDetected => networkOk;

  bool get storageHealthy {
    return diskOk && storageHealthOk && storageCapacityOk;
  }

  List<String> get warnings => issues;

  List<String> get minorIssues {
    final failed = <String>[];

    if (!mouseOk) failed.add('Mouse');
    if (!keyboardOk) failed.add('Keyboard');
    if (!monitorOk) failed.add('Monitor');

    return failed;
  }

  List<String> get highIssues {
    return [
      if (!networkOk) 'Ethernet',
    ];
  }

  List<String> get criticalIssues {
    final failed = <String>[];

    if (!cpuOk) failed.add('CPU');
    if (!ramOk) failed.add('RAM');
    if (!diskOk) failed.add('Disk');
    if (!storageHealthOk) failed.add('Storage Health');
    if (!storageCapacityOk) failed.add('Storage Capacity');

    return failed;
  }

  List<String> get peripheralIssues => [
    ...minorIssues,
    ...highIssues,
  ];

  List<String> get pcHealthIssues => criticalIssues;

  List<String> get failedComponents {
    return [
      ...minorIssues,
      ...highIssues,
      ...criticalIssues,
    ];
  }

  bool get hasPeripheralIssue => peripheralIssues.isNotEmpty;
  bool get hasPcHealthIssue => criticalIssues.isNotEmpty;
  bool get hasMinorIssue => minorIssues.isNotEmpty;
  bool get hasHighIssue => highIssues.isNotEmpty;
  bool get hasCriticalIssue => criticalIssues.isNotEmpty;
  bool get hasBlockingIssue => hasHighIssue || hasCriticalIssue;

  String get severity {
    if (hasCriticalIssue) return 'Critical';
    if (hasHighIssue) return 'High';
    if (hasMinorIssue) return 'Minor';
    return 'Normal';
  }

  String get pcStatus {
    if (hasBlockingIssue) return 'Broken';
    if (hasMinorIssue) return 'Minor';
    return 'Online';
  }

  Map<String, dynamic> toMap() {
    return {
      'cpuOk': cpuOk,
      'ramOk': ramOk,
      'diskOk': diskOk,
      'storageHealthOk': storageHealthOk,
      'storageCapacityOk': storageCapacityOk,
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
      'minorIssues': minorIssues,
      'highIssues': highIssues,
      'criticalIssues': criticalIssues,
      'failedComponents': failedComponents,
      'severity': severity,
      'pcStatus': pcStatus,
    };
  }

  factory HardwareStatus.normal() {
    return HardwareStatus(
      cpuOk: true,
      ramOk: true,
      diskOk: true,
      storageHealthOk: true,
      storageCapacityOk: true,
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