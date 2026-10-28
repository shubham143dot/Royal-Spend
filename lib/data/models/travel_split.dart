import 'dart:convert';

class SplitSettlement {
  final String fromPerson;
  final String toPerson;
  final double amount;

  const SplitSettlement({
    required this.fromPerson,
    required this.toPerson,
    required this.amount,
  });
}

class TravelSplit {
  final String id;
  final String tripId;
  final String? expenseId;
  final String title;
  final double totalAmount;
  final String paidBy;
  final String splitType; // 'equal', 'exact'
  final Map<String, double> shares;
  final DateTime createdAt;

  TravelSplit({
    required this.id,
    required this.tripId,
    this.expenseId,
    required this.title,
    required this.totalAmount,
    required this.paidBy,
    this.splitType = 'equal',
    required this.shares,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  TravelSplit copyWith({
    String? id,
    String? tripId,
    String? expenseId,
    String? title,
    double? totalAmount,
    String? paidBy,
    String? splitType,
    Map<String, double>? shares,
    DateTime? createdAt,
  }) {
    return TravelSplit(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      expenseId: expenseId ?? this.expenseId,
      title: title ?? this.title,
      totalAmount: totalAmount ?? this.totalAmount,
      paidBy: paidBy ?? this.paidBy,
      splitType: splitType ?? this.splitType,
      shares: shares ?? this.shares,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trip_id': tripId,
      'expense_id': expenseId,
      'title': title,
      'total_amount': totalAmount,
      'paid_by': paidBy,
      'split_type': splitType,
      'shares_json': jsonEncode(shares),
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory TravelSplit.fromMap(Map<String, dynamic> map) {
    Map<String, double> parseShares(dynamic raw) {
      if (raw == null) return {};
      try {
        final decoded = jsonDecode(raw.toString()) as Map<String, dynamic>;
        return decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
      } catch (_) {
        return {};
      }
    }

    return TravelSplit(
      id: map['id'] as String,
      tripId: map['trip_id'] as String,
      expenseId: map['expense_id'] as String?,
      title: map['title'] as String,
      totalAmount: (map['total_amount'] as num).toDouble(),
      paidBy: map['paid_by'] as String,
      splitType: (map['split_type'] as String?) ?? 'equal',
      shares: parseShares(map['shares_json']),
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  /// Calculates simplified debt settlements among a list of TravelSplits.
  static List<SplitSettlement> calculateNetSettlements(
      List<TravelSplit> splits) {
    // 1. Calculate net balances: positive means they are owed money; negative means they owe money.
    final Map<String, double> balances = {};

    for (final s in splits) {
      // Payer gets credit (+)
      balances[s.paidBy] = (balances[s.paidBy] ?? 0.0) + s.totalAmount;
      // Each participant owes their share (-)
      s.shares.forEach((person, share) {
        balances[person] = (balances[person] ?? 0.0) - share;
      });
    }

    // 2. Separate into debtors (owe money) and creditors (owed money)
    final List<MapEntry<String, double>> debtors = [];
    final List<MapEntry<String, double>> creditors = [];

    balances.forEach((person, balance) {
      // Round to 2 decimal places to avoid floating point precision artifacts
      final rounded = double.parse(balance.toStringAsFixed(2));
      if (rounded < -0.01) {
        debtors.add(MapEntry(person, -rounded));
      } else if (rounded > 0.01) {
        creditors.add(MapEntry(person, rounded));
      }
    });

    final List<SplitSettlement> settlements = [];
    int dIndex = 0;
    int cIndex = 0;

    while (dIndex < debtors.length && cIndex < creditors.length) {
      final debtor = debtors[dIndex];
      final creditor = creditors[cIndex];

      final amount = debtor.value < creditor.value ? debtor.value : creditor.value;
      if (amount > 0.01) {
        settlements.add(SplitSettlement(
          fromPerson: debtor.key,
          toPerson: creditor.key,
          amount: double.parse(amount.toStringAsFixed(2)),
        ));
      }

      debtors[dIndex] = MapEntry(debtor.key, debtor.value - amount);
      creditors[cIndex] = MapEntry(creditor.key, creditor.value - amount);

      if (debtors[dIndex].value <= 0.01) dIndex++;
      if (creditors[cIndex].value <= 0.01) cIndex++;
    }

    return settlements;
  }
}
