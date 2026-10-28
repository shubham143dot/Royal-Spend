import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/default_categories.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../data/models/expense_category.dart';
import '../../../data/models/quick_log_preset.dart';
import '../../../providers/quick_log_provider.dart';
import '../../../providers/settings_provider.dart';
import '../category_chip.dart';
import '../glass_button.dart';
import '../glass_text_field.dart';
import '../liquid_pop.dart';

/// Modal bottom sheet to create or edit a custom Quick Log shortcut preset.
class AddEditQuickLogSheet extends StatefulWidget {
  final QuickLogPreset? preset;

  const AddEditQuickLogSheet({super.key, this.preset});

  static Future<void> show(BuildContext context, {QuickLogPreset? preset}) {
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
      builder: (ctx) => AddEditQuickLogSheet(preset: preset),
    );
  }

  @override
  State<AddEditQuickLogSheet> createState() => _AddEditQuickLogSheetState();
}

class _AddEditQuickLogSheetState extends State<AddEditQuickLogSheet> {
  late TextEditingController _titleController;
  late TextEditingController _amountController;

  late String _selectedCategoryId;
  int? _selectedIconCodePoint;
  int? _selectedColorValue;

  bool _isSaving = false;

  final List<IconData> _quickIcons = [
    CupertinoIcons.flame_fill,
    CupertinoIcons.cart_fill,
    CupertinoIcons.car_detailed,
    CupertinoIcons.bag_fill,
    CupertinoIcons.play_rectangle_fill,
    CupertinoIcons.bolt_fill,
    CupertinoIcons.sparkles,
    CupertinoIcons.heart_fill,
    CupertinoIcons.book_fill,
    CupertinoIcons.airplane,
    CupertinoIcons.creditcard_fill,
    CupertinoIcons.tag_fill,
  ];

  final List<(String title, double amount, String categoryId, IconData icon)> _suggestions = [
    ('Chai / Coffee', 20.0, 'food', CupertinoIcons.flame_fill),
    ('Metro / Bus', 40.0, 'transport', CupertinoIcons.car_detailed),
    ('Daily Lunch', 120.0, 'food', CupertinoIcons.bag_fill),
    ('Groceries', 250.0, 'groceries', CupertinoIcons.cart_fill),
    ('Snacks', 60.0, 'food', CupertinoIcons.sparkles),
    ('Auto / Cab', 150.0, 'transport', CupertinoIcons.car_detailed),
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.preset;
    _titleController = TextEditingController(text: p?.title ?? '');
    _amountController = TextEditingController(
      text: p != null ? (p.amount % 1 == 0 ? p.amount.toInt().toString() : p.amount.toString()) : '',
    );
    _selectedCategoryId = p?.categoryId ?? 'food';
    _selectedIconCodePoint = p?.iconCodePoint;
    _selectedColorValue = p?.colorValue;

    _titleController.addListener(() => setState(() {}));
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  ExpenseCategory get _currentCategory => DefaultCategories.getCategoryById(_selectedCategoryId);

  IconData get _resolvedIcon {
    if (_selectedIconCodePoint != null) {
      return IconData(
        _selectedIconCodePoint!,
        fontFamily: 'CupertinoIcons',
        fontPackage: 'cupertino_icons',
      );
    }
    return _currentCategory.icon;
  }

  Color get _resolvedColor {
    if (_selectedColorValue != null) {
      return Color(_selectedColorValue!);
    }
    return _currentCategory.color;
  }

  void _addQuickAmount(double delta) {
    HapticHelper.selectionClick();
    final cur = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final next = (cur + delta).clamp(1.0, 1000000.0);
    _amountController.text = next % 1 == 0 ? next.toInt().toString() : next.toStringAsFixed(2);
  }

  void _applySuggestion(String title, double amount, String categoryId, IconData icon) {
    HapticHelper.selectionClick();
    setState(() {
      _titleController.text = title;
      _amountController.text = amount % 1 == 0 ? amount.toInt().toString() : amount.toString();
      _selectedCategoryId = categoryId;
      _selectedIconCodePoint = icon.codePoint;
      _selectedColorValue = null;
    });
  }

  Future<void> _handleSave() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      HapticHelper.heavyImpact();
      _showToast('Please enter a title for the shortcut.', isError: true);
      return;
    }

