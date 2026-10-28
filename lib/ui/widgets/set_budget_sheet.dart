import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/haptic_helper.dart';
import '../../providers/expense_provider.dart';
import '../../providers/settings_provider.dart';
import 'glass_button.dart';
import 'liquid_pop.dart';

/// Liquid iOS glassmorphic modal sheet to view and update the monthly budget limit anytime.
class SetBudgetSheet extends StatefulWidget {
  const SetBudgetSheet({super.key});

  static Future<void> show(BuildContext context) {
    HapticHelper.mediumImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      sheetAnimationStyle: AnimationStyle(
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
        duration: const Duration(milliseconds: 360),
      ),
      builder: (ctx) => const SetBudgetSheet(),
    );
  }

  @override
  State<SetBudgetSheet> createState() => _SetBudgetSheetState();
}

class _SetBudgetSheetState extends State<SetBudgetSheet> {
  late TextEditingController _controller;
  double _currentValue = 0.0;

  @override
  void initState() {
    super.initState();
    final expenseProvider = context.read<ExpenseProvider>();
    _currentValue = expenseProvider.monthlyLimit;
    _controller = TextEditingController(text: _currentValue.toStringAsFixed(0));
    _controller.addListener(() {
      final parsed = double.tryParse(_controller.text.replaceAll(',', '').trim()) ?? 0.0;
      if (parsed != _currentValue) {
        setState(() {
          _currentValue = parsed;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addAmount(double increment) {
    HapticHelper.selectionClick();
    final next = (_currentValue + increment).clamp(1000.0, 10000000.0);
    _controller.text = next.toStringAsFixed(0);
  }

  void _setPreset(double amount) {
    HapticHelper.selectionClick();
    _controller.text = amount.toStringAsFixed(0);
  }

  Future<void> _saveBudget() async {
    final val = double.tryParse(_controller.text.replaceAll(',', '').trim());
    if (val == null || val <= 0) {
      HapticHelper.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid monthly budget limit.'),
          backgroundColor: AppColors.roseExpense,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return;
    }

    HapticHelper.success();
    final expenseProvider = context.read<ExpenseProvider>();
    final settingsProvider = context.read<SettingsProvider>();

    await expenseProvider.setMonthlyBudget(val);
    await settingsProvider.setMonthlyBudget(val);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(CupertinoIcons.check_mark_circled_solid, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Monthly budget set to ${CurrencyFormatter.format(val, symbol: settingsProvider.currencySymbol)}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.royalIndigo,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final expenseProvider = context.watch<ExpenseProvider>();
    final isDark = settings.isDarkMode(context);
    final currency = settings.currencySymbol;

    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final remainingDays = (daysInMonth - now.day + 1).clamp(1, daysInMonth);
    final dailyTarget = _currentValue > 0 ? (_currentValue / daysInMonth) : 0.0;
    final remainingBudget = _currentValue - expenseProvider.totalExpenseThisMonth;

    final presets = [15000.0, 25000.0, 35000.0, 50000.0, 75000.0, 100000.0];

    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : const Color(0xFFFFFFFF),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? AppColors.darkGlassHighlight : const Color(0x60CBD5E1),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.2),
            blurRadius: 40,
            spreadRadius: 2,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.25),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Header Title and Close Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Set Monthly Budget',
                        style: AppTextStyles.titleLarge.copyWith(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Adjust your spending limit for this month anytime',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  LiquidPop(
                    pressedScale: 0.88,
                    onTap: () => Navigator.pop(context),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        CupertinoIcons.xmark_circle_fill,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        size: 26,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Current Spend & Remaining Status Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isDark ? AppColors.darkSurface : const Color(0xFFF2F2F7),
                  border: Border.all(
                    color: isDark ? const Color(0x1FFFFFFF) : const Color(0x99CBD5E1),
                    width: 0.6,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SPENT SO FAR',
                            style: AppTextStyles.labelUppercase.copyWith(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            CurrencyFormatter.format(expenseProvider.totalExpenseThisMonth, symbol: currency),
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: isDark ? const Color(0x33FFFFFF) : const Color(0x4094A3B8),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            remainingBudget >= 0 ? 'AVAILABLE BUDGET' : 'OVER BUDGET',
                            style: AppTextStyles.labelUppercase.copyWith(
                              color: remainingBudget >= 0 ? AppColors.electricCyan : AppColors.roseExpense,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            CurrencyFormatter.format(remainingBudget.abs(), symbol: currency),
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.w700,
                              color: remainingBudget >= 0 ? AppColors.electricCyan : AppColors.roseExpense,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Budget Amount Input Field
              Text(
                'BUDGET TARGET',
                style: AppTextStyles.labelUppercase.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  border: Border.all(
                    color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? AppColors.appleBlue : AppColors.royalIndigo).withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                child: Row(
                  children: [
                    Text(
                      currency,
                      style: AppTextStyles.titleLarge.copyWith(
                        color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                        fontWeight: FontWeight.w800,
                        fontSize: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        keyboardType: const TextInputType.numberWithOptions(decimal: false),
                        style: AppTextStyles.titleLarge.copyWith(
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 26,
                        ),
                        decoration: const InputDecoration(
                          hintText: '0',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    if (_controller.text.isNotEmpty)
                      LiquidPop(
                        pressedScale: 0.90,
                        onTap: () {
                          HapticHelper.selectionClick();
                          _controller.clear();
                        },
                        child: Icon(
                          CupertinoIcons.clear_circled_solid,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Daily Target Breakdown Info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: isDark ? AppColors.darkSurface : AppColors.royalIndigo.withValues(alpha: 0.08),
                  border: Border.all(
                    color: isDark ? const Color(0x1FFFFFFF) : AppColors.royalIndigo.withValues(alpha: 0.20),
                    width: 0.6,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.info_circle_fill,
                      size: 16,
                      color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Allows spending ≈ ${CurrencyFormatter.format(dailyTarget, symbol: currency)} / day across $daysInMonth days ($remainingDays days remaining).',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Quick Increments (+5,000, +10,000, etc.)
              Row(
                children: [
                  Expanded(
                    child: LiquidPop(
                      pressedScale: 0.94,
                      onTap: () => _addAmount(2000),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: isDark ? AppColors.darkSurface : const Color(0xFFF2F2F7),
                          border: Border.all(
                            color: isDark ? const Color(0x1FFFFFFF) : const Color(0x66CBD5E1),
                            width: 0.6,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '+ $currency 2,000',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LiquidPop(
                      pressedScale: 0.94,
                      onTap: () => _addAmount(5000),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: isDark ? AppColors.darkSurface : const Color(0xFFF2F2F7),
                          border: Border.all(
                            color: isDark ? const Color(0x1FFFFFFF) : const Color(0x66CBD5E1),
                            width: 0.6,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '+ $currency 5,000',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LiquidPop(
                      pressedScale: 0.94,
                      onTap: () => _addAmount(10000),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: isDark ? AppColors.darkSurface : const Color(0xFFF2F2F7),
                          border: Border.all(
                            color: isDark ? const Color(0x1FFFFFFF) : const Color(0x66CBD5E1),
                            width: 0.6,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '+ $currency 10,000',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Quick Presets
              Text(
                'POPULAR TARGETS',
                style: AppTextStyles.labelUppercase.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presets.map((amount) {
                  final isSelected = (_currentValue - amount).abs() < 1.0;
                  return LiquidPop(
                    pressedScale: 0.93,
                    onTap: () => _setPreset(amount),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: isSelected
                            ? (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
                            : (isDark ? AppColors.darkSurface : const Color(0xFFF2F2F7)),
                        border: Border.all(
                          color: isSelected
                              ? Colors.transparent
                              : (isDark ? const Color(0x1FFFFFFF) : const Color(0x55CBD5E1)),
                          width: 0.6,
                        ),
                      ),
                      child: Text(
                        CurrencyFormatter.format(amount, symbol: currency, compact: true),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),

              // Save Action Button
              GlassButton(
                label: 'Save Monthly Budget',
                icon: CupertinoIcons.checkmark_alt,
                isDark: isDark,
                variant: GlassButtonVariant.primary,
                width: double.infinity,
                onPressed: _saveBudget,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
