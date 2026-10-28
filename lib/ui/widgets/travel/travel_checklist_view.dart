import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/glass_decorations.dart';
import '../../../core/theme/spring_curves.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../data/models/travel_checklist_item.dart';
import '../../../providers/travel_provider.dart';
import '../glass_button.dart';
import '../glass_card.dart';
import '../glass_text_field.dart';
import '../liquid_pop.dart';

class TravelChecklistView extends StatefulWidget {
  final bool isDark;

  const TravelChecklistView({super.key, required this.isDark});

  @override
  State<TravelChecklistView> createState() => _TravelChecklistViewState();
}

class _TravelChecklistViewState extends State<TravelChecklistView> {
  ChecklistCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final travelProvider = context.watch<TravelProvider>();
    final items = travelProvider.currentChecklist;
    final isDark = widget.isDark;

    final filtered = items.where((i) {
      if (_selectedCategory != null && i.category != _selectedCategory) {
        return false;
      }
      return true;
    }).toList();

    final completedCount = items.where((i) => i.isCompleted).length;
    final totalCount = items.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Preparation Progress Card
          GlassCard(
            isDark: isDark,
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Preparation Progress',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '$completedCount of $totalCount completed',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.appleGreen
                            : AppColors.vividMint,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: isDark
                        ? AppColors.darkSurface
                        : Colors.black.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= 1.0
                          ? AppColors.appleGreen
                          : (isDark
                              ? AppColors.appleBlue
                              : AppColors.royalIndigo),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Action: Add Checklist Item
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Packing & Travel Tasks',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              LiquidPop(
                onTap: () => _showAddItemDialog(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
                        .withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.add,
                        size: 14,
                        color: isDark
                            ? AppColors.appleBlue
                            : AppColors.royalIndigo,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Add Item',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.appleBlue
                              : AppColors.royalIndigo,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _CategoryChip(
                  label: 'All Items',
                  isSelected: _selectedCategory == null,
                  isDark: isDark,
                  onTap: () {
                    HapticHelper.selectionClick();
                    setState(() => _selectedCategory = null);
                  },
                ),
                ...ChecklistCategory.values.map((cat) {
                  return _CategoryChip(
                    label: cat.displayName,
                    icon: cat.icon,
                    isSelected: _selectedCategory == cat,
                    isDark: isDark,
                    onTap: () {
                      HapticHelper.selectionClick();
                      setState(() => _selectedCategory = cat);
                    },
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4. Checklist Items
          if (filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 36.0),
                child: Text(
                  'No checklist items in this category.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final item = filtered[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: GlassCard(
                    isDark: isDark,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14.0, vertical: 12.0),
                    borderRadius: 14,
                    onTap: () {
                      HapticHelper.selectionClick();
                      travelProvider.toggleChecklistItem(item);
                    },
                    child: Row(
                      children: [
                        // Checkbox with spring pop transition
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (child, anim) => ScaleTransition(
                            scale: CurvedAnimation(
                              parent: anim,
                              curve: IOSSpringCurve.bouncy,
                            ),
                            child: child,
                          ),
                          child: Icon(
                            item.isCompleted
                                ? CupertinoIcons.check_mark_circled_solid
                                : CupertinoIcons.circle,
                            key: ValueKey<bool>(item.isCompleted),
                            size: 20,
                            color: item.isCompleted
                                ? AppColors.appleGreen
                                : (isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Item title & Category
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.item,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                  decoration: item.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.category.displayName,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: item.category.color,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Delete
                        GestureDetector(
                          onTap: () {
                            HapticHelper.mediumImpact();
                            travelProvider.deleteChecklistItem(item.id);
                          },
                          child: Icon(
                            CupertinoIcons.trash,
                            size: 14,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showAddItemDialog(BuildContext context) {
    final itemCtrl = TextEditingController();
    ChecklistCategory cat = ChecklistCategory.clothing;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration:
              GlassDecorations.glassModalDecoration(isDark: widget.isDark),
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? const Color(0x40FFFFFF)
                        : const Color(0x33000000),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Add Checklist Item',
                style: AppTextStyles.titleMedium.copyWith(
                  color: widget.isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              GlassTextField(
                controller: itemCtrl,
                labelText: 'Task or Item Description',
                hintText: 'e.g. Woolen gloves & thermal jacket',
                prefixIcon: CupertinoIcons.tag,
                isDark: widget.isDark,
              ),
              const SizedBox(height: 14),
              Text(
                'Category',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonHideUnderline(
                child: DropdownButton<ChecklistCategory>(
                  value: cat,
                  isExpanded: true,
                  dropdownColor:
                      widget.isDark ? AppColors.darkCard : Colors.white,
                  items: ChecklistCategory.values.map((c) {
                    return DropdownMenuItem(
                      value: c,
                      child: Row(
                        children: [
                          Icon(c.icon, size: 14, color: c.color),
                          const SizedBox(width: 8),
                          Text(c.displayName),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setSheetState(() => cat = v);
                    }
                  },
                ),
              ),
              const SizedBox(height: 18),
              GlassButton(
                label: 'Add to Checklist',
                icon: CupertinoIcons.check_mark,
                isDark: widget.isDark,
                onPressed: () {
                  if (itemCtrl.text.trim().isEmpty) return;
                  final tripId =
                      context.read<TravelProvider>().selectedTrip?.id;
                  if (tripId == null) return;

                  final item = TravelChecklistItem(
                    id: const Uuid().v4(),
                    tripId: tripId,
                    category: cat,
                    item: itemCtrl.text.trim(),
                  );
                  context.read<TravelProvider>().addChecklistItem(item);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
                : (isDark
                    ? AppColors.darkSurface
                    : Colors.black.withValues(alpha: 0.04)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 12,
                  color: isSelected
                      ? Colors.white
                      : (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
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
    );
  }
}
