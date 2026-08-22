import 'dart:convert';
import 'dart:io';

import '../models/hardware_status.dart';

class WindowsHardwareService {
  static HardwareStatus _lastReliableStatus = HardwareStatus.normal();

  static Future<HardwareStatus> checkHardware() async {
    if (!Platform.isWindows) {
      return HardwareStatus.normal();
    }

    try {
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          _hardwareScanScript,
        ],
      ).timeout(const Duration(seconds: 12));

      if (result.exitCode != 0) return _lastReliableStatus;

      final lines = result.stdout
          .toString()
          .trim()
          .split(RegExp(r'\r?\n'))
          .where((line) => line.trim().isNotEmpty)
          .toList();
      if (lines.isEmpty) return _lastReliableStatus;

      final data = Map<String, dynamic>.from(
        jsonDecode(lines.last) as Map,
      );

      bool ok(String key) => data[key] == true;

      final keyboardOk = _keyboardIsConnected(data);

      final status = HardwareStatus(
        cpuOk: ok('cpuOk'),
        ramOk: ok('ramOk'),
        diskOk: ok('diskOk'),
        storageHealthOk: ok('storageHealthOk'),
        storageCapacityOk: ok('storageCapacityOk'),
        networkOk: ok('networkOk'),
        keyboardOk: keyboardOk,
        mouseOk: ok('mouseOk'),
        monitorOk: ok('monitorOk'),
        webcamOk: true,
        printerOk: true,
        headsetOk: true,
        issues: [
          if (!ok('cpuOk')) 'CPU Not Detected',
          if (!ok('ramOk')) 'RAM Failure or Not Detected',
          if (!ok('diskOk')) 'Disk Not Detected',
          if (!ok('storageHealthOk')) 'Storage Health Failure',
          if (!ok('storageCapacityOk'))
            'Storage Capacity Critically Low',
          if (!ok('networkOk')) 'Ethernet Cable Disconnected',
          if (!keyboardOk) 'Keyboard Disconnected',
          if (!ok('mouseOk')) 'Mouse Disconnected',
          if (!ok('monitorOk')) 'Monitor Not Detected',
        ],
      );

