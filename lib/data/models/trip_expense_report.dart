import 'package:intl/intl.dart';
import 'expense.dart';

/// Represents a participant in a trip expense report.
class ReportParticipant {
  final String id;
  final String name;
  final String? email;

  ReportParticipant({
    required this.id,
    required this.name,
    this.email,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        if (email != null && email!.trim().isNotEmpty) 'email': email!.trim(),
      };

  factory ReportParticipant.fromMap(Map<String, dynamic> map) =>
      ReportParticipant(
        id: map['id'] as String,
        name: map['name'] as String,
        email: map['email'] as String?,
      );

  ReportParticipant copyWith({
    String? id,
    String? name,
    String? email,
  }) =>
      ReportParticipant(
        id: id ?? this.id,
        name: name ?? this.name,
        email: email ?? this.email,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportParticipant &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// A comprehensive financial report model for a trip expense split.
class TripExpenseReport {
  final String tripId;
  final String tripTitle;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime generatedAt;
  final List<Expense> expenses;
  final List<ReportParticipant> participants;
  final ReportParticipant payer;
  final String currency;

  TripExpenseReport({
    required this.tripId,
    required this.tripTitle,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.generatedAt,
    required this.expenses,
    required this.participants,
    required this.payer,
    this.currency = 'INR',
  });

  /// Total sum of all eligible expenses associated with the trip.
  double get totalExpenses =>
      expenses.fold(0.0, (sum, expense) => sum + expense.amount);

  /// Total number of transactions included in the report.
  int get totalTransactions => expenses.length;

  /// Total number of participants splitting the expense.
  int get totalParticipants => participants.length;

  /// Equal individual share per person.
  double get individualShare =>
      totalParticipants > 0 ? (totalExpenses / totalParticipants) : 0.0;

  /// Reconciles individual shares down to the cent/paisa so that
  /// sum(reconciledShares.values) == totalExpenses exactly, avoiding any rounding discrepancy.
  Map<String, double> get reconciledShares {
    if (totalParticipants == 0) return {};
    final totalCents = (totalExpenses * 100).round();
    final baseCents = totalCents ~/ totalParticipants;
    final remainderCents = totalCents - (baseCents * totalParticipants);

    final Map<String, double> result = {};
    for (int i = 0; i < participants.length; i++) {
      final p = participants[i];
      final cents = baseCents + (i < remainderCents ? 1 : 0);
      result[p.id] = cents / 100.0;
    }
    return result;
  }

  /// Formatted date range for the trip.
  String get dateRangeFormatted {
    final startFmt = DateFormat('dd MMM yyyy').format(startDate);
    final endFmt = DateFormat('dd MMM yyyy').format(endDate);
    return '$startFmt - $endFmt';
  }

  /// Formatted generation timestamp.
  String get generatedAtFormatted =>
      DateFormat('dd MMM yyyy, hh:mm a').format(generatedAt);
}
