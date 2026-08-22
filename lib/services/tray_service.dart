import 'dart:io';

import 'package:tray_manager/tray_manager.dart';

import 'pre_login_kiosk_service.dart';

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

    await trayManager.setToolTip('Syswatch');

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
        ],
      ),
    );
  }

  Future<void> hideToTray() async {
    await PreLoginKioskService.instance.hideToTray();
  }

  Future<void> showFromTray() async {
    await PreLoginKioskService.instance.showWindow();
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
    }
  }
}
