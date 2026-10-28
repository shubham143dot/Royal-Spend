import 'package:royal_spend/core/utils/currency_formatter.dart';
import 'package:royal_spend/core/utils/date_formatter.dart';
import 'package:royal_spend/data/models/expense.dart';
import 'parsed_transaction.dart';

/// Service that analyzes a parsed transaction against existing expenses to detect
/// potential accidental duplicate entries without discarding legitimate repeat transactions.
class DuplicateDetector {
  /// Evaluates [candidate] against [existingExpenses] and returns an updated [ParsedTransaction]
  /// with duplicate flags and human-friendly explanation if a match is found.
  static ParsedTransaction checkDuplicate(
    ParsedTransaction candidate,
    List<Expense> existingExpenses,
  ) {
    if (candidate.amount == null || candidate.amount! <= 0) {
      return candidate;
    }

    final candidateAmount = candidate.amount!;
    final candidateDate = candidate.date;
    final candidateRef = candidate.referenceId?.trim().toLowerCase();
    final candidateMerchant = candidate.merchant?.trim().toLowerCase();

    Expense? matchedExpense;
    String? reason;

    // Check 1: Exact Reference / UTR Number match in notes or title
    if (candidateRef != null && candidateRef.isNotEmpty) {
      for (final exp in existingExpenses) {
        if (exp.isIncome != candidate.isIncome) {
          continue;
        }
        final notesLower = exp.notes?.toLowerCase() ?? '';
        final titleLower = exp.title.toLowerCase();

        if (notesLower.contains(candidateRef) ||
            titleLower.contains(candidateRef)) {
          matchedExpense = exp;
          reason =
              'A transaction with the exact same Reference ID ($candidateRef) is already recorded.';
          break;
        }
      }
    }

    // Check 2: Same Amount + Same Date + Matching or Similar Merchant
    if (matchedExpense == null && candidateDate != null) {
      for (final exp in existingExpenses) {
        if (exp.isIncome != candidate.isIncome) {
          continue;
        }
        // Amount match within 0.01
        final amountDiff = (exp.amount - candidateAmount).abs();
        if (amountDiff > 0.01) continue;

        // Date match (same calendar day)
        final isSameDay =
            exp.date.year == candidateDate.year &&
            exp.date.month == candidateDate.month &&
            exp.date.day == candidateDate.day;

        if (!isSameDay) continue;

        // Merchant / Title check
        final existingTitleLower = exp.title.toLowerCase();

        bool isMerchantMatch = false;
        if (candidateMerchant != null && candidateMerchant.isNotEmpty) {
          if (existingTitleLower.contains(candidateMerchant) ||
              candidateMerchant.contains(existingTitleLower)) {
            isMerchantMatch = true;
          }
        }

        // If time is also close (within 2 hours) on the same day with same amount
        final minuteDiff = exp.date.difference(candidateDate).inMinutes.abs();
        final isVeryCloseInTime = minuteDiff < 120;

        if (isMerchantMatch || isVeryCloseInTime) {
          matchedExpense = exp;
          final formattedAmount = CurrencyFormatter.format(exp.amount);
          final formattedDate = DateFormatter.formatDate(exp.date);
          reason =
              'Matching transaction found: "$formattedAmount for ${exp.title}" on $formattedDate.';
          break;
        }
      }
    }

    if (matchedExpense != null) {
      return candidate.copyWith(
        isDuplicate: true,
        duplicateExpense: matchedExpense,
        duplicateReason: reason,
      );
    }

    return candidate.copyWith(
      isDuplicate: false,
      duplicateExpense: null,
      duplicateReason: null,
    );
  }
}
