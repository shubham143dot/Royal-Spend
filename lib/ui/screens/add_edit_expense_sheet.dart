import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:royal_spend/core/constants/default_categories.dart';
import 'package:royal_spend/core/services/ocr/image_picker_service.dart';
import 'package:royal_spend/core/services/ocr/parsed_transaction.dart';
import 'package:royal_spend/core/services/ocr/parsers/upi_parser_utils.dart';
import 'package:royal_spend/core/theme/app_colors.dart';
import 'package:royal_spend/core/theme/app_text_styles.dart';
import 'package:royal_spend/core/utils/date_formatter.dart';
import 'package:royal_spend/core/utils/haptic_helper.dart';
import 'package:royal_spend/data/models/expense.dart';
import 'package:royal_spend/providers/expense_provider.dart';
import 'package:royal_spend/providers/settings_provider.dart';
import 'package:royal_spend/ui/widgets/glass_button.dart';
import 'package:royal_spend/ui/widgets/glass_text_field.dart';
import 'package:royal_spend/ui/widgets/liquid_pop.dart';
import 'package:royal_spend/ui/widgets/smart_import/smart_import_section.dart';

enum ExpenseEntryMode { manual, smartImport }

class AddEditExpenseSheet extends StatefulWidget {
  final Expense? expenseToEdit;
  final String? initialTitle;
  final double? initialAmount;
  final String? initialCategoryId;
  final String? initialTripId;

  const AddEditExpenseSheet({
    super.key,
    this.expenseToEdit,
    this.initialTitle,
    this.initialAmount,
    this.initialCategoryId,
    this.initialTripId,
  });

