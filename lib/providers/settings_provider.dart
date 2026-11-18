import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:royal_spend/core/constants/app_constants.dart';
import 'package:royal_spend/core/services/auth/firebase_auth_gateway.dart';
import 'package:royal_spend/core/services/firestore/firestore_sync_service.dart';
import 'package:royal_spend/core/utils/haptic_helper.dart';
import 'package:royal_spend/data/repositories/settings_repository.dart';

class SettingsProvider extends ChangeNotifier {
  final SettingsRepository _repository;

  SettingsProvider({SettingsRepository? repository})
      : _repository = repository ?? SettingsRepository();

  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  String _currencySymbol = AppConstants.defaultCurrencySymbol;
  String get currencySymbol => _currencySymbol;

  String _currencyCode = AppConstants.defaultCurrencyCode;
  String get currencyCode => _currencyCode;

  String _userName = AppConstants.defaultUserName;
  String get userName => _userName;

  double _monthlyBudget = AppConstants.defaultMonthlyBudget;
  double get monthlyBudget => _monthlyBudget;

  bool _hapticsEnabled = true;
  bool get hapticsEnabled => _hapticsEnabled;

  bool _hasCompletedIntro = false;
  bool get hasCompletedIntro => _hasCompletedIntro;
  bool get hasSeenIntro => _hasCompletedIntro;

  String? _profilePhotoUrl;
  String? get profilePhotoUrl => _profilePhotoUrl;

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  String? _userEmail;
  String? get userEmail => _userEmail;

  /// Returns true if the active user email matches the designated admin email.
  bool get isAdmin => AppConstants.isAdmin(_userEmail);

  Future<void> init() async {
    _themeMode = await _repository.getThemeMode();
    _currencySymbol = await _repository.getCurrencySymbol();
    _currencyCode = await _repository.getCurrencyCode();
    _userName = await _repository.getUserName();
    _monthlyBudget = await _repository.getMonthlyBudget();
    _hapticsEnabled = await _repository.isHapticsEnabled();
    _hasCompletedIntro = await _repository.hasSeenIntro();
    _profilePhotoUrl = await _repository.getUserProfilePhoto();
    _isAuthenticated = await _repository.isAuthenticated();
    _userEmail = await _repository.getUserEmail();
    HapticHelper.enabled = _hapticsEnabled;
    notifyListeners();
  }

  Future<void> setUserEmail(String? email) async {
    _userEmail = email?.trim().toLowerCase();
    await _repository.setUserEmail(email);
    notifyListeners();
  }

  Future<void> setHasCompletedIntro(bool completed) async {
    _hasCompletedIntro = completed;
    await _repository.setHasCompletedIntro(completed);
    notifyListeners();
  }

  Future<void> setHasSeenIntro(bool seen) async {
    await setHasCompletedIntro(seen);
  }

  Future<void> setProfilePhotoUrl(String? photoUrl) async {
    _profilePhotoUrl = photoUrl;
    await _repository.setUserProfilePhoto(photoUrl);
    notifyListeners();
  }

  Future<void> setIsAuthenticated(bool authenticated) async {
    _isAuthenticated = authenticated;
    await _repository.setIsAuthenticated(authenticated);
    notifyListeners();
  }

  Future<void> logout() async {
    _isAuthenticated = false;
    _userEmail = null;
    await _repository.setIsAuthenticated(false);
    await _repository.setUserEmail(null);
    notifyListeners();
  }

  Future<void> resetIntroForTesting() async {
    _hasCompletedIntro = false;
    _isAuthenticated = false;
    _userEmail = null;
    await _repository.setHasCompletedIntro(false);
    await _repository.setIsAuthenticated(false);
    await _repository.setUserEmail(null);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _repository.setThemeMode(mode);
    unawaited(FirestoreSyncService.instance.saveUserPreferences(null, {
      'themeMode': mode == ThemeMode.dark
          ? 'dark'
          : (mode == ThemeMode.light ? 'light' : 'system'),
    }).catchError((_) {}));
    notifyListeners();
  }

  Future<void> setCurrency(String symbol, String code) async {
    _currencySymbol = symbol;
    _currencyCode = code;
    await _repository.setCurrencySymbol(symbol, code);
    unawaited(FirestoreSyncService.instance.saveUserPreferences(null, {
      'currencySymbol': symbol,
      'currencyCode': code,
    }).catchError((_) {}));
    notifyListeners();
  }

  Future<void> setUserName(String name) async {
    _userName = name;
    await _repository.setUserName(name);
    notifyListeners();
  }

  /// Centralized profile name update method.
  /// Saves locally, syncs to Firebase Authentication & Firestore profile,
  /// and instantly notifies listeners across the entire application.
  Future<void> updateUserName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _userName = trimmed;
    await _repository.setUserName(trimmed);
    try {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseAuthGateway().updateProfile(displayName: trimmed);
      }
    } catch (e) {
      debugPrint('Cloud profile sync note: $e');
    }
    notifyListeners();
  }

  Future<void> setMonthlyBudget(double amount) async {
    _monthlyBudget = amount;
    await _repository.setMonthlyBudget(amount);
    unawaited(FirestoreSyncService.instance.saveUserPreferences(null, {
      'monthlyBudget': amount,
    }).catchError((_) {}));
    notifyListeners();
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    _hapticsEnabled = enabled;
    HapticHelper.enabled = enabled;
    await _repository.setHapticsEnabled(enabled);
    unawaited(FirestoreSyncService.instance.saveUserPreferences(null, {
      'hapticsEnabled': enabled,
    }).catchError((_) {}));
    notifyListeners();
  }

  bool isDarkMode(BuildContext context) {
    if (_themeMode == ThemeMode.dark) return true;
    if (_themeMode == ThemeMode.light) return false;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }
}
