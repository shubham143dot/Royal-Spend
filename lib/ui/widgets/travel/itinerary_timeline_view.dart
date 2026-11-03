import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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

class ItineraryTimelineView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final travelProvider = context.watch<TravelProvider>();
    final activities = travelProvider.activitiesByDay[day.id] ?? [];
    final dailyTotal = travelProvider.getDailyEstimatedCost(day.id);
    final fullDateFormat = DateFormat('EEEE, d MMMM yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Day Header Summary Card
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: GlassCard(
            isDark: isDark,
            padding: const EdgeInsets.all(16.0),
            borderRadius: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
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
                        'Day ${day.dayNumber} Itinerary',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppColors.appleBlue
                              : AppColors.royalIndigo,
                        ),
                      ),
                    ),
                    Row(
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
                Text(
                  day.title != null && day.title!.isNotEmpty
                      ? day.title!
                      : 'Day ${day.dayNumber} Itinerary',
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
                Row(
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
                      fullDateFormat.format(day.date),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('•',
                        style: TextStyle(
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted)),
                    const SizedBox(width: 10),
                    Text(
                      '${activities.length} ${activities.length == 1 ? "stop" : "stops"} planned',
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
              ],
            ),
          ),
        ),

        // 2. Timeline Stops List or Empty State
        if (activities.isEmpty)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: GlassCard(
              isDark: isDark,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (isDark
                              ? AppColors.appleBlue
                              : AppColors.royalIndigo)
                          .withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      CupertinoIcons.map_pin_ellipse,
                      size: 28,
                      color:
                          isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No stops added for Day ${day.dayNumber}',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Start building your itinerary by recording places, arrival times, duration, and estimated expenses.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  LiquidPop(
                    onTap: onAddStop,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: AppColors.royalGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.royalIndigo.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.add,
                              size: 16, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Add Stop to Day',
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
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: activities.length + 1, // last item is the Add Stop row
            itemBuilder: (context, index) {
              if (index == activities.length) {
                // Bottom prominent Add Stop button
                return Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 32),
                  child: Center(
                    child: LiquidPop(
                      onTap: onAddStop,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 11),
                        decoration: BoxDecoration(
                          gradient: AppColors.royalGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.royalIndigo
                                  .withValues(alpha: 0.30),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.add_circled_solid,
                              size: 16,
                              color: Colors.white,
                            ),
                            SizedBox(width: 8),
                            Text(
                              '+ Add Another Stop to Day',
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
                );
              }

              final activity = activities[index];
              final isFirst = index == 0;
              final isLast = index == activities.length - 1;

              return _ActivityTimelineItem(
                activity: activity,
                stopNumber: index + 1,
                isFirst: isFirst,
                isLast: isLast,
                canMoveUp: index > 0,
                canMoveDown: index < activities.length - 1,
                isDark: isDark,
                onTap: () {
                  AddEditActivitySheet.show(
                    context,
                    tripId: activity.tripId,
                    dayId: activity.dayId,
                    activityToEdit: activity,
                    isDark: isDark,
                    onSave: (updated) {
                      travelProvider.updateActivity(updated);
                    },
                    onDelete: () {
                      travelProvider.deleteActivity(activity.id, activity.dayId);
                    },
                  );
                },
                onToggleComplete: () {
                  travelProvider.toggleActivityCompletion(activity);
                },
                onDelete: () {
                  travelProvider.deleteActivity(activity.id, activity.dayId);
                },
                onMoveUp: () {
                  HapticHelper.selectionClick();
                  travelProvider.reorderActivities(day.id, index, index - 1);
                },
                onMoveDown: () {
                  HapticHelper.selectionClick();
                  travelProvider.reorderActivities(day.id, index, index + 2);
                },
              );
            },
          ),
      ],
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

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
            child: Column(
              children: [
                // Top line
                Container(
                  width: 2,
                  height: 16,
                  color: isFirst
                      ? Colors.transparent
                      : (isDark
                          ? const Color(0x33FFFFFF)
                          : const Color(0x26000000)),
                ),
                // Circular bead with icon
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: activity.isCompleted
                        ? AppColors.appleGreen
                        : catColor.withValues(alpha: 0.20),
                    border: Border.all(
                      color:
                          activity.isCompleted ? AppColors.appleGreen : catColor,
                      width: 1.6,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      activity.isCompleted
                          ? CupertinoIcons.check_mark
                          : activity.category.icon,
                      size: 11,
                      color: activity.isCompleted ? Colors.white : catColor,
                    ),
                  ),
                ),
                // Bottom line
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast
                        ? Colors.transparent
                        : (isDark
                            ? const Color(0x33FFFFFF)
                            : const Color(0x26000000)),
                  ),
                ),
              ],
            ),
          ),

          // Activity Card Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14.0),
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
                            padding: const EdgeInsets.only(left: 2, bottom: 4),
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
                          )
                        else
                          const SizedBox.shrink(),

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
