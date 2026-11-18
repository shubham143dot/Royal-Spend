import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/haptic_helper.dart';
import '../../data/models/expense.dart';
import '../../data/models/expense_category.dart';
import '../../data/models/trip.dart';
import '../../providers/expense_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/travel_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/liquid_pop.dart';
import '../widgets/stat_badge.dart';
import '../widgets/transaction_detail_modal.dart';
import '../widgets/transaction_tile.dart';
import 'add_edit_expense_sheet.dart';

enum AnalyticsPeriodMode {
  monthly,
  daily;
}

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _touchedIndex = -1;
  late DateTime _selectedMonth;
  late DateTime _selectedDate;
  AnalyticsPeriodMode _periodMode = AnalyticsPeriodMode.monthly;
  ExpenseScope _selectedScope = ExpenseScope.personal;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  void _prevMonth() {
    HapticHelper.selectionClick();
    setState(() {
      _touchedIndex = -1;
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    HapticHelper.selectionClick();
    setState(() {
      _touchedIndex = -1;
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    });
  }

  void _goToCurrentMonth() {
    HapticHelper.mediumImpact();
    final now = DateTime.now();
    setState(() {
      _touchedIndex = -1;
      _selectedMonth = DateTime(now.year, now.month, 1);
    });
  }

  bool get _isCurrentDay {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  void _prevDay() {
    HapticHelper.selectionClick();
    setState(() {
      _touchedIndex = -1;
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
      _selectedMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    });
  }

  void _nextDay() {
    HapticHelper.selectionClick();
    setState(() {
      _touchedIndex = -1;
      _selectedDate = _selectedDate.add(const Duration(days: 1));
      _selectedMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    });
  }

  void _goToToday() {
    HapticHelper.mediumImpact();
    final now = DateTime.now();
    setState(() {
      _touchedIndex = -1;
      _selectedDate = DateTime(now.year, now.month, now.day);
      _selectedMonth = DateTime(now.year, now.month, 1);
    });
  }

  Future<void> _pickDate(BuildContext context, bool isDark) async {
    HapticHelper.mediumImpact();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: _selectedScope == ExpenseScope.travel
                        ? const Color(0xFF10B981)
                        : AppColors.appleBlue,
                    onPrimary: Colors.white,
                    surface: const Color(0xFF1E2433),
                    onSurface: Colors.white,
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: ColorScheme.light(
                    primary: _selectedScope == ExpenseScope.travel
                        ? const Color(0xFF0D9488)
                        : AppColors.royalIndigo,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black,
                  ),
                ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      HapticHelper.selectionClick();
      setState(() {
        _touchedIndex = -1;
        _selectedDate = picked;
        _selectedMonth = DateTime(picked.year, picked.month, 1);
      });
    }
  }

  void _showMonthPickerSheet(BuildContext context, bool isDark) {
    HapticHelper.mediumImpact();
    int pickerYear = _selectedMonth.year;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final now = DateTime.now();
          final months = [
            'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
          ];

          return Container(
            decoration: GlassDecorations.glassModalDecoration(isDark: isDark),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Drag Handle
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0x40FFFFFF)
                          : const Color(0x33000000),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Month & Year',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      LiquidPop(
                        pressedScale: 0.90,
                        onTap: () => Navigator.pop(ctx),
                        child: Icon(
                          CupertinoIcons.clear_circled_solid,
                          size: 22,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Year Stepper
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0x18FFFFFF)
                          : const Color(0x0C000000),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        LiquidPop(
                          pressedScale: 0.88,
                          onTap: () {
                            HapticHelper.selectionClick();
                            setModalState(() => pickerYear--);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Icon(
                              CupertinoIcons.chevron_left,
                              size: 16,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '$pickerYear',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        LiquidPop(
                          pressedScale: 0.88,
                          onTap: () {
                            HapticHelper.selectionClick();
                            setModalState(() => pickerYear++);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Icon(
                              CupertinoIcons.chevron_right,
                              size: 16,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4x3 Month Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.8,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      final monthNum = index + 1;
                      final isSelected = _selectedMonth.year == pickerYear &&
                          _selectedMonth.month == monthNum;
                      final isCurrent =
                          now.year == pickerYear && now.month == monthNum;

                      return LiquidPop(
                        pressedScale: 0.92,
                        onTap: () {
                          HapticHelper.selectionClick();
                          setState(() {
                            _touchedIndex = -1;
                            _selectedMonth = DateTime(pickerYear, monthNum, 1);
                          });
                          Navigator.pop(ctx);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (_selectedScope == ExpenseScope.travel
                                    ? (isDark
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFF0D9488))
                                    : (isDark
                                        ? AppColors.appleBlue
                                        : AppColors.royalIndigo))
                                : (isDark
                                    ? const Color(0x18FFFFFF)
                                    : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.transparent
                                  : isCurrent
                                      ? (_selectedScope == ExpenseScope.travel
                                          ? const Color(0xFF10B981)
                                          : AppColors.royalIndigo)
                                      : (isDark
                                          ? const Color(0x22FFFFFF)
                                          : const Color(0xFFE2E8F0)),
                              width: isCurrent && !isSelected ? 1.4 : 0.8,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  months[index],
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark
                                            ? AppColors.darkTextPrimary
                                            : AppColors.lightTextPrimary),
                                  ),
                                ),
                                if (isCurrent && !isSelected) ...[
                                  const SizedBox(height: 2),
                                  Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _selectedScope == ExpenseScope.travel
                                          ? const Color(0xFF10B981)
                                          : AppColors.royalIndigo,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Quick Current Month Action
                  LiquidPop(
                    pressedScale: 0.96,
                    onTap: () {
                      _goToCurrentMonth();
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0x18FFFFFF)
                            : const Color(0x0C000000),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? const Color(0x22FFFFFF)
                              : const Color(0x14000000),
                          width: 0.8,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Jump to Current Month (${DateFormat('MMM yyyy').format(now)})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _selectedScope == ExpenseScope.travel
                                ? (isDark
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF0D9488))
                                : (isDark
                                    ? AppColors.appleBlue
                                    : AppColors.royalIndigo),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expenseProvider = context.watch<ExpenseProvider>();
    final travelProvider = context.watch<TravelProvider>();
    final settings = context.watch<SettingsProvider>();
    final isDark = settings.isDarkMode(context);
    final currency = settings.currencySymbol;
    final isMonthly = _periodMode == AnalyticsPeriodMode.monthly;

    // --- Monthly Data Calculations ---
    final targetYear = _selectedMonth.year;
    final targetMonth = _selectedMonth.month;

    final categoryMap = expenseProvider.getCategorySpendForMonth(
      targetYear,
      targetMonth,
      scope: _selectedScope,
    );
    final totalSpent = expenseProvider.getTotalExpenseForMonth(
      targetYear,
      targetMonth,
      scope: _selectedScope,
    );
    final entries = categoryMap.entries.toList();

    final monthExpenses = expenseProvider.getExpensesForMonth(
      targetYear,
      targetMonth,
      scope: _selectedScope,
    );
    final travelExpenses = expenseProvider.getExpensesForMonth(
      targetYear,
      targetMonth,
      scope: ExpenseScope.travel,
    );
    final travelSpentMonth = expenseProvider.getTotalExpenseForMonth(
      targetYear,
      targetMonth,
      scope: ExpenseScope.travel,
    );

    final activeTrips = travelProvider.trips.where((trip) {
      final monthStart = DateTime(targetYear, targetMonth, 1);
      final monthEnd = DateTime(targetYear, targetMonth + 1, 0, 23, 59, 59);
      final overlaps =
          !trip.endDate.isBefore(monthStart) && !trip.startDate.isAfter(monthEnd);
      final hasExpenseInMonth = travelExpenses.any((e) => e.tripId == trip.id);
      return overlaps || hasExpenseInMonth;
    }).toList();

    // --- Daily Data Calculations ---
    final dayExpenses = expenseProvider.getExpensesForDate(
      _selectedDate,
      scope: _selectedScope,
    );
    final totalDaySpent = expenseProvider.getTotalExpenseForDate(
      _selectedDate,
      scope: _selectedScope,
    );
    final dayCategoryMap = expenseProvider.getCategorySpendForDate(
      _selectedDate,
      scope: _selectedScope,
    );
    final dayEntries = dayCategoryMap.entries.toList();

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        cacheExtent: 1200.0,
        slivers: [
          // Header Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
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
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isMonthly
                              ? (_selectedScope == ExpenseScope.personal
                                  ? 'Monthly Personal Spending & Trends'
                                  : 'Monthly Travel & Vacation Analysis')
                              : (_selectedScope == ExpenseScope.personal
                                  ? 'Daily Personal Spending & Activity'
                                  : 'Daily Travel Spending & Activity'),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatBadge(
                    label: isMonthly
                        ? '${monthExpenses.length} Records'
                        : '${dayExpenses.length} Records',
                    icon: _selectedScope == ExpenseScope.travel
                        ? CupertinoIcons.airplane
                        : CupertinoIcons.chart_pie_fill,
                    color: _selectedScope == ExpenseScope.travel
                        ? (isDark
                            ? const Color(0xFF10B981)
                            : const Color(0xFF0D9488))
                        : (isDark
                            ? AppColors.appleBlue
                            : AppColors.royalIndigo),
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),

          // 1. Month <-> Day Switching System (Period Mode Switcher)
          SliverToBoxAdapter(
            child: _buildPeriodModeSegmentedControl(isDark),
          ),

          // 2. Personal <-> Travel Scope Switcher
          SliverToBoxAdapter(
            child: _buildScopeSegmentedControl(isDark),
          ),

          // 3. Period Navigator (Month Navigator vs Day Navigator)
          SliverToBoxAdapter(
            child: isMonthly
                ? _buildMonthNavigator(isDark)
                : _buildDayNavigator(isDark),
          ),

          // 4. Interactive Horizontal 7-Day Strip (Only in Daily Mode)
          if (!isMonthly) ...[
            SliverToBoxAdapter(
              child: _buildHorizontalDateStrip(isDark, expenseProvider),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 6)),

          // 5. Dynamic Content Container (Cross-fades smoothly between modes, periods & scopes)
          SliverToBoxAdapter(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: child,
              ),
              child: isMonthly
                  ? _buildMonthlyView(
                      key: ValueKey('month_${targetYear}_${targetMonth}_${_selectedScope.name}'),
                      targetYear: targetYear,
                      targetMonth: targetMonth,
                      entries: entries,
                      totalSpent: totalSpent,
                      monthExpenses: monthExpenses,
                      travelSpentMonth: travelSpentMonth,
                      activeTrips: activeTrips,
                      travelExpensesCount: travelExpenses.length,
                      expenseProvider: expenseProvider,
                      isDark: isDark,
                      currency: currency,
                    )
                  : _buildDailyView(
                      key: ValueKey('day_${_selectedDate.year}_${_selectedDate.month}_${_selectedDate.day}_${_selectedScope.name}'),
                      dayExpenses: dayExpenses,
                      totalDaySpent: totalDaySpent,
                      dayEntries: dayEntries,
                      isDark: isDark,
                      currency: currency,
                    ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }

  // --- 0. Period Mode Switcher (Monthly <-> Daily) ---

  Widget _buildPeriodModeSegmentedControl(bool isDark) {
    final isMonthly = _periodMode == AnalyticsPeriodMode.monthly;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      height: 42,
      decoration: BoxDecoration(
        color: isDark ? const Color(0x18FFFFFF) : const Color(0x0C000000),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isDark ? const Color(0x1AFFFFFF) : const Color(0x10000000),
          width: 0.8,
        ),
      ),
      padding: const EdgeInsets.all(3),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pillWidth = constraints.maxWidth / 2;
          return Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                alignment:
                    isMonthly ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  width: pillWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark
                        ? (_selectedScope == ExpenseScope.travel
                            ? const Color(0xFF10B981)
                            : AppColors.appleBlue)
                        : (_selectedScope == ExpenseScope.travel
                            ? const Color(0xFF0D9488)
                            : AppColors.royalIndigo),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: (_selectedScope == ExpenseScope.travel
                                ? (isDark
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF0D9488))
                                : (isDark
                                    ? AppColors.appleBlue
                                    : AppColors.royalIndigo))
                            .withValues(alpha: 0.32),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (_periodMode != AnalyticsPeriodMode.monthly) {
                          HapticHelper.selectionClick();
                          setState(() {
                            _periodMode = AnalyticsPeriodMode.monthly;
                            _selectedMonth =
                                DateTime(_selectedDate.year, _selectedDate.month, 1);
                            _touchedIndex = -1;
                          });
                        }
                      },
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.calendar,
                              size: 14,
                              color: isMonthly
                                  ? Colors.white
                                  : (isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Monthly',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isMonthly
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isMonthly
                                    ? Colors.white
                                    : (isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (_periodMode != AnalyticsPeriodMode.daily) {
                          HapticHelper.selectionClick();
                          setState(() {
                            _periodMode = AnalyticsPeriodMode.daily;
                            final now = DateTime.now();
                            if (_selectedMonth.year == now.year &&
                                _selectedMonth.month == now.month) {
                              _selectedDate =
                                  DateTime(now.year, now.month, now.day);
                            } else {
                              _selectedDate = DateTime(
                                  _selectedMonth.year, _selectedMonth.month, 1);
                            }
                            _touchedIndex = -1;
                          });
                        }
                      },
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.calendar_today,
                              size: 14,
                              color: !isMonthly
                                  ? Colors.white
                                  : (isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Daily',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: !isMonthly
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: !isMonthly
                                    ? Colors.white
                                    : (isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary),
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
          );
        },
      ),
    );
  }

  // --- 1. Scope Switcher (Personal <-> Travel) with Smooth Sliding Pill ---

  Widget _buildScopeSegmentedControl(bool isDark) {
    final isPersonal = _selectedScope == ExpenseScope.personal;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? const Color(0x18FFFFFF) : const Color(0x0C000000),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0x1AFFFFFF) : const Color(0x10000000),
          width: 0.8,
        ),
      ),
      padding: const EdgeInsets.all(3),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pillWidth = constraints.maxWidth / 2;
          return Stack(
            children: [
              // Fluid sliding background pill
              AnimatedAlign(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment:
                    isPersonal ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  width: pillWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: isPersonal
                        ? (isDark
                            ? const LinearGradient(
                                colors: [AppColors.appleBlue, Color(0xFF0071E3)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : AppColors.royalGradient)
                        : (isDark
                            ? const LinearGradient(
                                colors: [Color(0xFF059669), Color(0xFF10B981)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : const LinearGradient(
                                colors: [Color(0xFF0D9488), Color(0xFF0284C7)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: (isPersonal
                                ? (isDark
                                    ? AppColors.appleBlue
                                    : AppColors.royalIndigo)
                                : (isDark
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF0D9488)))
                            .withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),

              // Interactive Segment Tap Targets
              Row(
                children: [
                  // Personal Segment
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (_selectedScope != ExpenseScope.personal) {
                          HapticHelper.selectionClick();
                          setState(() {
                            _selectedScope = ExpenseScope.personal;
                            _touchedIndex = -1;
                          });
                        }
                      },
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.person_crop_circle_fill,
                              size: 15,
                              color: isPersonal
                                  ? Colors.white
                                  : (isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Personal',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isPersonal
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isPersonal
                                    ? Colors.white
                                    : (isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Travel Segment
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (_selectedScope != ExpenseScope.travel) {
                          HapticHelper.selectionClick();
                          setState(() {
                            _selectedScope = ExpenseScope.travel;
                            _touchedIndex = -1;
                          });
                        }
                      },
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.airplane,
                              size: 15,
                              color: !isPersonal
                                  ? Colors.white
                                  : (isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Travel',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: !isPersonal
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: !isPersonal
                                    ? Colors.white
                                    : (isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary),
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
          );
        },
      ),
    );
  }

  // --- 2. Month Navigator Capsule ---

  Widget _buildMonthNavigator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      child: Row(
        children: [
          // Previous Month button
          LiquidPop(
            pressedScale: 0.88,
            onTap: _prevMonth,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0x18FFFFFF)
                    : const Color(0x0C000000),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0x1AFFFFFF)
                      : const Color(0x10000000),
                  width: 0.8,
                ),
              ),
              child: Icon(
                CupertinoIcons.chevron_left,
                size: 16,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Center Month/Year Pill (tappable to open month picker sheet)
          Expanded(
            child: LiquidPop(
              pressedScale: 0.96,
              onTap: () => _showMonthPickerSheet(context, isDark),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0x18FFFFFF)
                      : const Color(0x0C000000),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? const Color(0x1AFFFFFF)
                        : const Color(0x10000000),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.calendar,
                      size: 15,
                      color: _selectedScope == ExpenseScope.travel
                          ? (isDark
                              ? const Color(0xFF10B981)
                              : const Color(0xFF0D9488))
                          : (isDark
                              ? AppColors.appleBlue
                              : AppColors.royalIndigo),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: child,
                        ),
                        child: Text(
                          DateFormatter.formatMonthYear(_selectedMonth),
                          key: ValueKey(
                              '${_selectedMonth.year}_${_selectedMonth.month}'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      CupertinoIcons.chevron_down,
                      size: 11,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Next Month button
          LiquidPop(
            pressedScale: 0.88,
            onTap: _nextMonth,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0x18FFFFFF)
                    : const Color(0x0C000000),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0x1AFFFFFF)
                      : const Color(0x10000000),
                  width: 0.8,
                ),
              ),
              child: Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
          ),

          // "Current" shortcut chip if looking at a past/future month
          if (!_isCurrentMonth) ...[
            const SizedBox(width: 6),
            LiquidPop(
              pressedScale: 0.90,
              onTap: _goToCurrentMonth,
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: (_selectedScope == ExpenseScope.travel
                          ? (isDark
                              ? const Color(0xFF10B981)
                              : const Color(0xFF0D9488))
                          : (isDark
                              ? AppColors.appleBlue
                              : AppColors.royalIndigo))
                      .withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (_selectedScope == ExpenseScope.travel
                            ? (isDark
                                ? const Color(0xFF10B981)
                                : const Color(0xFF0D9488))
                            : (isDark
                                ? AppColors.appleBlue
                                : AppColors.royalIndigo))
                        .withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Center(
                  child: Text(
                    'Current',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _selectedScope == ExpenseScope.travel
                          ? (isDark
                              ? const Color(0xFF10B981)
                              : const Color(0xFF0D9488))
                          : (isDark
                              ? AppColors.appleBlue
                              : AppColors.royalIndigo),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Day Navigator Capsule ---

  Widget _buildDayNavigator(bool isDark) {
    final isToday = _isCurrentDay;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      child: Row(
        children: [
          // Previous Day button
          LiquidPop(
            pressedScale: 0.88,
            onTap: _prevDay,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0x18FFFFFF)
                    : const Color(0x0C000000),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0x1AFFFFFF)
                      : const Color(0x10000000),
                  width: 0.8,
                ),
              ),
              child: Icon(
                CupertinoIcons.chevron_left,
                size: 16,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Center Day Pill (tappable to open date picker)
          Expanded(
            child: LiquidPop(
              pressedScale: 0.96,
              onTap: () => _pickDate(context, isDark),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0x18FFFFFF)
                      : const Color(0x0C000000),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? const Color(0x1AFFFFFF)
                        : const Color(0x10000000),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.calendar_today,
                      size: 15,
                      color: _selectedScope == ExpenseScope.travel
                          ? (isDark
                              ? const Color(0xFF10B981)
                              : const Color(0xFF0D9488))
                          : (isDark
                              ? AppColors.appleBlue
                              : AppColors.royalIndigo),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        DateFormat('EEE, d MMM yyyy').format(_selectedDate),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      CupertinoIcons.chevron_down,
                      size: 11,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Next Day button
          LiquidPop(
            pressedScale: 0.88,
            onTap: _nextDay,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0x18FFFFFF)
                    : const Color(0x0C000000),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0x1AFFFFFF)
                      : const Color(0x10000000),
                  width: 0.8,
                ),
              ),
              child: Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
          ),

          // "Today" shortcut if viewing another date
          if (!isToday) ...[
            const SizedBox(width: 6),
            LiquidPop(
              pressedScale: 0.90,
              onTap: _goToToday,
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: (_selectedScope == ExpenseScope.travel
                          ? (isDark
                              ? const Color(0xFF10B981)
                              : const Color(0xFF0D9488))
                          : (isDark
                              ? AppColors.appleBlue
                              : AppColors.royalIndigo))
                      .withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (_selectedScope == ExpenseScope.travel
                            ? const Color(0xFF10B981)
                            : AppColors.royalIndigo)
                        .withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Center(
                  child: Text(
                    'Today',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _selectedScope == ExpenseScope.travel
                          ? (isDark
                              ? const Color(0xFF10B981)
                              : const Color(0xFF0D9488))
                          : (isDark
                              ? AppColors.appleBlue
                              : AppColors.royalIndigo),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Horizontal 7-Day Quick Strip ---

  Widget _buildHorizontalDateStrip(bool isDark, ExpenseProvider expenseProvider) {
    final days = List.generate(7, (i) => _selectedDate.add(Duration(days: i - 3)));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      height: 64,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: days.map((day) {
          final isSelected = day.year == _selectedDate.year &&
              day.month == _selectedDate.month &&
              day.day == _selectedDate.day;
          final isToday = day.year == DateTime.now().year &&
              day.month == DateTime.now().month &&
              day.day == DateTime.now().day;
          final hasData = expenseProvider.hasDataForDate(day, scope: _selectedScope);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: LiquidPop(
                pressedScale: 0.92,
                onTap: () {
                  HapticHelper.selectionClick();
                  setState(() {
                    _selectedDate = day;
                    _selectedMonth = DateTime(day.year, day.month, 1);
                    _touchedIndex = -1;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (_selectedScope == ExpenseScope.travel
                            ? (isDark
                                ? const Color(0xFF10B981)
                                : const Color(0xFF0D9488))
                            : (isDark
                                ? AppColors.appleBlue
                                : AppColors.royalIndigo))
                        : (isDark
                            ? const Color(0x18FFFFFF)
                            : const Color(0x0C000000)),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : isToday
                              ? (_selectedScope == ExpenseScope.travel
                                  ? const Color(0xFF10B981)
                                  : AppColors.royalIndigo)
                              : (isDark
                                  ? const Color(0x1AFFFFFF)
                                  : const Color(0x10000000)),
                      width: isToday && !isSelected ? 1.4 : 0.8,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: (_selectedScope == ExpenseScope.travel
                                      ? const Color(0xFF10B981)
                                      : AppColors.appleBlue)
                                  .withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('EEE').format(day).toUpperCase(),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.9)
                              : (isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : (isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hasData
                              ? (isSelected
                                  ? Colors.white
                                  : (_selectedScope == ExpenseScope.travel
                                      ? const Color(0xFF10B981)
                                      : AppColors.appleBlue))
                              : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- Monthly View ---

  Widget _buildMonthlyView({
    required Key key,
    required int targetYear,
    required int targetMonth,
    required List<MapEntry<ExpenseCategory, double>> entries,
    required double totalSpent,
    required List<Expense> monthExpenses,
    required double travelSpentMonth,
    required List<Trip> activeTrips,
    required int travelExpensesCount,
    required ExpenseProvider expenseProvider,
    required bool isDark,
    required String currency,
  }) {
    return KeyedSubtree(
      key: key,
      child: Column(
        children: [
          if (entries.isEmpty || totalSpent <= 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: GlassCard(
                isDark: isDark,
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    Icon(
                      _selectedScope == ExpenseScope.travel
                          ? CupertinoIcons.airplane
                          : CupertinoIcons.creditcard_fill,
                      size: 44,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _selectedScope == ExpenseScope.travel
                          ? 'No Travel Expenses in ${DateFormatter.formatMonthYear(_selectedMonth)}'
                          : 'No Personal Expenses in ${DateFormatter.formatMonthYear(_selectedMonth)}',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedScope == ExpenseScope.travel
                          ? 'No trip-linked travel expenses were logged for this month. Use the Travel Planner or Quick Travel Expense FAB to record transit, stays, and tour spending.'
                          : 'Log your daily personal transactions to see interactive category breakdowns, spend percentages, and budget utilization.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Monthly Financial Overview Metric Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: _buildMonthlyOverviewCard(
                totalSpent: totalSpent,
                transactionCount: monthExpenses.length,
                travelSpent: travelSpentMonth,
                isDark: isDark,
                currency: currency,
              ),
            ),

            // Donut Chart Glass Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: _buildDonutChartCard(
                entries: entries,
                totalSpent: totalSpent,
                isDark: isDark,
                currency: currency,
              ),
            ),

            // Daily Spending Trends Bar Chart
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: _buildDailySpendingTrendCard(
                year: targetYear,
                month: targetMonth,
                provider: expenseProvider,
                isDark: isDark,
                currency: currency,
              ),
            ),

            // Health / Summary Card (Personal budget vs Travel overview)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: _selectedScope == ExpenseScope.personal
                  ? _buildBudgetHealthCard(
                      provider: expenseProvider,
                      isDark: isDark,
                      currency: currency,
                      totalPersonalSpent: totalSpent,
                    )
                  : _buildTravelOverviewCard(
                      totalTravelSpent: totalSpent,
                      activeTrips: activeTrips,
                      travelExpensesCount: travelExpensesCount,
                      isDark: isDark,
                      currency: currency,
                    ),
            ),

            // Category Breakdown Header
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _selectedScope == ExpenseScope.personal
                          ? 'PERSONAL CATEGORY BREAKDOWN'
                          : 'TRAVEL SPENDING BREAKDOWN',
                      style: AppTextStyles.labelUppercase.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${entries.length} categories',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ),

            // Category Ranking List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                children: List.generate(entries.length, (index) {
                  final item = entries[index];
                  final category = item.key;
                  final amount = item.value;
                  final percentage =
                      totalSpent > 0 ? (amount / totalSpent) * 100 : 0.0;

                  return _buildCategoryRankItem(
                    index: index + 1,
                    category: category,
                    amount: amount,
                    percentage: percentage,
                    currency: currency,
                    isDark: isDark,
                  );
                }),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Daily View ---

  Widget _buildDailyView({
    required Key key,
    required List<Expense> dayExpenses,
    required double totalDaySpent,
    required List<MapEntry<ExpenseCategory, double>> dayEntries,
    required bool isDark,
    required String currency,
  }) {
    return KeyedSubtree(
      key: key,
      child: Column(
        children: [
          // Daily Financial Overview Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: _buildDailyOverviewCard(
              totalSpent: totalDaySpent,
              transactionCount: dayExpenses.length,
              dayExpenses: dayExpenses,
              isDark: isDark,
              currency: currency,
            ),
          ),

          if (dayExpenses.isEmpty || totalDaySpent <= 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: GlassCard(
                isDark: isDark,
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    Icon(
                      CupertinoIcons.calendar_badge_plus,
                      size: 44,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'No Expenses on ${DateFormat('d MMMM yyyy').format(_selectedDate)}',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No transactions were recorded on this date. Tap below to log one instantly.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 18),
                    LiquidPop(
                      pressedScale: 0.94,
                      onTap: () {
                        AddEditExpenseSheet.show(
                          context,
                          initialDate: _selectedDate,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 11),
                        decoration: BoxDecoration(
                          gradient: _selectedScope == ExpenseScope.travel
                              ? const LinearGradient(
                                  colors: [Color(0xFF059669), Color(0xFF10B981)],
                                )
                              : AppColors.royalGradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.add,
                                size: 16, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'Add Expense for this Day',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Daily Donut Chart Glass Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: _buildDonutChartCard(
                entries: dayEntries,
                totalSpent: totalDaySpent,
                isDark: isDark,
                currency: currency,
                title: 'CATEGORY BREAKDOWN FOR ${DateFormat("MMM d").format(_selectedDate).toUpperCase()}',
              ),
            ),

            // Category Ranking List for the Day
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'CATEGORY SPENDING',
                      style: AppTextStyles.labelUppercase.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${dayEntries.length} categories',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                children: List.generate(dayEntries.length, (index) {
                  final item = dayEntries[index];
                  final category = item.key;
                  final amount = item.value;
                  final percentage = totalDaySpent > 0
                      ? (amount / totalDaySpent) * 100
                      : 0.0;

                  return _buildCategoryRankItem(
                    index: index + 1,
                    category: category,
                    amount: amount,
                    percentage: percentage,
                    currency: currency,
                    isDark: isDark,
                  );
                }),
              ),
            ),

            // Individual Transactions Recorded on this Date
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TRANSACTIONS ON THIS DATE (${dayExpenses.length})',
                    style: AppTextStyles.labelUppercase.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                  LiquidPop(
                    pressedScale: 0.92,
                    onTap: () {
                      AddEditExpenseSheet.show(
                        context,
                        initialDate: _selectedDate,
                      );
                    },
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.plus_circle_fill,
                          size: 15,
                          color: _selectedScope == ExpenseScope.travel
                              ? (isDark ? const Color(0xFF10B981) : const Color(0xFF0D9488))
                              : (isDark ? AppColors.appleBlue : AppColors.royalIndigo),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Add',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _selectedScope == ExpenseScope.travel
                                ? (isDark ? const Color(0xFF10B981) : const Color(0xFF0D9488))
                                : (isDark ? AppColors.appleBlue : AppColors.royalIndigo),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // List of Transaction Tiles for the selected date
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                children: dayExpenses.map((expense) {
                  return TransactionTile(
                    expense: expense,
                    currencySymbol: currency,
                    isDark: isDark,
                    onTap: () => TransactionDetailModal.show(context, expense),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Overview Cards & Trend Visualizers ---

  Widget _buildMonthlyOverviewCard({
    required double totalSpent,
    required int transactionCount,
    required double travelSpent,
    required bool isDark,
    required String currency,
  }) {
    return GlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MONTHLY TOTAL SPENT',
                style: AppTextStyles.labelUppercase.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  letterSpacing: 0.6,
                ),
              ),
              StatBadge(
                label: '$transactionCount Txns',
                icon: CupertinoIcons.list_bullet,
                color: _selectedScope == ExpenseScope.travel
                    ? (isDark ? const Color(0xFF10B981) : const Color(0xFF0D9488))
                    : (isDark ? AppColors.appleBlue : AppColors.royalIndigo),
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            CurrencyFormatter.format(totalSpent, symbol: currency),
            style: AppTextStyles.currencyNumber.copyWith(
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (_selectedScope == ExpenseScope.personal) ...[
                Icon(
                  CupertinoIcons.airplane,
                  size: 14,
                  color: isDark ? const Color(0xFF10B981) : const Color(0xFF0D9488),
                ),
                const SizedBox(width: 6),
                Text(
                  'Travel Spend: ${CurrencyFormatter.format(travelSpent, symbol: currency)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ] else ...[
                const Icon(
                  CupertinoIcons.check_mark_circled_solid,
                  size: 14,
                  color: AppColors.appleGreen,
                ),
                const SizedBox(width: 6),
                Text(
                  'Active Trips & Tour Expenses',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyOverviewCard({
    required double totalSpent,
    required int transactionCount,
    required List<Expense> dayExpenses,
    required bool isDark,
    required String currency,
  }) {
    final highestExpense = dayExpenses.isEmpty
        ? 0.0
        : dayExpenses.map((e) => e.amount).reduce((a, b) => a > b ? a : b);
    final travelSpent = dayExpenses
        .where((e) => e.tripId != null && e.tripId!.isNotEmpty)
        .fold(0.0, (sum, e) => sum + e.amount);

    return GlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DAILY TOTAL SPENT',
                style: AppTextStyles.labelUppercase.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  letterSpacing: 0.6,
                ),
              ),
              StatBadge(
                label: '$transactionCount Txns',
                icon: CupertinoIcons.list_bullet,
                color: _selectedScope == ExpenseScope.travel
                    ? (isDark ? const Color(0xFF10B981) : const Color(0xFF0D9488))
                    : (isDark ? AppColors.appleBlue : AppColors.royalIndigo),
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            CurrencyFormatter.format(totalSpent, symbol: currency),
            style: AppTextStyles.currencyNumber.copyWith(
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x12FFFFFF) : const Color(0x08000000),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Highest Expense',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.format(highestExpense, symbol: currency),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x12FFFFFF) : const Color(0x08000000),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedScope == ExpenseScope.personal ? 'Travel Share' : 'Trips Tagged',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedScope == ExpenseScope.personal
                            ? CurrencyFormatter.format(travelSpent, symbol: currency)
                            : '${dayExpenses.where((e) => e.tripId != null).length} linked',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _selectedScope == ExpenseScope.personal
                              ? (isDark ? const Color(0xFF10B981) : const Color(0xFF0D9488))
                              : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailySpendingTrendCard({
    required int year,
    required int month,
    required ExpenseProvider provider,
    required bool isDark,
    required String currency,
  }) {
    final dailyMap = provider.getDailySpendMapForMonth(year, month, scope: _selectedScope);
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final maxSpend = dailyMap.values.isEmpty
        ? 1.0
        : dailyMap.values.reduce((a, b) => a > b ? a : b);

    if (dailyMap.isEmpty || maxSpend <= 0) return const SizedBox.shrink();

    return GlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DAILY SPENDING TRENDS',
                style: AppTextStyles.labelUppercase.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              Text(
                'Day 1 - $daysInMonth',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 130,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxSpend * 1.15,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => isDark ? const Color(0xE810131E) : Colors.white,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final day = group.x.toInt();
                      final val = rod.toY;
                      return BarTooltipItem(
                        'Day $day\n${CurrencyFormatter.format(val, symbol: currency)}',
                        TextStyle(
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      interval: (daysInMonth / 6).ceilToDouble(),
                      getTitlesWidget: (value, meta) {
                        final d = value.toInt();
                        if (d < 1 || d > daysInMonth) return const SizedBox.shrink();
                        return Text(
                          '$d',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(daysInMonth, (i) {
                  final day = i + 1;
                  final spend = dailyMap[day] ?? 0.0;
                  final hasSpend = spend > 0;
                  return BarChartGroupData(
                    x: day,
                    barRods: [
                      BarChartRodData(
                        toY: spend,
                        width: daysInMonth > 28 ? 6.5 : 8.0,
                        color: hasSpend
                            ? (_selectedScope == ExpenseScope.travel
                                ? (isDark ? const Color(0xFF10B981) : const Color(0xFF0D9488))
                                : (isDark ? AppColors.appleBlue : AppColors.royalIndigo))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(3),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxSpend * 1.15,
                          color: isDark ? const Color(0x0CFFFFFF) : const Color(0x08000000),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. Interactive Donut Chart Glass Card ---

  Widget _buildDonutChartCard({
    required List<MapEntry<ExpenseCategory, double>> entries,
    required double totalSpent,
    required bool isDark,
    required String currency,
    String? title,
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
              Expanded(
                child: Text(
                  title ??
                      (_selectedScope == ExpenseScope.personal
                          ? 'PERSONAL EXPENSES BY CATEGORY'
                          : 'TRAVEL EXPENSES BY CATEGORY'),
                  style: AppTextStyles.labelUppercase.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Tap slice for details',
                style: AppTextStyles.bodySmall.copyWith(
                  color: isDark
                      ? AppColors.darkTextMuted
                      : AppColors.lightTextMuted,
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
                          _touchedIndex = pieTouchResponse
                              .touchedSection!.touchedSectionIndex;
                          if (_touchedIndex >= 0 &&
                              _touchedIndex < entries.length) {
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
                                child: Icon(category.icon,
                                    size: 12, color: category.color),
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
                      scale:
                          Tween<double>(begin: 0.94, end: 1.0).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Column(
                    key: ValueKey<String>(
                        activeCategory != null ? activeCategory.name : 'total'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        activeCategory != null
                            ? activeCategory.name
                            : (_selectedScope == ExpenseScope.personal
                                ? 'Personal Total'
                                : 'Travel Total'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.format(activeAmount,
                            symbol: currency, compact: true),
                        style: AppTextStyles.currencySmall.copyWith(
                          color:
                              isDark ? Colors.white : AppColors.lightTextPrimary,
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

  // --- 4. Personal Mode Budget Health Card ---

  Widget _buildBudgetHealthCard({
    required ExpenseProvider provider,
    required bool isDark,
    required String currency,
    required double totalPersonalSpent,
  }) {
    final limit = provider.monthlyLimit;
    final progress = limit > 0 ? (totalPersonalSpent / limit) : 0.0;
    final isExceeded = totalPersonalSpent > limit;
    final isWarning = progress >= 0.8 && !isExceeded;

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
      statusText = 'Healthy Personal Budget';
      statusColor = AppColors.vividMint;
      statusIcon = CupertinoIcons.checkmark_seal_fill;
    }

    final remaining = limit - totalPersonalSpent;

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
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isExceeded
                      ? 'You exceeded monthly budget by ${CurrencyFormatter.format(totalPersonalSpent - limit, symbol: currency)}'
                      : '${CurrencyFormatter.format(remaining > 0 ? remaining : 0.0, symbol: currency)} remaining of ${CurrencyFormatter.format(limit, symbol: currency)} (${(progress * 100).toInt()}% used)',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 5. Travel Mode Overview Card ---

  Widget _buildTravelOverviewCard({
    required double totalTravelSpent,
    required List<Trip> activeTrips,
    required int travelExpensesCount,
    required bool isDark,
    required String currency,
  }) {
    final double totalTripBudgets =
        activeTrips.fold(0.0, (sum, trip) => sum + trip.budget);

    return GlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isDark
                          ? const Color(0xFF10B981)
                          : const Color(0xFF0D9488))
                      .withValues(alpha: isDark ? 0.22 : 0.15),
                  border: Border.all(
                    color: (isDark
                            ? const Color(0xFF10B981)
                            : const Color(0xFF0D9488))
                        .withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Icon(
                  CupertinoIcons.airplane,
                  color: isDark
                      ? const Color(0xFF10B981)
                      : const Color(0xFF0D9488),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Travel & Trip Spending',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$travelExpensesCount travel transactions recorded in ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (activeTrips.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0x14FFFFFF)
                    : const Color(0x0A000000),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0x18FFFFFF)
                      : const Color(0x0F000000),
                  width: 0.8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'ACTIVE TRIPS THIS MONTH (${activeTrips.length})',
                          style: AppTextStyles.labelUppercase.copyWith(
                            fontSize: 9,
                            letterSpacing: 0.5,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (totalTripBudgets > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          'Combined Budget: ${CurrencyFormatter.format(totalTripBudgets, symbol: currency)}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? const Color(0xFF10B981)
                                : const Color(0xFF0D9488),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: activeTrips.map((t) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isDark
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF0D9488))
                              .withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.location_solid,
                              size: 11,
                              color: isDark
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF0D9488),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              t.title,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF0D9488),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- 6. Category Rank Item ---

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
                  color: isDark
                      ? AppColors.darkTextMuted
                      : AppColors.lightTextMuted,
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
                      color: category.color
                          .withValues(alpha: isDark ? 0.40 : 0.25),
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
                        Expanded(
                          child: Text(
                            category.name,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(amount, symbol: currency),
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
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
                              backgroundColor: isDark
                                  ? AppColors.darkSurface
                                  : const Color(0x2294A3B8),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(category.color),
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
