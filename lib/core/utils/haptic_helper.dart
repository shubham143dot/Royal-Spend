import 'package:flutter/services.dart';

class HapticHelper {
  static bool enabled = true;

  static void lightImpact() {
    if (enabled) {
      HapticFeedback.lightImpact();
    }
  }

  static void mediumImpact() {
    if (enabled) {
      HapticFeedback.mediumImpact();
    }
  }

  static void selectionClick() {
    if (enabled) {
      HapticFeedback.selectionClick();
    }
  }

  static void heavyImpact() {
    if (enabled) {
      HapticFeedback.heavyImpact();
    }
  }

  static void success() {
    if (enabled) {
      HapticFeedback.heavyImpact();
    }
  }
}
