import 'dart:io';

import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';

class StartupService {
  StartupService._();

  static Future<void> enableStartup() async {
    if (!Platform.isWindows) return;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      launchAtStartup.setup(
        appName: packageInfo.appName,
        appPath: Platform.resolvedExecutable,
        packageName: packageInfo.packageName,
      );
      if (!await launchAtStartup.isEnabled()) {
        await launchAtStartup.enable();
      }
    } catch (_) {
      // Startup registration can fail during flutter run. Release builds can retry.
    }
  }
}
