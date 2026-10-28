import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/glass_decorations.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../data/models/itinerary_activity.dart';
import '../glass_button.dart';
import '../glass_text_field.dart';

class AddEditActivitySheet extends StatefulWidget {
  final String tripId;
  final String dayId;
  final ItineraryActivity? activityToEdit;
  final bool isDark;
  final ValueChanged<ItineraryActivity> onSave;

  const AddEditActivitySheet({
    super.key,
    required this.tripId,
    required this.dayId,
    this.activityToEdit,
    required this.isDark,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required String tripId,
    required String dayId,
    ItineraryActivity? activityToEdit,
    required bool isDark,
    required ValueChanged<ItineraryActivity> onSave,
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
      builder: (ctx) => AddEditActivitySheet(
        tripId: tripId,
        dayId: dayId,
        activityToEdit: activityToEdit,
        isDark: isDark,
        onSave: onSave,
      ),
    );
  }

  @override
  State<AddEditActivitySheet> createState() => _AddEditActivitySheetState();
}

class _AddEditActivitySheetState extends State<AddEditActivitySheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _placeController;
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;
  late TextEditingController _costController;
  late TextEditingController _notesController;

  late ActivityCategory _selectedCategory;
  late BookingStatus _selectedBookingStatus;

  @override
  void initState() {
    super.initState();
    final a = widget.activityToEdit;
    _titleController = TextEditingController(text: a?.title ?? '');
    _placeController = TextEditingController(text: a?.placeName ?? '');
    _startTimeController = TextEditingController(text: a?.startTime ?? '');
    _endTimeController = TextEditingController(text: a?.endTime ?? '');
    _costController = TextEditingController(
        text: a != null && a.estimatedCost > 0
            ? a.estimatedCost.toStringAsFixed(0)
            : '');
    _notesController = TextEditingController(text: a?.notes ?? '');

    _selectedCategory = a?.category ?? ActivityCategory.sightseeing;
    _selectedBookingStatus = a?.bookingStatus ?? BookingStatus.unconfirmed;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _placeController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _costController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(BuildContext context, TextEditingController controller) async {
    HapticHelper.selectionClick();
    final localizations = MaterialLocalizations.of(context);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
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

    if (picked != null && mounted) {
      controller.text = localizations.formatTimeOfDay(picked);
    }
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;
    HapticHelper.success();

    final cost = double.tryParse(_costController.text.trim()) ?? 0.0;
    final activity = ItineraryActivity(
      id: widget.activityToEdit?.id ?? const Uuid().v4(),
      tripId: widget.tripId,
      dayId: widget.dayId,
      title: _titleController.text.trim(),
      placeName: _placeController.text.trim().isNotEmpty
          ? _placeController.text.trim()
          : null,
      startTime: _startTimeController.text.trim().isNotEmpty
          ? _startTimeController.text.trim()
          : null,
      endTime: _endTimeController.text.trim().isNotEmpty
          ? _endTimeController.text.trim()
          : null,
      category: _selectedCategory,
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
      estimatedCost: cost,
      bookingStatus: _selectedBookingStatus,
      isCompleted: widget.activityToEdit?.isCompleted ?? false,
      isDestinationConfirmed:
          widget.activityToEdit?.isDestinationConfirmed ?? true,
      sortOrder: widget.activityToEdit?.sortOrder ?? 0,
    );

    widget.onSave(activity);
    Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

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
                    color: isDark
                        ? const Color(0x40FFFFFF)
                        : const Color(0x33000000),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title Header
              Text(
                widget.activityToEdit == null
                    ? 'Add Stop to Itinerary'
                    : 'Edit Activity',
                style: AppTextStyles.titleMedium.copyWith(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),

              // Activity Title
              GlassTextField(
                controller: _titleController,
                labelText: 'Activity or Stop Title',
                hintText: 'e.g. Visit Japanese Peace Pagoda',
                prefixIcon: CupertinoIcons.tag,
                isDark: isDark,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 14),

              // Place Name
              GlassTextField(
                controller: _placeController,
                labelText: 'Place / Destination Name (Optional)',
                hintText: 'e.g. Japanese Peace Pagoda, Darjeeling',
                prefixIcon: CupertinoIcons.placemark,
                isDark: isDark,
              ),
              const SizedBox(height: 14),

              // Category Picker Chips
              Text(
                'CATEGORY',
                style: AppTextStyles.labelUppercase.copyWith(
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
                  children: ActivityCategory.values.map((cat) {
                    final isSel = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: GestureDetector(
                        onTap: () {
                          HapticHelper.selectionClick();
                          setState(() => _selectedCategory = cat);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSel
                                ? cat.color.withValues(alpha: 0.20)
                                : (isDark
                                    ? AppColors.darkSurface
                                    : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSel
                                  ? cat.color
                                  : (isDark
                                      ? const Color(0x22FFFFFF)
                                      : const Color(0xFFE2E8F0)),
                              width: isSel ? 1.4 : 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(cat.icon, size: 14, color: cat.color),
                              const SizedBox(width: 6),
                              Text(
                                cat.displayName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight:
                                      isSel ? FontWeight.w700 : FontWeight.w500,
                                  color: isSel
                                      ? (isDark ? Colors.white : cat.color)
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
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Time Fields (Start & End Time)
              Row(
                children: [
                  Expanded(
                    child: GlassTextField(
                      controller: _startTimeController,
                      labelText: 'Start Time',
                      hintText: 'e.g. 10:30 AM',
                      prefixIcon: CupertinoIcons.time,
                      isDark: isDark,
                      suffix: IconButton(
                        icon: const Icon(CupertinoIcons.clock, size: 16),
                        onPressed: () => _pickTime(context, _startTimeController),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GlassTextField(
                      controller: _endTimeController,
                      labelText: 'End Time',
                      hintText: 'e.g. 01:00 PM',
                      prefixIcon: CupertinoIcons.time_solid,
                      isDark: isDark,
                      suffix: IconButton(
                        icon: const Icon(CupertinoIcons.clock, size: 16),
                        onPressed: () => _pickTime(context, _endTimeController),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Estimated Cost & Booking Status
              Row(
                children: [
                  Expanded(
                    child: GlassTextField(
                      controller: _costController,
                      labelText: 'Estimated Cost (₹)',
                      hintText: '0',
                      prefixIcon: CupertinoIcons.money_dollar,
                      keyboardType: TextInputType.number,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BOOKING STATUS',
                          style: AppTextStyles.labelUppercase.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurface
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0x2BFFFFFF)
                                  : const Color(0xFFCBD5E1),
                              width: 0.8,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<BookingStatus>(
                              value: _selectedBookingStatus,
                              isExpanded: true,
                              dropdownColor: isDark
                                  ? AppColors.darkCard
                                  : Colors.white,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                              items: BookingStatus.values.map((status) {
                                return DropdownMenuItem(
                                  value: status,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: status.badgeColor,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(status.displayName),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _selectedBookingStatus = v);
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
              const SizedBox(height: 14),

              // Notes
              GlassTextField(
                controller: _notesController,
                labelText: 'Notes & Travel Advice',
                hintText: 'Opening hours, transport tips, what to pack...',
                prefixIcon: CupertinoIcons.pencil,
                maxLines: 2,
                isDark: isDark,
              ),
              const SizedBox(height: 20),

              // Submit Button
              GlassButton(
                label: widget.activityToEdit == null
                    ? 'Save Activity'
                    : 'Update Activity',
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
