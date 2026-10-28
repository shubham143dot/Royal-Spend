import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/glass_decorations.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../data/models/travel_split.dart';
import '../../../providers/travel_provider.dart';
import '../glass_button.dart';
import '../glass_text_field.dart';

class BillSplitDialog extends StatefulWidget {
  final String tripId;
  final bool isDark;

  const BillSplitDialog({
    super.key,
    required this.tripId,
    required this.isDark,
  });

  static Future<void> show(
    BuildContext context, {
    required String tripId,
    required bool isDark,
  }) {
    HapticHelper.mediumImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BillSplitDialog(tripId: tripId, isDark: isDark),
    );
  }

  @override
  State<BillSplitDialog> createState() => _BillSplitDialogState();
}

class _BillSplitDialogState extends State<BillSplitDialog> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  late List<String> _travelers;
  late String _paidBy;
  final Set<String> _includedTravelers = {};
  final String _splitType = 'equal'; // 'equal', 'exact'

  @override
  void initState() {
    super.initState();
    final trip = context.read<TravelProvider>().selectedTrip;
    _travelers = trip?.travelersNames.isNotEmpty == true
        ? trip!.travelersNames
        : ['You', 'Friend 1'];
    _paidBy = _travelers.first;
    _includedTravelers.addAll(_travelers);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    if (title.isEmpty || amount <= 0 || _includedTravelers.isEmpty) {
      HapticHelper.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title, valid amount, and select at least 1 person.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticHelper.success();

    final perPerson = amount / _includedTravelers.length;
    final Map<String, double> shares = {};
    for (final person in _includedTravelers) {
      shares[person] = double.parse(perPerson.toStringAsFixed(2));
    }

    final split = TravelSplit(
      id: const Uuid().v4(),
      tripId: widget.tripId,
      title: title,
      totalAmount: amount,
      paidBy: _paidBy,
      splitType: _splitType,
      shares: shares,
    );

    context.read<TravelProvider>().addSplit(split);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: GlassDecorations.glassModalDecoration(isDark: isDark),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color:
                      isDark ? const Color(0x40FFFFFF) : const Color(0x33000000),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Split Trip Expense',
              style: AppTextStyles.titleMedium.copyWith(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Easily split group bills, cabs, stays, or meals with zero confusion.',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 16),

            // Title
            GlassTextField(
              controller: _titleController,
              labelText: 'Expense Description',
              hintText: 'e.g. Siliguri to Darjeeling Shared Cab',
              prefixIcon: CupertinoIcons.tag,
              isDark: isDark,
            ),
            const SizedBox(height: 12),

            // Total Amount
            GlassTextField(
              controller: _amountController,
              labelText: 'Total Bill Amount (₹)',
              hintText: '0.00',
              prefixIcon: CupertinoIcons.money_dollar,
              keyboardType: TextInputType.number,
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            // Paid By Selector
            Text(
              'Paid By',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _travelers.map((traveler) {
                  final isPayer = _paidBy == traveler;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        HapticHelper.selectionClick();
                        setState(() => _paidBy = traveler);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: isPayer
                              ? (isDark
                                  ? AppColors.appleBlue
                                  : AppColors.royalIndigo)
                              : (isDark
                                  ? AppColors.darkSurface
                                  : Colors.black.withValues(alpha: 0.04)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isPayer
                                ? Colors.transparent
                                : (isDark
                                    ? const Color(0x1AFFFFFF)
                                    : const Color(0x1A000000)),
                            width: 0.6,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.person_crop_circle_fill,
                              size: 14,
                              color: isPayer
                                  ? Colors.white
                                  : (isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              traveler,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isPayer
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isPayer
                                    ? Colors.white
                                    : (isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Split Among Checkboxes
            Text(
              'Split Among (Equally)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _travelers.map((traveler) {
                final isIncluded = _includedTravelers.contains(traveler);
                return FilterChip(
                  label: Text(traveler),
                  selected: isIncluded,
                  onSelected: (val) {
                    HapticHelper.selectionClick();
                    setState(() {
                      if (val) {
                        _includedTravelers.add(traveler);
                      } else {
                        if (_includedTravelers.length > 1) {
                          _includedTravelers.remove(traveler);
                        }
                      }
                    });
                  },
                  selectedColor: (isDark
                          ? AppColors.appleGreen
                          : AppColors.vividMint)
                      .withValues(alpha: 0.25),
                  checkmarkColor:
                      isDark ? AppColors.appleGreen : AppColors.vividMint,
                  backgroundColor: isDark
                      ? AppColors.darkSurface
                      : Colors.black.withValues(alpha: 0.04),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isIncluded ? FontWeight.w700 : FontWeight.w500,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Save Split Button
            GlassButton(
              label: 'Save & Calculate Settlement',
              icon: CupertinoIcons.arrow_right_arrow_left,
              isDark: isDark,
              onPressed: _handleSave,
            ),
          ],
        ),
      ),
    );
  }
}
