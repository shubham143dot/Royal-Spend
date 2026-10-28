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
      icon: IconData(
        map['icon_code'] as int,
        fontFamily: CupertinoIcons.iconFont,
        fontPackage: CupertinoIcons.iconFontPackage,
      ),
      colorValue: map['color_value'] as int,
      isDefault: (map['is_default'] as int) == 1,
    );
  }
}
