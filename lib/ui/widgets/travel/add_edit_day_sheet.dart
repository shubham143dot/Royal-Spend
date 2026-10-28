import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/glass_decorations.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../data/models/itinerary_day.dart';
import '../glass_button.dart';
import '../glass_text_field.dart';
import '../liquid_pop.dart';

/// Modal bottom sheet for adding or editing an itinerary day in a trip.
class AddEditDaySheet extends StatefulWidget {
  final String tripId;
  final ItineraryDay? dayToEdit;
  final int defaultDayNumber;
  final DateTime defaultDate;
  final bool isDark;
  final ValueChanged<ItineraryDay> onSave;

  const AddEditDaySheet({
    super.key,
    required this.tripId,
    this.dayToEdit,
    required this.defaultDayNumber,
    required this.defaultDate,
    required this.isDark,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required String tripId,
    ItineraryDay? dayToEdit,
    required int defaultDayNumber,
    required DateTime defaultDate,
    required bool isDark,
    required ValueChanged<ItineraryDay> onSave,
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
        duration: const Duration(milliseconds: 320),
      ),
      builder: (ctx) => AddEditDaySheet(
        tripId: tripId,
        dayToEdit: dayToEdit,
        defaultDayNumber: defaultDayNumber,
        defaultDate: defaultDate,
        isDark: isDark,
        onSave: onSave,
      ),
    );
  }

  @override
  State<AddEditDaySheet> createState() => _AddEditDaySheetState();
}

class _AddEditDaySheetState extends State<AddEditDaySheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  late DateTime _selectedDate;
  late int _dayNumber;

  @override
  void initState() {
    super.initState();
    final d = widget.dayToEdit;
    _dayNumber = d?.dayNumber ?? widget.defaultDayNumber;
    _titleController = TextEditingController(
      text: d?.title ?? 'Day $_dayNumber Itinerary',
    );
    _notesController = TextEditingController(text: d?.notes ?? '');
    _selectedDate = d?.date ?? widget.defaultDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    HapticHelper.selectionClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.royalIndigo,
              brightness: widget.isDark ? Brightness.dark : Brightness.light,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;
    HapticHelper.success();

    final day = ItineraryDay(
      id: widget.dayToEdit?.id ?? const Uuid().v4(),
      tripId: widget.tripId,
      dayNumber: _dayNumber,
      date: _selectedDate,
      title: _titleController.text.trim(),
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    );

    widget.onSave(day);
    Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final dateFormat = DateFormat('EEE, d MMMM yyyy');

    return Container(
      decoration: GlassDecorations.glassModalDecoration(isDark: isDark),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x40FFFFFF) : const Color(0x33000000),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.dayToEdit == null ? 'Add Itinerary Day' : 'Edit Itinerary Day',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'DAY $_dayNumber',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Day Title Input
              GlassTextField(
                controller: _titleController,
                labelText: 'Day Theme / Title',
                hintText: 'e.g. Tiger Hill Sunrise & Tea Gardens',
                prefixIcon: CupertinoIcons.sparkles,
                isDark: isDark,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Please enter a day title' : null,
              ),
              const SizedBox(height: 14),

              // Date Picker Card
              Text(
                'DATE',
                style: AppTextStyles.labelUppercase.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 6),
              LiquidPop(
                onTap: () => _pickDate(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0x2BFFFFFF) : const Color(0xFFCBD5E1),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.25)
                            : const Color(0xFF64748B).withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 1.5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.calendar,
                        size: 20,
                        color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          dateFormat.format(_selectedDate),
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        CupertinoIcons.chevron_right,
                        size: 14,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Notes Input
              GlassTextField(
                controller: _notesController,
                labelText: 'Day Notes & Advice (Optional)',
                hintText: 'Morning wakeup time, what to carry, ticket reminders...',
                prefixIcon: CupertinoIcons.doc_text,
                maxLines: 2,
                isDark: isDark,
              ),
              const SizedBox(height: 22),

              // Save Action Button
              GlassButton(
                label: widget.dayToEdit == null ? 'Add Day' : 'Save Changes',
                icon: CupertinoIcons.check_mark,
                isDark: isDark,
                onPressed: _handleSave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
