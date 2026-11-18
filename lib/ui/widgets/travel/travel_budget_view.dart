import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../providers/expense_provider.dart';
import '../../../providers/travel_provider.dart';
import '../glass_card.dart';
import '../liquid_pop.dart';
import 'bill_split_dialog.dart';
import 'quick_travel_expense_sheet.dart';
import 'set_travel_budget_sheet.dart';

class TravelBudgetView extends StatelessWidget {
  final bool isDark;

  const TravelBudgetView({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final travelProvider = context.watch<TravelProvider>();
    final expenseProvider = context.watch<ExpenseProvider>();
    final trip = travelProvider.selectedTrip;

    if (trip == null) {
      return const SizedBox.shrink();
    }

    // Dynamic travel expenses linked to this trip from the global ExpenseProvider
    final liveTripExpenses = expenseProvider.allExpenses
        .where((e) => e.tripId == trip.id && !e.isIncome)
        .toList();
    final effectiveExpenses = liveTripExpenses.isNotEmpty
        ? liveTripExpenses
        : travelProvider.currentLinkedExpenses.where((e) => !e.isIncome).toList();

    final double totalBudget = trip.budget;
    final double actualSpent = effectiveExpenses.fold(
        0.0, (sum, exp) => sum + exp.amount);
    final double remainingBudget = totalBudget - actualSpent;
    final double utilizationPct =
        totalBudget > 0 ? (actualSpent / totalBudget) * 100 : 0.0;
    final double progress = totalBudget > 0 ? (actualSpent / totalBudget) : 0.0;

    final estimated = travelProvider.estimatedCost;
    final settlements = travelProvider.settlements;
    final splits = travelProvider.currentSplits;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Dedicated Travel Budget & Spending Card
          GlassCard(
            isDark: isDark,
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with "Set / Edit Budget" Action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: (isDark
                                    ? AppColors.appleBlue
                                    : AppColors.royalIndigo)
                                .withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            CupertinoIcons.airplane,
                            size: 15,
                            color: isDark
                                ? AppColors.appleBlue
                                : AppColors.royalIndigo,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Travel Budget',
                              style: AppTextStyles.titleMedium.copyWith(
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              trip.title,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Set / Edit Budget Button
                    LiquidPop(
                      onTap: () {
                        HapticHelper.selectionClick();
                        SetTravelBudgetSheet.show(
                          context,
                          trip: trip,
                          isDark: isDark,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: (isDark
                                  ? AppColors.appleBlue
                                  : AppColors.royalIndigo)
                              .withValues(alpha: isDark ? 0.22 : 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (isDark
                                    ? AppColors.appleBlue
                                    : AppColors.royalIndigo)
                                .withValues(alpha: 0.35),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              totalBudget > 0
                                  ? CupertinoIcons.pencil
                                  : CupertinoIcons.plus,
                              size: 12,
                              color: isDark
                                  ? AppColors.appleBlue
                                  : AppColors.royalIndigo,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              totalBudget > 0 ? 'Edit Budget' : 'Set Budget',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.appleBlue
                                    : AppColors.royalIndigo,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Metrics Grid: 4 Core Metrics
                // Total Travel Budget, Total Amount Spent, Remaining Budget, Budget Utilization %
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _BudgetColumn(
                      label: 'Travel Budget',
                      value: totalBudget > 0
                          ? CurrencyFormatter.format(totalBudget)
                          : 'Not Set',
                      isDark: isDark,
                    ),
                    _BudgetColumn(
                      label: 'Total Spent',
                      value: CurrencyFormatter.format(actualSpent),
                      valueColor: progress >= 1.0
                          ? AppColors.roseExpense
                          : (isDark
                              ? AppColors.appleBlue
                              : AppColors.royalIndigo),
                      isDark: isDark,
                    ),
                    _BudgetColumn(
                      label: 'Remaining',
                      value: totalBudget > 0
                          ? CurrencyFormatter.format(remainingBudget)
                          : '--',
                      valueColor: totalBudget <= 0
                          ? null
                          : (remainingBudget < 0
                              ? AppColors.roseExpense
                              : AppColors.appleGreen),
                      isDark: isDark,
                    ),
                    _BudgetColumn(
                      label: 'Utilization',
                      value: totalBudget > 0
                          ? '${utilizationPct.toStringAsFixed(1)}%'
                          : '0.0%',
                      valueColor: progress >= 1.0
                          ? AppColors.roseExpense
                          : (progress >= 0.8
                              ? AppColors.amberWarning
                              : AppColors.appleGreen),
                      isDark: isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Visual Budget Progress Indicator
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: totalBudget > 0 ? progress.clamp(0.0, 1.0) : 0.0,
                    minHeight: 8,
                    backgroundColor: isDark
                        ? AppColors.darkSurface
                        : Colors.black.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= 1.0
                          ? AppColors.roseExpense
                          : (progress >= 0.8
                              ? AppColors.amberWarning
                              : AppColors.appleGreen),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Planned Itinerary Estimates vs Actual
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Planned Estimates: ${CurrencyFormatter.format(estimated)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      totalBudget > 0
                          ? '${utilizationPct.toStringAsFixed(1)}% utilized'
                          : 'No limit set',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: progress >= 1.0
                            ? AppColors.roseExpense
                            : (progress >= 0.8
                                ? AppColors.amberWarning
                                : (isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2. Appropriate Budget Warning Banners
          if (totalBudget > 0 && progress >= 1.0)
            Container(
              margin: const EdgeInsets.only(bottom: 12.0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.roseExpense.withValues(alpha: isDark ? 0.22 : 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.roseExpense.withValues(alpha: 0.45),
                  width: 0.9,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.exclamationmark_triangle_fill,
                    size: 18,
                    color: AppColors.roseExpense,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Travel Budget Exceeded',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.roseExpense,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'You have spent ${CurrencyFormatter.format(actualSpent - totalBudget)} over your travel budget of ${CurrencyFormatter.format(totalBudget)} (${utilizationPct.toStringAsFixed(1)}% utilized).',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else if (totalBudget > 0 && progress >= 0.8)
            Container(
              margin: const EdgeInsets.only(bottom: 12.0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.amberWarning.withValues(alpha: isDark ? 0.22 : 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.amberWarning.withValues(alpha: 0.45),
                  width: 0.9,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.exclamationmark_circle_fill,
                    size: 18,
                    color: AppColors.amberWarning,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Approaching Budget Limit',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.amberWarning,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'You have utilized ${utilizationPct.toStringAsFixed(1)}% of your travel budget. ${CurrencyFormatter.format(remainingBudget)} remaining.',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else if (totalBudget <= 0)
            Container(
              margin: const EdgeInsets.only(bottom: 12.0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
                    .withValues(alpha: isDark ? 0.14 : 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
                      .withValues(alpha: 0.25),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.info_circle_fill,
                    size: 18,
                    color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No travel budget set for this trip. Tap "Set Budget" to define spending limits and track your remaining balance.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // 2. Action Buttons (Record Expense, Split Bill)
          Row(
            children: [
              Expanded(
                child: LiquidPop(
                  onTap: () async {
                    HapticHelper.mediumImpact();
                    await QuickTravelExpenseSheet.show(
                      context,
                      initialTripId: trip.id,
                    );
                    if (context.mounted) {
                      await travelProvider.refreshLinkedExpenses();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: AppColors.royalGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.royalIndigo.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.add_circled,
                            size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'Record Expense',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LiquidPop(
                  onTap: () {
                    BillSplitDialog.show(
                      context,
                      tripId: trip.id,
                      isDark: isDark,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurface
                          : Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: (isDark
                                ? AppColors.applePurple
                                : AppColors.violetAccent)
                            .withValues(alpha: 0.4),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.arrow_right_arrow_left,
                          size: 15,
                          color: isDark
                              ? AppColors.applePurple
                              : AppColors.violetAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Split Trip Expense',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.applePurple
                                : AppColors.violetAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 3. Bill Settlement Section
          if (settlements.isNotEmpty || splits.isNotEmpty) ...[
            Text(
              'Group Bill Splitting & Settlements',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 10),

            // Net Settlements Card
            if (settlements.isNotEmpty)
              GlassCard(
                isDark: isDark,
                padding: const EdgeInsets.all(14.0),
                borderRadius: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.checkmark_seal_fill,
                          size: 14,
                          color: AppColors.appleGreen,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Suggested Settlements to Square Up',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...settlements.map((s) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          children: [
                            Text(
                              s.fromPerson,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Text(' owes '),
                            Text(
                              s.toPerson,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.appleBlue
                                    : AppColors.royalIndigo,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              CurrencyFormatter.format(s.amount),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.appleGreen,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            const SizedBox(height: 12),

            // List of Splits
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: splits.length,
              itemBuilder: (context, index) {
                final split = splits[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: GlassCard(
                    isDark: isDark,
                    padding: const EdgeInsets.all(12.0),
                    borderRadius: 14,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: (isDark
                                    ? AppColors.applePurple
                                    : AppColors.violetAccent)
                                .withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            CupertinoIcons.person_2_fill,
                            size: 14,
                            color: isDark
                                ? AppColors.applePurple
                                : AppColors.violetAccent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                split.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                ),
                              ),
                              Text(
                                'Paid by ${split.paidBy} • Split among ${split.shares.length} people',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(split.totalAmount),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            travelProvider.deleteSplit(split.id);
                          },
                          child: Icon(
                            CupertinoIcons.trash,
                            size: 14,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],

          // 4. Linked Expenses List
          Text(
            'Recorded Expenses (${effectiveExpenses.length})',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 10),

          if (effectiveExpenses.isEmpty)
            GlassCard(
              isDark: isDark,
              padding: const EdgeInsets.all(20.0),
              child: Center(
                child: Text(
                  'No expenses recorded for this trip yet.\nTap "Record Expense" to link bills and transactions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: effectiveExpenses.length,
              itemBuilder: (context, index) {
                final exp = effectiveExpenses[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: GlassCard(
                    isDark: isDark,
                    padding: const EdgeInsets.all(12.0),
                    borderRadius: 14,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: exp.category.color.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            exp.category.icon,
                            size: 15,
                            color: exp.category.color,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                exp.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                ),
                              ),
                              Text(
                                '${exp.category.name} • ${exp.paymentMethod.displayName}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(exp.amount),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _BudgetColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isDark;

  const _BudgetColumn({
    required this.label,
    required this.value,
    this.valueColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: valueColor ??
                (isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary),
          ),
        ),
      ],
    );
  }
}
