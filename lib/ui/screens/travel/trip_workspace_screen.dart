import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../data/models/trip.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/travel_provider.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/liquid_pop.dart';
import '../../widgets/travel/add_edit_activity_sheet.dart';
import '../../widgets/travel/add_edit_day_sheet.dart';
import '../../widgets/travel/itinerary_timeline_view.dart';
import '../../widgets/travel/liquid_add_travel_expense_fab.dart';
import '../../widgets/travel/transport_accommodation_view.dart';
import '../../widgets/travel/travel_budget_view.dart';
import '../../widgets/travel/travel_checklist_view.dart';
import '../../widgets/travel/trip_map_view.dart';
import 'create_plan_wizard_screen.dart';

class TripWorkspaceScreen extends StatefulWidget {
  final String tripId;

  const TripWorkspaceScreen({super.key, required this.tripId});

  @override
  State<TripWorkspaceScreen> createState() => _TripWorkspaceScreenState();
}

class _TripWorkspaceScreenState extends State<TripWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = [
    'Overview',
    'Itinerary',
    'Map & Places',
    'Budget',
    'Checklist',
    'Details',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final travelProvider = context.read<TravelProvider>();
      if (travelProvider.selectedTrip?.id != widget.tripId) {
        travelProvider.selectTrip(widget.tripId);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDark = settings.isDarkMode(context);
    final travelProvider = context.watch<TravelProvider>();

    final trip = travelProvider.selectedTrip;

    if (travelProvider.isWorkspaceLoading || trip == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: AmbientBackground(
          isDark: isDark,
          child: const Center(
            child: CupertinoActivityIndicator(radius: 16),
          ),
        ),
      );
    }

    final dateFormat = DateFormat('d MMM yyyy');
    final dateRangeStr =
        '${dateFormat.format(trip.startDate)} – ${dateFormat.format(trip.endDate)}';
    final calendarDays = trip.calendarDaysCount;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientBackground(
        isDark: isDark,
        child: SafeArea(
          child: Column(
            children: [
              // Top Navigation Bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    // Back button to Travel Plans Dashboard
                    LiquidPop(
                      onTap: () {
                        HapticHelper.selectionClick();
                        Navigator.pop(context);
                      },
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

                    // Trip Title & Destination
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trip.title,
                            style: AppTextStyles.titleMedium.copyWith(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${trip.destination} • $calendarDays days',
                            style: TextStyle(
                              fontSize: 12,
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

                    // Actions menu
                    LiquidPop(
                      onTap: () => _showTripMenu(context, trip, travelProvider),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurface
                              : Colors.white.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.ellipsis, size: 18),
                      ),
                    ),
                  ],
                ),
              ),

              // Segmented Tab Bar (Overview, Itinerary, Map, Budget, Checklist, Details)
              Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                height: 40,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  physics: const BouncingScrollPhysics(),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                  labelStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500),
                  dividerColor: Colors.transparent,
                  tabAlignment: TabAlignment.start,
                  padding: EdgeInsets.zero,
                  tabs: _tabs.map((tabName) => Tab(text: tabName)).toList(),
                ),
              ),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Overview
                    _buildOverviewTab(
                        context, trip, travelProvider, isDark, dateRangeStr),

                    // Tab 2: Day-by-Day Itinerary Editor
                    _buildItineraryTab(
                        context, trip, travelProvider, isDark),

                    // Tab 3: Map & Places
                    TripMapView(isDark: isDark),

                    // Tab 4: Budget & Expenses
                    TravelBudgetView(isDark: isDark),

                    // Tab 5: Checklist
                    TravelChecklistView(isDark: isDark),

                    // Tab 6: Details (Transport & Accommodation)
                    TransportAccommodationView(isDark: isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: LiquidAddTravelExpenseFab(
        isDark: isDark,
        currentTripId: trip.id,
        bottomPadding: 16,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // --- Tab 1: Overview ---

  Widget _buildOverviewTab(
    BuildContext context,
    Trip trip,
    TravelProvider travelProvider,
    bool isDark,
    String dateRangeStr,
  ) {
    final daysCount = trip.calendarDaysCount;
    final activitiesCount = travelProvider.activitiesByDay.values
        .fold<int>(0, (sum, l) => sum + l.length);
    final placesCount = travelProvider.currentSavedPlaces.length;
    final checklistProgress = travelProvider.checklistProgress;
    final budget = trip.budget;
    final actualSpent = travelProvider.actualRecordedSpending;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Destination Card
          GlassCard(
            isDark: isDark,
            padding: const EdgeInsets.all(20.0),
            borderRadius: 22,
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF0284C7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        trip.status.displayName,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (trip.daysUntilTrip > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Starts in ${trip.daysUntilTrip} days',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  trip.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(CupertinoIcons.placemark_fill,
                        size: 14, color: Colors.white70),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        trip.destination,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '$dateRangeStr • $daysCount calendar days',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Key Metrics Grid
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Planned Stops',
                  value: '$activitiesCount',
                  icon: CupertinoIcons.map_pin_ellipse,
                  color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                  isDark: isDark,
                  onTap: () => _tabController.animateTo(1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  title: 'Saved Places',
                  value: '$placesCount',
                  icon: CupertinoIcons.bookmark_fill,
                  color:
                      isDark ? AppColors.applePurple : AppColors.violetAccent,
                  isDark: isDark,
                  onTap: () => _tabController.animateTo(2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Checklist',
                  value: '${(checklistProgress * 100).toInt()}% Done',
                  icon: CupertinoIcons.check_mark_circled_solid,
                  color: AppColors.appleGreen,
                  isDark: isDark,
                  onTap: () => _tabController.animateTo(4),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  title: 'Trip Spending',
                  value: CurrencyFormatter.format(actualSpent),
                  subtitle: budget > 0
                      ? 'of ${CurrencyFormatter.format(budget)}'
                      : null,
                  icon: CupertinoIcons.money_dollar,
                  color: AppColors.appleOrange,
                  isDark: isDark,
                  onTap: () => _tabController.animateTo(3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Quick Action Row
          Row(
            children: [
              Expanded(
                child: LiquidPop(
                  onTap: () {
                    final currentDay = travelProvider.selectedDay;
                    if (currentDay == null) return;
                    AddEditActivitySheet.show(
                      context,
                      tripId: trip.id,
                      dayId: currentDay.id,
                      isDark: isDark,
                      onSave: (act) => travelProvider.addActivity(act),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: AppColors.royalGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.royalIndigo.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.add, size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'Add Stop',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
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
                  onTap: () => _tabController.animateTo(1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurface
                          : Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: (isDark
                                ? AppColors.appleBlue
                                : AppColors.royalIndigo)
                            .withValues(alpha: 0.35),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.calendar,
                          size: 16,
                          color: isDark
                              ? AppColors.appleBlue
                              : AppColors.royalIndigo,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'View Itinerary',
                          style: TextStyle(
                            fontSize: 12,
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
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Overview summary description
          if (trip.description != null && trip.description!.isNotEmpty) ...[
            Text(
              'Trip Notes',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            GlassCard(
              isDark: isDark,
              padding: const EdgeInsets.all(14.0),
              borderRadius: 16,
              child: Text(
                trip.description!,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Tab 2: Day-by-Day Itinerary Editor ---

  Widget _buildItineraryTab(
    BuildContext context,
    Trip trip,
    TravelProvider travelProvider,
    bool isDark,
  ) {
    final days = travelProvider.currentDays;
    final selectedDay = travelProvider.selectedDay ?? (days.isNotEmpty ? days.first : null);

    if (days.isEmpty || selectedDay == null) {
      return Center(
        child: Text(
          'No itinerary days generated.',
          style: TextStyle(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
      );
    }

    final dateFormat = DateFormat('d MMM');
    final weekdayFormat = DateFormat('EEE');

    return Column(
      children: [
        // Horizontally Scrollable Day Selector
        Container(
          height: 84,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: days.length + 1,
            itemBuilder: (context, index) {
              if (index == days.length) {
                // Add Day Card
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: LiquidPop(
                    pressedScale: 0.92,
                    onTap: () {
                      HapticHelper.selectionClick();
                      final nextDayNum = days.length + 1;
                      final nextDate = days.isNotEmpty
                          ? days.last.date.add(const Duration(days: 1))
                          : trip.startDate;
                      AddEditDaySheet.show(
                        context,
                        tripId: trip.id,
                        defaultDayNumber: nextDayNum,
                        defaultDate: nextDate,
                        isDark: isDark,
                        onSave: (newDay) => travelProvider.addDay(newDay),
                      );
                    },
                    child: Container(
                      width: 72,
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurface.withValues(alpha: 0.6)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
                              .withValues(alpha: 0.45),
                          width: 0.8,
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.add_circled,
                              size: 20,
                              color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add Day',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }

              final day = days[index];
              final isSelected = day.id == selectedDay.id;
              final activitiesCount =
                  travelProvider.activitiesByDay[day.id]?.length ?? 0;

              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: LiquidPop(
                  pressedScale: 0.94,
                  onTap: () {
                    HapticHelper.selectionClick();
                    travelProvider.selectDay(day);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: 72,
                    padding: const EdgeInsets.symmetric(
                        vertical: 6, horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
                          : (isDark
                              ? AppColors.darkSurface
                              : Colors.white.withValues(alpha: 0.8)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : (isDark
                                ? const Color(0x1AFFFFFF)
                                : const Color(0x1A000000)),
                        width: 0.6,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: (isDark
                                        ? AppColors.appleBlue
                                        : AppColors.royalIndigo)
                                    .withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Day ${day.dayNumber}',
                            style: TextStyle(
                              fontSize: 10,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white70
                                  : (isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.lightTextMuted),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateFormat.format(day.date),
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                weekdayFormat.format(day.date),
                                style: TextStyle(
                                  fontSize: 9,
                                  height: 1.15,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                  ? Colors.white70
                                      : (isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary),
                                ),
                              ),
                              if (activitiesCount > 0) ...[
                                const SizedBox(width: 4),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.appleGreen,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Selected Day Header Info
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticHelper.selectionClick();
                    AddEditDaySheet.show(
                      context,
                      tripId: trip.id,
                      dayToEdit: selectedDay,
                      defaultDayNumber: selectedDay.dayNumber,
                      defaultDate: selectedDay.date,
                      isDark: isDark,
                      onSave: (updatedDay) => travelProvider.updateDay(updatedDay),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          selectedDay.title ?? 'Day ${selectedDay.dayNumber} Timeline',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        CupertinoIcons.pencil_circle_fill,
                        size: 15,
                        color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              LiquidPop(
                onTap: () {
                  AddEditActivitySheet.show(
                    context,
                    tripId: trip.id,
                    dayId: selectedDay.id,
                    isDark: isDark,
                    onSave: (act) => travelProvider.addActivity(act),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.add_circled_solid,
                      size: 14,
                      color:
                          isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Add Stop',
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
            ],
          ),
        ),

        // Timeline View
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ItineraryTimelineView(
              day: selectedDay,
              isDark: isDark,
              onAddStop: () {
                AddEditActivitySheet.show(
                  context,
                  tripId: trip.id,
                  dayId: selectedDay.id,
                  isDark: isDark,
                  onSave: (act) => travelProvider.addActivity(act),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _showTripMenu(
      BuildContext context, Trip trip, TravelProvider provider) {
    HapticHelper.mediumImpact();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(trip.title),
        message: Text('${trip.destination} • ${trip.calendarDaysCount} days'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (_) => CreatePlanWizardScreen(tripToEdit: trip),
                ),
              );
            },
            child: const Text('Edit Trip Details'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              await provider.duplicateTrip(trip.id);
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Trip duplicated successfully as a new plan'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Duplicate Plan as Template'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              provider.toggleTripArchive(trip.id);
            },
            child: Text(trip.status == TripStatus.archived
                ? 'Unarchive Trip'
                : 'Archive Trip'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _confirmDelete(context, trip, provider);
            },
            child: const Text('Delete Trip'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, Trip trip, TravelProvider provider) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Delete "${trip.title}"?'),
        content: const Text(
            'This action permanently deletes this trip, its day-by-day itinerary, saved places, and checklists. Associated expense financial history will be preserved.'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              final nav = Navigator.of(context);
              Navigator.pop(ctx);
              await provider.deleteTrip(trip.id);
              if (mounted) nav.pop();
            },
            child: const Text('Delete Plan'),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _MetricCard({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(14.0),
      borderRadius: 16,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextMuted
                      : AppColors.lightTextMuted,
                ),
              ),
              Icon(icon, size: 14, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 10,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
