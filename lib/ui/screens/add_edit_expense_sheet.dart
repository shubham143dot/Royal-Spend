import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:royal_spend/core/constants/default_categories.dart';
import 'package:royal_spend/core/services/firestore/firestore_sync_service.dart';
import 'package:royal_spend/core/services/network/network_status_service.dart';
import 'package:royal_spend/core/theme/app_colors.dart';
import 'package:royal_spend/core/theme/app_text_styles.dart';
import 'package:royal_spend/core/utils/date_formatter.dart';
import 'package:royal_spend/core/utils/haptic_helper.dart';
import 'package:royal_spend/data/models/expense.dart';
import 'package:royal_spend/providers/expense_provider.dart';
import 'package:royal_spend/providers/settings_provider.dart';
import 'package:royal_spend/providers/travel_provider.dart';
import 'package:royal_spend/ui/widgets/glass_button.dart';
import 'package:royal_spend/ui/widgets/glass_text_field.dart';
import 'package:royal_spend/ui/widgets/liquid_pop.dart';

class AddEditExpenseSheet extends StatefulWidget {
  final Expense? expenseToEdit;
  final String? initialTitle;
  final double? initialAmount;
  final String? initialCategoryId;
  final String? initialTripId;
  final DateTime? initialDate;

  const AddEditExpenseSheet({
    super.key,
    this.expenseToEdit,
    this.initialTitle,
    this.initialAmount,
    this.initialCategoryId,
    this.initialTripId,
    this.initialDate,
  });

  static Future<void> show(
    BuildContext context, {
    Expense? expenseToEdit,
    String? initialTitle,
    double? initialAmount,
    String? initialCategoryId,
    String? initialTripId,
    DateTime? initialDate,
  }) {
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
      builder: (ctx) => AddEditExpenseSheet(
        expenseToEdit: expenseToEdit,
        initialTitle: initialTitle,
        initialAmount: initialAmount,
        initialCategoryId: initialCategoryId,
        initialTripId: initialTripId,
        initialDate: initialDate,
      ),
    );
  }

  @override
  State<AddEditExpenseSheet> createState() => _AddEditExpenseSheetState();
}

