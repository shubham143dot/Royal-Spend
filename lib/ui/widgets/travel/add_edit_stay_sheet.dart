import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/glass_decorations.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../data/models/travel_accommodation.dart';
import '../glass_button.dart';
import '../glass_text_field.dart';
import '../liquid_pop.dart';

/// Modal bottom sheet for adding or editing an accommodation/stay with comprehensive
/// check-in/out dates, timings, night calculation, booking status, and contact details.
class AddEditStaySheet extends StatefulWidget {
  final String tripId;
  final TravelAccommodation? accommodationToEdit;
  final bool isDark;
  final ValueChanged<TravelAccommodation> onSave;
  final VoidCallback? onDelete;

  const AddEditStaySheet({
    super.key,
    required this.tripId,
    this.accommodationToEdit,
    required this.isDark,
    required this.onSave,
    this.onDelete,
  });

  static Future<void> show(
    BuildContext context, {
    required String tripId,
    TravelAccommodation? accommodationToEdit,
    required bool isDark,
    required ValueChanged<TravelAccommodation> onSave,
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
      builder: (ctx) => AddEditStaySheet(
        tripId: tripId,
        accommodationToEdit: accommodationToEdit,
        isDark: isDark,
        onSave: onSave,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<AddEditStaySheet> createState() => _AddEditStaySheetState();
}

class _AddEditStaySheetState extends State<AddEditStaySheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _bookingRefCtrl;
  late TextEditingController _contactCtrl;
  late TextEditingController _costCtrl;
  late TextEditingController _notesCtrl;

  late AccommodationStatus _selectedStatus;

  late DateTime _checkInDate;
  late TimeOfDay _checkInTime;

  late DateTime _checkOutDate;
  late TimeOfDay _checkOutTime;

  final DateFormat _dateFormat = DateFormat('EEE, d MMM yyyy');

  @override
  void initState() {
    super.initState();
    final a = widget.accommodationToEdit;

    _nameCtrl = TextEditingController(text: a?.propertyName ?? '');
    _addressCtrl = TextEditingController(text: a?.address ?? '');
    _bookingRefCtrl = TextEditingController(text: a?.bookingReference ?? '');
    _contactCtrl = TextEditingController(text: a?.contactInfo ?? '');
    _costCtrl = TextEditingController(
      text: a != null && a.cost > 0 ? a.cost.toStringAsFixed(0) : '',
    );
    _notesCtrl = TextEditingController(text: a?.notes ?? '');

    _selectedStatus = a?.bookingStatus ?? AccommodationStatus.planned;

    final now = DateTime.now();
    final inTime = a?.checkIn ?? DateTime(now.year, now.month, now.day, 14, 0); // 2:00 PM
    final outTime = a?.checkOut ?? DateTime(now.year, now.month, now.day + 2, 11, 0); // 11:00 AM

    _checkInDate = DateTime(inTime.year, inTime.month, inTime.day);
    _checkInTime = TimeOfDay(hour: inTime.hour, minute: inTime.minute);

    _checkOutDate = DateTime(outTime.year, outTime.month, outTime.day);
    _checkOutTime = TimeOfDay(hour: outTime.hour, minute: outTime.minute);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _bookingRefCtrl.dispose();
    _contactCtrl.dispose();
    _costCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  DateTime get _combinedCheckInDateTime => DateTime(
        _checkInDate.year,
        _checkInDate.month,
        _checkInDate.day,
        _checkInTime.hour,
        _checkInTime.minute,
      );

  DateTime get _combinedCheckOutDateTime => DateTime(
        _checkOutDate.year,
        _checkOutDate.month,
        _checkOutDate.day,
        _checkOutTime.hour,
        _checkOutTime.minute,
      );

  int get _nightsCount {
    final start =
        DateTime(_checkInDate.year, _checkInDate.month, _checkInDate.day);
    final end =
        DateTime(_checkOutDate.year, _checkOutDate.month, _checkOutDate.day);
    final diff = end.difference(start).inDays;
    return diff > 0 ? diff : 1;
  }

  Future<void> _pickCheckInDate() async {
    HapticHelper.selectionClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: _checkInDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) => _calendarThemeWrapper(child!),
    );
    if (picked != null) {
      setState(() {
        _checkInDate = picked;
        if (_checkOutDate.isBefore(_checkInDate)) {
          _checkOutDate = _checkInDate.add(const Duration(days: 1));
        }
      });
    }
  }

  Future<void> _pickCheckInTime() async {
    HapticHelper.selectionClick();
    final picked = await showTimePicker(
      context: context,
      initialTime: _checkInTime,
      builder: (context, child) => _calendarThemeWrapper(child!),
    );
    if (picked != null) {
      setState(() {
        _checkInTime = picked;
      });
    }
  }

  Future<void> _pickCheckOutDate() async {
    HapticHelper.selectionClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: _checkOutDate.isBefore(_checkInDate)
          ? _checkInDate.add(const Duration(days: 1))
          : _checkOutDate,
      firstDate: _checkInDate,
      lastDate: DateTime(2035),
      builder: (context, child) => _calendarThemeWrapper(child!),
    );
    if (picked != null) {
      setState(() {
        _checkOutDate = picked;
      });
    }
  }

