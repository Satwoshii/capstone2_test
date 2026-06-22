import 'dart:io';

import '../models/hardware_status.dart';

class WindowsHardwareService {
  static Future<HardwareStatus> checkHardware() async {
    if (!Platform.isWindows) {
      return HardwareStatus.normal();
    }

    try {
      final cpuOk = await _hasWmiDevice('Win32_Processor');
      final ramOk = await _hasWmiDevice('Win32_PhysicalMemory');
      final diskOk = await _diskHealthy();
      final networkOk = await _ethernetDetected();
      final keyboardOk = await _hasWmiDevice('Win32_Keyboard');
      final mouseOk = await _hasWmiDevice('Win32_PointingDevice');
      final monitorOk = await _hasWmiDevice('Win32_DesktopMonitor');
      // The school-required peripherals are keyboard, mouse, monitor, and Ethernet.
      // Other peripherals such as webcam, printer, and headset are not checked.
      const webcamOk = true;
      const printerOk = true;
      const headsetOk = true;

      final issues = <String>[];

      if (!cpuOk) issues.add('CPU Not Detected');
      if (!ramOk) issues.add('RAM Failure or Not Detected');
      if (!diskOk) issues.add('Disk Failure');
      if (!networkOk) issues.add('Ethernet / LAN Connection Not Detected');
      if (!keyboardOk) issues.add('Keyboard Missing');
      if (!mouseOk) issues.add('Mouse Disconnected');
      if (!monitorOk) issues.add('Monitor Not Detected');

      return HardwareStatus(
        cpuOk: cpuOk,
        ramOk: ramOk,
        diskOk: diskOk,
        networkOk: networkOk,
        keyboardOk: keyboardOk,
        mouseOk: mouseOk,
        monitorOk: monitorOk,
        webcamOk: webcamOk,
        printerOk: printerOk,
        headsetOk: headsetOk,
        issues: issues,
      );
    } catch (_) {
      return HardwareStatus.normal();
    }
  }

  static Future<bool> _hasWmiDevice(String className) async {
    final result = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-Command',
        '(Get-CimInstance $className | Measure-Object).Count',
      ],
    );

    final output = result.stdout.toString().trim();
    final count = int.tryParse(output) ?? 0;

    return count > 0;
  }


  static Future<bool> _ethernetDetected() async {
    final command =
        "(Get-CimInstance Win32_NetworkAdapter | Where-Object { \$_.NetConnectionStatus -eq 2 -and (\$_.Name -match 'Ethernet|Realtek|Intel|LAN|GbE|PCIe') } | Measure-Object).Count";

    final result = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-Command',
        command,
      ],
    );

    final output = result.stdout.toString().trim();
    final count = int.tryParse(output) ?? 0;

    return count > 0;
  }

  static Future<bool> _hasPnPKeyword(String keyword) async {
    final command =
        "(Get-CimInstance Win32_PnPEntity | Where-Object { \$_.Name -match '$keyword' } | Measure-Object).Count";

    final result = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-Command',
        command,
      ],
    );

    final output = result.stdout.toString().trim();
    final count = int.tryParse(output) ?? 0;

    return count > 0;
  }

  static Future<bool> _diskHealthy() async {
    final command =
        "(Get-CimInstance Win32_DiskDrive | Where-Object { \$_.Status -eq 'OK' } | Measure-Object).Count";

    final result = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-Command',
        command,
      ],
    );

    final output = result.stdout.toString().trim();
    final count = int.tryParse(output) ?? 0;

    return count > 0;
  }
}
