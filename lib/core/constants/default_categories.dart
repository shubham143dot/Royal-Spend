import 'package:flutter/cupertino.dart';
import '../../data/models/expense_category.dart';

class DefaultCategories {
  static const List<ExpenseCategory> categories = [
    ExpenseCategory(
      id: 'food',
      name: 'Food & Dining',
      icon: CupertinoIcons.cart_fill,
      colorValue: 0xFFF59E0B, // Amber
    ),
    ExpenseCategory(
      id: 'transport',
      name: 'Transportation',
      icon: CupertinoIcons.car_detailed,
      colorValue: 0xFF38BDF8, // Cyan Sky
    ),
    ExpenseCategory(
      id: 'shopping',
      name: 'Shopping',
      icon: CupertinoIcons.bag_fill,
      colorValue: 0xFFF43F5E, // Rose Coral
    ),
    ExpenseCategory(
      id: 'bills',
      name: 'Bills & Utilities',
      icon: CupertinoIcons.bolt_fill,
      colorValue: 0xFF818CF8, // Royal Indigo
    ),
    ExpenseCategory(
      id: 'entertainment',
      name: 'Entertainment',
      icon: CupertinoIcons.play_rectangle_fill,
      colorValue: 0xFFA855F7, // Purple
    ),
    ExpenseCategory(
      id: 'health',
      name: 'Health & Wellness',
      icon: CupertinoIcons.heart_fill,
      colorValue: 0xFFEF4444, // Red
    ),
    ExpenseCategory(
      id: 'education',
      name: 'Education',
      icon: CupertinoIcons.book_fill,
      colorValue: 0xFF10B981, // Emerald
    ),
    ExpenseCategory(
      id: 'travel',
      name: 'Travel & Trips',
      icon: CupertinoIcons.airplane,
      colorValue: 0xFF0EA5E9, // Ocean Blue
    ),
    ExpenseCategory(
      id: 'groceries',
      name: 'Groceries & Supplies',
      icon: CupertinoIcons.cart_badge_plus,
      colorValue: 0xFF10B981, // Emerald Green
    ),
    ExpenseCategory(
      id: 'other',
      name: 'Other Spends',
      icon: CupertinoIcons.ellipsis_circle_fill,
      colorValue: 0xFF64748B, // Slate
    ),
  ];

  static ExpenseCategory getCategoryById(String id) {
    if (id == 'salary') {
      return const ExpenseCategory(
        id: 'salary',
        name: 'General Expense',
        icon: CupertinoIcons.tag_fill,
        colorValue: 0xFF64748B,
      );
    }
    return categories.firstWhere(
      (c) => c.id == id,
      orElse: () => categories.last,
    );
  }
}
