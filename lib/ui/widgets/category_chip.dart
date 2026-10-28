import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/expense_category.dart';
import 'liquid_pop.dart';

/// Premier iOS Liquid Glass category selection chip with frosted blur,
/// glowing specular active border, and spring pop bounce.
class CategoryChip extends StatelessWidget {
  final ExpenseCategory category;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.category,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool highContrast = MediaQuery.of(context).highContrast;

    final activeBg = category.color.withValues(alpha: isDark ? 0.28 : 0.20);
    final inactiveBg = isDark
        ? AppColors.darkSurface
        : (highContrast ? const Color(0xFFFFFFFF) : const Color(0xE8FFFFFF));

    final activeBorder = category.color;
    final inactiveBorder = isDark
        ? AppColors.darkGlassHighlight
        : (highContrast ? const Color(0xFF64748B) : const Color(0x90FFFFFF));

    Widget chipContent = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isSelected ? activeBg : inactiveBg,
        border: Border.all(
          color: isSelected ? activeBorder : inactiveBorder,
          width: isSelected ? 1.5 : 0.6,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: category.color.withValues(alpha: isDark ? 0.40 : 0.30),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
                if (!isDark)
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.8),
                    blurRadius: 6,
                    offset: const Offset(0, -1),
                  ),
              ]
            : [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.2)
                      : const Color(0xFF64748B).withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: category.color.withValues(alpha: isDark ? 0.35 : 0.25),
            ),
            child: Icon(
              category.icon,
              size: 14,
              color: category.color,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            category.name,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isSelected
                  ? (isDark ? Colors.white : AppColors.lightTextPrimary)
                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    return LiquidPop(
      onTap: onTap,
      pressedScale: 0.93,
      child: AnimatedScale(
        scale: isSelected ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: chipContent,
      ),
    );
  }
}
