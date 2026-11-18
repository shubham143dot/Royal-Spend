import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/glass_decorations.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../data/models/itinerary_activity.dart';
import '../../../data/models/travel_transport.dart';
import '../glass_button.dart';
import '../glass_text_field.dart';
import '../liquid_pop.dart';

/// Modal bottom sheet for adding or editing a transport connection with comprehensive
/// date, timing, provider, route, and booking details.
class AddEditTransportSheet extends StatefulWidget {
  final String tripId;
  final TravelTransport? transportToEdit;
  final bool isDark;
  final ValueChanged<TravelTransport> onSave;
  final VoidCallback? onDelete;

  const AddEditTransportSheet({
    super.key,
    required this.tripId,
    this.transportToEdit,
    required this.isDark,
    required this.onSave,
    this.onDelete,
  });

  static Future<void> show(
    BuildContext context, {
    required String tripId,
    TravelTransport? transportToEdit,
    required bool isDark,
    required ValueChanged<TravelTransport> onSave,
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
      builder: (ctx) => AddEditTransportSheet(
        tripId: tripId,
        transportToEdit: transportToEdit,
        isDark: isDark,
        onSave: onSave,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<AddEditTransportSheet> createState() => _AddEditTransportSheetState();
}

class _AddEditTransportSheetState extends State<AddEditTransportSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _depPlaceCtrl;
  late TextEditingController _arrPlaceCtrl;
  late TextEditingController _providerCtrl;
  late TextEditingController _bookingRefCtrl;
  late TextEditingController _costCtrl;
  late TextEditingController _notesCtrl;

  late TransportType _selectedType;
  late BookingStatus _selectedBookingStatus;

  late DateTime _departureDate;
  late TimeOfDay _departureTime;

  late DateTime _arrivalDate;
  late TimeOfDay _arrivalTime;

  final DateFormat _dateFormat = DateFormat('EEE, d MMM yyyy');

  @override
  void initState() {
    super.initState();
    final t = widget.transportToEdit;

    _depPlaceCtrl = TextEditingController(text: t?.departurePlace ?? '');
    _arrPlaceCtrl = TextEditingController(text: t?.arrivalPlace ?? '');
    _providerCtrl = TextEditingController(text: t?.provider ?? '');
    _bookingRefCtrl = TextEditingController(text: t?.bookingReference ?? '');
    _costCtrl = TextEditingController(
      text: t != null && t.cost > 0 ? t.cost.toStringAsFixed(0) : '',
    );
    _notesCtrl = TextEditingController(text: t?.notes ?? '');

    _selectedType = t?.type ?? TransportType.flight;
    _selectedBookingStatus = t?.bookingStatus ?? BookingStatus.planned;

    final now = DateTime.now();
    final dep = t?.departureTime ?? now;
    final arr = t?.arrivalTime ?? now.add(const Duration(hours: 3));

    _departureDate = DateTime(dep.year, dep.month, dep.day);
    _departureTime = TimeOfDay(hour: dep.hour, minute: dep.minute);

    _arrivalDate = DateTime(arr.year, arr.month, arr.day);
    _arrivalTime = TimeOfDay(hour: arr.hour, minute: arr.minute);
  }

  @override
  void dispose() {
    _depPlaceCtrl.dispose();
    _arrPlaceCtrl.dispose();
    _providerCtrl.dispose();
    _bookingRefCtrl.dispose();
    _costCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  DateTime get _combinedDepartureDateTime => DateTime(
        _departureDate.year,
        _departureDate.month,
        _departureDate.day,
        _departureTime.hour,
        _departureTime.minute,
      );

  DateTime get _combinedArrivalDateTime => DateTime(
        _arrivalDate.year,
        _arrivalDate.month,
        _arrivalDate.day,
        _arrivalTime.hour,
        _arrivalTime.minute,
      );

  String get _calculatedDurationText {
    final dep = _combinedDepartureDateTime;
    final arr = _combinedArrivalDateTime;
    final diff = arr.difference(dep);

    if (diff.isNegative) return 'Arrival is earlier than departure';

    final totalMinutes = diff.inMinutes;
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;

    final overnight = arr.day != dep.day;

    if (hours == 0) {
      return '$mins min${overnight ? ' (Overnight)' : ''}';
    } else if (mins == 0) {
      return '${hours}h${overnight ? ' (Overnight)' : ''}';
    } else {
      return '${hours}h ${mins}m${overnight ? ' (Overnight)' : ''}';
    }
  }

  Future<void> _pickDepartureDate() async {
    HapticHelper.selectionClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: _departureDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) => _calendarThemeWrapper(child!),
    );
    if (picked != null) {
      setState(() {
        _departureDate = picked;
        // If arrival was before new departure, adjust arrival date to match
        if (_arrivalDate.isBefore(_departureDate)) {
          _arrivalDate = _departureDate;
        }
      });
    }
  }

  Future<void> _pickDepartureTime() async {
    HapticHelper.selectionClick();
    final picked = await showTimePicker(
      context: context,
      initialTime: _departureTime,
      builder: (context, child) => _calendarThemeWrapper(child!),
    );
    if (picked != null) {
      setState(() {
        _departureTime = picked;
      });
    }
  }

  Future<void> _pickArrivalDate() async {
    HapticHelper.selectionClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: _arrivalDate.isBefore(_departureDate)
          ? _departureDate
          : _arrivalDate,
      firstDate: _departureDate,
      lastDate: DateTime(2035),
      builder: (context, child) => _calendarThemeWrapper(child!),
    );
    if (picked != null) {
      setState(() {
        _arrivalDate = picked;
      });
    }
  }

