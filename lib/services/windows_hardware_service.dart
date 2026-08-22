import 'dart:convert';
import 'dart:io';

import '../models/hardware_status.dart';

class WindowsHardwareService {
  static HardwareStatus _lastReliableStatus = HardwareStatus.normal();
  static int? _expectedKeyboardDeviceCount;
  static int? _expectedMouseDeviceCount;
  static DateTime? _lastEventViewerScanAt;
  static bool _eventViewerScanSucceeded = false;
  static List<Map<String, dynamic>> _eventDiagnostics = const [];

  static Future<HardwareStatus> checkHardware() async {
    if (!Platform.isWindows) {
      return HardwareStatus.normal();
    }

    final eventViewerRefresh = _refreshEventViewerDiagnostics();

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

      if (result.exitCode != 0) {
        await eventViewerRefresh;
        return _withCurrentDiagnostics(_lastReliableStatus);
      }

      final lines = result.stdout
          .toString()
          .trim()
          .split(RegExp(r'\r?\n'))
          .where((line) => line.trim().isNotEmpty)
          .toList();
      if (lines.isEmpty) {
        await eventViewerRefresh;
        return _withCurrentDiagnostics(_lastReliableStatus);
      }

      final data = Map<String, dynamic>.from(
        jsonDecode(lines.last) as Map,
      );

      bool ok(String key) => data[key] == true;

      final keyboardOk = _keyboardIsConnected(data);
      final mouseOk = _mouseIsConnected(data);
      await eventViewerRefresh;

      final status = HardwareStatus(
        cpuOk: ok('cpuOk'),
        ramOk: ok('ramOk'),
        diskOk: ok('diskOk'),
        storageHealthOk: ok('storageHealthOk'),
        storageCapacityOk: ok('storageCapacityOk'),
        networkOk: ok('networkOk'),
        keyboardOk: keyboardOk,
        mouseOk: mouseOk,
        monitorOk: ok('monitorOk'),
        webcamOk: true,
        printerOk: true,
        headsetOk: true,
        eventViewerScanSucceeded: _eventViewerScanSucceeded,
        eventDiagnostics: _eventDiagnostics,
        detectionDiagnostics: {
          'keyboardDeviceCount': _deviceCount(
            data,
            countKey: 'keyboardDeviceCount',
            okKey: 'keyboardOk',
          ),
          'expectedKeyboardDeviceCount': _expectedKeyboardDeviceCount,
          'mouseDeviceCount': _deviceCount(
            data,
            countKey: 'mouseDeviceCount',
            okKey: 'mouseOk',
          ),
          'expectedMouseDeviceCount': _expectedMouseDeviceCount,
          'networkScanSucceeded': data['networkScanSucceeded'] == true,
          'ethernetAdapterCount': data['ethernetAdapterCount'] ?? 0,
          'connectedEthernetCount': data['connectedEthernetCount'] ?? 0,
        },
        issues: [
          if (!ok('cpuOk')) 'CPU Not Detected',
          if (!ok('ramOk')) 'RAM Failure or Not Detected',
          if (!ok('diskOk')) 'Disk Not Detected',
          if (!ok('storageHealthOk')) 'Storage Health Failure',
          if (!ok('storageCapacityOk'))
            'Storage Capacity Critically Low',
          if (!ok('networkOk')) 'Ethernet Cable Disconnected',
          if (!keyboardOk) 'Keyboard Disconnected',
          if (!mouseOk) 'Mouse Disconnected',
          if (!ok('monitorOk')) 'Monitor Not Detected',
        ],
      );

      _lastReliableStatus = status;
      return status;
    } catch (_) {
      // A failed PowerShell invocation must not falsely mark a real,
      // unresolved fault as recovered.
      await eventViewerRefresh;
      return _withCurrentDiagnostics(_lastReliableStatus);
    }
  }

  static HardwareStatus _withCurrentDiagnostics(HardwareStatus status) {
    return HardwareStatus(
      cpuOk: status.cpuOk,
      ramOk: status.ramOk,
      diskOk: status.diskOk,
      storageHealthOk: status.storageHealthOk,
      storageCapacityOk: status.storageCapacityOk,
      networkOk: status.networkOk,
      keyboardOk: status.keyboardOk,
      mouseOk: status.mouseOk,
      monitorOk: status.monitorOk,
      webcamOk: status.webcamOk,
      printerOk: status.printerOk,
      headsetOk: status.headsetOk,
      issues: status.issues,
      eventViewerScanSucceeded: _eventViewerScanSucceeded,
      eventDiagnostics: _eventDiagnostics,
      detectionDiagnostics: status.detectionDiagnostics,
    );
  }

  static Future<void> _refreshEventViewerDiagnostics() async {
    final now = DateTime.now();
    final previousScanAt = _lastEventViewerScanAt;
    if (previousScanAt != null &&
        now.difference(previousScanAt) < const Duration(seconds: 30)) {
      return;
    }

    _lastEventViewerScanAt = now;
    final data = await _runEventViewerScan();
    if (data == null || data['scanSucceeded'] != true) {
      _eventViewerScanSucceeded = false;
      return;
    }

    _eventViewerScanSucceeded = true;
    final rawDiagnostics = data['eventDiagnostics'];
    final values = rawDiagnostics is List
        ? rawDiagnostics
        : [if (rawDiagnostics != null) rawDiagnostics];
    _eventDiagnostics = List<Map<String, dynamic>>.unmodifiable(
      values
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList(),
    );
  }

  static Future<Map<String, dynamic>?> _runEventViewerScan() async {
    try {
      final result = await Process.run(
        'powershell',
        [
          '-NoLogo',
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          _eventViewerScanScript,
        ],
      ).timeout(const Duration(seconds: 10));

      if (result.exitCode != 0) return null;
      final lines = result.stdout
          .toString()
          .trim()
          .split(RegExp(r'\r?\n'))
          .where((line) => line.trim().isNotEmpty)
          .toList();
      if (lines.isEmpty) return null;

      final decoded = jsonDecode(lines.last);
      if (decoded is! Map) return null;
      final data = Map<String, dynamic>.from(decoded);
      return data['schemaVersion'] == 1 ? data : null;
    } catch (_) {
      return null;
    }
  }

  static bool _keyboardIsConnected(Map<String, dynamic> data) {
    final currentCount = _deviceCount(
      data,
      countKey: 'keyboardDeviceCount',
      okKey: 'keyboardOk',
    );
    _expectedKeyboardDeviceCount ??= currentCount > 0 ? currentCount : null;
    final expectedCount = _expectedKeyboardDeviceCount;
    return expectedCount == null
        ? currentCount > 0
        : currentCount >= expectedCount;
  }

  static bool _mouseIsConnected(Map<String, dynamic> data) {
    final currentCount = _deviceCount(
      data,
      countKey: 'mouseDeviceCount',
      okKey: 'mouseOk',
    );
    _expectedMouseDeviceCount ??= currentCount > 0 ? currentCount : null;
    final expectedCount = _expectedMouseDeviceCount;
    return expectedCount == null
        ? currentCount > 0
        : currentCount >= expectedCount;
  }

  static int _deviceCount(
    Map<String, dynamic> data, {
    required String countKey,
    required String okKey,
  }) {
    final reportedCount = data[countKey];
    return reportedCount is num
        ? reportedCount.toInt()
        : (data[okKey] == true ? 1 : 0);
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

# Physical Ethernet cable state. Internet access is not required: the link is
# healthy only when Windows reports a connected, operational wired adapter.
$networkOk = $false
$networkScanSucceeded = $false
$ethernetAdapterCount = 0
$connectedEthernetCount = 0
$excludedNetworkPattern = `
  'Wi-Fi|Wireless|WLAN|802\.11|Bluetooth|Virtual|VMware|Hyper-V|VPN|TAP|TUN|Loopback|Host-Only'
$ethernetNamePattern = `
  'Ethernet|Gigabit|GbE|Fast Ethernet|PCIe.*(LAN|Network|Controller)'

# Windows 8/10/11 primary provider. MediaConnectState 1 means connected and
# InterfaceOperationalStatus 1 means the adapter is operationally up.
try {
  $standardAdapters = @(
    Get-CimInstance -Namespace root/StandardCimv2 `
      -ClassName MSFT_NetAdapter -ErrorAction Stop |
    Where-Object {
      $identity = $_.Name + ' ' + $_.InterfaceDescription
      $_.HardwareInterface -eq $true -and
      $_.ConnectorPresent -eq $true -and
      $_.Virtual -ne $true -and
      $_.Hidden -ne $true -and
      $identity -notmatch $excludedNetworkPattern -and
      (
        $_.LinkTechnology -eq 2 -or
        $_.NdisPhysicalMedium -eq 14 -or
        $identity -match $ethernetNamePattern
      )
    }
  )

  $networkScanSucceeded = $true
  $ethernetAdapterCount = $standardAdapters.Count
  $connectedAdapters = @($standardAdapters | Where-Object {
    $_.MediaConnectState -eq 1 -and
    $_.InterfaceOperationalStatus -eq 1 -and
    $_.OperationalStatusDownMediaDisconnected -ne $true
  })
  $connectedEthernetCount = $connectedAdapters.Count
  $networkOk = $connectedEthernetCount -gt 0
} catch {
  $networkScanSucceeded = $false
}

# Get-NetAdapter fallback for systems where the CIM provider is unavailable.
if (-not $networkScanSucceeded) {
  $netAdapterCommand = Get-Command Get-NetAdapter `
    -ErrorAction SilentlyContinue
  if ($null -ne $netAdapterCommand) {
    try {
      $physicalAdapters = @(Get-NetAdapter -Physical -ErrorAction Stop |
        Where-Object {
          ($_.Name + ' ' + $_.InterfaceDescription) -notmatch `
            $excludedNetworkPattern
        })
      $networkScanSucceeded = $true
      $ethernetAdapterCount = $physicalAdapters.Count
      $connectedAdapters = @($physicalAdapters | Where-Object {
        $mediaState = [string]$_.MediaConnectionState
        $_.Status -eq 'Up' -and
        (
          [string]::IsNullOrWhiteSpace($mediaState) -or
          $mediaState -eq 'Connected'
        )
      })
      $connectedEthernetCount = $connectedAdapters.Count
      $networkOk = $connectedEthernetCount -gt 0
    } catch {
      $networkScanSucceeded = $false
    }
  }
}

# Final compatibility fallback. NetConnectionStatus 2 means connected.
if (-not $networkScanSucceeded) {
  try {
    $legacyAdapters = @(Get-CimInstance Win32_NetworkAdapter `
      -ErrorAction Stop |
      Where-Object {
        $identity = $_.Name + ' ' + $_.Description
        $_.PhysicalAdapter -eq $true -and
        $identity -notmatch $excludedNetworkPattern -and
        (
          $_.AdapterTypeID -eq 0 -or
          $identity -match $ethernetNamePattern
        )
      })
    $networkScanSucceeded = $true
    $ethernetAdapterCount = $legacyAdapters.Count
    $connectedAdapters = @($legacyAdapters | Where-Object {
      $_.NetEnabled -eq $true -and $_.NetConnectionStatus -eq 2
    })
    $connectedEthernetCount = $connectedAdapters.Count
    $networkOk = $connectedEthernetCount -gt 0
  } catch {
    $networkScanSucceeded = $false
  }
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
  networkScanSucceeded = [bool]$networkScanSucceeded
  networkOk = [bool]$networkOk
  ethernetAdapterCount = [int]$ethernetAdapterCount
  connectedEthernetCount = [int]$connectedEthernetCount
  keyboardOk = [bool]$keyboardOk
  keyboardDeviceCount = [int]$keyboardDeviceCount
  mouseOk = [bool]$mouseOk
  mouseDeviceCount = [int]$mouseDeviceCount
  monitorOk = [bool]$monitorOk
} | ConvertTo-Json -Compress
''';

  static const String _eventViewerScanScript = r'''
$ErrorActionPreference = 'SilentlyContinue'
$scanSucceeded = $false
$eventDiagnostics = @()
$startTime = (Get-Date).AddMinutes(-15)
$candidateLogs = @(
  'System',
  'Microsoft-Windows-DriverFrameworks-UserMode/Operational',
  'Microsoft-Windows-DeviceSetupManager/Admin',
  'Microsoft-Windows-Kernel-PnP/Configuration',
  'Microsoft-Windows-UserPnp/DeviceInstall'
)

try {
  $readableLogs = @()
  foreach ($logName in $candidateLogs) {
    try {
      $logInfo = Get-WinEvent -ListLog $logName -ErrorAction Stop
      if ($null -ne $logInfo -and $logInfo.IsEnabled) {
        $readableLogs += $logName
      }
    } catch {
    }
  }

  if ($readableLogs -contains 'System') {
    $scanSucceeded = $true
  }

  $events = @()
  foreach ($logName in $readableLogs) {
    try {
      $events += @(Get-WinEvent -FilterHashtable @{
          LogName = $logName
          StartTime = $startTime
        } -MaxEvents 120 -ErrorAction Stop)
      $scanSucceeded = $true
    } catch {
    }
  }

  foreach ($event in $events) {
    $provider = [string]$event.ProviderName
    $message = [string]$event.Message
    if ([string]::IsNullOrWhiteSpace($message)) {
      try {
        $message = [string]$event.FormatDescription()
      } catch {
        $message = ''
      }
    }

    $message = ($message -replace '[\r\n\t]+', ' ' `
      -replace '\s{2,}', ' ').Trim()
    if ($message.Length -gt 700) {
      $message = $message.Substring(0, 700)
    }

    $evidenceText = $provider + ' ' + $message
    $component = ''

    if ($evidenceText -match 'keyboard|kbdhid|i8042prt') {
      $component = 'keyboard'
    } elseif ($evidenceText -match 'mouse|mouhid|pointing device') {
      $component = 'mouse'
    } elseif ($evidenceText -match `
      'monitor|display device|displayport|hdmi|dxgkrnl') {
      $component = 'monitor'
    } elseif ($evidenceText -match `
      'ethernet|network adapter|NDIS|media connect|network link|GbE') {
      $component = 'ethernet'
    } elseif ($evidenceText -match `
      'physical memory|memory module|MemoryDiagnostics|RAM') {
      $component = 'ram'
    } elseif ($evidenceText -match `
      'processor|CPU|WHEA-Logger|Machine Check') {
      $component = 'cpu'
    } elseif ($evidenceText -match `
      '(^|[^a-z])disk([^a-z]|$)|NTFS|storahci|stornvme|NVMe|SATA|bad block|I/O error|volmgr|partmgr') {
      $component = 'storage'
    } elseif ($evidenceText -match 'USB|HID|PnP device|device instance') {
      $component = 'device'
    }

    if ([string]::IsNullOrWhiteSpace($component)) {
      continue
    }

    $state = 'information'
    if ($evidenceText -match `
      'disconnect|removed|removal|surprise removal|stopped|failed|failure|not migrated|not started|problem|error|link is down|media disconnected') {
      $state = 'problem'
    } elseif ($evidenceText -match `
      'connected|started|configured|installed|arrived|enumerated|link is up|media connected') {
      $state = 'connected'
    } elseif ([int]$event.Level -le 3 -and [int]$event.Level -gt 0) {
      $state = 'warning'
    }

    # Keep informational entries only when the message contains an explicit
    # device transition. Error and warning entries are always useful.
    $hasTransition = $state -ne 'information'
    if (-not $hasTransition -and [int]$event.Level -gt 3) {
      continue
    }

    $timeCreated = ''
    if ($null -ne $event.TimeCreated) {
      $timeCreated = $event.TimeCreated.ToUniversalTime().ToString('o')
    }

    $eventDiagnostics += [pscustomobject]@{
      component = $component
      state = $state
      logName = [string]$event.LogName
      provider = $provider
      eventId = [int]$event.Id
      recordId = [int64]$event.RecordId
      level = [string]$event.LevelDisplayName
      timeCreated = $timeCreated
      message = $message
    }
  }

  $eventDiagnostics = @($eventDiagnostics |
    Sort-Object timeCreated -Descending |
    Select-Object -First 30)
} catch {
  $scanSucceeded = $false
}

[pscustomobject]@{
  schemaVersion = 1
  scanSucceeded = [bool]$scanSucceeded
  checkedAt = (Get-Date).ToUniversalTime().ToString('o')
  eventDiagnostics = @($eventDiagnostics)
} | ConvertTo-Json -Compress -Depth 6
''';
}
