import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/default_categories.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../data/models/expense.dart';
import '../../../data/models/trip.dart';
import '../../../providers/expense_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/travel_provider.dart';
import '../../screens/travel/create_plan_wizard_screen.dart';
import '../glass_button.dart';
import '../glass_text_field.dart';
import '../liquid_pop.dart';

/// Modal bottom sheet for logging travel-specific expenses quickly.
/// Automatically targets the active trip, and provides an intuitive trip
/// selector when multiple trips exist.
class QuickTravelExpenseSheet extends StatefulWidget {
  final String? initialTripId;

  const QuickTravelExpenseSheet({
    super.key,
    this.initialTripId,
  });

  static Future<void> show(
    BuildContext context, {
    String? initialTripId,
  }) {
    HapticHelper.mediumImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.60),
      sheetAnimationStyle: AnimationStyle(
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
        duration: const Duration(milliseconds: 360),
      ),
      builder: (ctx) => QuickTravelExpenseSheet(
        initialTripId: initialTripId,
      ),
    );
  }

  @override
  State<QuickTravelExpenseSheet> createState() =>
      _QuickTravelExpenseSheetState();
}

class _QuickTravelExpenseSheetState extends State<QuickTravelExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  Trip? _selectedTrip;
  String _selectedCategoryId = 'travel';
  PaymentMethod _selectedPaymentMethod = PaymentMethod.upi;
  DateTime _selectedDate = DateTime.now();
  bool _isSubmitting = false;

  // Travel quick suggestions
  static const List<Map<String, String>> _quickSuggestions = [
    {'title': 'Cab / Taxi', 'cat': 'transport'},
    {'title': 'Hotel Stay', 'cat': 'travel'},
    {'title': 'Food & Drinks', 'cat': 'food'},
    {'title': 'Entry Ticket', 'cat': 'entertainment'},
    {'title': 'Souvenirs', 'cat': 'shopping'},
    {'title': 'Train / Flight', 'cat': 'transport'},
  ];

  @override
  void initState() {
    super.initState();
    final travelProvider = context.read<TravelProvider>();
    final trips = travelProvider.trips;

    if (widget.initialTripId != null) {
      _selectedTrip = trips.cast<Trip?>().firstWhere(
            (t) => t?.id == widget.initialTripId,
            orElse: () => null,
          );
    }

    _selectedTrip ??= travelProvider.selectedTrip ??
        (trips.isNotEmpty ? trips.first : null);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _applyQuickSuggestion(String title, String categoryId) {
    HapticHelper.selectionClick();
    setState(() {
      _titleController.text = title;
      if (DefaultCategories.categories.any((c) => c.id == categoryId)) {
        _selectedCategoryId = categoryId;
      }
    });
  }

  void _addQuickAmount(double delta) {
    HapticHelper.selectionClick();
    final current = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final updated = current + delta;
    setState(() {
      _amountController.text = updated.toStringAsFixed(
        updated.truncateToDouble() == updated ? 0 : 2,
      );
    });
  }

  Future<void> _showTripPicker(
      BuildContext context, List<Trip> trips, bool isDark) async {
    HapticHelper.selectionClick();
    final chosen = await showModalBottomSheet<Trip>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark ? AppColors.darkGlassHighlight : const Color(0x33000000),
              width: 0.8,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Target Trip',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  Text(
                    '${trips.length} Trips',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.appleOrange : const Color(0xFFF97316),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: trips.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final trip = trips[index];
                    final isSelected = trip.id == _selectedTrip?.id;

                    return GestureDetector(
                      onTap: () {
                        HapticHelper.selectionClick();
                        Navigator.pop(ctx, trip);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark
                                  ? AppColors.appleOrange.withValues(alpha: 0.16)
                                  : const Color(0xFFF97316).withValues(alpha: 0.12))
                              : (isDark
                                  ? AppColors.darkSurface
                                  : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? (isDark
                                    ? AppColors.appleOrange
                                    : const Color(0xFFF97316))
                                : (isDark
                                    ? const Color(0x1AFFFFFF)
                                    : const Color(0x1A000000)),
                            width: isSelected ? 1.4 : 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (isDark
                                        ? AppColors.appleOrange
                                        : const Color(0xFFF97316))
                                    .withValues(alpha: 0.18),
                              ),
                              child: Icon(
                                CupertinoIcons.airplane,
                                size: 18,
                                color: isDark
                                    ? AppColors.appleOrange
                                    : const Color(0xFFF97316),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    trip.title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.lightTextPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${trip.destination} • ${trip.calendarDaysCount} days',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                CupertinoIcons.check_mark_circled_solid,
                                color: isDark
                                    ? AppColors.appleOrange
                                    : const Color(0xFFF97316),
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (chosen != null && mounted) {
      setState(() {
        _selectedTrip = chosen;
      });
    }
  }

  Future<void> _pickDate(bool isDark) async {
    HapticHelper.selectionClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: AppColors.appleOrange,
                    onPrimary: Colors.white,
                    surface: AppColors.darkCard,
                    onSurface: AppColors.darkTextPrimary,
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFFF97316),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Color(0xFF0F172A),
                  ),
                ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      HapticHelper.heavyImpact();
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || !amount.isFinite || amount <= 0) {
      HapticHelper.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid expense amount greater than 0'),
          backgroundColor: AppColors.roseExpense,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return;
    }

    if (_selectedTrip == null) {
      HapticHelper.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a target trip for this expense'),
          backgroundColor: AppColors.roseExpense,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final expenseProvider = context.read<ExpenseProvider>();
      final travelProvider = context.read<TravelProvider>();

      final title = _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : '${_selectedTrip!.destination} Expense';

      final expense = Expense(
        id: const Uuid().v4(),
        title: title,
        amount: amount,
        categoryId: _selectedCategoryId,
        date: _selectedDate,
        paymentMethod: _selectedPaymentMethod,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        tripId: _selectedTrip!.id,
        isIncome: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await expenseProvider.addExpense(expense);
      await travelProvider.refreshLinkedExpenses();

      HapticHelper.success();
      if (mounted) {
        setState(() => _isSubmitting = false);
        Navigator.maybePop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFF97316),
            content: Text(
              'Added ${CurrencyFormatter.format(amount)} to ${_selectedTrip!.destination}!',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final travelProvider = context.watch<TravelProvider>();
    final isDark = settings.isDarkMode(context);
    final currencySymbol = settings.currencySymbol;
    final trips = travelProvider.trips;

    // Theme color: Solar sunset amber-orange for travel
    final travelAccent = isDark ? AppColors.appleOrange : const Color(0xFFF97316);

    // If user has zero trips, present a friendly onboarding state
    if (trips.isEmpty) {
      return Container(
        padding: EdgeInsets.only(
          top: 24,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 28,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(
            color: isDark ? AppColors.darkGlassHighlight : const Color(0x33000000),
            width: 0.8,
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: travelAccent.withValues(alpha: 0.16),
                ),
                child: Icon(
                  CupertinoIcons.airplane,
                  size: 32,
                  color: travelAccent,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No Travel Plans Found',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create a travel plan first to record travel expenses directly against your trip budget.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              GlassButton(
                label: 'Create New Plan',
                icon: CupertinoIcons.add,
                variant: GlassButtonVariant.primary,
                isDark: isDark,
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (_) => const CreatePlanWizardScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : const Color(0xF7FFFFFF),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: isDark ? AppColors.darkGlassHighlight : const Color(0xCCFFFFFF),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.7 : 0.2),
            blurRadius: 36,
            spreadRadius: 2,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Sheet Grabber Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.20)
                          : Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Sheet Title & Travel Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: travelAccent.withValues(alpha: 0.16),
                          ),
                          child: Icon(
                            CupertinoIcons.airplane,
                            size: 16,
                            color: travelAccent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Quick Travel Expense',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(CupertinoIcons.xmark, size: 18),
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // --- 1. TARGET TRIP SELECTOR CARD ---
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 6),
                  child: Text(
                    'TARGET TRIP',
                    style: AppTextStyles.labelUppercase.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: trips.length > 1
                      ? () => _showTripPicker(context, trips, isDark)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurface
                          : Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: travelAccent.withValues(alpha: 0.4),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: travelAccent.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.map_pin_ellipse,
                          size: 18,
                          color: travelAccent,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedTrip?.title ?? 'Select a Trip',
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
                              Text(
                                _selectedTrip != null
                                    ? '${_selectedTrip!.destination} • ${DateFormatter.formatDate(_selectedTrip!.startDate)}'
                                    : 'Tap to pick trip',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (trips.length > 1) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: travelAccent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Change',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: travelAccent,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  CupertinoIcons.chevron_down,
                                  size: 10,
                                  color: travelAccent,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // --- 2. AMOUNT INPUT FIELD ---
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 6),
                  child: Text(
                    'EXPENSE AMOUNT',
                    style: AppTextStyles.labelUppercase.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurface
                        : Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: travelAccent.withValues(alpha: 0.35),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        currencySymbol,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: travelAccent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          key: const Key('quick_travel_amount_field'),
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: '0.00',
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Enter an amount';
                            }
                            final d = double.tryParse(val.trim());
                            if (d == null || d <= 0) {
                              return 'Enter a valid amount';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Quick Increment Amount Chips
                Row(
                  children: [100.0, 500.0, 1000.0, 2000.0].map((amt) {
                    final label = '+$currencySymbol${amt.toInt()}';
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: LiquidPop(
                        onTap: () => _addQuickAmount(amt),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: travelAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: travelAccent.withValues(alpha: 0.3),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: travelAccent,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // --- 3. EXPENSE TITLE & QUICK SUGGESTIONS ---
                GlassTextField(
                  controller: _titleController,
                  hintText: 'e.g. Taxi to Mall, Hotel Dinner, Train Ticket',
                  labelText: 'EXPENSE TITLE',
                  prefixIcon: CupertinoIcons.tag,
                  isDark: isDark,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                // Quick Title Suggestions
                SizedBox(
                  height: 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _quickSuggestions.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, idx) {
                      final item = _quickSuggestions[idx];
                      return GestureDetector(
                        onTap: () => _applyQuickSuggestion(
                            item['title']!, item['cat']!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurface
                                : Colors.white.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0x1AFFFFFF)
                                  : const Color(0x1A000000),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            item['title']!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // --- 4. CATEGORY SELECTOR ---
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 6),
                  child: Text(
                    'CATEGORY',
                    style: AppTextStyles.labelUppercase.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: DefaultCategories.categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = DefaultCategories.categories[index];
                      final isSelected = cat.id == _selectedCategoryId;

                      return GestureDetector(
                        onTap: () {
                          HapticHelper.selectionClick();
                          setState(() => _selectedCategoryId = cat.id);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? travelAccent
                                : (isDark
                                    ? AppColors.darkSurface
                                    : Colors.white.withValues(alpha: 0.8)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.transparent
                                  : (isDark
                                      ? const Color(0x1AFFFFFF)
                                      : const Color(0x1A000000)),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                cat.icon,
                                size: 14,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                cat.name,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.lightTextPrimary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // --- 5. DATE & PAYMENT METHOD ROW ---
                Row(
                  children: [
                    // Date Picker
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 6),
                            child: Text(
                              'DATE',
                              style: AppTextStyles.labelUppercase.copyWith(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _pickDate(isDark),
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: isDark
                                    ? AppColors.darkSurface
                                    : Colors.white.withValues(alpha: 0.70),
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.darkGlassHighlight
                                      : Colors.white.withValues(alpha: 0.85),
                                  width: 0.6,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    CupertinoIcons.calendar,
                                    size: 16,
                                    color: travelAccent,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      DateFormatter.formatDate(_selectedDate),
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? AppColors.darkTextPrimary
                                            : AppColors.lightTextPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Payment Method Dropdown
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 6),
                            child: Text(
                              'PAYMENT METHOD',
                              style: AppTextStyles.labelUppercase.copyWith(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ),
                          Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: isDark
                                  ? AppColors.darkSurface
                                  : Colors.white.withValues(alpha: 0.70),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.darkGlassHighlight
                                    : Colors.white.withValues(alpha: 0.85),
                                width: 0.6,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<PaymentMethod>(
                                value: _selectedPaymentMethod,
                                isExpanded: true,
                                icon: Icon(
                                  CupertinoIcons.chevron_down,
                                  size: 12,
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.lightTextMuted,
                                ),
                                dropdownColor:
                                    isDark ? AppColors.darkCard : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                items: PaymentMethod.values.map((method) {
                                  return DropdownMenuItem<PaymentMethod>(
                                    value: method,
                                    child: Row(
                                      children: [
                                        Icon(
                                          method.icon,
                                          size: 14,
                                          color: travelAccent,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            method.displayName,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: isDark
                                                  ? AppColors.darkTextPrimary
                                                  : AppColors.lightTextPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (method) {
                                  if (method != null) {
                                    HapticHelper.selectionClick();
                                    setState(() =>
                                        _selectedPaymentMethod = method);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // --- 6. OPTIONAL NOTES ---
                GlassTextField(
                  controller: _notesController,
                  hintText: 'Add an optional note, bill reference...',
                  labelText: 'NOTES (OPTIONAL)',
                  prefixIcon: CupertinoIcons.doc_text,
                  isDark: isDark,
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // --- 7. SAVE ACTION BUTTON ---
                LiquidPop(
                  onTap: _isSubmitting ? null : _save,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          travelAccent,
                          travelAccent.withValues(alpha: 0.85),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: travelAccent.withValues(alpha: 0.40),
                          blurRadius: 16,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isSubmitting) ...[
                          const CupertinoActivityIndicator(
                            color: Colors.white,
                            radius: 10,
                          ),
                          const SizedBox(width: 8),
                        ] else ...[
                          const Icon(
                            CupertinoIcons.add_circled_solid,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          _isSubmitting
                              ? 'Recording Travel Expense...'
                              : 'Record Travel Expense',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
