import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../providers/travel_provider.dart';
import '../glass_card.dart';
import '../liquid_pop.dart';
import 'bill_split_dialog.dart';
import 'quick_travel_expense_sheet.dart';

class TravelBudgetView extends StatelessWidget {
  final bool isDark;

  const TravelBudgetView({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final travelProvider = context.watch<TravelProvider>();
    final trip = travelProvider.selectedTrip;

    if (trip == null) {
      return const SizedBox.shrink();
    }

    final totalBudget = trip.budget;
    final estimated = travelProvider.estimatedCost;
    final actual = travelProvider.actualRecordedSpending;
    final remaining = travelProvider.remainingBudget;
    final progress = travelProvider.budgetProgress;
    final linkedExpenses = travelProvider.currentLinkedExpenses;
    final settlements = travelProvider.settlements;
    final splits = travelProvider.currentSplits;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Budget Overview Card
          GlassCard(
            isDark: isDark,
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Trip Budget & Spending',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    // Warning badge if over 80% or 100%
                    if (progress >= 1.0 && totalBudget > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.roseExpense.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Exceeded',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.roseExpense,
                          ),
                        ),
                      )
                    else if (progress >= 0.8 && totalBudget > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.amberWarning.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '80% Reached',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.amberWarning,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Metrics Row: Total Budget, Actual Spent, Remaining
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _BudgetColumn(
                      label: 'Total Budget',
                      value: CurrencyFormatter.format(totalBudget),
                      isDark: isDark,
                    ),
                    _BudgetColumn(
                      label: 'Actual Spent',
                      value: CurrencyFormatter.format(actual),
                      valueColor: progress >= 1.0
                          ? AppColors.roseExpense
                          : (isDark
                              ? AppColors.appleBlue
                              : AppColors.royalIndigo),
                      isDark: isDark,
                    ),
                    _BudgetColumn(
                      label: 'Remaining',
                      value: CurrencyFormatter.format(remaining),
                      valueColor: remaining < 0
                          ? AppColors.roseExpense
                          : AppColors.appleGreen,
                      isDark: isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Progress Bar
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

                // Estimated vs Actual comparison
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Planned Itinerary Estimates: ${CurrencyFormatter.format(estimated)}',
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
                      '${(progress * 100).toInt()}% spent',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
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
                          'Split a Bill',
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
            'Recorded Expenses (${linkedExpenses.length})',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 10),

          if (linkedExpenses.isEmpty)
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
              itemCount: linkedExpenses.length,
              itemBuilder: (context, index) {
                final exp = linkedExpenses[index];
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