      _lastReliableStatus = status;
      return status;
    } catch (_) {
      // A failed PowerShell invocation must not falsely mark a real,
      // unresolved fault as recovered.
      return _lastReliableStatus;
    }
  }

  static bool _keyboardIsConnected(Map<String, dynamic> data) {
    final reportedCount = data['keyboardDeviceCount'];
    final keyboardDeviceCount = reportedCount is num
        ? reportedCount.toInt()
        : (data['keyboardOk'] == true ? 1 : 0);

    // Keyboard brand, model, USB port, and HID interface count do not matter.
    // At least one currently present and working physical keyboard means the
    // keyboard is connected; zero means it is disconnected.
    return keyboardDeviceCount > 0;
  }

  static const String _hardwareScanScript = r'''
$ErrorActionPreference = 'SilentlyContinue'

function Test-CimDevice([string]$className) {
  return @(Get-CimInstance $className -ErrorAction SilentlyContinue).Count -gt 0
}

function Get-ConnectedKeyboardCount {
  $pnpCommand = Get-Command Get-PnpDevice -ErrorAction SilentlyContinue

  if ($null -ne $pnpCommand) {
    $connectedKeyboards = @(
      Get-PnpDevice -PresentOnly -Class Keyboard `
        -ErrorAction SilentlyContinue |
      Where-Object {
        $_.Status -eq 'OK' -and
        ($_.InstanceId + ' ' + $_.FriendlyName + ' ' + $_.Name) -notmatch `
          'ROOT\\|RDP|REMOTE|VIRTUAL|VMWARE|VMBUS|HYPER-V|CITRIX'
      }
    )

    return [int]$connectedKeyboards.Count
  }

  # Fallback for Windows editions without Get-PnpDevice. Only devices that
  # Windows currently marks present and error-free are counted.
  $connectedKeyboards = @(
    Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue |
    Where-Object {
      $_.PNPClass -eq 'Keyboard' -and
      $_.Present -eq $true -and
      $_.ConfigManagerErrorCode -eq 0 -and
      ($_.DeviceID + ' ' + $_.Name) -notmatch `
        'ROOT\\|RDP|REMOTE|VIRTUAL|VMWARE|VMBUS|HYPER-V|CITRIX'
    }
  )

  return [int]$connectedKeyboards.Count
}

function Get-PhysicalHidDeviceCount(
  [string]$pnpClass,
  [string]$usagePattern
) {
  $pnpCommand = Get-Command Get-PnpDevice -ErrorAction SilentlyContinue

  if ($null -ne $pnpCommand) {
    $devices = @(Get-PnpDevice -PresentOnly -Class $pnpClass `
      -ErrorAction SilentlyContinue)
    $physicalDevices = @()

    foreach ($device in $devices) {
      $instanceId = [string]$device.InstanceId
      $deviceName = [string]($device.FriendlyName + ' ' + $device.Name)

      if ($device.Status -ne 'OK') {
        continue
      }

      # A real wired USB HID device has a VID/PID-backed HID or USB ID.
      # ROOT, RDP, VMware and other software keyboard devices must not count.
      if ($instanceId -notmatch '^(HID|USB)\\VID_[0-9A-F]{4}&PID_[0-9A-F]{4}') {
        continue
      }

      if (($instanceId + ' ' + $deviceName) -match `
        'ROOT\\|RDP|REMOTE|VIRTUAL|VMWARE|VMBUS|HYPER-V|CITRIX') {
        continue
      }

      $hardwareIds = @(
        Get-PnpDeviceProperty -InstanceId $instanceId `
          -KeyName 'DEVPKEY_Device_HardwareIds' `
          -ErrorAction SilentlyContinue
      )

      $hardwareIdText = [string]::Join(
        ' ',
        @($hardwareIds | ForEach-Object { $_.Data })
      )

      # This rejects media-control and vendor HID interfaces that Windows may
      # also place in the Keyboard or Mouse PnP class. Some Windows editions
      # do not expose this property to a standard user, so a physical VID/PID
      # device is still accepted when the property is unavailable.
      if (
        -not [string]::IsNullOrWhiteSpace($hardwareIdText) -and
        $hardwareIdText -notmatch $usagePattern
      ) {
        continue
      }

      $physicalDevices += $device
    }

    return [int]$physicalDevices.Count
  }

  # Older Windows fallback. Present and ConfigManagerErrorCode are checked
  # because Win32_Keyboard by itself can keep disconnected devices cached.
  $cimDevices = @(
    Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue |
    Where-Object {
      $_.PNPClass -eq $pnpClass -and
      $_.Present -eq $true -and
      $_.ConfigManagerErrorCode -eq 0 -and
      $_.DeviceID -match '^(HID|USB)\\VID_[0-9A-F]{4}&PID_[0-9A-F]{4}' -and
      ([string]::Join(' ', @($_.HardwareID))) -match $usagePattern -and
      ($_.DeviceID + ' ' + $_.Name) -notmatch `
        'ROOT\\|RDP|REMOTE|VIRTUAL|VMWARE|VMBUS|HYPER-V|CITRIX'
    }
  )

  return [int]$cimDevices.Count
}

$cpuOk = Test-CimDevice 'Win32_Processor'
$ramOk = Test-CimDevice 'Win32_PhysicalMemory'
$diskOk = Test-CimDevice 'Win32_DiskDrive'
$keyboardDeviceCount = Get-ConnectedKeyboardCount
$mouseDeviceCount = Get-PhysicalHidDeviceCount `
  'Mouse' 'HID_DEVICE_SYSTEM_MOUSE|UP:0001_U:0002'
$keyboardOk = $keyboardDeviceCount -gt 0
$mouseOk = $mouseDeviceCount -gt 0

$activeMonitors = @(Get-CimInstance -Namespace root\wmi `
  -ClassName WmiMonitorID -ErrorAction SilentlyContinue |
  Where-Object { $_.Active -eq $true })
$monitorOk = $activeMonitors.Count -gt 0

if (-not $monitorOk) {
  $pnpCommand = Get-Command Get-PnpDevice -ErrorAction SilentlyContinue
  if ($null -ne $pnpCommand) {
    $monitorOk = @(Get-PnpDevice -PresentOnly -Class Monitor `
      -ErrorAction SilentlyContinue |
      Where-Object { $_.Status -eq 'OK' }).Count -gt 0
  }
}

$networkOk = $false
$netAdapterCommand = Get-Command Get-NetAdapter -ErrorAction SilentlyContinue
if ($null -ne $netAdapterCommand) {
  $networkOk = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
    Where-Object {
      $_.Status -eq 'Up' -and
      ($_.Name + ' ' + $_.InterfaceDescription) -notmatch `
        'Wi-Fi|Wireless|WLAN|802\.11|Bluetooth'
    }).Count -gt 0
} else {
  $networkOk = @(Get-CimInstance Win32_NetworkAdapter `
    -ErrorAction SilentlyContinue |
    Where-Object {
      $_.NetConnectionStatus -eq 2 -and
      ($_.Name + ' ' + $_.Description) -notmatch `
        'Wi-Fi|Wireless|WLAN|802\.11|Bluetooth'
    }).Count -gt 0
}

$physicalDisks = @(Get-PhysicalDisk -ErrorAction SilentlyContinue)
if ($physicalDisks.Count -gt 0) {
  $storageHealthOk = @($physicalDisks | Where-Object {
    $_.HealthStatus -ne 'Healthy'
  }).Count -eq 0
} else {
  $wmiDisks = @(Get-CimInstance Win32_DiskDrive `
    -ErrorAction SilentlyContinue)
  $storageHealthOk = $wmiDisks.Count -gt 0 -and `
    @($wmiDisks | Where-Object { $_.Status -ne 'OK' }).Count -eq 0
}

$logicalDrive = Get-CimInstance Win32_LogicalDisk `
  -ErrorAction SilentlyContinue |
  Where-Object { $_.DeviceID -eq $env:SystemDrive } |
  Select-Object -First 1

$storageCapacityOk = $false
if ($null -ne $logicalDrive -and $logicalDrive.Size -gt 0) {
  $storageCapacityOk = $logicalDrive.FreeSpace -ge 5GB -or `
    ($logicalDrive.FreeSpace / $logicalDrive.Size) -ge 0.05
}

[pscustomobject]@{
  cpuOk = [bool]$cpuOk
  ramOk = [bool]$ramOk
  diskOk = [bool]$diskOk
  storageHealthOk = [bool]$storageHealthOk
  storageCapacityOk = [bool]$storageCapacityOk
  networkOk = [bool]$networkOk
  keyboardOk = [bool]$keyboardOk
  keyboardDeviceCount = [int]$keyboardDeviceCount
  mouseOk = [bool]$mouseOk
  mouseDeviceCount = [int]$mouseDeviceCount
  monitorOk = [bool]$monitorOk
} | ConvertTo-Json -Compress
''';
}
