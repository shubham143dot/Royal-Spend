import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quick_log_preset.dart';

abstract class IQuickLogRepository {
  Future<List<QuickLogPreset>> getPresets();
  Future<void> savePresets(List<QuickLogPreset> presets);
  Future<void> addPreset(QuickLogPreset preset);
  Future<void> updatePreset(QuickLogPreset preset);
  Future<void> deletePreset(String id);
}

class QuickLogRepository implements IQuickLogRepository {
  static const String _keyQuickLogPresets = 'royal_spend_quick_log_presets_v2';

  @override
  Future<List<QuickLogPreset>> getPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString(_keyQuickLogPresets);
    if (rawJson == null || rawJson.trim().isEmpty) {
      // Empty by default: all hardcoded old quick logs removed
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(rawJson) as List<dynamic>;
      return decoded
          .map((item) => QuickLogPreset.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> savePresets(List<QuickLogPreset> presets) async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = jsonEncode(presets.map((p) => p.toJson()).toList());
    await prefs.setString(_keyQuickLogPresets, rawJson);
  }

  @override
  Future<void> addPreset(QuickLogPreset preset) async {
    final current = await getPresets();
    current.add(preset);
    await savePresets(current);
  }

  @override
  Future<void> updatePreset(QuickLogPreset preset) async {
    final current = await getPresets();
    final index = current.indexWhere((p) => p.id == preset.id);
    if (index != -1) {
      current[index] = preset;
      await savePresets(current);
    }
  }

  @override
  Future<void> deletePreset(String id) async {
    final current = await getPresets();
    current.removeWhere((p) => p.id == id);
    await savePresets(current);
  }
}
