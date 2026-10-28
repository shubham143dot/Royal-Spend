import 'package:flutter/cupertino.dart';
import '../../core/constants/default_categories.dart';
import 'expense_category.dart';

enum PaymentMethod {
  upi,
  creditCard,
  debitCard,
  cash,
  bankTransfer,
  other;

  String get displayName {
    switch (this) {
      case PaymentMethod.upi:
        return 'UPI';
      case PaymentMethod.creditCard:
        return 'Credit Card';
      case PaymentMethod.debitCard:
        return 'Debit Card';
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethod.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case PaymentMethod.upi:
        return CupertinoIcons.qrcode;
      case PaymentMethod.creditCard:
      case PaymentMethod.debitCard:
        return CupertinoIcons.creditcard_fill;
      case PaymentMethod.cash:
        return CupertinoIcons.money_dollar;
      case PaymentMethod.bankTransfer:
        return CupertinoIcons.building_2_fill;
      case PaymentMethod.other:
        return CupertinoIcons.square_fill_line_vertical_square;
    }
  }
}

class Expense {
  final String id;
  final String title;
  final double amount;
  final String categoryId;
  final DateTime date;
  final PaymentMethod paymentMethod;
  final String? notes;
  final bool isIncome;
  final String? tripId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.categoryId,
    required this.date,
    this.paymentMethod = PaymentMethod.upi,
    this.notes,
    this.isIncome = false,
    this.tripId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  ExpenseCategory get category => DefaultCategories.getCategoryById(categoryId);

  Expense copyWith({
    String? id,
    String? title,
    double? amount,
    String? categoryId,
    DateTime? date,
    PaymentMethod? paymentMethod,
    String? notes,
    bool? isIncome,
    String? tripId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      date: date ?? this.date,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      isIncome: isIncome ?? this.isIncome,
      tripId: tripId ?? this.tripId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category_id': categoryId,
      'date': date.millisecondsSinceEpoch,
      'payment_method': paymentMethod.name,
      'notes': notes,
      'is_income': isIncome ? 1 : 0,
      'trip_id': tripId,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as String,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['category_id'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      paymentMethod: PaymentMethod.values.firstWhere(
        (p) => p.name == map['payment_method'],
        orElse: () => PaymentMethod.other,
      ),
      notes: map['notes'] as String?,
      isIncome: (map['is_income'] as int) == 1,
      tripId: map['trip_id'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
}
