import 'package:flutter/material.dart';
import 'package:royal_spend/core/constants/app_constants.dart';
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

  Future<void> init() async {
    _themeMode = await _repository.getThemeMode();
    _currencySymbol = await _repository.getCurrencySymbol();
    _currencyCode = await _repository.getCurrencyCode();
    _userName = await _repository.getUserName();
    _monthlyBudget = await _repository.getMonthlyBudget();
    _hapticsEnabled = await _repository.isHapticsEnabled();
    HapticHelper.enabled = _hapticsEnabled;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _repository.setThemeMode(mode);
    notifyListeners();
  }

  Future<void> setCurrency(String symbol, String code) async {
    _currencySymbol = symbol;
    _currencyCode = code;
    await _repository.setCurrencySymbol(symbol, code);
    notifyListeners();
  }

  Future<void> setUserName(String name) async {
    _userName = name;
    await _repository.setUserName(name);
    notifyListeners();
  }

  Future<void> setMonthlyBudget(double amount) async {
    _monthlyBudget = amount;
    await _repository.setMonthlyBudget(amount);
    notifyListeners();
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    _hapticsEnabled = enabled;
    HapticHelper.enabled = enabled;
    await _repository.setHapticsEnabled(enabled);
    notifyListeners();
  }

  bool isDarkMode(BuildContext context) {
    if (_themeMode == ThemeMode.dark) return true;
    if (_themeMode == ThemeMode.light) return false;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }
}
