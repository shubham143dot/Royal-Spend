import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/haptic_helper.dart';
import '../../data/models/expense.dart';
import 'liquid_pop.dart';

/// Premier iOS Liquid Glass transaction list tile with theme-balanced surfaces,
/// specular rim highlights, category avatar, and spring pop bounce.
class TransactionTile extends StatelessWidget {
  final Expense expense;
  final String currencySymbol;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const TransactionTile({
    super.key,
    required this.expense,
    required this.currencySymbol,
    required this.isDark,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bool highContrast = MediaQuery.of(context).highContrast;
    final category = expense.category;

    // Use accessible high-contrast colors in light mode, vibrant iOS neon in dark mode
    final amountColor = expense.isIncome
        ? (isDark ? AppColors.appleGreen : const Color(0xFF16A34A))
        : (isDark ? AppColors.appleRed : const Color(0xFFDC2626));

    final tileSurface = highContrast
        ? (isDark ? AppColors.darkCard : const Color(0xFFFFFFFF))
        : (isDark ? AppColors.darkCard : const Color(0xFFFFFFFF));

    final tileBorder = highContrast
        ? (isDark ? Colors.white : const Color(0xFF64748B))
        : (isDark ? const Color(0x22FFFFFF) : const Color(0xFFE2E8F0));

    Widget tileBody = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: tileSurface,
        border: Border.all(
          color: tileBorder,
          width: highContrast ? 1.4 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.35)
                : const Color(0xFF64748B).withValues(alpha: 0.08),
            blurRadius: isDark ? 8 : 10,
            offset: const Offset(0, 2),
          ),
          if (!isDark && !highContrast)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.8),
              blurRadius: 4,
              offset: const Offset(0, -1),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            // Apple iOS Style Category Squircle Badge
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: category.color,
                boxShadow: [
                  BoxShadow(
                    color: category.color.withValues(alpha: isDark ? 0.35 : 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  category.icon,
                  size: 21,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Title & Meta info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        expense.paymentMethod.icon,
                        size: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        expense.paymentMethod.displayName,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '•',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormatter.formatTime(expense.date),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.formatSigned(
                    expense.amount,
                    symbol: currencySymbol,
                    isIncome: expense.isIncome,
                  ),
                  style: AppTextStyles.currencySmall.copyWith(
                    color: amountColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  category.name,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    tileBody = LiquidPop(
      onTap: onTap,
      pressedScale: 0.965,
      child: tileBody,
    );

    return Dismissible(
      key: Key(expense.id),
      direction: onDelete != null ? DismissDirection.endToStart : DismissDirection.none,
      confirmDismiss: (direction) async {
        HapticHelper.mediumImpact();
        return await showCupertinoDialog<bool>(
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
      },
      onDismissed: (_) {
        if (onDelete != null) onDelete!();
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.roseExpense.withValues(alpha: 0.88),
        ),
        child: const Icon(
          CupertinoIcons.trash,
          color: Colors.white,
          size: 22,
        ),
      ),
      child: tileBody,
    );
  }
}
