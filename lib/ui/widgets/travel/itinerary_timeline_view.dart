import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/services/maps/google_maps_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../data/models/itinerary_activity.dart';
import '../../../data/models/itinerary_day.dart';
import '../../../providers/travel_provider.dart';
import '../glass_card.dart';
import '../liquid_pop.dart';
import 'add_edit_activity_sheet.dart';
import 'set_starting_point_sheet.dart';

enum ItineraryFilter { all, pending, completed }

/// High-clarity, Apple iOS-inspired Itinerary Timeline View.
/// Features a dedicated Starting Point hub, sequential stops with transit cues,
/// intuitive route overview, and quick reordering.
class ItineraryTimelineView extends StatefulWidget {
  final ItineraryDay day;
  final bool isDark;
  final VoidCallback onAddStop;

  const ItineraryTimelineView({
    super.key,
    required this.day,
    required this.isDark,
    required this.onAddStop,
  });

  @override
  State<ItineraryTimelineView> createState() => _ItineraryTimelineViewState();
}

class _ItineraryTimelineViewState extends State<ItineraryTimelineView> {
  ItineraryFilter _activeFilter = ItineraryFilter.all;

  IconData _getStartTypeIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'hotel':
        return CupertinoIcons.bed_double_fill;
      case 'airport':
        return CupertinoIcons.airplane;
      case 'station':
        return CupertinoIcons.tram_fill;
      case 'home':
        return CupertinoIcons.house_fill;
      default:
        return CupertinoIcons.flag_fill;
    }
  }

  void _openStartingPointSheet(
      BuildContext context, TravelProvider travelProvider) {
    SetStartingPointSheet.show(
      context,
      day: widget.day,
      isDark: widget.isDark,
      onSave: (updated) {
        travelProvider.updateDay(updated);
      },
    );
  }

  void _openAddStopSheet(BuildContext context, TravelProvider travelProvider,
      int nextStopNumber) {
    AddEditActivitySheet.show(
      context,
      tripId: widget.day.tripId,
      dayId: widget.day.id,
      stopNumber: nextStopNumber,
      isDark: widget.isDark,
      onSave: (act) => travelProvider.addActivity(act),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final travelProvider = context.watch<TravelProvider>();
    final allActivities = travelProvider.activitiesByDay[widget.day.id] ?? [];
    final dailyTotal = travelProvider.getDailyEstimatedCost(widget.day.id);
    final fullDateFormat = DateFormat('EEEE, d MMMM yyyy');

    final completedCount = allActivities.where((a) => a.isCompleted).length;
    final pendingCount = allActivities.length - completedCount;

    final filteredActivities = allActivities.where((a) {
      if (_activeFilter == ItineraryFilter.completed) return a.isCompleted;
      if (_activeFilter == ItineraryFilter.pending) return !a.isCompleted;
      return true;
    }).toList();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Day Header Summary Card
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: GlassCard(
                  isDark: isDark,
                  padding: const EdgeInsets.all(16.0),
                  borderRadius: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Day Pill + Budget
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (isDark
                                        ? AppColors.appleBlue
                                        : AppColors.royalIndigo)
                                    .withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Day ${widget.day.dayNumber} Itinerary',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? AppColors.appleBlue
                                      : AppColors.royalIndigo,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.money_dollar_circle,
                                size: 14,
                                color: isDark
                                    ? AppColors.appleGreen
                                    : AppColors.vividMint,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Est: ${CurrencyFormatter.format(dailyTotal)}',
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
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Day Theme Title
                      Text(
                        widget.day.title != null && widget.day.title!.isNotEmpty
                            ? widget.day.title!
                            : 'Day ${widget.day.dayNumber} Itinerary',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Date & Stop Count Row
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.calendar,
                                size: 13,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                fullDateFormat.format(widget.day.date),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Text('•',
                              style: TextStyle(
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.lightTextMuted)),
                          Text(
                            '${allActivities.length} ${allActivities.length == 1 ? "stop" : "stops"} planned',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.appleBlue
                                  : AppColors.royalIndigo,
                            ),
                          ),
                        ],
                      ),

                      // Route Quick Summary Pills (Starting Point -> Stops)
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0x1AFFFFFF)
                              : const Color(0x0A000000),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? const Color(0x1AFFFFFF)
                                : const Color(0x12000000),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Starting Point indicator
                            GestureDetector(
                              onTap: () => _openStartingPointSheet(
                                  context, travelProvider),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getStartTypeIcon(widget.day.startType),
                                    size: 13,
                                    color: widget.day.hasStartingPoint
                                        ? AppColors.appleGreen
                                        : (isDark
                                            ? AppColors.appleBlue
                                            : AppColors.royalIndigo),
                                  ),
                                  const SizedBox(width: 5),
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 110),
                                    child: Text(
                                      widget.day.hasStartingPoint
                                          ? widget.day.startPlaceName!
                                          : 'Set Start Point',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: widget.day.hasStartingPoint
                                            ? (isDark
                                                ? AppColors.appleGreen
                                                : AppColors.vividMint)
                                            : (isDark
                                                ? AppColors.appleBlue
                                                : AppColors.royalIndigo),
                                        decoration: widget.day.hasStartingPoint
                                            ? null
                                            : TextDecoration.underline,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              CupertinoIcons.chevron_right,
                              size: 10,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                            const SizedBox(width: 6),

                            // Stops summary
                            Expanded(
                              child: Text(
                                allActivities.isEmpty
                                    ? 'No stops added yet'
                                    : allActivities
                                        .map((a) => a.placeName ?? a.title)
                                        .join(' ➔ '),
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
                            ),
                          ],
                        ),
                      ),

                      // Completion Progress bar (if stops exist)
                      if (allActivities.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$completedCount of ${allActivities.length} stops completed',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                            Text(
                              '${((completedCount / allActivities.length) * 100).round()}%',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.appleGreen
                                    : AppColors.vividMint,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: completedCount / allActivities.length,
                            minHeight: 4,
                            backgroundColor: isDark
                                ? const Color(0x22FFFFFF)
                                : const Color(0x1F000000),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDark
                                  ? AppColors.appleGreen
                                  : AppColors.vividMint,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // 2. Starting Point Section (Origin Card)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 4.0),
                child: _buildStartingPointCard(
                    context, travelProvider, isDark),
              ),

              // Connector line between Starting Point and Stops
              _buildStartingPointToStopsConnector(
                  isDark, allActivities.isNotEmpty),

              // 3. Filter Segment (if 3+ stops exist)
              if (allActivities.length >= 3)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                  child: Row(
                    children: [
                      _buildFilterChip(
                        label: 'All (${allActivities.length})',
                        filter: ItineraryFilter.all,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Pending ($pendingCount)',
                        filter: ItineraryFilter.pending,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Done ($completedCount)',
                        filter: ItineraryFilter.completed,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // 4. Stops Timeline List or Empty State (Virtualized lazy loading)
        if (allActivities.isEmpty)
          SliverToBoxAdapter(
            child: _buildEmptyStopsCard(context, travelProvider, isDark),
          )
        else ...[
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            sliver: SliverList.builder(
              itemCount: filteredActivities.length,
              itemBuilder: (context, index) {
                final activity = filteredActivities[index];
                final originalIndex =
                    allActivities.indexWhere((a) => a.id == activity.id);
                final stopNumber =
                    (originalIndex != -1 ? originalIndex : index) + 1;
                final isFirst = index == 0;
                final isLast = index == filteredActivities.length - 1;

                return Column(
                  children: [
                    _ActivityTimelineItem(
                      activity: activity,
                      stopNumber: stopNumber,
                      isFirst: isFirst,
                      isLast: isLast,
                      canMoveUp: originalIndex > 0,
                      canMoveDown: originalIndex < allActivities.length - 1,
                      isDark: isDark,
                      onTap: () {
                        AddEditActivitySheet.show(
                          context,
                          tripId: activity.tripId,
                          dayId: activity.dayId,
                          activityToEdit: activity,
                          stopNumber: stopNumber,
                          isDark: isDark,
                          onSave: (updated) {
                            travelProvider.updateActivity(updated);
                          },
                          onDelete: () {
                            travelProvider.deleteActivity(
                                activity.id, activity.dayId);
                          },
                        );
                      },
                      onToggleComplete: () {
                        travelProvider.toggleActivityCompletion(activity);
                      },
                      onDelete: () {
                        travelProvider.deleteActivity(
                            activity.id, activity.dayId);
                      },
                      onMoveUp: () {
                        HapticHelper.selectionClick();
                        travelProvider.reorderActivities(
                            widget.day.id, originalIndex, originalIndex - 1);
                      },
                      onMoveDown: () {
                        HapticHelper.selectionClick();
                        travelProvider.reorderActivities(
                            widget.day.id, originalIndex, originalIndex + 2);
                      },
                    ),

                    // Transit cue between stops
                    if (!isLast)
                      _buildTransitBetweenStops(isDark, stopNumber + 1),
                  ],
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: _buildBottomActions(
              context,
              travelProvider,
              allActivities.length + 1,
              isDark,
            ),
          ),
        ],
      ],
    );
  }

  /// Builds the dedicated Starting Point Card (Set or Not Set)
  Widget _buildStartingPointCard(
      BuildContext context, TravelProvider travelProvider, bool isDark) {
    final hasStart = widget.day.hasStartingPoint;

    if (!hasStart) {
      // Starting Point NOT Set yet
      return GlassCard(
        isDark: isDark,
        padding: const EdgeInsets.all(16.0),
        borderRadius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (isDark
                            ? AppColors.appleGreen
                            : AppColors.vividMint)
                        .withValues(alpha: 0.18),
                  ),
                  child: Icon(
                    CupertinoIcons.flag_fill,
                    size: 18,
                    color:
                        isDark ? AppColors.appleGreen : AppColors.vividMint,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Starting Point',
                            style: AppTextStyles.titleMedium.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isDark
                                      ? AppColors.appleGreen
                                      : AppColors.vividMint)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'STEP 1 • ORIGIN',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? AppColors.appleGreen
                                    : AppColors.vividMint,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Where does Day ${widget.day.dayNumber} begin? (Hotel, Airport, Home)',
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: LiquidPop(
                    onTap: () =>
                        _openStartingPointSheet(context, travelProvider),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  const Color(0xFF30D158),
                                  const Color(0xFF0A84FF),
                                ]
                              : [
                                  const Color(0xFF059669),
                                  const Color(0xFF2563EB),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: (isDark
                                    ? const Color(0xFF30D158)
                                    : const Color(0xFF059669))
                                .withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.plus_circle_fill,
                              size: 15, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'Set Starting Point',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Starting Point IS Set
    final typeIcon = _getStartTypeIcon(widget.day.startType);

    return GlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(16.0),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Node
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isDark ? AppColors.appleGreen : AppColors.vividMint)
                      .withValues(alpha: 0.20),
                  border: Border.all(
                    color: isDark ? AppColors.appleGreen : AppColors.vividMint,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    typeIcon,
                    size: 18,
                    color: isDark ? AppColors.appleGreen : AppColors.vividMint,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Starting Point Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: (isDark
                                    ? AppColors.appleGreen
                                    : AppColors.vividMint)
                                .withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.flag_fill,
                                size: 9,
                                color: isDark
                                    ? AppColors.appleGreen
                                    : AppColors.vividMint,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'STARTING POINT',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? AppColors.appleGreen
                                      : AppColors.vividMint,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.day.startTime != null &&
                            widget.day.startTime!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0x1FFFFFFF)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.time_solid,
                                  size: 10,
                                  color: isDark
                                      ? AppColors.appleGreen
                                      : AppColors.vividMint,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Departs: ${widget.day.startTime!}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Place Name
                    Text(
                      widget.day.startPlaceName!,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),

                    // Address / Landmark if present
                    if (widget.day.startAddress != null &&
                        widget.day.startAddress!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.location_solid,
                            size: 11,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.day.startAddress!,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Notes if present
                    if (widget.day.startNotes != null &&
                        widget.day.startNotes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.day.startNotes!,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    if (widget.day.hasStartingCoordinates) ...[
                      const SizedBox(height: 6),
                      LiquidPop(
                        onTap: () {
                          HapticHelper.mediumImpact();
                          GoogleMapsLauncher.launchPlaceLocation(
                            latitude: widget.day.startLatitude!,
                            longitude: widget.day.startLongitude!,
                            placeName: widget.day.startPlaceName,
                            placeId: widget.day.startPlaceId,
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.location_fill,
                              size: 11,
                              color: isDark ? AppColors.appleGreen : AppColors.vividMint,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Open in Google Maps',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.appleGreen : AppColors.vividMint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Edit Button
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openStartingPointSheet(context, travelProvider),
                child: Padding(
                  padding: const EdgeInsets.only(left: 6, top: 2),
                  child: Icon(
                    CupertinoIcons.pencil_circle_fill,
                    size: 20,
                    color:
                        isDark ? AppColors.appleGreen : AppColors.vividMint,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Visual transit connector from Starting Point downwards
  Widget _buildStartingPointToStopsConnector(
      bool isDark, bool hasStops) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 4.0),
      child: Row(
        children: [
          Container(
            width: 2,
            height: 24,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  isDark ? AppColors.appleGreen : AppColors.vividMint,
                  isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.arrow_down,
                  size: 10,
                  color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                ),
                const SizedBox(width: 4),
                Text(
                  hasStops ? 'Head to Stop 1' : 'Route begins here',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color:
                        isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Transit cue connector between consecutive stops
  Widget _buildTransitBetweenStops(bool isDark, int nextStopNumber) {
    return Padding(
      padding: const EdgeInsets.only(left: 78.0, top: 2.0, bottom: 2.0),
      child: Row(
        children: [
          Container(
            width: 1,
            height: 16,
            color: isDark ? const Color(0x33FFFFFF) : const Color(0x22000000),
          ),
          const SizedBox(width: 10),
          Icon(
            CupertinoIcons.arrow_down_circle_fill,
            size: 11,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
          const SizedBox(width: 4),
          Text(
            'Next: Stop $nextStopNumber',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color:
                  isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  /// Empty state when no stops exist yet
  Widget _buildEmptyStopsCard(
      BuildContext context, TravelProvider travelProvider, bool isDark) {
    final hasStart = widget.day.hasStartingPoint;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: GlassCard(
        isDark: isDark,
        padding: const EdgeInsets.all(22.0),
        borderRadius: 20,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
                    .withValues(alpha: 0.14),
              ),
              child: Icon(
                CupertinoIcons.map_pin_ellipse,
                size: 26,
                color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              hasStart
                  ? 'Ready for Day ${widget.day.dayNumber} Stops'
                  : 'No stops added for Day ${widget.day.dayNumber}',
              style: AppTextStyles.titleMedium.copyWith(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasStart
                  ? 'Your starting point is set to "${widget.day.startPlaceName}". Now add Stop 1 to plan your first visit.'
                  : 'Start building your itinerary by setting your starting point, then record places, arrival times, and expenses.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            LiquidPop(
              onTap: () => _openAddStopSheet(context, travelProvider, 1),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                decoration: BoxDecoration(
                  gradient: AppColors.royalGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.royalIndigo.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.add, size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Add Stop 1 to Day',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom actions: Add Next Stop + Return to Starting Point
  Widget _buildBottomActions(BuildContext context, TravelProvider travelProvider,
      int nextStopNumber, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 32),
      child: Column(
        children: [
          Center(
            child: LiquidPop(
              onTap: () =>
                  _openAddStopSheet(context, travelProvider, nextStopNumber),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                decoration: BoxDecoration(
                  gradient: AppColors.royalGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.royalIndigo.withValues(alpha: 0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      CupertinoIcons.add_circled_solid,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+ Add Stop $nextStopNumber to Day',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Shortcut to Return to Starting Point (if start is set)
          if (widget.day.hasStartingPoint) ...[
            const SizedBox(height: 10),
            LiquidPop(
              onTap: () {
                HapticHelper.selectionClick();
                final returnActivity = ItineraryActivity(
                  id: 'return_${widget.day.id}_${DateTime.now().millisecondsSinceEpoch}',
                  tripId: widget.day.tripId,
                  dayId: widget.day.id,
                  title: 'Return to ${widget.day.startPlaceName!}',
                  placeName: widget.day.startPlaceName!,
                  address: widget.day.startAddress,
                  category: ActivityCategory.accommodation,
                  sortOrder: nextStopNumber,
                  notes: 'End of day journey • Rest & recharge',
                );
                travelProvider.addActivity(returnActivity);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0x1AFFFFFF)
                      : const Color(0x0A000000),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? const Color(0x22FFFFFF)
                        : const Color(0x18000000),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.arrow_counterclockwise_circle_fill,
                      size: 13,
                      color: isDark
                          ? AppColors.appleGreen
                          : AppColors.vividMint,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '🏁 Add Return to "${widget.day.startPlaceName!}"',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.appleGreen
                            : AppColors.vividMint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required ItineraryFilter filter,
    required bool isDark,
  }) {
    final isSel = _activeFilter == filter;
    return GestureDetector(
      onTap: () {
        HapticHelper.selectionClick();
        setState(() => _activeFilter = filter);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSel
              ? (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
                  .withValues(alpha: 0.20)
              : (isDark ? const Color(0x12FFFFFF) : const Color(0x0A000000)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSel
                ? (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
            color: isSel
                ? (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
                : (isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }
}

class _ActivityTimelineItem extends StatelessWidget {
  final ItineraryActivity activity;
  final int stopNumber;
  final bool isFirst;
  final bool isLast;
  final bool canMoveUp;
  final bool canMoveDown;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onToggleComplete;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  const _ActivityTimelineItem({
    required this.activity,
    required this.stopNumber,
    required this.isFirst,
    required this.isLast,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.isDark,
    required this.onTap,
    required this.onToggleComplete,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  String _formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    if (minutes % 60 == 0) return '${minutes ~/ 60}h';
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }

  @override
  Widget build(BuildContext context) {
    final catColor = activity.category.color;
    final lineColor =
        isDark ? const Color(0x33FFFFFF) : const Color(0x26000000);

    return RepaintBoundary(
      child: Stack(
        children: [
          // Continuous timeline connecting line
          Positioned(
            top: isFirst ? 26 : 0,
            bottom: isLast ? null : 0,
            height: isLast ? 26 : null,
            left: 62.0 + 12.0, // center of the 26px bead column
            child: Container(
              width: 2.0,
              color: lineColor,
            ),
          ),
          // Foreground Content Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Time Column: Arrival Time, Departure Time
              SizedBox(
                width: 62,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const SizedBox(height: 14),
                    // Arrival / Start time
                    Text(
                      activity.startTime ?? 'Anytime',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                    if (activity.endTime != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        activity.endTime!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ],
                ),
              ),

              // Central Timeline Track & Bead
              SizedBox(
                width: 26,
                child: Padding(
                  padding: const EdgeInsets.only(top: 15),
                  child: Center(
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: activity.isCompleted
                            ? AppColors.appleGreen
                            : catColor.withValues(alpha: 0.20),
                        border: Border.all(
                          color: activity.isCompleted
                              ? AppColors.appleGreen
                              : catColor,
                          width: 1.6,
                        ),
                      ),
                      child: Center(
                        child: activity.isCompleted
                            ? const Icon(
                                CupertinoIcons.check_mark,
                                size: 11,
                                color: Colors.white,
                              )
                            : Text(
                                '$stopNumber',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: catColor,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),

              // Activity Card Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: GlassCard(
                    isDark: isDark,
                    padding: const EdgeInsets.all(14.0),
                    borderRadius: 18,
                    onTap: onTap,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Row: Stop Number Tag + Category Badge + Menu
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  // Stop Number Tag
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: (isDark
                                              ? AppColors.appleBlue
                                              : AppColors.royalIndigo)
                                          .withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Stop $stopNumber',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: isDark
                                            ? AppColors.appleBlue
                                            : AppColors.royalIndigo,
                                      ),
                                    ),
                                  ),

                                  // Category pill
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: catColor.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      activity.category.displayName,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: catColor,
                                      ),
                                    ),
                                  ),

                                  // Duration badge if provided
                                  if (activity.durationMinutes != null &&
                                      activity.durationMinutes! > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0x1FFFFFFF)
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            CupertinoIcons.stopwatch,
                                            size: 10,
                                            color: isDark
                                                ? AppColors.darkTextSecondary
                                                : AppColors.lightTextSecondary,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            _formatDuration(
                                                activity.durationMinutes!),
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
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
                            const SizedBox(width: 4),

                            // Reorder Arrows (Move Up & Down)
                            if (canMoveUp)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: onMoveUp,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Icon(
                                    CupertinoIcons.arrow_up,
                                    size: 14,
                                    color: isDark
                                        ? AppColors.darkTextMuted
                                        : AppColors.lightTextMuted,
                                  ),
                                ),
                              ),
                            if (canMoveDown)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: onMoveDown,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Icon(
                                    CupertinoIcons.arrow_down,
                                    size: 14,
                                    color: isDark
                                        ? AppColors.darkTextMuted
                                        : AppColors.lightTextMuted,
                                  ),
                                ),
                              ),

                            // Action Menu
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _showItemActions(context),
                              child: Padding(
                                padding:
                                    const EdgeInsets.only(left: 2, bottom: 4),
                                child: Icon(
                                  CupertinoIcons.ellipsis,
                                  size: 16,
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.lightTextMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Place Name (Prominent)
                        Text(
                          activity.placeName != null &&
                                  activity.placeName!.isNotEmpty
                              ? activity.placeName!
                              : activity.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                            decoration: activity.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),

                        // Location / Address if present
                        if (activity.address != null &&
                            activity.address!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.location_solid,
                                size: 12,
                                color: isDark
                                    ? AppColors.appleBlue
                                    : AppColors.royalIndigo,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  activity.address!,
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
                              ),
                            ],
                          ),
                        ],

                        // Description / Activity subtitle (if placeName and title differ)
                        if (activity.placeName != null &&
                            activity.title.isNotEmpty &&
                            activity.title != activity.placeName) ...[
                          const SizedBox(height: 4),
                          Text(
                            activity.title,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],

                        // Notes if present
                        if (activity.notes != null &&
                            activity.notes!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            activity.notes!,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],

                        // Footer Row: Estimated Cost & Completion Toggle
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (activity.estimatedCost > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: (isDark
                                                ? AppColors.appleGreen
                                                : AppColors.vividMint)
                                            .withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Est: ${CurrencyFormatter.format(activity.estimatedCost)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? AppColors.appleGreen
                                              : AppColors.vividMint,
                                        ),
                                      ),
                                    ),
                                  if (activity.latitude != null &&
                                      activity.longitude != null)
                                    LiquidPop(
                                      onTap: () {
                                        HapticHelper.mediumImpact();
                                        GoogleMapsLauncher.launchPlaceLocation(
                                          latitude: activity.latitude!,
                                          longitude: activity.longitude!,
                                          placeName: activity.placeName ??
                                              activity.title,
                                          placeId: activity.placeId,
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: (isDark
                                                  ? AppColors.appleBlue
                                                  : AppColors.royalIndigo)
                                              .withValues(alpha: 0.14),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              CupertinoIcons.location_fill,
                                              size: 10,
                                              color: isDark
                                                  ? AppColors.appleBlue
                                                  : AppColors.royalIndigo,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              'Maps',
                                              style: TextStyle(
                                                fontSize: 10,
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
                            ),
                            const SizedBox(width: 8),

                            // Completion checkmark toggle
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: onToggleComplete,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    activity.isCompleted
                                        ? CupertinoIcons.check_mark_circled_solid
                                        : CupertinoIcons.circle,
                                    size: 16,
                                    color: activity.isCompleted
                                        ? AppColors.appleGreen
                                        : (isDark
                                            ? AppColors.darkTextMuted
                                            : AppColors.lightTextMuted),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    activity.isCompleted ? 'Done' : 'Mark done',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: activity.isCompleted
                                          ? AppColors.appleGreen
                                          : (isDark
                                              ? AppColors.darkTextMuted
                                              : AppColors.lightTextMuted),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showItemActions(BuildContext context) {
    HapticHelper.mediumImpact();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(activity.placeName ?? activity.title),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              onTap();
            },
            child: const Text('Edit Stop'),
          ),
          if (canMoveUp)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                onMoveUp();
              },
              child: const Text('Move Up in Itinerary'),
            ),
          if (canMoveDown)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                onMoveDown();
              },
              child: const Text('Move Down in Itinerary'),
            ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              onToggleComplete();
            },
            child: Text(activity.isCompleted
                ? 'Mark as Incomplete'
                : 'Mark as Completed'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            child: const Text('Delete Stop'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}
