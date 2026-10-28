import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/default_categories.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/haptic_helper.dart';
import '../../data/models/expense.dart';
import '../../providers/expense_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_text_field.dart';
import '../widgets/liquid_pop.dart';
import '../widgets/set_budget_sheet.dart';
import '../widgets/transaction_detail_modal.dart';
import '../widgets/transaction_tile.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expenseProvider = context.watch<ExpenseProvider>();
    final settings = context.watch<SettingsProvider>();
    final isDark = settings.isDarkMode(context);
    final currency = settings.currencySymbol;

    final filtered = expenseProvider.filteredExpenses;
    final totalSpentFiltered = filtered
        .fold(0.0, (sum, item) => sum + item.amount);

    // Group filtered expenses chronologically by date string
    final Map<String, List<Expense>> grouped = {};
    for (final exp in filtered) {
      final header = DateFormatter.formatDayHeader(exp.date);
      grouped.putIfAbsent(header, () => []).add(exp);
    }

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
                  Text(
                    'Expense History',
                    style: AppTextStyles.titleLarge.copyWith(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Row(
                    children: [
                      LiquidPop(
                        pressedScale: 0.90,
                        onTap: () {
                          HapticHelper.selectionClick();
                          SetBudgetSheet.show(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
                                .withValues(alpha: isDark ? 0.20 : 0.12),
                            border: Border.all(
                              color: (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
                                  .withValues(alpha: isDark ? 0.45 : 0.35),
                              width: 0.9,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                CupertinoIcons.slider_horizontal_3,
                                size: 13,
                                color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Budget',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (expenseProvider.searchQuery.isNotEmpty ||
                          expenseProvider.selectedCategoryId != null ||
                          expenseProvider.dateFilter != DateFilterType.all) ...[
                        const SizedBox(width: 8),
                        LiquidPop(
                          pressedScale: 0.90,
                          onTap: () {
                            HapticHelper.selectionClick();
                            _searchController.clear();
                            expenseProvider.clearFilters();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: AppColors.roseExpense.withValues(alpha: isDark ? 0.22 : 0.16),
                              border: Border.all(
                                color: AppColors.roseExpense.withValues(alpha: isDark ? 0.45 : 0.35),
                                width: 0.9,
                              ),
                            ),
                            child: Row(
                              children: const [
                                Icon(CupertinoIcons.clear_circled, size: 14, color: AppColors.roseExpense),
                                SizedBox(width: 4),
                                Text(
                                  'Reset',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.roseExpense,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Search Input
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: GlassTextField(
                controller: _searchController,
                hintText: 'Search by title, note, or amount...',
                prefixIcon: CupertinoIcons.search,
                isDark: isDark,
                onChanged: (val) => expenseProvider.setSearchQuery(val.trim()),
                suffix: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(CupertinoIcons.clear_circled_solid, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          expenseProvider.setSearchQuery('');
                        },
                      )
                    : null,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // Date Filter Pills
          SliverToBoxAdapter(
            child: SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                children: [
                  _buildDatePill(expenseProvider, DateFilterType.all, 'All Dates', isDark),
                  _buildDatePill(expenseProvider, DateFilterType.thisMonth, 'This Month', isDark),
                  _buildDatePill(expenseProvider, DateFilterType.thisWeek, 'This Week', isDark),
                  _buildDatePill(expenseProvider, DateFilterType.today, 'Today', isDark),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),

          // Category Filter Horizontal List
          SliverToBoxAdapter(
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                children: [
                  // 'All' chip
                  _buildCategoryFilterChip(
                    label: 'All Categories',
                    isSelected: expenseProvider.selectedCategoryId == null,
                    isDark: isDark,
                    onTap: () => expenseProvider.setSelectedCategory(null),
                  ),
                  ...DefaultCategories.categories.map((cat) {
                    final isSelected = expenseProvider.selectedCategoryId == cat.id;
                    return _buildCategoryFilterChip(
                      label: cat.name,
                      icon: cat.icon,
                      color: cat.color,
                      isSelected: isSelected,
                      isDark: isDark,
                      onTap: () => expenseProvider.setSelectedCategory(isSelected ? null : cat.id),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 14)),

          // Filter Summary Glass Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: GlassDecorations.glassTileDecoration(isDark: isDark),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${filtered.length} ${filtered.length == 1 ? 'transaction' : 'transactions'}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'Total Spend: ',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(totalSpentFiltered, symbol: currency),
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 14)),

          // Empty results state
          if (filtered.isEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
                child: GlassCard(
                  isDark: isDark,
                  borderRadius: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? const Color(0x1A64748B) : const Color(0x106366F1),
                          ),
                          child: Icon(
                            CupertinoIcons.search,
                            size: 38,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Matching Transactions',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Try adjusting your search keywords or filter options.',
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
            ),
          ] else ...[
            // Grouped Transactions
            ...grouped.entries.map((entry) {
              final headerTitle = entry.key;
              final dayExpenses = entry.value;
              final dayTotal = dayExpenses
                  .fold(0.0, (sum, i) => sum + i.amount);

              return SliverMainAxisGroup(
                slivers: [
                  // Day Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            headerTitle,
                            style: AppTextStyles.labelUppercase.copyWith(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                          if (dayTotal > 0)
                            Text(
                              CurrencyFormatter.format(dayTotal, symbol: currency),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Day Transactions List
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final expense = dayExpenses[index];
                          return TransactionTile(
                            expense: expense,
                            currencySymbol: currency,
                            isDark: isDark,
                            onTap: () => TransactionDetailModal.show(context, expense),
                            onDelete: () => expenseProvider.deleteExpense(expense.id),
                          );
                        },
                        childCount: dayExpenses.length,
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }

  Widget _buildDatePill(
    ExpenseProvider provider,
    DateFilterType type,
    String label,
    bool isDark,
  ) {
    final isSelected = provider.dateFilter == type;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: LiquidPop(
        pressedScale: 0.93,
        onTap: () {
          HapticHelper.selectionClick();
          provider.setDateFilter(type);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: GlassDecorations.glassPillDecoration(
            isDark: isDark,
            isSelected: isSelected,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : AppColors.royalIndigo)
                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilterChip({
    required String label,
    IconData? icon,
    Color? color,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final activeColor = color ?? (isDark ? AppColors.appleBlue : AppColors.royalIndigo);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: LiquidPop(
        pressedScale: 0.93,
        onTap: () {
          HapticHelper.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: GlassDecorations.glassPillDecoration(
            isDark: isDark,
            isSelected: isSelected,
            activeColor: activeColor,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 12, color: color ?? activeColor),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.white : AppColors.lightTextPrimary)
                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
