import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String format(
    double amount, {
    String symbol = '₹',
    bool showDecimals = true,
    bool compact = false,
  }) {
    if (compact && amount.abs() >= 1000000) {
      final millions = amount / 1000000;
      return '$symbol${millions.toStringAsFixed(1)}M';
    } else if (compact && amount.abs() >= 10000) {
      final thousands = amount / 1000;
      return '$symbol${thousands.toStringAsFixed(1)}k';
    }

    final hasDecimals = amount.truncateToDouble() != amount;
    final formatter = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: (showDecimals && hasDecimals) ? 2 : 0,
      customPattern: '$symbol#,##0${(showDecimals && hasDecimals) ? '.00' : ''}',
    );

    return formatter.format(amount);
  }

  static String formatSigned(
    double amount, {
    String symbol = '₹',
    bool isIncome = false,
  }) {
    final prefix = isIncome ? '+' : '-';
    return '$prefix${format(amount.abs(), symbol: symbol)}';
  }
}
