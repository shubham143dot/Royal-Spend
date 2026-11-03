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
import '../liquid_pop.dart';

class AddEditActivitySheet extends StatefulWidget {
  final String tripId;
  final String dayId;
  final ItineraryActivity? activityToEdit;
  final bool isDark;
  final ValueChanged<ItineraryActivity> onSave;
  final VoidCallback? onDelete;

  const AddEditActivitySheet({
    super.key,
    required this.tripId,
    required this.dayId,
    this.activityToEdit,
    required this.isDark,
    required this.onSave,
    this.onDelete,
  });

  static Future<void> show(
    BuildContext context, {
    required String tripId,
    required String dayId,
    ItineraryActivity? activityToEdit,
    required bool isDark,
    required ValueChanged<ItineraryActivity> onSave,
    VoidCallback? onDelete,
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
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<AddEditActivitySheet> createState() => _AddEditActivitySheetState();
}

class _AddEditActivitySheetState extends State<AddEditActivitySheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _placeController;
  late TextEditingController _locationController;
  late TextEditingController _titleController;
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;
  late TextEditingController _durationController;
  late TextEditingController _costController;
  late TextEditingController _notesController;

  late ActivityCategory _selectedCategory;
  late BookingStatus _selectedBookingStatus;

  final List<String> _quickDurations = [
    '30m',
    '45m',
    '1h',
    '1.5h',
    '2h',
    '3h',
    'Half Day',
  ];

  @override
  void initState() {
    super.initState();
    final a = widget.activityToEdit;

    _placeController = TextEditingController(text: a?.placeName ?? '');
    _locationController = TextEditingController(text: a?.address ?? '');
    _titleController = TextEditingController(text: a?.title ?? '');
    _startTimeController = TextEditingController(text: a?.startTime ?? '');
    _endTimeController = TextEditingController(text: a?.endTime ?? '');

    String durationText = '';
    if (a?.durationMinutes != null && a!.durationMinutes! > 0) {
      final mins = a.durationMinutes!;
      if (mins % 60 == 0) {
        durationText = '${mins ~/ 60}h';
      } else if (mins > 60) {
        durationText = '${mins ~/ 60}h ${mins % 60}m';
      } else {
        durationText = '${mins}m';
      }
    }
    _durationController = TextEditingController(text: durationText);

    _costController = TextEditingController(
      text: a != null && a.estimatedCost > 0
          ? a.estimatedCost.toStringAsFixed(0)
          : '',
    );
    _notesController = TextEditingController(text: a?.notes ?? '');

    _selectedCategory = a?.category ?? ActivityCategory.sightseeing;
    _selectedBookingStatus = a?.bookingStatus ?? BookingStatus.planned;
  }

  @override
  void dispose() {
    _placeController.dispose();
    _locationController.dispose();
    _titleController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _durationController.dispose();
    _costController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(
      BuildContext context, TextEditingController controller) async {
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

  int? _parseDurationMinutes(String raw) {
    if (raw.trim().isEmpty) return null;
    final text = raw.trim().toLowerCase();
    if (text.contains('half')) return 240; // 4 hours
    if (text.contains('full')) return 480; // 8 hours

    int totalMinutes = 0;
    final hourMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:h|hr|hour)').firstMatch(text);
    if (hourMatch != null) {
      final hours = double.tryParse(hourMatch.group(1)!) ?? 0.0;
      totalMinutes += (hours * 60).round();
    }

    final minMatch = RegExp(r'(\d+)\s*(?:m|min|minute)').firstMatch(text);
    if (minMatch != null) {
      final mins = int.tryParse(minMatch.group(1)!) ?? 0;
      totalMinutes += mins;
    }

    if (totalMinutes > 0) return totalMinutes;
    final directNum = int.tryParse(text);
    if (directNum != null) return directNum;
    return null;
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) {
      HapticHelper.heavyImpact();
      return;
    }

    final title = _titleController.text.trim();
    var placeName = _placeController.text.trim();
    if (placeName.isEmpty) {
      placeName = title;
    }

    HapticHelper.success();

    final cost = double.tryParse(_costController.text.trim()) ?? 0.0;
    final location = _locationController.text.trim();
    final durationMins = _parseDurationMinutes(_durationController.text);

    final activity = ItineraryActivity(
      id: widget.activityToEdit?.id ?? const Uuid().v4(),
      tripId: widget.tripId,
      dayId: widget.dayId,
      title: title,
      placeName: placeName.isNotEmpty ? placeName : title,
      address: location.isNotEmpty ? location : null,
      startTime: _startTimeController.text.trim().isNotEmpty
          ? _startTimeController.text.trim()
          : null,
      endTime: _endTimeController.text.trim().isNotEmpty
          ? _endTimeController.text.trim()
          : null,
      durationMinutes: durationMins,
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
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.activityToEdit != null;

    return Container(
      decoration: GlassDecorations.glassModalDecoration(isDark: isDark),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: SafeArea(
        top: false,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'Edit Itinerary Stop' : 'Add Stop to Day',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    LiquidPop(
                      pressedScale: 0.90,
                      onTap: () => Navigator.pop(context),
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

                // Title / Stop Name Field
                GlassTextField(
                  controller: _titleController,
                  labelText: 'Activity or Stop Title',
                  hintText: 'e.g. Sunrise view, Temple visit, Lunch & tea tasting',
                  prefixIcon: CupertinoIcons.tag,
                  isDark: isDark,
                  autofocus: !isEditing,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Place Name Field
                GlassTextField(
                  controller: _placeController,
                  labelText: 'Place Name (Optional)',
                  hintText: 'e.g. Japanese Peace Pagoda, Tiger Hill, Mall Road',
                  prefixIcon: CupertinoIcons.placemark_fill,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),

                // Location / Address Field
                GlassTextField(
                  controller: _locationController,
                  labelText: 'Location / Address (Optional)',
                  hintText: 'e.g. Jalapahar, West Bengal / Main Square',
                  prefixIcon: CupertinoIcons.map_pin_ellipse,
                  isDark: isDark,
                ),
                const SizedBox(height: 14),

                // Category Selector Chips
                Text(
                  'CATEGORY',
                  style: AppTextStyles.labelUppercase.copyWith(
                    fontSize: 11,
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
                                  ? cat.color.withValues(alpha: 0.22)
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
                                    fontWeight: isSel
                                        ? FontWeight.w700
                                        : FontWeight.w500,
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

                // Arrival & Departure Time
                Row(
                  children: [
                    Expanded(
                      child: GlassTextField(
                        controller: _startTimeController,
                        labelText: 'Arrival Time',
                        hintText: 'e.g. 10:30 AM',
                        prefixIcon: CupertinoIcons.time,
                        isDark: isDark,
                        suffix: IconButton(
                          icon: const Icon(CupertinoIcons.clock, size: 16),
                          onPressed: () =>
                              _pickTime(context, _startTimeController),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GlassTextField(
                        controller: _endTimeController,
                        labelText: 'Departure Time',
                        hintText: 'e.g. 12:00 PM',
                        prefixIcon: CupertinoIcons.time_solid,
                        isDark: isDark,
                        suffix: IconButton(
                          icon: const Icon(CupertinoIcons.clock, size: 16),
                          onPressed: () =>
                              _pickTime(context, _endTimeController),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Estimated Duration & Quick Chips
                GlassTextField(
                  controller: _durationController,
                  labelText: 'Estimated Duration',
                  hintText: 'e.g. 1h 30m, 2h',
                  prefixIcon: CupertinoIcons.stopwatch,
                  isDark: isDark,
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: _quickDurations.map((dur) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: GestureDetector(
                          onTap: () {
                            HapticHelper.selectionClick();
                            setState(() => _durationController.text = dur);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSurface
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _durationController.text == dur
                                    ? (isDark
                                        ? AppColors.appleBlue
                                        : AppColors.royalIndigo)
                                    : Colors.transparent,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              dur,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _durationController.text == dur
                                    ? (isDark
                                        ? AppColors.appleBlue
                                        : AppColors.royalIndigo)
                                    : (isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),

                // Estimated Expense & Booking Status
                Row(
                  children: [
                    Expanded(
                      child: GlassTextField(
                        controller: _costController,
                        labelText: 'Estimated Expense (₹)',
                        hintText: '0',
                        prefixIcon: CupertinoIcons.money_dollar,
                        keyboardType: TextInputType.number,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'STATUS',
                            style: AppTextStyles.labelUppercase.copyWith(
                              fontSize: 10,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 52,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
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
                                  fontSize: 12,
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
                                          width: 7,
                                          height: 7,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: status.badgeColor,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
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
                const SizedBox(height: 12),

                // Optional Notes
                GlassTextField(
                  controller: _notesController,
                  labelText: 'Optional Notes & Tips',
                  hintText: 'Entry tickets, opening times, photography rules...',
                  prefixIcon: CupertinoIcons.pencil,
                  maxLines: 2,
                  isDark: isDark,
                ),
                const SizedBox(height: 22),

                // Save Action Button
                GlassButton(
                  label: isEditing ? 'Update Activity' : 'Save Activity',
                  icon: CupertinoIcons.check_mark_circled_solid,
                  variant: GlassButtonVariant.primary,
                  isDark: isDark,
                  onPressed: _handleSave,
                ),

                if (isEditing && widget.onDelete != null) ...[
                  const SizedBox(height: 12),
                  LiquidPop(
                    onTap: () {
                      HapticHelper.heavyImpact();
                      showCupertinoDialog(
                        context: context,
                        builder: (dialogCtx) => CupertinoAlertDialog(
                          title: Text('Delete "${widget.activityToEdit!.title}"?'),
                          content: const Text(
                            'Are you sure you want to remove this stop from your itinerary?',
                          ),
                          actions: [
                            CupertinoDialogAction(
                              isDefaultAction: true,
                              onPressed: () => Navigator.pop(dialogCtx),
                              child: const Text('Cancel'),
                            ),
                            CupertinoDialogAction(
                              isDestructiveAction: true,
                              onPressed: () {
                                Navigator.pop(dialogCtx);
                                Navigator.pop(context);
                                widget.onDelete!();
                              },
                              child: const Text('Delete Stop'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: AppColors.roseExpense.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.roseExpense.withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.trash,
                              size: 15, color: AppColors.roseExpense),
                          SizedBox(width: 8),
                          Text(
                            'Delete Stop',
                            style: TextStyle(
                              fontSize: 13,
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
          ),
        ),
      ),
    );
  }
}
