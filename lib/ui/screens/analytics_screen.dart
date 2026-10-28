import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/haptic_helper.dart';
import '../../data/models/expense_category.dart';
import '../../providers/expense_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/liquid_pop.dart';
import '../widgets/stat_badge.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final expenseProvider = context.watch<ExpenseProvider>();
    final settings = context.watch<SettingsProvider>();
    final isDark = settings.isDarkMode(context);
    final currency = settings.currencySymbol;

    final categoryMap = expenseProvider.categorySpendThisMonth;
    final totalSpent = expenseProvider.totalExpenseThisMonth;
    final entries = categoryMap.entries.toList();

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Spending Insights',
                          style: AppTextStyles.titleLarge.copyWith(
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormatter.formatMonthYear(DateTime.now()),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatBadge(
                    label: '${entries.length} Categories',
                    icon: CupertinoIcons.chart_pie_fill,
                    color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),

          if (entries.isEmpty || totalSpent <= 0) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: GlassCard(
                  isDark: isDark,
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        CupertinoIcons.chart_bar_alt_fill,
                        size: 48,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Expense Data This Month',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Log your expenses to see interactive breakdowns, category insights, and budget utilization charts.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            // Interactive Donut Chart Glass Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: _buildDonutChartCard(
                  entries: entries,
                  totalSpent: totalSpent,
                  isDark: isDark,
                  currency: currency,
                ),
              ),
            ),

            // Budget Health Overview
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                child: _buildBudgetHealthCard(
                  provider: expenseProvider,
                  isDark: isDark,
                  currency: currency,
                ),
              ),
            ),

            // Category Breakdown Ranking Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 10),
                child: Text(
                  'CATEGORY BREAKDOWN',
                  style: AppTextStyles.labelUppercase.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            ),

            // Category Ranking List
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = entries[index];
                    final category = item.key;
                    final amount = item.value;
                    final percentage = totalSpent > 0 ? (amount / totalSpent) * 100 : 0.0;

                    return _buildCategoryRankItem(
                      index: index + 1,
                      category: category,
                      amount: amount,
                      percentage: percentage,
                      currency: currency,
                      isDark: isDark,
                    );
                  },
                  childCount: entries.length,
                ),
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }

  Widget _buildDonutChartCard({
    required List<MapEntry<ExpenseCategory, double>> entries,
    required double totalSpent,
    required bool isDark,
    required String currency,
  }) {
    ExpenseCategory? activeCategory;
    double activeAmount = totalSpent;
    double activePercentage = 100.0;

    if (_touchedIndex >= 0 && _touchedIndex < entries.length) {
      activeCategory = entries[_touchedIndex].key;
      activeAmount = entries[_touchedIndex].value;
      activePercentage = (activeAmount / totalSpent) * 100;
    }

    return GlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SPENDING BY CATEGORY',
                style: AppTextStyles.labelUppercase.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              Text(
                'Tap slice for details',
                style: AppTextStyles.bodySmall.copyWith(
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Donut Chart with Center Display
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            _touchedIndex = -1;
                            return;
                          }
                          _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                          if (_touchedIndex >= 0 && _touchedIndex < entries.length) {
                            HapticHelper.selectionClick();
                          }
                        });
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    sectionsSpace: 3,
                    centerSpaceRadius: 65,
                    sections: List.generate(entries.length, (i) {
                      final isTouched = i == _touchedIndex;
                      final radius = isTouched ? 36.0 : 28.0;
                      final item = entries[i];
                      final category = item.key;
                      final amount = item.value;

                      return PieChartSectionData(
                        color: category.color,
                        value: amount,
                        title: '',
                        radius: radius,
                        badgeWidget: isTouched
                            ? Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.25),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: Icon(category.icon, size: 12, color: category.color),
                              )
                            : null,
                        badgePositionPercentageOffset: .98,
                      );
                    }),
                  ),
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                ),

                // Center Dynamic Metric with smooth AnimatedSwitcher
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.94, end: 1.0).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Column(
                    key: ValueKey<String>(activeCategory != null ? activeCategory.name : 'total_spent'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        activeCategory != null ? activeCategory.name : 'Total Spent',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.format(activeAmount, symbol: currency, compact: true),
                        style: AppTextStyles.currencySmall.copyWith(
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (activeCategory != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${activePercentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: activeCategory.color,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetHealthCard({
    required ExpenseProvider provider,
    required bool isDark,
    required String currency,
  }) {
    final progress = provider.budgetProgress;
    final isExceeded = provider.isBudgetExceeded;
    final isWarning = provider.isBudgetWarning;

    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (isExceeded) {
      statusText = 'Budget Exceeded';
      statusColor = AppColors.roseExpense;
      statusIcon = CupertinoIcons.exclamationmark_octagon_fill;
    } else if (isWarning) {
      statusText = 'Approaching Limit';
      statusColor = AppColors.amberWarning;
      statusIcon = CupertinoIcons.exclamationmark_triangle_fill;
    } else {
      statusText = 'Healthy Spending';
      statusColor = AppColors.vividMint;
      statusIcon = CupertinoIcons.checkmark_seal_fill;
    }

    return GlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor.withValues(alpha: isDark ? 0.22 : 0.15),
              border: Border.all(
                color: statusColor.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isExceeded
                      ? 'You have exceeded your monthly limit by ${CurrencyFormatter.format(provider.totalExpenseThisMonth - provider.monthlyLimit, symbol: currency)}'
                      : '${CurrencyFormatter.format(provider.remainingBudget, symbol: currency)} remaining of ${CurrencyFormatter.format(provider.monthlyLimit, symbol: currency)} (${(progress * 100).toInt()}% used)',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRankItem({
    required int index,
    required ExpenseCategory category,
    required double amount,
    required double percentage,
    required String currency,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: LiquidPop(
        pressedScale: 0.97,
        onTap: () {
          HapticHelper.lightImpact();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: GlassDecorations.glassTileDecoration(isDark: isDark),
              child: Row(
                children: [
                  // Rank number
                  Text(
                    '#$index',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Apple squircle icon badge
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.5),
                      color: category.color,
                      boxShadow: [
                        BoxShadow(
                          color: category.color.withValues(alpha: isDark ? 0.40 : 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(category.icon, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 12),

                  // Name and Progress
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
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (percentage / 100).clamp(0.0, 1.0),
                                  minHeight: 5,
                                  backgroundColor: isDark ? AppColors.darkSurface : const Color(0x2294A3B8),
                                  valueColor: AlwaysStoppedAnimation<Color>(category.color),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${percentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: category.color,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
