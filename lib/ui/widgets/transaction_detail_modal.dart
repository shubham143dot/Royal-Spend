import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/haptic_helper.dart';
import '../../data/models/expense.dart';
import '../../providers/expense_provider.dart';
import '../../providers/settings_provider.dart';
import '../screens/add_edit_expense_sheet.dart';
import 'glass_button.dart';

class TransactionDetailModal extends StatelessWidget {
  final Expense expense;

  const TransactionDetailModal({
    super.key,
    required this.expense,
  });

  static Future<void> show(BuildContext context, Expense expense) {
    HapticHelper.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      sheetAnimationStyle: AnimationStyle(
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
        duration: const Duration(milliseconds: 320),
      ),
      builder: (ctx) => TransactionDetailModal(expense: expense),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDark = settings.isDarkMode(context);
    final currency = settings.currencySymbol;
    final category = expense.category;

    final amountColor = expense.isIncome
        ? (isDark ? AppColors.appleGreen : const Color(0xFF16A34A))
        : (isDark ? AppColors.appleRed : const Color(0xFFDC2626));

    final sheetContent = Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 22,
        right: 22,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : const Color(0xFFFFFFFF),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: isDark ? const Color(0x2BFFFFFF) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.16),
            blurRadius: 40,
            spreadRadius: 2,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Top Notch Handle
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: 22),

            // Category Icon Badge (Apple Squircle)
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: category.color,
                boxShadow: [
                  BoxShadow(
                    color: category.color.withValues(alpha: isDark ? 0.35 : 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  category.icon,
                  size: 32,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Amount Display
            Text(
              CurrencyFormatter.formatSigned(
                expense.amount,
                symbol: currency,
                isIncome: expense.isIncome,
              ),
              style: AppTextStyles.displayMedium.copyWith(
                color: amountColor,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),

            // Category Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: isDark ? AppColors.darkSurface : category.color.withValues(alpha: 0.12),
                border: Border.all(
                  color: isDark ? const Color(0x1FFFFFFF) : category.color.withValues(alpha: 0.30),
                  width: 0.8,
                ),
              ),
              child: Text(
                category.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : category.color,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Transaction Info Table Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
                border: Border.all(
                  color: isDark ? const Color(0x22FFFFFF) : const Color(0xFFE2E8F0),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? const Color(0x40000000)
                        : const Color(0xFF64748B).withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    label: 'Title',
                    value: expense.title,
                    isDark: isDark,
                  ),
                  _buildRowDivider(isDark),
                  _buildDetailRow(
                    label: 'Date & Time',
                    value: '${DateFormatter.formatFull(expense.date)} at ${DateFormatter.formatTime(expense.date)}',
                    isDark: isDark,
                  ),
                  _buildRowDivider(isDark),
                  _buildDetailRow(
                    label: 'Payment Method',
                    value: expense.paymentMethod.displayName,
                    icon: expense.paymentMethod.icon,
                    isDark: isDark,
                  ),
                  if (expense.notes != null && expense.notes!.isNotEmpty) ...[
                    _buildRowDivider(isDark),
                    _buildDetailRow(
                      label: 'Notes',
                      value: expense.notes!,
                      isDark: isDark,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons: Edit and Delete
            Row(
              children: [
                Expanded(
                  child: GlassButton(
                    label: 'Edit',
                    icon: CupertinoIcons.pencil,
                    variant: GlassButtonVariant.secondary,
                    isDark: isDark,
                    onPressed: () {
                      Navigator.pop(context);
                      AddEditExpenseSheet.show(context, expenseToEdit: expense);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassButton(
                    label: 'Delete',
                    icon: CupertinoIcons.trash,
                    variant: GlassButtonVariant.danger,
                    isDark: isDark,
                    onPressed: () async {
                      final confirmed = await showCupertinoDialog<bool>(
                        context: context,
                        builder: (ctx) => CupertinoAlertDialog(
                          title: const Text('Delete Expense?'),
                          content: Text('Are you sure you want to remove "${expense.title}"?'),
                          actions: [
                            CupertinoDialogAction(
                              isDefaultAction: true,
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            CupertinoDialogAction(
                              isDestructiveAction: true,
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true && context.mounted) {
                        Navigator.pop(context);
                        context.read<ExpenseProvider>().deleteExpense(expense.id);
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Transaction deleted'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: isDark ? AppColors.darkSurface : const Color(0xFF1E293B),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return sheetContent;
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    IconData? icon,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: isDark ? AppColors.electricCyan : AppColors.royalIndigo),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRowDivider(bool isDark) {
    return Divider(
      height: 14,
      thickness: 0.6,
      color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
    );
  }
}
