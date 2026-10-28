import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/haptic_helper.dart';
import '../../data/models/expense.dart';
import '../../data/models/quick_log_preset.dart';
import '../../providers/expense_provider.dart';
import '../../providers/quick_log_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/liquid_pop.dart';
import '../widgets/quick_log/add_edit_quick_log_sheet.dart';
import '../widgets/set_budget_sheet.dart';
import '../widgets/stat_badge.dart';
import '../widgets/transaction_detail_modal.dart';
import '../widgets/transaction_tile.dart';
import 'add_edit_expense_sheet.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onNavigateToHistory;

  const DashboardScreen({
    super.key,
    required this.onNavigateToHistory,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Expense? _lastLoggedExpense;
  QuickLogPreset? _lastLoggedPreset;
  Timer? _undoToastTimer;

  @override
  void dispose() {
    _undoToastTimer?.cancel();
    super.dispose();
  }

  void _showQuickLogToast(Expense expense, QuickLogPreset preset) {
    _undoToastTimer?.cancel();
    setState(() {
      _lastLoggedExpense = expense;
      _lastLoggedPreset = preset;
    });

    _undoToastTimer = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) {
        setState(() {
          _lastLoggedExpense = null;
          _lastLoggedPreset = null;
        });
      }
    });
  }

  void _dismissToast() {
    _undoToastTimer?.cancel();
    if (mounted) {
      setState(() {
        _lastLoggedExpense = null;
        _lastLoggedPreset = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenseProvider = context.watch<ExpenseProvider>();
    final settings = context.watch<SettingsProvider>();
    final isDark = settings.isDarkMode(context);
    final currency = settings.currencySymbol;
    final bool highContrast = MediaQuery.of(context).highContrast;

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
          // Header / Greeting App Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            DateFormatter.getGreeting(),
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text('✨', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        settings.userName,
                        style: AppTextStyles.titleLarge.copyWith(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                  // Current Month Tag
                  LiquidPop(
                    pressedScale: 0.94,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: highContrast ? 0 : 14,
                          sigmaY: highContrast ? 0 : 14,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: GlassDecorations.glassPillDecoration(
                            isDark: isDark,
                            highContrast: highContrast,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                CupertinoIcons.calendar,
                                size: 14,
                                color: isDark ? AppColors.electricCyan : AppColors.royalIndigo,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                DateFormatter.formatMonthYear(DateTime.now()),
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Hero Monthly Financial Overview Glass Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: _buildHeroOverviewCard(context, expenseProvider, isDark, currency),
            ),
          ),

          // Budget Alert Banner (if warning or exceeded)
          if (expenseProvider.isBudgetWarning || expenseProvider.isBudgetExceeded) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                child: _buildBudgetAlertBanner(expenseProvider, isDark, currency),
              ),
            ),
          ],

          // Budget Progress Bar Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: _buildBudgetProgressCard(context, expenseProvider, isDark, currency),
            ),
          ),

          // 7-Day Spending Trend Mini Chart
          if (expenseProvider.last7DaysSpend.any((day) => (day['amount'] as double) > 0)) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: _buildSpendingTrendCard(context, expenseProvider, isDark, currency),
              ),
            ),
          ],

          // Top Category Spend Section
          if (expenseProvider.categorySpendThisMonth.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOP CATEGORIES',
                      style: AppTextStyles.labelUppercase.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    Text(
                      'This Month',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: _buildTopCategoriesCard(context, expenseProvider, isDark, currency),
              ),
            ),
          ],

          // Quick Log Presets Row
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 6),
              child: _buildQuickLogBar(context, isDark, currency),
            ),
          ),

          // Recent Transactions Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RECENT TRANSACTIONS',
                    style: AppTextStyles.labelUppercase.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  if (expenseProvider.recentExpenses.isNotEmpty)
                    LiquidPop(
                      pressedScale: 0.92,
                      onTap: () {
                        HapticHelper.selectionClick();
                        widget.onNavigateToHistory();
                      },
                      child: Row(
                        children: [
                          Text(
                            'See All',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: isDark ? AppColors.electricCyan : AppColors.royalIndigo,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            CupertinoIcons.chevron_right,
                            size: 13,
                            color: isDark ? AppColors.electricCyan : AppColors.royalIndigo,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Recent Transactions List or Empty State
          if (expenseProvider.recentExpenses.isEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _buildEmptyState(context, isDark),
              ),
            ),
          ] else ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final expense = expenseProvider.recentExpenses[index];
                    return TransactionTile(
                      expense: expense,
                      currencySymbol: currency,
                      isDark: isDark,
                      onTap: () => TransactionDetailModal.show(context, expense),
                      onDelete: () => expenseProvider.deleteExpense(expense.id),
                    );
                  },
                  childCount: expenseProvider.recentExpenses.length,
                ),
              ),
            ),
          ],

          // Bottom padding so content does not collide with floating navigation bar
          const SliverToBoxAdapter(
            child: SizedBox(height: 120),
          ),
        ],
      ),
      if (_lastLoggedExpense != null && _lastLoggedPreset != null)
        Positioned(
          left: 16,
          right: 16,
          bottom: 96,
          child: TweenAnimationBuilder<double>(
            key: ValueKey(_lastLoggedExpense!.id),
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, (1.0 - value) * 20),
                child: Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: _buildQuickLogUndoToast(
              context,
              _lastLoggedExpense!,
              _lastLoggedPreset!,
              isDark,
              currency,
            ),
          ),
        ),
    ],
  ),
);
  }

  Widget _buildHeroOverviewCard(
    BuildContext context,
    ExpenseProvider provider,
    bool isDark,
    String currency,
  ) {
    return GlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(22),
      gradient: isDark
          ? null
          : const LinearGradient(
              colors: [
                Color(0xF5FFFFFF),
                Color(0xCCF1F5F9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SPENT THIS MONTH',
                style: AppTextStyles.labelUppercase.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  letterSpacing: 0.6,
                ),
              ),
              StatBadge(
                label: provider.isBudgetExceeded
                    ? 'Over Budget'
                    : '${(provider.budgetProgress * 100).toInt()}% of Limit',
                icon: provider.isBudgetExceeded
                    ? CupertinoIcons.exclamationmark_triangle_fill
                    : CupertinoIcons.shield_lefthalf_fill,
                color: provider.isBudgetExceeded
                    ? AppColors.appleRed
                    : (provider.isBudgetWarning ? AppColors.appleOrange : AppColors.appleGreen),
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            CurrencyFormatter.format(provider.totalExpenseThisMonth, symbol: currency),
            style: AppTextStyles.currencyNumber.copyWith(
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 20),

          // Two Interactive Budget Pills
          Row(
            children: [
              // Monthly Budget Pill (Interactive: Tap to change anytime)
              Expanded(
                child: LiquidPop(
                  pressedScale: 0.95,
                  onTap: () {
                    HapticHelper.selectionClick();
                    SetBudgetSheet.show(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: isDark
                          ? AppColors.darkSurface
                          : AppColors.royalIndigo.withValues(alpha: 0.09),
                      border: Border.all(
                        color: isDark
                            ? const Color(0x1FFFFFFF)
                            : AppColors.royalIndigo.withValues(alpha: 0.28),
                        width: 0.6,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? const Color(0x30000000)
                              : AppColors.royalIndigo.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? AppColors.appleBlue.withValues(alpha: 0.22)
                                : AppColors.royalIndigo.withValues(alpha: 0.15),
                          ),
                          child: Icon(
                            CupertinoIcons.slider_horizontal_3,
                            size: 14,
                            color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Budget Limit',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    CupertinoIcons.pencil,
                                    size: 10,
                                    color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                                  ),
                                ],
                              ),
                              Text(
                                CurrencyFormatter.format(provider.monthlyLimit, symbol: currency, compact: true),
                                style: AppTextStyles.bodyLarge.copyWith(
                                  color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Budget Remaining Pill (Interactive)
              Expanded(
                child: LiquidPop(
                  pressedScale: 0.95,
                  onTap: () {
                    HapticHelper.selectionClick();
                    SetBudgetSheet.show(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: isDark
                          ? AppColors.darkSurface
                          : (provider.remainingBudget >= 0 ? AppColors.vividMint : AppColors.roseExpense)
                              .withValues(alpha: 0.09),
                      border: Border.all(
                        color: isDark
                            ? const Color(0x1FFFFFFF)
                            : (provider.remainingBudget >= 0 ? AppColors.vividMint : AppColors.roseExpense)
                                .withValues(alpha: 0.28),
                        width: 0.6,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? const Color(0x30000000)
                              : const Color(0x10000000),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (provider.remainingBudget >= 0 ? AppColors.appleGreen : AppColors.appleRed)
                                .withValues(alpha: 0.22),
                          ),
                          child: Icon(
                            provider.remainingBudget >= 0
                                ? CupertinoIcons.checkmark_seal_fill
                                : CupertinoIcons.exclamationmark_circle_fill,
                            size: 14,
                            color: provider.remainingBudget >= 0 ? AppColors.vividMint : AppColors.roseExpense,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                provider.remainingBudget >= 0 ? 'Remaining' : 'Overspent',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                CurrencyFormatter.format(provider.remainingBudget.abs(), symbol: currency, compact: true),
                                style: AppTextStyles.bodyLarge.copyWith(
                                  color: provider.remainingBudget >= 0 ? AppColors.vividMint : AppColors.roseExpense,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetProgressCard(
    BuildContext context,
    ExpenseProvider provider,
    bool isDark,
    String currency,
  ) {
    final progress = provider.budgetProgress.clamp(0.0, 1.0);
    final percentage = (provider.budgetProgress * 100).toInt();
    final isExceeded = provider.isBudgetExceeded;
    final isWarning = provider.isBudgetWarning;

    Color barColor;
    if (isExceeded) {
      barColor = AppColors.roseExpense;
    } else if (isWarning) {
      barColor = AppColors.amberWarning;
    } else {
      barColor = AppColors.electricCyan;
    }

    return LiquidPop(
      pressedScale: 0.985,
      onTap: () {
        HapticHelper.selectionClick();
        SetBudgetSheet.show(context);
      },
      child: GlassCard(
        isDark: isDark,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'MONTHLY BUDGET',
                      style: AppTextStyles.labelUppercase.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: (isDark ? AppColors.electricCyan : AppColors.royalIndigo).withValues(alpha: 0.15),
                        border: Border.all(
                          color: (isDark ? AppColors.electricCyan : AppColors.royalIndigo).withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.pencil, size: 10, color: isDark ? AppColors.electricCyan : AppColors.royalIndigo),
                          const SizedBox(width: 3),
                          Text(
                            'Edit',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.electricCyan : AppColors.royalIndigo,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                StatBadge(
                  label: isExceeded ? 'Exceeded by $percentage%' : '$percentage% Used',
                  icon: isExceeded ? CupertinoIcons.exclamationmark_triangle_fill : CupertinoIcons.gauge,
                  color: barColor,
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Custom Animated Glass Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  Container(
                    height: 10,
                    width: double.infinity,
                    color: isDark ? const Color(0x33334155) : const Color(0x3394A3B8),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          colors: [
                            barColor.withValues(alpha: 0.7),
                            barColor,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: barColor.withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Limit and Remaining info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Limit: ${CurrencyFormatter.format(provider.monthlyLimit, symbol: currency)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  isExceeded
                      ? 'Over: ${CurrencyFormatter.format(provider.totalExpenseThisMonth - provider.monthlyLimit, symbol: currency)}'
                      : 'Remaining: ${CurrencyFormatter.format(provider.remainingBudget, symbol: currency)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isExceeded ? AppColors.roseExpense : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpendingTrendCard(
    BuildContext context,
    ExpenseProvider provider,
    bool isDark,
    String currency,
  ) {
    final days = provider.last7DaysSpend;
    double maxAmount = 1.0;
    for (final day in days) {
      final amount = day['amount'] as double;
      if (amount > maxAmount) maxAmount = amount;
    }

    return GlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LAST 7 DAYS SPENDING',
                style: AppTextStyles.labelUppercase.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              Icon(
                CupertinoIcons.waveform_path,
                size: 16,
                color: isDark ? AppColors.electricCyan : AppColors.royalIndigo,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 90,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: days.map((day) {
                final amount = day['amount'] as double;
                final heightFactor = (amount / maxAmount).clamp(0.08, 1.0);
                final isToday = day['date'].day == DateTime.now().day;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Bar
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 22,
                      height: 60 * heightFactor,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: isToday
                            ? AppColors.royalGradient
                            : LinearGradient(
                                colors: isDark
                                    ? [
                                        const Color(0x3338BDF8),
                                        const Color(0x666366F1),
                                      ]
                                    : [
                                        const Color(0x55818CF8),
                                        const Color(0xAA6366F1),
                                      ],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      day['weekday'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                        color: isToday
                            ? (isDark ? AppColors.electricCyan : AppColors.royalIndigo)
                            : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCategoriesCard(
    BuildContext context,
    ExpenseProvider provider,
    bool isDark,
    String currency,
  ) {
    final topCategories = provider.categorySpendThisMonth.entries.take(4).toList();
    final totalMonthExpense = provider.totalExpenseThisMonth;

    return GlassCard(
      isDark: isDark,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        children: topCategories.map((entry) {
          final category = entry.key;
          final amount = entry.value;
          final percentage = totalMonthExpense > 0 ? (amount / totalMonthExpense * 100).toInt() : 0;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: category.color.withValues(alpha: 0.2),
                  ),
                  child: Icon(category.icon, size: 16, color: category.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            category.name,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(amount, symbol: currency),
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percentage / 100,
                          minHeight: 4,
                          backgroundColor: isDark ? const Color(0x22334155) : const Color(0x2294A3B8),
                          valueColor: AlwaysStoppedAnimation<Color>(category.color),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return GlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.royalIndigo.withValues(alpha: 0.15),
              border: Border.all(
                color: AppColors.royalIndigo.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: const Icon(
              CupertinoIcons.sparkles,
              size: 34,
              color: AppColors.electricCyan,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No Expenses Recorded',
            style: AppTextStyles.titleMedium.copyWith(
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start your financial journey with Royal Spend. Tap the + button to record your first expense.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 20),
          LiquidPop(
            pressedScale: 0.94,
            onTap: () => AddEditExpenseSheet.show(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: AppColors.royalGradient,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(CupertinoIcons.add, size: 16, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Record Expense',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetAlertBanner(
    ExpenseProvider provider,
    bool isDark,
    String currency,
  ) {
    final bool isExceeded = provider.isBudgetExceeded;
    final alertColor = isExceeded ? AppColors.roseExpense : AppColors.amberWarning;
    final overspentAmount = provider.totalExpenseThisMonth - provider.monthlyLimit;
    final percent = (provider.budgetProgress * 100).toInt();

    Widget banner = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: alertColor.withValues(alpha: isDark ? 0.16 : 0.10),
        border: Border.all(
          color: alertColor.withValues(alpha: isDark ? 0.45 : 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: alertColor.withValues(alpha: isDark ? 0.15 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          if (!isDark)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.8),
              blurRadius: 6,
              offset: const Offset(0, -1),
            ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: alertColor.withValues(alpha: 0.20),
            ),
            child: Icon(
              isExceeded
                  ? CupertinoIcons.exclamationmark_triangle_fill
                  : CupertinoIcons.exclamationmark_circle_fill,
              size: 20,
              color: alertColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExceeded ? 'Monthly Budget Exceeded' : 'Budget Warning Alert',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: alertColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isExceeded
                      ? 'You have spent ${CurrencyFormatter.format(overspentAmount, symbol: currency)} over your limit of ${CurrencyFormatter.format(provider.monthlyLimit, symbol: currency)}.'
                      : 'You have used $percent% of your monthly budget. Only ${CurrencyFormatter.format(provider.remainingBudget, symbol: currency)} remaining.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: banner,
      ),
    );
  }

  Widget _buildQuickLogBar(BuildContext context, bool isDark, String currency) {
    final quickLogProvider = context.watch<QuickLogProvider>();
    final presets = quickLogProvider.presets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick Log Header Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      color: AppColors.amberWarning.withValues(alpha: 0.16),
                    ),
                    child: const Center(
                      child: Icon(
                        CupertinoIcons.bolt_fill,
                        size: 13,
                        color: AppColors.amberWarning,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'QUICK LOG',
                    style: AppTextStyles.labelUppercase.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  if (presets.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                      ),
                      child: Text(
                        '${presets.length}',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              // '+ New' Shortcut Button
              LiquidPop(
                pressedScale: 0.90,
                onTap: () => AddEditQuickLogSheet.show(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    border: Border.all(
                      color: isDark ? AppColors.darkGlassHighlight : const Color(0x30CBD5E1),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.plus,
                        size: 12,
                        color: isDark ? AppColors.electricCyan : AppColors.royalIndigo,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'New',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.electricCyan : AppColors.royalIndigo,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Body: Empty State Card OR Horizontal Carousel of Quick Log Chips
        if (presets.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: LiquidPop(
              pressedScale: 0.97,
              onTap: () => AddEditQuickLogSheet.show(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isDark ? AppColors.darkCard : Colors.white.withValues(alpha: 0.8),
                  border: Border.all(
                    color: isDark ? AppColors.darkGlassHighlight : const Color(0x30CBD5E1),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        gradient: const LinearGradient(
                          colors: [AppColors.amberWarning, Color(0xFFEA580C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.amberWarning.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          CupertinoIcons.bolt_fill,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create 1-Tap Quick Logs',
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tap to setup shortcuts for chai, metro, or lunch.',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9),
                        border: Border.all(
                          color: isDark ? const Color(0x22FFFFFF) : const Color(0x33000000),
                          width: 0.6,
                        ),
                      ),
                      child: Icon(
                        CupertinoIcons.plus,
                        size: 15,
                        color: isDark ? AppColors.electricCyan : AppColors.royalIndigo,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: presets.length + 1,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                // Trailing '+ Add' button chip
                if (index == presets.length) {
                  return LiquidPop(
                    pressedScale: 0.92,
                    onTap: () => AddEditQuickLogSheet.show(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: isDark ? AppColors.darkSurface.withValues(alpha: 0.6) : const Color(0xFFF1F5F9),
                        border: Border.all(
                          color: isDark ? AppColors.darkGlassHighlight : const Color(0x30CBD5E1),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.plus,
                            size: 14,
                            color: isDark ? AppColors.electricCyan : AppColors.royalIndigo,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Add',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.electricCyan : AppColors.royalIndigo,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final preset = presets[index];
                Widget chipBody = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: isDark
                        ? AppColors.darkSurface
                        : Colors.white.withValues(alpha: 0.70),
                    border: Border.all(
                      color: isDark
                          ? const Color(0x1FFFFFFF)
                          : preset.color.withValues(alpha: 0.35),
                      width: 0.6,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? const Color(0x20000000)
                            : preset.color.withValues(alpha: 0.12),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                      if (!isDark)
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.8),
                          blurRadius: 6,
                          offset: const Offset(0, -1),
                        ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(7),
                          color: preset.color,
                        ),
                        child: Center(
                          child: Icon(
                            preset.icon,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        preset.title,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        CurrencyFormatter.format(preset.amount, symbol: currency),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );

                if (!isDark) {
                  chipBody = ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: chipBody,
                    ),
                  );
                }

                return LiquidPop(
                  pressedScale: 0.93,
                  onTap: () async {
                    HapticHelper.mediumImpact();
                    final expense = Expense(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      title: preset.title,
                      amount: preset.amount,
                      categoryId: preset.categoryId,
                      date: DateTime.now(),
                      notes: 'Quick Log',
                    );
                    await context.read<ExpenseProvider>().addExpense(expense);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      _showQuickLogToast(expense, preset);
                    }
                  },
                  onLongPress: () {
                    HapticHelper.heavyImpact();
                    _showPresetOptions(context, preset);
                  },
                  child: chipBody,
                );
              },
            ),
          ),
      ],
    );
  }

  void _showPresetOptions(BuildContext context, QuickLogPreset preset) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(
          preset.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        message: const Text('Manage Quick Log shortcut'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              AddEditQuickLogSheet.show(context, preset: preset);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.pencil, size: 18),
                SizedBox(width: 8),
                Text('Edit Shortcut'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              final confirm = await showCupertinoDialog<bool>(
                context: context,
                builder: (dCtx) => CupertinoAlertDialog(
                  title: const Text('Delete Quick Log'),
                  content: Text('Are you sure you want to delete "${preset.title}"?'),
                  actions: [
                    CupertinoDialogAction(
                      isDefaultAction: true,
                      onPressed: () => Navigator.pop(dCtx, false),
                      child: const Text('Cancel'),
                    ),
                    CupertinoDialogAction(
                      isDestructiveAction: true,
                      onPressed: () => Navigator.pop(dCtx, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await context.read<QuickLogProvider>().deletePreset(preset.id);
              }
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.trash, size: 18),
                SizedBox(width: 8),
                Text('Delete Shortcut'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Widget _buildQuickLogUndoToast(
    BuildContext context,
    Expense expense,
    QuickLogPreset preset,
    bool isDark,
    String currency,
  ) {
    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.down,
      onDismissed: (_) => _dismissToast(),
      child: LiquidPop(
        pressedScale: 0.98,
        onTap: _dismissToast,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? const Color(0x33FFFFFF) : const Color(0xFFCBD5E1),
              width: 0.9,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: preset.color,
                ),
                child: Center(
                  child: Icon(preset.icon, size: 15, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                    children: [
                      const TextSpan(text: 'Logged '),
                      TextSpan(
                        text: preset.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: ' • ${CurrencyFormatter.format(preset.amount, symbol: currency)}',
                        style: TextStyle(
                          color: isDark ? AppColors.electricCyan : AppColors.royalIndigo,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              LiquidPop(
                pressedScale: 0.90,
                onTap: () async {
                  HapticHelper.heavyImpact();
                  _dismissToast();
                  await context.read<ExpenseProvider>().deleteExpense(expense.id);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: AppColors.amberWarning.withValues(alpha: 0.16),
                  ),
                  child: const Text(
                    'UNDO',
                    style: TextStyle(
                      color: AppColors.amberWarning,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

