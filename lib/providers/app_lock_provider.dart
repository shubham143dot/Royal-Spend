import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../core/services/security/app_lock_service.dart';
import '../data/repositories/settings_repository.dart';

/// App Lock State & Lifecycle Management Controller for Royal Spend.
///
/// Implements PhonePe-style native security locking on startup and backgrounding,
/// ensuring zero financial data exposure before native biometric/device authentication.
class AppLockProvider extends ChangeNotifier with WidgetsBindingObserver {
  final IAppLockService _service;
  final SettingsRepository _settingsRepo;

  bool _isAppLockEnabled = false;
  bool _isLocked = false;
  bool _isAuthenticating = false;
  bool _isDeviceSupported = false;
  List<BiometricType> _availableBiometrics = const [];
  String? _errorMessage;
  DateTime? _backgroundedAt;

  AppLockProvider({
    IAppLockService? service,
    SettingsRepository? settingsRepo,
  })  : _service = service ?? AppLockService(),
        _settingsRepo = settingsRepo ?? SettingsRepository();

  bool get isAppLockEnabled => _isAppLockEnabled;
  bool get isLocked => _isLocked;
  bool get isAuthenticating => _isAuthenticating;
  bool get isDeviceSupported => _isDeviceSupported;
  List<BiometricType> get availableBiometrics => List.unmodifiable(_availableBiometrics);
  String? get errorMessage => _errorMessage;
  DateTime? get backgroundedAt => _backgroundedAt;

  /// Returns user-friendly biometric capabilities description.
  String get biometricDescription {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return 'Unlock with Face ID or device credentials';
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return 'Unlock with Fingerprint or device credentials';
    } else {
      return 'Unlock with device PIN, Pattern, or Biometrics';
    }
  }

  /// Returns the most appropriate native security icon for the device.
  IconData get securityIcon {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return CupertinoIcons.person_crop_circle_badge_checkmark;
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return Icons.fingerprint;
    }
    return CupertinoIcons.lock_shield_fill;
  }

  /// Initializes the provider, checks native device capabilities,
  /// loads persistence, and enforces startup lock if enabled.
  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);

    _isAppLockEnabled = await _settingsRepo.isAppLockEnabled();
    _isDeviceSupported = await _service.isDeviceSecure();
    _availableBiometrics = await _service.getAvailableBiometrics();

    if (_isAppLockEnabled) {
      // Start in a securely locked state to prevent any financial data leakage.
      // Native authentication is prompted when AppLockScreen mounts on screen after splash animation.
      _isLocked = true;
      notifyListeners();
    } else {
      _isLocked = false;
      notifyListeners();
    }
  }

  /// Enables App Lock after verifying device security & successful authentication.
  Future<bool> enableAppLock(BuildContext context) async {
    _errorMessage = null;

    final isSecure = await _service.isDeviceSecure();
    if (!isSecure) {
      _errorMessage = 'Please set up a screen lock on your device to enable App Lock.';
      notifyListeners();
      return false;
    }

    final success = await _service.authenticate(
      reason: 'Authenticate to enable App Lock for Royal Spend.',
    );

    if (success) {
      _isAppLockEnabled = true;
      _isLocked = false;
      _errorMessage = null;
      await _settingsRepo.setAppLockEnabled(true);
      notifyListeners();
      return true;
    } else {
      _errorMessage = 'Authentication was cancelled or failed.';
      notifyListeners();
      return false;
    }
  }

  /// Disables App Lock only after successful native device authentication.
  Future<bool> disableAppLock(BuildContext context) async {
    _errorMessage = null;

    final success = await _service.authenticate(
      reason: 'Authenticate to disable App Lock.',
    );

    if (success) {
      _isAppLockEnabled = false;
      _isLocked = false;
      _errorMessage = null;
      await _settingsRepo.setAppLockEnabled(false);
      notifyListeners();
      return true;
    } else {
      _errorMessage = 'Authentication failed. App Lock remains enabled.';
      notifyListeners();
      return false;
    }
  }

  /// Unlocks the application using native biometrics or device PIN/pattern/passcode.
  Future<bool> unlockApp() async {
    if (!_isAppLockEnabled) {
      _isLocked = false;
      notifyListeners();
      return true;
    }

    if (_isAuthenticating) {
      return false;
    }

    _isAuthenticating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _service.authenticate(
        reason: 'Authenticate to access Royal Spend.',
      );

      if (success) {
        _isLocked = false;
        _errorMessage = null;
      } else {
        _isLocked = true;
        _errorMessage = 'Authentication required to access Royal Spend.';
      }
      return success;
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }

  /// Manually locks the application immediately.
  void lockApp() {
    if (_isAppLockEnabled && !_isLocked) {
      _isLocked = true;
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isAppLockEnabled) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      // App entered background: lock immediately to prevent app switcher preview leaks
      _backgroundedAt = DateTime.now();
      _isLocked = true;
      notifyListeners();
    } else if (state == AppLifecycleState.resumed) {
      // App returned to foreground: enforce lock and prompt authentication
      if (_isLocked && !_isAuthenticating) {
        unlockApp();
      }
      _backgroundedAt = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
