import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/haptic_helper.dart';
import '../../providers/expense_provider.dart';

/// Premium iOS-inspired Apple Liquid Glass three-option category selector:
/// Personal | Travel | Mix
///
/// Features:
/// - Smooth animated sliding glass indicator
/// - 120Hz-ready physics transitions
/// - Haptic feedback on selection
/// - Multi-user persistent synchronization between Expense and History screens
class ExpenseCategorySelector extends StatelessWidget {
  final bool isDark;

  const ExpenseCategorySelector({
    super.key,
    required this.isDark,
  });

  static const List<({ExpenseScope scope, String label, IconData icon})> _options = [
    (scope: ExpenseScope.personal, label: 'Personal', icon: CupertinoIcons.person_fill),
    (scope: ExpenseScope.travel, label: 'Travel', icon: CupertinoIcons.airplane),
    (scope: ExpenseScope.all, label: 'Mix', icon: CupertinoIcons.square_stack_3d_up_fill),
  ];

  @override
  Widget build(BuildContext context) {
    final expenseProvider = context.watch<ExpenseProvider>();
    final currentScope = expenseProvider.categoryScope;

    final selectedIndex = _options.indexWhere((opt) => opt.scope == currentScope);
    final activeIndex = selectedIndex >= 0 ? selectedIndex : 2; // Default to Mix

    return LayoutBuilder(
      builder: (context, constraints) {
        const double containerHeight = 44.0;
        const double padding = 3.0;
        final double itemWidth = (constraints.maxWidth - (padding * 2)) / 3;

        return Container(
          height: containerHeight,
          padding: const EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF141A24).withValues(alpha: 0.85)
                : const Color(0xFFE2E8F0).withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.white.withValues(alpha: 0.80),
              width: 0.9,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Smooth Sliding Active Pill
              AnimatedPositioned(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                left: activeIndex * itemWidth,
                top: 0,
                bottom: 0,
                width: itemWidth,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.royalGradient,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.royalIndigo.withValues(alpha: 0.40),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),

              // Segment Buttons
              Row(
                children: List.generate(_options.length, (index) {
                  final option = _options[index];
                  final isSelected = index == activeIndex;

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (!isSelected) {
                          HapticHelper.selectionClick();
                          expenseProvider.setCategoryScope(option.scope);
                        }
                      },
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          style: TextStyle(
                            fontFamily: 'SF Pro Display',
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            letterSpacing: -0.2,
                            color: isSelected
                                ? Colors.white
                                : (isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  option.icon,
                                  size: 13,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary),
                                ),
                                const SizedBox(width: 5),
                                Text(option.label),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}
