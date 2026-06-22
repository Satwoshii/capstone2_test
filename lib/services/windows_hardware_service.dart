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
      final networkOk = await _hasWmiDevice('Win32_NetworkAdapter');
      final keyboardOk = await _hasWmiDevice('Win32_Keyboard');
      final mouseOk = await _hasWmiDevice('Win32_PointingDevice');
      final monitorOk = await _hasWmiDevice('Win32_DesktopMonitor');
      final webcamOk = await _hasPnPKeyword('camera');
      final printerOk = await _hasWmiDevice('Win32_Printer');
      final headsetOk = await _hasPnPKeyword('audio');

      final issues = <String>[];

      if (!cpuOk) issues.add('CPU Not Detected');
      if (!ramOk) issues.add('RAM Failure or Not Detected');
      if (!diskOk) issues.add('Disk Failure');
      if (!networkOk) issues.add('Network Adapter Not Detected');
      if (!keyboardOk) issues.add('Keyboard Missing');
      if (!mouseOk) issues.add('Mouse Disconnected');
      if (!monitorOk) issues.add('Monitor Not Detected');
      if (!webcamOk) issues.add('Webcam Not Found');
      if (!printerOk) issues.add('Printer Not Found');
      if (!headsetOk) issues.add('Headset Not Found');

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