  static Future<void> show(
    BuildContext context, {
    Expense? expenseToEdit,
    String? initialTitle,
    double? initialAmount,
    String? initialCategoryId,
    String? initialTripId,
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

  ExpenseEntryMode _entryMode = ExpenseEntryMode.manual;
  ParsedTransaction? _parsedTransaction;
  bool _smartImportAmountConfirmed = false;
  final bool _isOcrProcessing = false;

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
    _selectedDate = item?.date ?? DateTime.now();
    _selectedTripId = item?.tripId ?? widget.initialTripId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _handleTransactionParsed(ParsedTransaction parsed) {
    setState(() {
      _parsedTransaction = parsed;
      _smartImportAmountConfirmed =
          parsed.amountStatus == AmountExtractionStatus.extracted;
      if (parsed.merchant != null && parsed.merchant!.isNotEmpty) {
        _titleController.text = parsed.merchant!;
      }

      // Determine amount to populate into the expense field:
      // Prefer primary parsed amount, or top candidate, or extract any Rupee amount from text
      var targetAmount = parsed.amount ??
          (parsed.candidateAmounts.isNotEmpty ? parsed.candidateAmounts.first : null);

      if (targetAmount == null || targetAmount <= 0) {
        final fallbackRupees = UpiParserUtils.extractAllRupeeAmounts(parsed.rawText);
        if (fallbackRupees.isNotEmpty) {
          targetAmount = fallbackRupees.first;
          parsed = parsed.copyWith(
            amount: targetAmount,
            amountStatus: AmountExtractionStatus.extracted,
            candidateAmounts: fallbackRupees,
          );
          _parsedTransaction = parsed;
        }
      }

      if (targetAmount != null && targetAmount > 0) {
        _amountController.text = targetAmount.toStringAsFixed(
          targetAmount.truncateToDouble() == targetAmount ? 0 : 2,
        );
        _smartImportAmountConfirmed = true;
        if (parsed.amount == null) {
          _parsedTransaction = parsed.copyWith(
            amount: targetAmount,
            amountStatus: AmountExtractionStatus.extracted,
          );
        }
      } else {
        // Clear any amount left from a previous/manual entry
        if (_amountController.text.trim().isEmpty) {
          _amountController.clear();
        }
      }
      if (DefaultCategories.categories.any((c) => c.id == parsed.categoryId)) {
        _selectedCategoryId = parsed.categoryId;
      }
      _selectedPaymentMethod = parsed.paymentMethod;
      if (parsed.date != null) {
        _selectedDate = parsed.date!;
      }
      if (parsed.referenceId != null && parsed.referenceId!.isNotEmpty) {
        final currentNotes = _notesController.text.trim();
        if (currentNotes.isEmpty) {
          _notesController.text = 'Ref: ${parsed.referenceId}';
        } else if (!currentNotes.contains(parsed.referenceId!)) {
          _notesController.text = '$currentNotes | Ref: ${parsed.referenceId}';
        }
      }
    });
  }

  void _handleSelectCandidateAmount(double amount) {
    setState(() {
      _amountController.text = amount.toStringAsFixed(
        amount.truncateToDouble() == amount ? 0 : 2,
      );
      _smartImportAmountConfirmed = true;
      if (_parsedTransaction != null) {
        _parsedTransaction = _parsedTransaction!.copyWith(
          amount: amount,
          amountStatus: AmountExtractionStatus.extracted,
        );
      }
    });
  }

  void _handleResetSmartImport() {
    HapticHelper.selectionClick();
    setState(() {
      _parsedTransaction = null;
      _smartImportAmountConfirmed = false;
    });
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
    _smartImportAmountConfirmed = true;

    setState(() => _isSubmitting = true);

    try {
      final provider = context.read<ExpenseProvider>();
      final isEditing = widget.expenseToEdit != null;

      final expense = Expense(
        id: isEditing ? widget.expenseToEdit!.id : const Uuid().v4(),
        title: _titleController.text.trim(),
        amount: amount,
        categoryId: _selectedCategoryId,
        date: _selectedDate,
        paymentMethod: _selectedPaymentMethod,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        tripId: isEditing ? widget.expenseToEdit!.tripId : _selectedTripId,
        isIncome: isEditing
            ? widget.expenseToEdit!.isIncome
            : (_entryMode == ExpenseEntryMode.smartImport &&
                  (_parsedTransaction?.isIncome ?? false)),
        createdAt: isEditing ? widget.expenseToEdit!.createdAt : DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (isEditing) {
        await provider.updateExpense(expense);
      } else {
        await provider.addExpense(expense);
      }

      // Privacy: Clean up temporary receipt image if one was used
      if (_parsedTransaction?.imagePath != null) {
        await ImagePickerService.deleteTempImage(_parsedTransaction!.imagePath);
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
                  : (_entryMode == ExpenseEntryMode.smartImport
                        ? 'Smart receipt imported successfully!'
                        : 'Expense recorded successfully!'),
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

  String _amountReviewMessage(
    AmountExtractionStatus status,
  ) => switch (status) {
    AmountExtractionStatus.ambiguous =>
      'Several amounts look possible. Select one above or enter the amount.',
    AmountExtractionStatus.invalid =>
      'The amount text could not be read safely. Enter it manually.',
    AmountExtractionStatus.missing =>
      'No reliable amount was found. Enter it manually.',
    AmountExtractionStatus.extracted => '',
  };

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDark = settings.isDarkMode(context);
    final currencySymbol = settings.currencySymbol;
    final isEditing = widget.expenseToEdit != null;
    final isSmartImportSelected = _entryMode == ExpenseEntryMode.smartImport;
    final isAwaitingSmartImportImage =
        isSmartImportSelected && _parsedTransaction == null;

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
                      isEditing
                          ? 'Edit Expense'
                          : (_entryMode == ExpenseEntryMode.smartImport
                                ? 'Smart Import'
                                : 'Record Expense'),
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

                // Segmented Switcher (Manual Entry vs Smart Import)
                if (!isEditing) ...[
                  _ModeSwitcher(
                    currentMode: _entryMode,
                    isDark: isDark,
                    onModeChanged: (mode) {
                      HapticHelper.selectionClick();
                      setState(() => _entryMode = mode);
                    },
                  ),
                  const SizedBox(height: 18),
                ],

                // Smart Import Section (Pickers / Processing / Parsed Preview)
                if (isSmartImportSelected) ...[
                  SmartImportSection(
                    isDark: isDark,
                    parsedTransaction: _parsedTransaction,
                    amountManuallyConfirmed: _smartImportAmountConfirmed,
                    isProcessing: _isOcrProcessing,
                    onTransactionParsed: _handleTransactionParsed,
                    onReset: _handleResetSmartImport,
                    onSelectCandidateAmount: _handleSelectCandidateAmount,
                    onFallbackToManual: () =>
                        setState(() => _entryMode = ExpenseEntryMode.manual),
                  ),
                ],

                // Editable Fields & Preview (Hidden only when user has not yet picked an image in Smart Import mode)
                if (!isAwaitingSmartImportImage) ...[
                  if (isSmartImportSelected && _parsedTransaction != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 12),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.pencil_ellipsis_rectangle,
                            size: 15,
                            color: isDark
                                ? AppColors.appleBlue
                                : AppColors.royalIndigo,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'CONFIRM & EDIT TRANSACTION DETAILS',
                            style: AppTextStyles.labelUppercase.copyWith(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

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
                    autofocus: !isEditing && !isSmartImportSelected,
                    warning:
                        isSmartImportSelected &&
                        _parsedTransaction != null &&
                        _parsedTransaction!.amountStatus !=
                            AmountExtractionStatus.extracted &&
                        !_smartImportAmountConfirmed,
                    onChanged:
                        isSmartImportSelected && _parsedTransaction != null
                        ? (value) {
                            final enteredAmount = double.tryParse(value.trim());
                            setState(
                              () => _smartImportAmountConfirmed =
                                  enteredAmount != null && enteredAmount > 0,
                            );
                          }
                        : null,
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
                  if (isSmartImportSelected &&
                      _parsedTransaction != null &&
                      _parsedTransaction!.amountStatus !=
                          AmountExtractionStatus.extracted &&
                      !_smartImportAmountConfirmed) ...[
                    const SizedBox(height: 7),
                    Text(
                      _amountReviewMessage(_parsedTransaction!.amountStatus),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.amberWarning
                            : const Color(0xFF92400E),
                      ),
                    ),
                  ],
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

                  // Actions: Cancel & Save Expense
                  if (isSmartImportSelected &&
                      _parsedTransaction != null &&
                      _parsedTransaction!.isDuplicate) ...[
                    Row(
                      children: [
                        Expanded(
                          child: GlassButton(
                            label: 'Cancel Import',
                            icon: CupertinoIcons.xmark,
                            variant: GlassButtonVariant.secondary,
                            isDark: isDark,
                            onPressed: _handleResetSmartImport,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: GlassButton(
                            label: 'Save Anyway',
                            icon: CupertinoIcons.check_mark_circled_solid,
                            variant: GlassButtonVariant.primary,
                            isDark: isDark,
                            isLoading: _isSubmitting,
                            onPressed: _save,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    GlassButton(
                      label: isEditing
                          ? 'Update Expense'
                          : (isSmartImportSelected
                                ? (_parsedTransaction?.isIncome == true
                                      ? 'Save Smart Income'
                                      : 'Save Smart Expense')
                                : 'Save Expense'),
                      icon: isEditing
                          ? CupertinoIcons.check_mark_circled_solid
                          : CupertinoIcons.add_circled_solid,
                      variant: GlassButtonVariant.primary,
                      isDark: isDark,
                      isLoading: _isSubmitting,
                      onPressed: _save,
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeSwitcher extends StatelessWidget {
  final ExpenseEntryMode currentMode;
  final bool isDark;
  final ValueChanged<ExpenseEntryMode> onModeChanged;

  const _ModeSwitcher({
    required this.currentMode,
    required this.isDark,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.darkGlassHighlight
              : Colors.white.withValues(alpha: 0.8),
          width: 0.6,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeSwitchTab(
              title: 'Manual Entry',
              icon: CupertinoIcons.pencil,
              isSelected: currentMode == ExpenseEntryMode.manual,
              isDark: isDark,
              onTap: () => onModeChanged(ExpenseEntryMode.manual),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _ModeSwitchTab(
              title: 'Smart Import',
              icon: CupertinoIcons.sparkles,
              isSelected: currentMode == ExpenseEntryMode.smartImport,
              isDark: isDark,
              accentColor: AppColors.electricCyan,
              onTap: () => onModeChanged(ExpenseEntryMode.smartImport),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSwitchTab extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final bool isDark;
  final Color? accentColor;
  final VoidCallback onTap;

  const _ModeSwitchTab({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.isDark,
    this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidPop(
      onTap: onTap,
      pressedScale: 0.96,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? (isDark ? AppColors.darkCard : Colors.white)
              : Colors.transparent,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? (accentColor ??
                          (isDark
                              ? AppColors.appleBlue
                              : AppColors.royalIndigo))
                    : (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.white : AppColors.lightTextPrimary)
                      : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