  Future<void> _pickCheckOutTime() async {
    HapticHelper.selectionClick();
    final picked = await showTimePicker(
      context: context,
      initialTime: _checkOutTime,
      builder: (context, child) => _calendarThemeWrapper(child!),
    );
    if (picked != null) {
      setState(() {
        _checkOutTime = picked;
      });
    }
  }

  Widget _calendarThemeWrapper(Widget child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.royalIndigo,
          brightness: widget.isDark ? Brightness.dark : Brightness.light,
        ),
      ),
      child: child,
    );
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) {
      HapticHelper.heavyImpact();
      return;
    }

    final name = _nameCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final bookingRef = _bookingRefCtrl.text.trim();
    final contact = _contactCtrl.text.trim();
    final notes = _notesCtrl.text.trim();
    final cost = double.tryParse(_costCtrl.text.trim()) ?? 0.0;

    HapticHelper.success();

    final accommodation = TravelAccommodation(
      id: widget.accommodationToEdit?.id ?? const Uuid().v4(),
      tripId: widget.tripId,
      propertyName: name,
      address: address.isNotEmpty ? address : null,
      checkIn: _combinedCheckInDateTime,
      checkOut: _combinedCheckOutDateTime,
      bookingStatus: _selectedStatus,
      cost: cost,
      bookingReference: bookingRef.isNotEmpty ? bookingRef : null,
      contactInfo: contact.isNotEmpty ? contact : null,
      notes: notes.isNotEmpty ? notes : null,
      createdAt: widget.accommodationToEdit?.createdAt,
    );

    widget.onSave(accommodation);
    Navigator.pop(context);
  }

  void _confirmDelete() {
    HapticHelper.heavyImpact();
    showCupertinoDialog(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('Delete Accommodation?'),
        content: Text(
          'Are you sure you want to delete this stay record for "${_nameCtrl.text.trim()}"?\n\nThis action cannot be undone.',
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
              widget.onDelete?.call();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.accommodationToEdit != null;

    final timeFormat = DateFormat('h:mm a');

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
                // Top drag handle
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
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (isDark
                                      ? AppColors.appleGreen
                                      : AppColors.vividMint)
                                  .withValues(alpha: 0.18),
                            ),
                            child: Icon(
                              CupertinoIcons.bed_double_fill,
                              size: 18,
                              color: isDark
                                  ? AppColors.appleGreen
                                  : AppColors.vividMint,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEditing
                                      ? 'Edit Accommodation'
                                      : 'Add Accommodation',
                                  style: AppTextStyles.titleMedium.copyWith(
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Hotel, Resort, Homestay & Stay Details',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
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
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
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

                // Property Name Field
                GlassTextField(
                  controller: _nameCtrl,
                  labelText: 'Property / Hotel / Homestay Name',
                  hintText: 'e.g. Mayfair Tea Resort, Live In Nature Homestay',
                  prefixIcon: CupertinoIcons.house_fill,
                  isDark: isDark,
                  autofocus: !isEditing,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Please enter property name'
                      : null,
                ),
                const SizedBox(height: 12),

                // Address / Location Field
                GlassTextField(
                  controller: _addressCtrl,
                  labelText: 'Address or Area (Optional)',
                  hintText: 'e.g. Promenade Road, Lebong, Darjeeling',
                  prefixIcon: CupertinoIcons.placemark,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),

                // Check-in Date & Timing Section
                Text(
                  'CHECK-IN DATE & TIMING',
                  style: AppTextStyles.labelUppercase.copyWith(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    // Check-in Date Picker Button
                    Expanded(
                      flex: 3,
                      child: LiquidPop(
                        onTap: _pickCheckInDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurface
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0x2BFFFFFF)
                                  : const Color(0xFFCBD5E1),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                CupertinoIcons.calendar,
                                size: 16,
                                color: isDark
                                    ? AppColors.appleGreen
                                    : AppColors.vividMint,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _dateFormat.format(_checkInDate),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Check-in Time Picker Button
                    Expanded(
                      flex: 2,
                      child: LiquidPop(
                        onTap: _pickCheckInTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurface
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0x2BFFFFFF)
                                  : const Color(0xFFCBD5E1),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                CupertinoIcons.clock_fill,
                                size: 16,
                                color: isDark
                                    ? AppColors.appleGreen
                                    : AppColors.vividMint,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  timeFormat.format(_combinedCheckInDateTime),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Check-out Date & Timing Section
                Text(
                  'CHECK-OUT DATE & TIMING',
                  style: AppTextStyles.labelUppercase.copyWith(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    // Check-out Date Picker Button
                    Expanded(
                      flex: 3,
                      child: LiquidPop(
                        onTap: _pickCheckOutDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurface
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0x2BFFFFFF)
                                  : const Color(0xFFCBD5E1),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                CupertinoIcons.calendar,
                                size: 16,
                                color: isDark
                                    ? AppColors.applePurple
                                    : AppColors.violetAccent,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _dateFormat.format(_checkOutDate),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Check-out Time Picker Button
                    Expanded(
                      flex: 2,
                      child: LiquidPop(
                        onTap: _pickCheckOutTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurface
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0x2BFFFFFF)
                                  : const Color(0xFFCBD5E1),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                CupertinoIcons.clock_fill,
                                size: 16,
                                color: isDark
                                    ? AppColors.applePurple
                                    : AppColors.violetAccent,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  timeFormat.format(_combinedCheckOutDateTime),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Calculated Nights Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0x18FFFFFF)
                        : const Color(0x0C000000),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? const Color(0x18FFFFFF)
                          : const Color(0x10000000),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.moon_stars_fill,
                        size: 14,
                        color: isDark
                            ? AppColors.applePurple
                            : AppColors.violetAccent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Total Stay: ',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                      Text(
                        '$_nightsCount ${_nightsCount == 1 ? "Night" : "Nights"}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.applePurple
                              : AppColors.violetAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Booking Status Selector Chips
                Text(
                  'BOOKING STATUS',
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
                    children: AccommodationStatus.values.map((status) {
                      final isSel = _selectedStatus == status;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: GestureDetector(
                          onTap: () {
                            HapticHelper.selectionClick();
                            setState(() => _selectedStatus = status);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? status.badgeColor.withValues(alpha: 0.22)
                                  : (isDark
                                      ? AppColors.darkSurface
                                      : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSel
                                    ? status.badgeColor
                                    : (isDark
                                        ? const Color(0x22FFFFFF)
                                        : const Color(0xFFE2E8F0)),
                                width: isSel ? 1.4 : 0.8,
                              ),
                            ),
                            child: Text(
                              status.displayName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSel
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSel
                                    ? (isDark ? Colors.white : status.badgeColor)
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
                const SizedBox(height: 16),

                // Booking Reference / Confirmation Code
                GlassTextField(
                  controller: _bookingRefCtrl,
                  labelText: 'Booking Reference / Confirmation Code (Optional)',
                  hintText: 'e.g. Booking.com #92847291 / MMT-29402',
                  prefixIcon: CupertinoIcons.barcode,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),

                // Contact Info
                GlassTextField(
                  controller: _contactCtrl,
                  labelText: 'Contact Phone / Host / Email (Optional)',
                  hintText: 'e.g. +91 98765 43210, frontdesk@hotel.com',
                  prefixIcon: CupertinoIcons.phone_fill,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),

                // Cost Input
                GlassTextField(
                  controller: _costCtrl,
                  labelText: 'Estimated Stay Cost / Total Rate (₹)',
                  hintText: '0',
                  prefixIcon: CupertinoIcons.money_dollar_circle_fill,
                  keyboardType: TextInputType.number,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),

                // Notes Input
                GlassTextField(
                  controller: _notesCtrl,
                  labelText: 'Notes & Preferences (Optional)',
                  hintText: 'Mountain view room, breakfast included, extra bed...',
                  prefixIcon: CupertinoIcons.doc_plaintext,
                  maxLines: 2,
                  isDark: isDark,
                ),
                const SizedBox(height: 22),

                // Action Buttons (Save + Delete if editing)
                Row(
                  children: [
                    if (isEditing && widget.onDelete != null) ...[
                      Expanded(
                        child: GlassButton(
                          label: 'Delete',
                          icon: CupertinoIcons.trash,
                          variant: GlassButtonVariant.danger,
                          onPressed: _confirmDelete,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: 2,
                      child: GlassButton(
                        label: isEditing
                            ? 'Update Accommodation'
                            : 'Save Accommodation',
                        icon: CupertinoIcons.checkmark_alt,
                        variant: GlassButtonVariant.primary,
                        onPressed: _handleSave,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