  Future<void> _pickArrivalTime() async {
    HapticHelper.selectionClick();
    final picked = await showTimePicker(
      context: context,
      initialTime: _arrivalTime,
      builder: (context, child) => _calendarThemeWrapper(child!),
    );
    if (picked != null) {
      setState(() {
        _arrivalTime = picked;
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

    final depPlace = _depPlaceCtrl.text.trim();
    final arrPlace = _arrPlaceCtrl.text.trim();
    final provider = _providerCtrl.text.trim();
    final bookingRef = _bookingRefCtrl.text.trim();
    final notes = _notesCtrl.text.trim();
    final cost = double.tryParse(_costCtrl.text.trim()) ?? 0.0;

    HapticHelper.success();

    final transport = TravelTransport(
      id: widget.transportToEdit?.id ?? const Uuid().v4(),
      tripId: widget.tripId,
      type: _selectedType,
      provider: provider.isNotEmpty ? provider : null,
      departurePlace: depPlace,
      arrivalPlace: arrPlace,
      departureTime: _combinedDepartureDateTime,
      arrivalTime: _combinedArrivalDateTime,
      bookingReference: bookingRef.isNotEmpty ? bookingRef : null,
      bookingStatus: _selectedBookingStatus,
      cost: cost,
      notes: notes.isNotEmpty ? notes : null,
      createdAt: widget.transportToEdit?.createdAt,
    );

    widget.onSave(transport);
    Navigator.pop(context);
  }

  void _confirmDelete() {
    HapticHelper.heavyImpact();
    showCupertinoDialog(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('Delete Transport Connection?'),
        content: Text(
          'Are you sure you want to delete this transport record for ${_providerCtrl.text.isNotEmpty ? _providerCtrl.text : _selectedType.displayName} (${_depPlaceCtrl.text} → ${_arrPlaceCtrl.text})?\n\nThis action cannot be undone.',
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
    final isEditing = widget.transportToEdit != null;

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
                                      ? AppColors.appleBlue
                                      : AppColors.royalIndigo)
                                  .withValues(alpha: 0.18),
                            ),
                            child: Icon(
                              _selectedType.icon,
                              size: 18,
                              color: isDark
                                  ? AppColors.appleBlue
                                  : AppColors.royalIndigo,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEditing
                                      ? 'Edit Transport'
                                      : 'Add Transport',
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
                                  'Flight, Train, Bus, Cab & Vehicle Details',
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

                // Transport Type Selector Chips
                Text(
                  'TRANSPORT TYPE',
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
                    children: TransportType.values.map((type) {
                      final isSel = _selectedType == type;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: GestureDetector(
                          onTap: () {
                            HapticHelper.selectionClick();
                            setState(() => _selectedType = type);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? (isDark
                                          ? AppColors.appleBlue
                                          : AppColors.royalIndigo)
                                      .withValues(alpha: 0.22)
                                  : (isDark
                                      ? AppColors.darkSurface
                                      : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSel
                                    ? (isDark
                                        ? AppColors.appleBlue
                                        : AppColors.royalIndigo)
                                    : (isDark
                                        ? const Color(0x22FFFFFF)
                                        : const Color(0xFFE2E8F0)),
                                width: isSel ? 1.4 : 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  type.icon,
                                  size: 14,
                                  color: isSel
                                      ? (isDark
                                          ? AppColors.appleBlue
                                          : AppColors.royalIndigo)
                                      : (isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  type.displayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSel
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSel
                                        ? (isDark
                                            ? Colors.white
                                            : AppColors.royalIndigo)
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

                // Departure & Arrival Location Inputs
                GlassTextField(
                  controller: _depPlaceCtrl,
                  labelText: 'Departure Location / Terminal',
                  hintText: 'e.g. T3 IGI Airport Delhi / Howrah Station',
                  prefixIcon: CupertinoIcons.arrow_up_right_circle_fill,
                  isDark: isDark,
                  autofocus: !isEditing,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Please enter departure location'
                      : null,
                ),
                const SizedBox(height: 12),

                GlassTextField(
                  controller: _arrPlaceCtrl,
                  labelText: 'Arrival Location / Station',
                  hintText: 'e.g. Bagdogra Airport / NJP Station',
                  prefixIcon: CupertinoIcons.arrow_down_left_circle_fill,
                  isDark: isDark,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Please enter arrival location'
                      : null,
                ),
                const SizedBox(height: 16),

                // Departure Timing Section
                Text(
                  'DEPARTURE DATE & TIMING',
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
                    // Departure Date Picker Button
                    Expanded(
                      flex: 3,
                      child: LiquidPop(
                        onTap: _pickDepartureDate,
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
                                    ? AppColors.appleBlue
                                    : AppColors.royalIndigo,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _dateFormat.format(_departureDate),
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

                    // Departure Time Picker Button
                    Expanded(
                      flex: 2,
                      child: LiquidPop(
                        onTap: _pickDepartureTime,
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
                                    ? AppColors.appleBlue
                                    : AppColors.royalIndigo,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  timeFormat.format(_combinedDepartureDateTime),
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

                // Arrival Timing Section
                Text(
                  'ARRIVAL DATE & TIMING',
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
                    // Arrival Date Picker Button
                    Expanded(
                      flex: 3,
                      child: LiquidPop(
                        onTap: _pickArrivalDate,
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
                                  _dateFormat.format(_arrivalDate),
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

                    // Arrival Time Picker Button
                    Expanded(
                      flex: 2,
                      child: LiquidPop(
                        onTap: _pickArrivalTime,
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
                                  timeFormat.format(_combinedArrivalDateTime),
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

                // Calculated Duration & Overnight badge
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
                        CupertinoIcons.stopwatch,
                        size: 14,
                        color: isDark
                            ? AppColors.appleBlue
                            : AppColors.royalIndigo,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Journey Duration: ',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                      Text(
                        _calculatedDurationText,
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
                const SizedBox(height: 16),

                // Carrier / Provider Input
                GlassTextField(
                  controller: _providerCtrl,
                  labelText: 'Carrier / Service / Vehicle Name',
                  hintText: 'e.g. IndiGo 6E-204, Vande Bharat Express, Uber',
                  prefixIcon: CupertinoIcons.tag_fill,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),

                // Booking Reference / PNR
                GlassTextField(
                  controller: _bookingRefCtrl,
                  labelText: 'PNR / Ticket / Confirmation Number (Optional)',
                  hintText: 'e.g. PNR: 8294729103, TKT-49204',
                  prefixIcon: CupertinoIcons.barcode,
                  isDark: isDark,
                ),
                const SizedBox(height: 14),

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
                    children: BookingStatus.values.map((status) {
                      final isSel = _selectedBookingStatus == status;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: GestureDetector(
                          onTap: () {
                            HapticHelper.selectionClick();
                            setState(() => _selectedBookingStatus = status);
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

                // Fare / Cost Input
                GlassTextField(
                  controller: _costCtrl,
                  labelText: 'Fare / Total Cost (₹)',
                  hintText: '0',
                  prefixIcon: CupertinoIcons.money_dollar_circle_fill,
                  keyboardType: TextInputType.number,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),

                // Notes Input
                GlassTextField(
                  controller: _notesCtrl,
                  labelText: 'Notes & Instructions (Optional)',
                  hintText: 'Terminal gate, baggage allowance, seat numbers...',
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
                            ? 'Update Transport'
                            : 'Save Transport',
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

