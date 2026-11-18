import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/glass_decorations.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../data/models/itinerary_day.dart';
import '../../../providers/travel_provider.dart';
import '../glass_button.dart';
import '../glass_text_field.dart';
import '../liquid_pop.dart';
import '../maps/places_autocomplete_dialog.dart';

enum StartingPointType {
  hotel('Hotel / Stay', CupertinoIcons.bed_double_fill, Color(0xFF30D158)),
  airport('Airport', CupertinoIcons.airplane, Color(0xFF0A84FF)),
  home('Home / Base', CupertinoIcons.house_fill, Color(0xFFFF9F0A)),
  station('Train / Bus Hub', CupertinoIcons.tram_fill, Color(0xFFBF5AF2)),
  custom('Custom Spot', CupertinoIcons.placemark_fill, Color(0xFF64D2FF));

  final String label;
  final IconData icon;
  final Color color;

  const StartingPointType(this.label, this.icon, this.color);
}

/// A dedicated iOS Liquid Glass bottom sheet for configuring the daily journey Starting Point.
class SetStartingPointSheet extends StatefulWidget {
  final ItineraryDay day;
  final bool isDark;
  final void Function(ItineraryDay updatedDay) onSave;

  const SetStartingPointSheet({
    super.key,
    required this.day,
    required this.isDark,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required ItineraryDay day,
    required bool isDark,
    required void Function(ItineraryDay updatedDay) onSave,
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
      builder: (ctx) => SetStartingPointSheet(
        day: day,
        isDark: isDark,
        onSave: onSave,
      ),
    );
  }

  @override
  State<SetStartingPointSheet> createState() => _SetStartingPointSheetState();
}

