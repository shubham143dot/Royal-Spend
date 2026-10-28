import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/travel/darjeeling_sample_data.dart';
import '../../../core/services/travel/itinerary_text_parser.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../data/models/itinerary_activity.dart';
import '../../../data/models/itinerary_day.dart';
import '../../../data/models/trip.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/travel_provider.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/glass_button.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/liquid_pop.dart';
import 'trip_workspace_screen.dart';

class SmartItineraryImportScreen extends StatefulWidget {
  final String? initialText;

  const SmartItineraryImportScreen({super.key, this.initialText});

  @override
  State<SmartItineraryImportScreen> createState() =>
      _SmartItineraryImportScreenState();
}

class _SmartItineraryImportScreenState
    extends State<SmartItineraryImportScreen> {
  late TextEditingController _textController;
  ParsedItineraryResult? _parsedResult;
  bool _isAnalyzing = false;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText ?? '');
    if (_textController.text.isNotEmpty) {
      _analyzeText();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _analyzeText() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() => _parsedResult = null);
      return;
    }

    setState(() => _isAnalyzing = true);
    HapticHelper.mediumImpact();

    Future.delayed(const Duration(milliseconds: 160), () {
      if (!mounted) return;
      final result = ItineraryTextParser.parse(text);
      setState(() {
        _parsedResult = result;
        _isAnalyzing = false;
      });
    });
  }

  Future<void> _pasteFromClipboard() async {
    HapticHelper.mediumImpact();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      _textController.text = data.text!;
      _analyzeText();
    }
  }

  void _loadDarjeelingSample() {
    HapticHelper.mediumImpact();
    _textController.text = DarjeelingSampleData.rawText.trim();
    _analyzeText();
  }

  Future<void> _confirmAndCreatePlan() async {
    if (_parsedResult == null || _isCreating) return;

    setState(() => _isCreating = true);
    HapticHelper.success();

    final travelProvider = context.read<TravelProvider>();
    const uuid = Uuid();
    final newTripId = uuid.v4();
    final p = _parsedResult!;

    // 1. Build Trip
    final trip = Trip(
      id: newTripId,
      title: p.title,
      destination: p.destination,
      departureCity: p.departureCity,
      startDate: p.startDate,
      endDate: p.endDate,
      currency: 'INR',
      travelersCount: 1,
      travelersNames: const ['You'],
      budget: 25000.0,
      description: 'Imported adventure plan with day-by-day itinerary.',
      status: TripStatus.upcoming,
      preferences: const ['Mountains', 'Nature', 'Scenic viewpoints'],
    );

    // 2. Build Days & Activities
    final days = <ItineraryDay>[];
    final activities = <ItineraryActivity>[];

    for (final day in p.days) {
      final dayId = '${newTripId}_day_${day.dayNumber}';
      days.add(ItineraryDay(
        id: dayId,
        tripId: newTripId,
        dayNumber: day.dayNumber,
        date: day.date,
        title: day.title ?? 'Day ${day.dayNumber}',
      ));

      for (int i = 0; i < day.activities.length; i++) {
        final act = day.activities[i];
        activities.add(ItineraryActivity(
          id: uuid.v4(),
          tripId: newTripId,
          dayId: dayId,
          title: act.title,
          placeName: act.placeName,
          startTime: act.startTime,
          endTime: act.endTime,
          durationMinutes: act.durationMinutes,
          category: act.category,
          notes: act.notes,
          estimatedCost: act.estimatedCost,
          bookingStatus: act.bookingStatus,
          isDestinationConfirmed: act.isDestinationConfirmed,
          sortOrder: i + 1,
        ));
      }
    }

    // 3. Saved Places
    final savedPlaces = p.detectedSavedPlaces
        .map((sp) => sp.copyWith(id: uuid.v4(), tripId: newTripId))
        .toList();

    // 4. Save to Database
    await travelProvider.createTrip(
      trip,
      days: days,
      activities: activities,
      savedPlaces: savedPlaces,
    );

    if (!mounted) return;

    // 5. Select active trip and open workspace
    await travelProvider.selectTrip(newTripId);
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      CupertinoPageRoute(
        builder: (_) => TripWorkspaceScreen(tripId: newTripId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDark = settings.isDarkMode(context);
    final dateFormat = DateFormat('d MMM yyyy');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientBackground(
        isDark: isDark,
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    LiquidPop(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurface
                              : Colors.white.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.back, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Smart Itinerary Import',
                            style: AppTextStyles.titleMedium.copyWith(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            'Turn raw notes into an adventure plan',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18.0, vertical: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Instructions Card
                      GlassCard(
                        isDark: isDark,
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: (isDark
                                            ? AppColors.appleBlue
                                            : AppColors.royalIndigo)
                                        .withValues(alpha: 0.16),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    CupertinoIcons.sparkles,
                                    size: 16,
                                    color: isDark
                                        ? AppColors.appleBlue
                                        : AppColors.royalIndigo,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Paste rough travel notes or messages',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Supports bullet points, times, overnight trains, destinations, and day outlines. Royal Spend automatically extracts days, schedules, and places.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Quick action buttons (Paste from clipboard & Load Darjeeling sample)
                      Row(
                        children: [
                          Expanded(
                            child: LiquidPop(
                              onTap: _pasteFromClipboard,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 9, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.darkSurface
                                      : Colors.white.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: (isDark
                                            ? AppColors.appleBlue
                                            : AppColors.royalIndigo)
                                        .withValues(alpha: 0.35),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      CupertinoIcons.doc_on_clipboard,
                                      size: 14,
                                      color: isDark
                                          ? AppColors.appleBlue
                                          : AppColors.royalIndigo,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Paste Notes',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? AppColors.appleBlue
                                              : AppColors.royalIndigo,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: LiquidPop(
                              onTap: _loadDarjeelingSample,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 9, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: (isDark
                                          ? AppColors.applePurple
                                          : AppColors.violetAccent)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: (isDark
                                            ? AppColors.applePurple
                                            : AppColors.violetAccent)
                                        .withValues(alpha: 0.35),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      CupertinoIcons.sparkles,
                                      size: 14,
                                      color: isDark
                                          ? AppColors.applePurple
                                          : AppColors.violetAccent,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Darjeeling Sample',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? AppColors.applePurple
                                              : AppColors.violetAccent,
                                        ),
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

                      // Raw text input field
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurface
                              : Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark
                                ? const Color(0x26FFFFFF)
                                : const Color(0x26000000),
                            width: 0.8,
                          ),
                        ),
                        child: TextField(
                          controller: _textController,
                          maxLines: 7,
                          onChanged: (_) => _analyzeText(),
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                            height: 1.4,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'Paste your text itinerary here...\n\nExample:\nDarjeeling Trip, 10 to 18 December 2026.\n10 December: Train from Hijli at 10:50 AM...',
                            hintStyle: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Analysis indicator
                      if (_isAnalyzing)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CupertinoActivityIndicator(),
                                const SizedBox(width: 10),
                                Text(
                                  'Analyzing itinerary structure...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Parsed Preview
                      if (_parsedResult != null && !_isAnalyzing) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Detected Itinerary Preview',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.appleGreen
                                    .withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_parsedResult!.calendarDays} Days Detected',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.appleGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Detected Summary Card
                        GlassCard(
                          isDark: isDark,
                          padding: const EdgeInsets.all(14.0),
                          borderRadius: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _parsedResult!.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    CupertinoIcons.placemark,
                                    size: 13,
                                    color: isDark
                                        ? AppColors.appleBlue
                                        : AppColors.royalIndigo,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _parsedResult!.destination,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    CupertinoIcons.calendar,
                                    size: 13,
                                    color: isDark
                                        ? AppColors.darkTextMuted
                                        : AppColors.lightTextMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '${dateFormat.format(_parsedResult!.startDate)} – ${dateFormat.format(_parsedResult!.endDate)} (${_parsedResult!.calendarDays} calendar days)',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? AppColors.darkTextMuted
                                            : AppColors.lightTextMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Warnings / Alerts list
                        if (_parsedResult!.warnings.isNotEmpty) ...[
                          ..._parsedResult!.warnings.map((w) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.amberWarning
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.amberWarning
                                      .withValues(alpha: 0.4),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 2.0),
                                    child: Icon(
                                      CupertinoIcons
                                          .exclamationmark_triangle_fill,
                                      size: 13,
                                      color: AppColors.amberWarning,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      w,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.amberWarning,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                        ],

                        // Day-by-Day Preview List
                        ..._parsedResult!.days.map((day) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: GlassCard(
                              isDark: isDark,
                              padding: const EdgeInsets.all(12.0),
                              borderRadius: 14,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Day ${day.dayNumber} — ${dateFormat.format(day.date)}',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${day.activities.length} stops',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark
                                              ? AppColors.darkTextMuted
                                              : AppColors.lightTextMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (day.activities.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    ...day.activities.map((act) {
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 6.0),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: act.category.color
                                                    .withValues(alpha: 0.16),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                act.category.icon,
                                                size: 10,
                                                color: act.category.color,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if (act.startTime != null) ...[
                                              Text(
                                                act.startTime!,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                            ],
                                            Expanded(
                                              child: Text(
                                                act.title,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: isDark
                                                      ? AppColors
                                                          .darkTextPrimary
                                                      : AppColors
                                                          .lightTextPrimary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ] else ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Awaiting plan (Ready to add saved places)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? AppColors.darkTextMuted
                                            : AppColors.lightTextMuted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),

              // Confirm and Create Plan Button
              if (_parsedResult != null)
                Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: GlassButton(
                    label: _isCreating
                        ? 'Creating Plan...'
                        : 'Confirm and Create Plan',
                    icon: CupertinoIcons.sparkles,
                    isDark: isDark,
                    onPressed: _isCreating ? null : _confirmAndCreatePlan,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
