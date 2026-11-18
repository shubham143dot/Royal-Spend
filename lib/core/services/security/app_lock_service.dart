import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

abstract class IAppLockService {
  Future<bool> isDeviceSupported();
  Future<bool> canCheckBiometrics();
  Future<bool> isDeviceSecure();
  Future<List<BiometricType>> getAvailableBiometrics();
  Future<bool> authenticate({required String reason});
  Future<void> stopAuthentication();
  bool get isAuthenticating;
}

/// Production-ready Native App Lock Service using device's built-in security.
///
/// Supports Biometrics (Fingerprint, Face ID) and Device Credentials
/// (PIN, Pattern, Password / Passcode) without requiring a custom PIN or network access.
class AppLockService implements IAppLockService {
  final LocalAuthentication _localAuth;
  bool _isAuthenticating = false;

  AppLockService({LocalAuthentication? localAuth})
      : _localAuth = localAuth ?? LocalAuthentication();

  @override
  bool get isAuthenticating => _isAuthenticating;

  @override
  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } on PlatformException catch (e) {
      debugPrint('AppLockService isDeviceSupported PlatformException: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('AppLockService isDeviceSupported error: $e');
      return false;
    }
  }

  @override
  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } on PlatformException catch (e) {
      debugPrint('AppLockService canCheckBiometrics PlatformException: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('AppLockService canCheckBiometrics error: $e');
      return false;
    }
  }

  @override
  Future<bool> isDeviceSecure() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      final available = await getAvailableBiometrics();
      return isSupported || canCheck || available.isNotEmpty;
    } on PlatformException catch (e) {
      debugPrint('AppLockService isDeviceSecure PlatformException: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('AppLockService isDeviceSecure error: $e');
      return false;
    }
  }

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      debugPrint('AppLockService getAvailableBiometrics PlatformException: ${e.code} - ${e.message}');
      return const [];
    } catch (e) {
      debugPrint('AppLockService getAvailableBiometrics error: $e');
      return const [];
    }
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    if (_isAuthenticating) {
      debugPrint('AppLockService: Authentication already in progress. Ignoring duplicate invocation.');
      return false;
    }

    _isAuthenticating = true;
    try {
      final bool authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
        sensitiveTransaction: true,
      );
      return authenticated;
    } on PlatformException catch (e) {
      debugPrint('AppLockService authenticate PlatformException: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('AppLockService authenticate error: $e');
      return false;
    } finally {
      _isAuthenticating = false;
    }
  }

  @override
  Future<void> stopAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
    } catch (e) {
      debugPrint('AppLockService stopAuthentication error: $e');
    } finally {
      _isAuthenticating = false;
    }
  }
}