class _SetStartingPointSheetState extends State<SetStartingPointSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _placeController;
  late TextEditingController _addressController;
  late TextEditingController _timeController;
  late TextEditingController _notesController;

  late StartingPointType _selectedType;
  double? _startLatitude;
  double? _startLongitude;
  String? _startPlaceId;

  final List<String> _quickTimes = [
    '07:30 AM',
    '08:00 AM',
    '08:30 AM',
    '09:00 AM',
    '09:30 AM',
    '10:00 AM',
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.day;

    _placeController = TextEditingController(text: d.startPlaceName ?? '');
    _addressController = TextEditingController(text: d.startAddress ?? '');
    _timeController = TextEditingController(text: d.startTime ?? '08:30 AM');
    _notesController = TextEditingController(text: d.startNotes ?? '');
    _startLatitude = d.startLatitude;
    _startLongitude = d.startLongitude;
    _startPlaceId = d.startPlaceId;

    _selectedType = _resolveType(d.startType, d.startPlaceName);
  }

  Future<void> _searchGooglePlaces() async {
    final details = await PlacesAutocompleteDialog.show(
      context,
      title: 'Search Starting Point',
      hintText: 'Search hotels, airport, station, or address...',
      isDark: widget.isDark,
    );

    if (details != null && mounted) {
      setState(() {
        _placeController.text = details.name;
        _addressController.text = details.formattedAddress;
        _startLatitude = details.latitude;
        _startLongitude = details.longitude;
        _startPlaceId = details.id;
        _selectedType = _resolveType(details.bestCategory, details.name);
      });
    }
  }

  StartingPointType _resolveType(String? rawType, String? placeName) {
    if (rawType != null) {
      for (final t in StartingPointType.values) {
        if (t.name.toLowerCase() == rawType.toLowerCase()) return t;
      }
    }
    final lower = (placeName ?? '').toLowerCase();
    if (lower.contains('hotel') ||
        lower.contains('resort') ||
        lower.contains('stay') ||
        lower.contains('airbnb') ||
        lower.contains('inn')) {
      return StartingPointType.hotel;
    }
    if (lower.contains('airport') || lower.contains('terminal')) {
      return StartingPointType.airport;
    }
    if (lower.contains('station') ||
        lower.contains('junction') ||
        lower.contains('bus')) {
      return StartingPointType.station;
    }
    if (lower.contains('home')) {
      return StartingPointType.home;
    }
    return StartingPointType.hotel;
  }

  @override
  void dispose() {
    _placeController.dispose();
    _addressController.dispose();
    _timeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(BuildContext context) async {
    HapticHelper.selectionClick();
    final localizations = MaterialLocalizations.of(context);
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 30),
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
      _timeController.text = localizations.formatTimeOfDay(picked);
    }
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) {
      HapticHelper.heavyImpact();
      return;
    }

    final place = _placeController.text.trim();
    final address = _addressController.text.trim();
    final time = _timeController.text.trim();
    final notes = _notesController.text.trim();

    HapticHelper.success();

    final updated = widget.day.copyWith(
      startPlaceName: place,
      startAddress: address.isNotEmpty ? address : null,
      startLatitude: _startLatitude,
      startLongitude: _startLongitude,
      startPlaceId: _startPlaceId,
      startTime: time.isNotEmpty ? time : null,
      startNotes: notes.isNotEmpty ? notes : null,
      startType: _selectedType.name,
    );

    widget.onSave(updated);
    Navigator.pop(context);
  }

  void _handleClear() {
    HapticHelper.mediumImpact();
    final updated = widget.day.copyWith(
      clearStartPlaceName: true,
      clearStartAddress: true,
      clearStartCoordinates: true,
      clearStartPlaceId: true,
      clearStartTime: true,
      clearStartNotes: true,
      clearStartType: true,
    );
    widget.onSave(updated);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final travelProvider = context.watch<TravelProvider>();
    final accommodations = travelProvider.currentAccommodations;
    final hasExisting = widget.day.hasStartingPoint;

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

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _selectedType.color.withValues(alpha: 0.18),
                            ),
                            child: Icon(
                              _selectedType.icon,
                              size: 18,
                              color: _selectedType.color,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hasExisting
                                      ? 'Edit Starting Point'
                                      : 'Set Starting Point',
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
                                  'Day ${widget.day.dayNumber} Departure Base',
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

                // Helpful Subtitle
                Text(
                  'Where does your journey begin on Day ${widget.day.dayNumber}? Setting an origin anchors your route, organizes your stops, and helps calculate departure timing.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 14),

                // Starting Point Type Chips
                Text(
                  'ORIGIN TYPE',
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
                    children: StartingPointType.values.map((type) {
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
                                  ? type.color.withValues(alpha: 0.22)
                                  : (isDark
                                      ? AppColors.darkSurface
                                      : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSel
                                    ? type.color
                                    : (isDark
                                        ? const Color(0x22FFFFFF)
                                        : const Color(0xFFE2E8F0)),
                                width: isSel ? 1.4 : 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(type.icon, size: 14, color: type.color),
                                const SizedBox(width: 6),
                                Text(
                                  type.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSel
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSel
                                        ? (isDark ? Colors.white : type.color)
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
                const SizedBox(height: 14),

                // Quick Auto-fill Recommendations (e.g. from Accommodations)
                if (accommodations.isNotEmpty) ...[
                  Text(
                    'TRIP STAYS / SUGGESTIONS',
                    style: AppTextStyles.labelUppercase.copyWith(
                      fontSize: 10,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: accommodations.map((acc) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: LiquidPop(
                            onTap: () {
                              HapticHelper.selectionClick();
                              setState(() {
                                _placeController.text = acc.propertyName;
                                if (acc.address != null &&
                                    acc.address!.isNotEmpty) {
                                  _addressController.text = acc.address!;
                                }
                                _selectedType = StartingPointType.hotel;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: (isDark
                                        ? AppColors.appleGreen
                                        : AppColors.vividMint)
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: (isDark
                                          ? AppColors.appleGreen
                                          : AppColors.vividMint)
                                      .withValues(alpha: 0.40),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    CupertinoIcons.bed_double_fill,
                                    size: 12,
                                    color: isDark
                                        ? AppColors.appleGreen
                                        : AppColors.vividMint,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Use "${acc.propertyName}"',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? AppColors.appleGreen
                                          : AppColors.vividMint,
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
                  const SizedBox(height: 14),
                ],

                // Google Places Autocomplete Action
                LiquidPop(
                  onTap: _searchGooglePlaces,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
                            .withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.search,
                          size: 16,
                          color: isDark
                              ? AppColors.appleBlue
                              : AppColors.royalIndigo,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _placeController.text.isNotEmpty
                                ? 'Selected: ${_placeController.text}'
                                : 'Search location on Google Places',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.appleBlue
                                  : AppColors.royalIndigo,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_startLatitude != null && _startLongitude != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.appleGreen.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'GPS Verified',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AppColors.appleGreen,
                              ),
                            ),
                          )
                        else
                          Icon(
                            CupertinoIcons.chevron_right,
                            size: 13,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Starting Point Name Field
                GlassTextField(
                  controller: _placeController,
                  labelText: 'Starting Point Name',
                  hintText: 'e.g. Grand Hyatt, Terminal 3, Home, Central Station',
                  prefixIcon: _selectedType.icon,
                  isDark: isDark,
                  autofocus: !hasExisting,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter a starting point name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Departure Time Field + Quick Time Chips
                Row(
                  children: [
                    Expanded(
                      child: GlassTextField(
                        controller: _timeController,
                        labelText: 'Departure Time',
                        hintText: 'e.g. 08:30 AM',
                        prefixIcon: CupertinoIcons.time_solid,
                        isDark: isDark,
                        suffix: IconButton(
                          icon: const Icon(CupertinoIcons.clock, size: 16),
                          onPressed: () => _pickTime(context),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: _quickTimes.map((t) {
                      final isSel = _timeController.text == t;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: GestureDetector(
                          onTap: () {
                            HapticHelper.selectionClick();
                            setState(() => _timeController.text = t);
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
                                color: isSel
                                    ? (isDark
                                        ? AppColors.appleBlue
                                        : AppColors.royalIndigo)
                                    : Colors.transparent,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              t,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isSel
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
                const SizedBox(height: 12),

                // Address / Location Field
                GlassTextField(
                  controller: _addressController,
                  labelText: 'Address or Landmark (Optional)',
                  hintText: 'e.g. MG Road, Near City Center / Gate 2',
                  prefixIcon: CupertinoIcons.location_solid,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),

                // Departure Notes Field
                GlassTextField(
                  controller: _notesController,
                  labelText: 'Departure Notes / Checklist (Optional)',
                  hintText: 'e.g. Hotel checkout at 11 AM, pack umbrellas, grab breakfast',
                  prefixIcon: CupertinoIcons.doc_plaintext,
                  maxLines: 2,
                  isDark: isDark,
                ),
                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  children: [
                    if (hasExisting) ...[
                      Expanded(
                        child: GlassButton(
                          label: 'Remove',
                          icon: CupertinoIcons.trash,
                          variant: GlassButtonVariant.danger,
                          onPressed: _handleClear,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: 2,
                      child: GlassButton(
                        label: hasExisting
                            ? 'Update Starting Point'
                            : 'Set Starting Point',
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