    final rawAmount = _amountController.text.replaceAll(',', '').trim();
    final amount = double.tryParse(rawAmount);
    if (amount == null || amount <= 0) {
      HapticHelper.heavyImpact();
      _showToast('Please enter a valid amount greater than 0.', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    HapticHelper.success();

    final quickLogProvider = context.read<QuickLogProvider>();
    final newPreset = QuickLogPreset(
      id: widget.preset?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      amount: amount,
      categoryId: _selectedCategoryId,
      iconCodePoint: _selectedIconCodePoint,
      colorValue: _selectedColorValue,
    );

    if (widget.preset != null) {
      await quickLogProvider.updatePreset(newPreset);
      _showToast('Quick Log updated!');
    } else {
      await quickLogProvider.addPreset(newPreset);
      _showToast('Quick Log created!');
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _handleDelete() async {
    if (widget.preset == null) return;
    HapticHelper.heavyImpact();

    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Quick Log'),
        content: Text('Are you sure you want to delete "${widget.preset!.title}"?'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final quickLogProvider = context.read<QuickLogProvider>();
      await quickLogProvider.deletePreset(widget.preset!.id);
      _showToast('Quick Log removed.');
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.roseExpense : const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final isDark = settingsProvider.isDarkMode(context);
    final currency = settingsProvider.currencySymbol;
    final isEditing = widget.preset != null;

    final parsedAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final displayTitle = _titleController.text.trim().isEmpty ? 'Quick Spend' : _titleController.text.trim();

    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
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
          physics: const BouncingScrollPhysics(),
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

              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(11),
                          gradient: const LinearGradient(
                            colors: [AppColors.amberWarning, Color(0xFFEA580C)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.amberWarning.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            CupertinoIcons.bolt_fill,
                            size: 19,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Edit Quick Log' : 'New Quick Log',
                            style: AppTextStyles.titleLarge.copyWith(
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '1-tap shortcut for your daily spends',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
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
              const SizedBox(height: 20),

              // Live Preview Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: isDark ? AppColors.darkSurface.withValues(alpha: 0.7) : const Color(0xFFF8FAFC),
                  border: Border.all(
                    color: _resolvedColor.withValues(alpha: isDark ? 0.35 : 0.25),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PREVIEW',
                          style: AppTextStyles.labelUppercase.copyWith(
                            fontSize: 10,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'How it looks on home screen',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Live Chip representation
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: isDark ? AppColors.darkCard : Colors.white,
                        border: Border.all(
                          color: _resolvedColor.withValues(alpha: 0.40),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _resolvedColor.withValues(alpha: 0.22),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: _resolvedColor,
                            ),
                            child: Center(
                              child: Icon(
                                _resolvedIcon,
                                size: 15,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            displayTitle,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            CurrencyFormatter.format(parsedAmount, symbol: currency),
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: _resolvedColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Quick Suggestions (if creating new)
              if (!isEditing) ...[
                Text(
                  'POPULAR SHORTCUTS',
                  style: AppTextStyles.labelUppercase.copyWith(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _suggestions.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      final item = _suggestions[i];
                      return LiquidPop(
                        pressedScale: 0.92,
                        onTap: () => _applySuggestion(item.$1, item.$2, item.$3, item.$4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9),
                            border: Border.all(
                              color: isDark ? const Color(0x22FFFFFF) : const Color(0x33000000),
                              width: 0.6,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(item.$4, size: 13, color: isDark ? Colors.white70 : Colors.black87),
                              const SizedBox(width: 6),
                              Text(
                                item.$1,
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                CurrencyFormatter.format(item.$2, symbol: currency),
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.royalIndigoLight,
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
              ],

              // Title input
              GlassTextField(
                controller: _titleController,
                hintText: 'e.g., Morning Chai, Metro, Daily Lunch',
                labelText: 'SHORTCUT TITLE',
                prefixIcon: CupertinoIcons.tag_fill,
                isDark: isDark,
                textStyle: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Amount input
              GlassTextField(
                controller: _amountController,
                hintText: '0.00',
                labelText: 'DEFAULT AMOUNT',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                prefixIcon: CupertinoIcons.money_dollar,
                isDark: isDark,
                textStyle: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 8),

              // Quick Amount Increment Row
              Row(
                children: [
                  for (final inc in [10.0, 20.0, 50.0, 100.0, 500.0])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: LiquidPop(
                          pressedScale: 0.90,
                          onTap: () => _addQuickAmount(inc),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9),
                              border: Border.all(
                                color: isDark ? const Color(0x1FFFFFFF) : const Color(0x40CBD5E1),
                                width: 0.6,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '+$currency${inc.toInt()}',
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.royalIndigoLight : AppColors.royalIndigo,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Category Selector
              Text(
                'CATEGORY',
                style: AppTextStyles.labelUppercase.copyWith(
                  fontSize: 11,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: DefaultCategories.categories.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (ctx, idx) {
                    final cat = DefaultCategories.categories[idx];
                    final isSel = cat.id == _selectedCategoryId;
                    return CategoryChip(
                      category: cat,
                      isSelected: isSel,
                      isDark: isDark,
                      onTap: () {
                        HapticHelper.selectionClick();
                        setState(() {
                          _selectedCategoryId = cat.id;
                          _selectedColorValue = null;
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Icon Picker
              Text(
                'ICON STYLE',
                style: AppTextStyles.labelUppercase.copyWith(
                  fontSize: 11,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _quickIcons.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 10),
                  itemBuilder: (ctx, idx) {
                    final icon = _quickIcons[idx];
                    final isSel = _selectedIconCodePoint == icon.codePoint ||
                        (_selectedIconCodePoint == null && icon.codePoint == _currentCategory.icon.codePoint);
                    return LiquidPop(
                      pressedScale: 0.90,
                      onTap: () {
                        HapticHelper.selectionClick();
                        setState(() {
                          _selectedIconCodePoint = icon.codePoint;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: isSel
                              ? _resolvedColor.withValues(alpha: isDark ? 0.35 : 0.20)
                              : (isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9)),
                          border: Border.all(
                            color: isSel ? _resolvedColor : (isDark ? const Color(0x1FFFFFFF) : const Color(0x33000000)),
                            width: isSel ? 1.6 : 0.6,
                          ),
                          boxShadow: isSel
                              ? [
                                  BoxShadow(
                                    color: _resolvedColor.withValues(alpha: 0.30),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Icon(
                            icon,
                            size: 18,
                            color: isSel ? _resolvedColor : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 28),

              // Save Button (Primary Liquid Glass Action)
              GlassButton(
                label: isEditing ? 'Update Quick Log' : 'Save Quick Log',
                icon: CupertinoIcons.checkmark_circle_fill,
                isDark: isDark,
                isLoading: _isSaving,
                onPressed: _handleSave,
                height: 54,
                borderRadius: 28,
              ),

              if (isEditing) ...[
                const SizedBox(height: 12),
                GlassButton(
                  label: 'Delete Quick Log',
                  icon: CupertinoIcons.trash_fill,
                  isDark: isDark,
                  variant: GlassButtonVariant.danger,
                  onPressed: _handleDelete,
                  height: 50,
                  borderRadius: 26,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
