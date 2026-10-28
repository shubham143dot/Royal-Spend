import 'package:flutter/cupertino.dart';
import '../../core/constants/default_categories.dart';

/// Represents a 1-tap shortcut preset for logging frequent expenses.
class QuickLogPreset {
  final String id;
  final String title;
  final double amount;
  final String categoryId;
  final int? iconCodePoint;
  final int? colorValue;

  const QuickLogPreset({
    required this.id,
    required this.title,
    required this.amount,
    required this.categoryId,
    this.iconCodePoint,
    this.colorValue,
  });

  IconData get icon {
    if (iconCodePoint != null) {
      return IconData(
        iconCodePoint!,
        fontFamily: 'CupertinoIcons',
        fontPackage: 'cupertino_icons',
      );
    }
    return DefaultCategories.getCategoryById(categoryId).icon;
  }

  Color get color {
    if (colorValue != null) {
      return Color(colorValue!);
    }
    return DefaultCategories.getCategoryById(categoryId).color;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'categoryId': categoryId,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
    };
  }

  factory QuickLogPreset.fromJson(Map<String, dynamic> json) {
    return QuickLogPreset(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? 'Expense',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      categoryId: json['categoryId'] as String? ?? 'food',
      iconCodePoint: json['iconCodePoint'] as int?,
      colorValue: json['colorValue'] as int?,
    );
  }

  QuickLogPreset copyWith({
    String? id,
    String? title,
    double? amount,
    String? categoryId,
    int? iconCodePoint,
    int? colorValue,
  }) {
    return QuickLogPreset(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
    );
  }
}
