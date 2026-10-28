import 'package:flutter/foundation.dart';
import '../data/models/quick_log_preset.dart';
import '../data/repositories/quick_log_repository.dart';

class QuickLogProvider extends ChangeNotifier {
  final IQuickLogRepository _repository;

  QuickLogProvider({IQuickLogRepository? repository})
      : _repository = repository ?? QuickLogRepository();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  List<QuickLogPreset> _presets = [];
  List<QuickLogPreset> get presets => List.unmodifiable(_presets);
  bool get hasPresets => _presets.isNotEmpty;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    _presets = await _repository.getPresets();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    _presets = await _repository.getPresets();
    notifyListeners();
  }

  Future<void> addPreset(QuickLogPreset preset) async {
    _presets.add(preset);
    notifyListeners();
    await _repository.savePresets(_presets);
  }

  Future<void> updatePreset(QuickLogPreset preset) async {
    final index = _presets.indexWhere((p) => p.id == preset.id);
    if (index != -1) {
      _presets[index] = preset;
      notifyListeners();
      await _repository.savePresets(_presets);
    }
  }

  Future<void> deletePreset(String id) async {
    _presets.removeWhere((p) => p.id == id);
    notifyListeners();
    await _repository.savePresets(_presets);
  }

  Future<void> reorderPresets(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _presets.removeAt(oldIndex);
    _presets.insert(newIndex, item);
    notifyListeners();
    await _repository.savePresets(_presets);
  }
}
