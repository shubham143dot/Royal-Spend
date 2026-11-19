import 'package:flutter/cupertino.dart';

class ExpenseCategory {
  final String id;
  final String name;
  final IconData icon;
  final int colorValue; // ARGB hex value
  final bool isDefault;

  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorValue,
    this.isDefault = true,
  });

  Color get color => Color(colorValue);

  static final Map<int, IconData> _knownIcons = {
    CupertinoIcons.cart_fill.codePoint: CupertinoIcons.cart_fill,
    CupertinoIcons.car_detailed.codePoint: CupertinoIcons.car_detailed,
    CupertinoIcons.bag_fill.codePoint: CupertinoIcons.bag_fill,
    CupertinoIcons.bolt_fill.codePoint: CupertinoIcons.bolt_fill,
    CupertinoIcons.play_rectangle_fill.codePoint:
        CupertinoIcons.play_rectangle_fill,
    CupertinoIcons.heart_fill.codePoint: CupertinoIcons.heart_fill,
    CupertinoIcons.book_fill.codePoint: CupertinoIcons.book_fill,
    CupertinoIcons.airplane.codePoint: CupertinoIcons.airplane,
    CupertinoIcons.cart_badge_plus.codePoint: CupertinoIcons.cart_badge_plus,
    CupertinoIcons.ellipsis_circle_fill.codePoint:
        CupertinoIcons.ellipsis_circle_fill,
    CupertinoIcons.tag_fill.codePoint: CupertinoIcons.tag_fill,
    CupertinoIcons.flame_fill.codePoint: CupertinoIcons.flame_fill,
    CupertinoIcons.sparkles.codePoint: CupertinoIcons.sparkles,
    CupertinoIcons.creditcard_fill.codePoint: CupertinoIcons.creditcard_fill,
  };

  /// Resolves an integer icon codePoint to a constant IconData instance,
  /// preserving 100% constant IconData tree-shaking for release builds.
  static IconData resolveIcon(int? codePoint,
      [IconData fallback = CupertinoIcons.tag_fill]) {
    if (codePoint == null) return fallback;
    return _knownIcons[codePoint] ?? fallback;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon_code': icon.codePoint,
      'color_value': colorValue,
      'is_default': isDefault ? 1 : 0,
    };
  }

  factory ExpenseCategory.fromMap(Map<String, dynamic> map) {
    return ExpenseCategory(
      id: map['id'] as String,
      name: map['name'] as String,
      icon: resolveIcon(map['icon_code'] as int?),
      colorValue: map['color_value'] as int,
      isDefault: (map['is_default'] as int) == 1,
    );
  }
}