class _AddEditExpenseSheetState extends State<AddEditExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _notesController;

  late String _selectedCategoryId;
  late PaymentMethod _selectedPaymentMethod;
  late DateTime _selectedDate;
  String? _selectedTripId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final item = widget.expenseToEdit;

    final defaultTitle = item?.title ?? widget.initialTitle ?? '';
    final defaultAmount = item != null
        ? item.amount.toStringAsFixed(
            item.amount.truncateToDouble() == item.amount ? 0 : 2,
          )
        : (widget.initialAmount != null
              ? widget.initialAmount!.toStringAsFixed(
                  widget.initialAmount!.truncateToDouble() ==
                          widget.initialAmount
                      ? 0
                      : 2,
                )
              : '');

    _titleController = TextEditingController(text: defaultTitle);
    _amountController = TextEditingController(text: defaultAmount);
    _notesController = TextEditingController(text: item?.notes ?? '');

    _selectedCategoryId =
        item?.categoryId ??
        widget.initialCategoryId ??
        DefaultCategories.categories.first.id;
    _selectedPaymentMethod = item?.paymentMethod ?? PaymentMethod.upi;
    _selectedDate = item?.date ?? widget.initialDate ?? DateTime.now();
    _selectedTripId = item?.tripId ?? widget.initialTripId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
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
                    primary: AppColors.appleBlue,
                    onPrimary: Colors.white,
                    surface: AppColors.darkCard,
                    onSurface: AppColors.darkTextPrimary,
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AppColors.appleBlue,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Color(0xFF0F172A),
                  ),
                ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
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
          content: const Text(
            'Please enter a valid expense amount greater than 0',
          ),
          backgroundColor: AppColors.roseExpense,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);

    try {
      final provider = context.read<ExpenseProvider>();
      final isEditing = widget.expenseToEdit != null;
      final expenseId = isEditing ? widget.expenseToEdit!.id : const Uuid().v4();

      String? authUid;
      try {
        authUid = FirestoreSyncService.instance.currentUserId;
      } catch (_) {}
      final settingsEmail = context.read<SettingsProvider>().userEmail;
      final userId = authUid ?? settingsEmail;
      final isOnline = NetworkStatusService.instance.isConnected;
      final syncStatus = isOnline ? ExpenseSyncStatus.synced : ExpenseSyncStatus.pending;

      final expense = Expense(
        id: expenseId,
        title: _titleController.text.trim(),
        amount: amount,
        categoryId: _selectedCategoryId,
        date: _selectedDate,
        paymentMethod: _selectedPaymentMethod,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        tripId: _selectedTripId,
        isIncome: isEditing ? widget.expenseToEdit!.isIncome : false,
        createdAt: isEditing ? widget.expenseToEdit!.createdAt : DateTime.now(),
        updatedAt: DateTime.now(),
        userId: isEditing ? (widget.expenseToEdit!.userId ?? userId) : userId,
        syncStatus: isEditing ? widget.expenseToEdit!.syncStatus : syncStatus,
        receiptPath: widget.expenseToEdit?.receiptPath,
        cloudImageUrl: widget.expenseToEdit?.cloudImageUrl,
        ocrData: widget.expenseToEdit?.ocrData,
      );

      if (isEditing) {
        await provider.updateExpense(expense);
      } else {
        await provider.addExpense(expense);
      }

      // Synchronize travel plan budget & expenses if associated with a trip
      if (mounted) {
        try {
          final travelProv = context.read<TravelProvider>();
          if (expense.tripId != null || (widget.expenseToEdit?.tripId != null)) {
            await travelProv.refreshLinkedExpenses();
          }
        } catch (_) {}
      }

      HapticHelper.success();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.royalIndigo,
            content: Text(
              isEditing
                  ? 'Expense updated successfully!'
                  : 'Expense recorded successfully!',
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
    } catch (e, stack) {
      debugPrint('Error saving expense: $e\n$stack');
      HapticHelper.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.roseExpense,
            content: Text('Failed to save expense: $e'),
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
    final isDark = settings.isDarkMode(context);
    final currencySymbol = settings.currencySymbol;
    final isEditing = widget.expenseToEdit != null;

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
          color: isDark
              ? AppColors.darkGlassHighlight
              : const Color(0xCCFFFFFF),
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
                // Top Notch Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: isDark
                          ? AppColors.darkTextMuted.withValues(alpha: 0.4)
                          : Colors.black.withValues(alpha: 0.25),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Header Title and Close Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'Edit Expense' : 'Record Expense',
                      style: AppTextStyles.titleLarge.copyWith(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    LiquidPop(
                      pressedScale: 0.88,
                      onTap: () => Navigator.pop(context),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          CupertinoIcons.xmark_circle_fill,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                          size: 26,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Big Amount Field
                GlassTextField(
                  controller: _amountController,
                  hintText: '0.00',
                  labelText: 'EXPENSE AMOUNT',
                  prefixIcon: null,
                  isDark: isDark,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  autofocus: !isEditing,
                  textStyle: AppTextStyles.currencyNumber.copyWith(
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                  suffix: Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        currencySymbol,
                        style: AppTextStyles.titleLarge.copyWith(
                          color: isDark
                              ? AppColors.appleBlue
                              : AppColors.royalIndigo,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter an amount';
                    }
                    final num = double.tryParse(value.trim());
                    if (num == null || !num.isFinite || num <= 0) {
                      return 'Amount must be greater than zero';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                  // Expense Title / Merchant
                  GlassTextField(
                    controller: _titleController,
                    hintText:
                        'What did you spend on? (e.g. Starbucks, Groceries)',
                    labelText: 'TITLE / MERCHANT',
                    prefixIcon: CupertinoIcons.tag,
                    isDark: isDark,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please describe this expense';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  // Category Selector
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
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
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: DefaultCategories.categories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final category = DefaultCategories.categories[index];
                        final isSelected = category.id == _selectedCategoryId;

                        return LiquidPop(
                          pressedScale: 0.94,
                          onTap: () {
                            HapticHelper.selectionClick();
                            setState(() => _selectedCategoryId = category.id);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: isSelected
                                  ? category.color.withValues(
                                      alpha: isDark ? 0.28 : 0.22,
                                    )
                                  : (isDark
                                        ? AppColors.darkSurface
                                        : Colors.white.withValues(alpha: 0.60)),
                              border: Border.all(
                                color: isSelected
                                    ? category.color
                                    : (isDark
                                          ? AppColors.darkGlassHighlight
                                          : Colors.white.withValues(
                                              alpha: 0.85,
                                            )),
                                width: isSelected ? 1.5 : 0.6,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: category.color.withValues(
                                          alpha: isDark ? 0.35 : 0.25,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  category.icon,
                                  size: 16,
                                  color: category.color,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  category.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? (isDark
                                              ? Colors.white
                                              : AppColors.lightTextPrimary)
                                        : (isDark
                                              ? AppColors.darkTextSecondary
                                              : AppColors.lightTextSecondary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Date & Payment Method Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date & Time Picker Pill
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 4,
                                bottom: 8,
                              ),
                              child: Text(
                                'DATE & TIME',
                                style: AppTextStyles.labelUppercase.copyWith(
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            ),
                            LiquidPop(
                              pressedScale: 0.95,
                              onTap: () => _pickDate(isDark),
                              child: Container(
                                height: 52,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
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
                                      size: 18,
                                      color: isDark
                                          ? AppColors.appleBlue
                                          : AppColors.royalIndigo,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        DateFormatter.formatDate(_selectedDate),
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                              color: isDark
                                                  ? AppColors.darkTextPrimary
                                                  : AppColors.lightTextPrimary,
                                              fontWeight: FontWeight.w600,
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

                      // Payment Method Dropdown Pill
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 4,
                                bottom: 8,
                              ),
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
                              height: 52,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
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
                                    size: 14,
                                    color: isDark
                                        ? AppColors.darkTextMuted
                                        : AppColors.lightTextMuted,
                                  ),
                                  dropdownColor: isDark
                                      ? AppColors.darkCard
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  items: PaymentMethod.values.map((method) {
                                    return DropdownMenuItem<PaymentMethod>(
                                      value: method,
                                      child: Row(
                                        children: [
                                          Icon(
                                            method.icon,
                                            size: 16,
                                            color: isDark
                                                ? AppColors.appleBlue
                                                : AppColors.royalIndigo,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              method.displayName,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTextStyles.bodyMedium
                                                  .copyWith(
                                                    color: isDark
                                                        ? AppColors
                                                              .darkTextPrimary
                                                        : AppColors
                                                              .lightTextPrimary,
                                                    fontWeight: FontWeight.w500,
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
                                      setState(
                                        () => _selectedPaymentMethod = method,
                                      );
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
                  const SizedBox(height: 18),

                  // Travel Plan Association (Optional)
                  Builder(
                    builder: (ctx) {
                      TravelProvider? travelProvider;
                      try {
                        travelProvider = Provider.of<TravelProvider>(ctx);
                      } catch (_) {
                        return const SizedBox.shrink();
                      }
                      final trips = travelProvider.trips;
                      if (trips.isEmpty) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8),
                            child: Row(
                              children: [
                                Icon(
                                  CupertinoIcons.airplane,
                                  size: 13,
                                  color: isDark ? AppColors.appleOrange : const Color(0xFFF97316),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'LINK TO TRAVEL PLAN (OPTIONAL)',
                                  style: AppTextStyles.labelUppercase.copyWith(
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 52,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: isDark
                                  ? AppColors.darkSurface
                                  : Colors.white.withValues(alpha: 0.70),
                              border: Border.all(
                                color: _selectedTripId != null
                                    ? (isDark ? AppColors.appleOrange : const Color(0xFFF97316))
                                    : (isDark
                                        ? AppColors.darkGlassHighlight
                                        : Colors.white.withValues(alpha: 0.85)),
                                width: _selectedTripId != null ? 1.2 : 0.6,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: _selectedTripId,
                                isExpanded: true,
                                icon: Icon(
                                  CupertinoIcons.chevron_down,
                                  size: 14,
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.lightTextMuted,
                                ),
                                dropdownColor:
                                    isDark ? AppColors.darkCard : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                items: [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Row(
                                      children: [
                                        Icon(
                                          CupertinoIcons.person_fill,
                                          size: 15,
                                          color: isDark
                                              ? AppColors.darkTextSecondary
                                              : AppColors.lightTextSecondary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Personal Expense (Not linked to trip)',
                                          style: AppTextStyles.bodyMedium.copyWith(
                                            color: isDark
                                                ? AppColors.darkTextPrimary
                                                : AppColors.lightTextPrimary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ...trips.map((trip) {
                                    return DropdownMenuItem<String?>(
                                      value: trip.id,
                                      child: Row(
                                        children: [
                                          const Icon(
                                            CupertinoIcons.airplane,
                                            size: 15,
                                            color: Color(0xFFF97316),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${trip.title} (${trip.destination})',
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTextStyles.bodyMedium.copyWith(
                                                color: isDark
                                                    ? AppColors.darkTextPrimary
                                                    : AppColors.lightTextPrimary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (tripId) {
                                  HapticHelper.selectionClick();
                                  setState(() => _selectedTripId = tripId);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],
                      );
                    },
                  ),

                  // Optional Notes
                  GlassTextField(
                    controller: _notesController,
                    hintText: 'Add an optional note or location...',
                    labelText: 'NOTES / REFERENCE (OPTIONAL)',
                    prefixIcon: CupertinoIcons.doc_text,
                    isDark: isDark,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),

                  // Actions: Save / Update Expense
                  GlassButton(
                    label: isEditing ? 'Update Expense' : 'Save Expense',
                    icon: isEditing
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.add_circled_solid,
                    variant: GlassButtonVariant.primary,
                    isDark: isDark,
                    isLoading: _isSubmitting,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }
