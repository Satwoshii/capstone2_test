import 'dart:async';
import 'dart:io';

import 'package:window_manager/window_manager.dart';

/// Controls the Student application's Windows pre-login kiosk state.
///
/// This is an application-level kiosk: it keeps Syswatch fullscreen, visible,
/// and non-minimizable until a student session starts. Windows secure-key
/// sequences (for example Ctrl+Alt+Delete) remain controlled by Windows.
class PreLoginKioskService with WindowListener {
  PreLoginKioskService._();

  static final PreLoginKioskService instance = PreLoginKioskService._();

  bool _initialized = false;
  bool _locked = true;
  bool _enforcing = false;
  bool _fullscreenFailsafeActive = false;

  bool get isLocked => _locked;
  bool get isFullscreenFailsafeActive => _fullscreenFailsafeActive;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  Future<void> initialize() async {
    if (_initialized || !_isDesktop) return;
    _initialized = true;
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);
  }

  /// Locks the workstation UI at Syswatch until student authentication.
  Future<void> lockForLogin() async {
    _locked = true;
    _fullscreenFailsafeActive = false;
    await enforceLockedWindow();
  }

  /// Releases kiosk restrictions after a valid student login.
  Future<void> releaseAfterLogin() async {
    _locked = false;
    _fullscreenFailsafeActive = false;
    if (!_isDesktop) return;

    try {
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setFullScreen(false);
      await windowManager.setResizable(true);
      await windowManager.setMinimizable(true);
      await windowManager.setClosable(true);
      await windowManager.maximize();
      await windowManager.focus();
    } catch (_) {
      // Do not invalidate a successful login because of a window API failure.
    }
  }

  /// Restores and re-applies all pre-login kiosk restrictions.
  Future<void> enforceLockedWindow() async {
    if (!_isDesktop || !_locked || _enforcing) return;
    _enforcing = true;

    try {
      await windowManager.setPreventClose(true);
      await windowManager.setClosable(false);
      await windowManager.setMinimizable(false);
      await windowManager.setResizable(_fullscreenFailsafeActive);
      await windowManager.setAlwaysOnTop(!_fullscreenFailsafeActive);
      await windowManager.show();
      await windowManager.restore();
      await windowManager.setFullScreen(!_fullscreenFailsafeActive);
      if (_fullscreenFailsafeActive) {
        await windowManager.maximize();
      }
      await windowManager.focus();
    } catch (_) {
      // A later lifecycle event will re-apply the kiosk state.
    } finally {
      _enforcing = false;
    }
  }

  /// Cancels fullscreen after the local triple-Delete failsafe is triggered.
  /// The workstation remains on the protected, maximized Student login screen.
  Future<void> cancelFullscreenWithFailsafe() async {
    if (!_isDesktop || !_locked) return;
    _fullscreenFailsafeActive = true;
    await enforceLockedWindow();
  }

  /// Hides the app only when an authenticated student session has released the
  /// pre-login lock.
  Future<void> hideToTray() async {
    if (_locked) {
      await enforceLockedWindow();
      return;
    }
    await windowManager.hide();
  }

  Future<void> showWindow() async {
    if (_locked) {
      await enforceLockedWindow();
      return;
    }
    await windowManager.show();
    await windowManager.restore();
    await windowManager.focus();
  }

  @override
  void onWindowClose() {
    unawaited(_locked ? enforceLockedWindow() : windowManager.hide());
  }

  @override
  void onWindowMinimize() {
    if (_locked) unawaited(enforceLockedWindow());
  }

  @override
  void onWindowBlur() {
    if (!_locked) return;
    // Reassert focus after Windows finishes processing the focus change.
    unawaited(
      Future<void>.delayed(
        const Duration(milliseconds: 100),
        enforceLockedWindow,
      ),
    );
  }
}
