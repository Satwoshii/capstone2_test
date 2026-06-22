import 'dart:io';

import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'sync_service.dart';

class TrayService with TrayListener {
  TrayService._();

  static final TrayService instance = TrayService._();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;

    _initialized = true;

    trayManager.addListener(this);

    await trayManager.setIcon(
      Platform.isWindows
          ? 'assets/tray/app_icon.ico'
          : 'assets/tray/app_icon.png',
    );

    await trayManager.setToolTip('Hybrid PC Monitoring System');

    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(
            key: 'show',
            label: 'Show App',
          ),
          MenuItem(
            key: 'hide',
            label: 'Hide to Tray',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'sync',
            label: 'Sync Now',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'exit',
            label: 'Exit',
          ),
        ],
      ),
    );
  }

  Future<void> hideToTray() async {
    await windowManager.hide();
  }

  Future<void> showFromTray() async {
    await windowManager.show();
    await windowManager.restore();
    await windowManager.focus();
  }

  @override
  void onTrayIconMouseDown() {
    showFromTray();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  Future<void> onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show':
        await showFromTray();
        break;

      case 'hide':
        await hideToTray();
        break;

      case 'sync':
        await SyncService.instance.syncPendingData();
        break;

      case 'exit':
        trayManager.removeListener(this);
        await trayManager.destroy();
        await windowManager.destroy();
        break;
    }
  }
}