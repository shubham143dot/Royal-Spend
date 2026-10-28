import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:royal_spend/data/models/quick_log_preset.dart';
import 'package:royal_spend/data/repositories/quick_log_repository.dart';
import 'package:royal_spend/providers/quick_log_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('QuickLogPreset Model Tests', () {
    test('Correct serialization and deserialization', () {
      final preset = QuickLogPreset(
        id: 'preset_1',
        title: 'Morning Chai',
        amount: 25.0,
        categoryId: 'food',
        iconCodePoint: CupertinoIcons.flame_fill.codePoint,
        colorValue: 0xFFF59E0B,
      );

      final map = preset.toJson();
      final restored = QuickLogPreset.fromJson(map);

      expect(restored.id, 'preset_1');
      expect(restored.title, 'Morning Chai');
      expect(restored.amount, 25.0);
      expect(restored.categoryId, 'food');
      expect(restored.iconCodePoint, CupertinoIcons.flame_fill.codePoint);
      expect(restored.colorValue, 0xFFF59E0B);
    });

    test('Falls back to category defaults when custom icon and color are null', () {
      final preset = QuickLogPreset(
        id: 'preset_2',
        title: 'Metro',
        amount: 40.0,
        categoryId: 'transport',
      );

      expect(preset.icon, isNotNull);
      expect(preset.color, isNotNull);
    });
  });

  group('QuickLogRepository Tests', () {
    test('Returns empty list initially (old hardcoded items removed)', () async {
      final repo = QuickLogRepository();
      final presets = await repo.getPresets();
      expect(presets, isEmpty);
    });

    test('Saves and loads presets with persistence', () async {
      final repo = QuickLogRepository();
      final preset = QuickLogPreset(
        id: 'p1',
        title: 'Lunch',
        amount: 150.0,
        categoryId: 'food',
      );

      await repo.savePresets([preset]);
      final loaded = await repo.getPresets();
      expect(loaded.length, 1);
      expect(loaded.first.title, 'Lunch');
      expect(loaded.first.amount, 150.0);
    });
  });

  group('QuickLogProvider Tests', () {
    test('Initializes with empty list, adds, updates, and deletes presets', () async {
      final provider = QuickLogProvider();
      await provider.init();
      expect(provider.presets, isEmpty);

      final p1 = QuickLogPreset(
        id: 'p1',
        title: 'Chai',
        amount: 15.0,
        categoryId: 'food',
      );

      await provider.addPreset(p1);
      expect(provider.presets.length, 1);
      expect(provider.presets.first.title, 'Chai');

      final updatedP1 = p1.copyWith(amount: 20.0, title: 'Special Chai');
      await provider.updatePreset(updatedP1);
      expect(provider.presets.first.amount, 20.0);
      expect(provider.presets.first.title, 'Special Chai');

      await provider.deletePreset('p1');
      expect(provider.presets, isEmpty);
    });
  });
}
