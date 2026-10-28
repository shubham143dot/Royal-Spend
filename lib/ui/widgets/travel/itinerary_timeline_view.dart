import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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

    if (activities.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
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
                  color: (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
                      .withValues(alpha: 0.12),
                ),
                child: Icon(
                  CupertinoIcons.map_pin_ellipse,
                  size: 28,
                  color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Complete your itinerary',
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
                'No stops scheduled for Day ${day.dayNumber} yet. Tap below or select from Saved Places to start planning this day.',
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  decoration: BoxDecoration(
                    gradient: AppColors.royalGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.royalIndigo.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.add, size: 16, color: Colors.white),
                      SizedBox(width: 6),
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
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: activities.length + 1, // last item is the Add Stop row
      itemBuilder: (context, index) {
        if (index == activities.length) {
          // Bottom add button row
          return Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 24),
            child: Center(
              child: LiquidPop(
                onTap: onAddStop,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurface
                        : Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
                          .withValues(alpha: 0.4),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.add_circled_solid,
                        size: 16,
                        color: isDark
                            ? AppColors.appleBlue
                            : AppColors.royalIndigo,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Add Another Stop',
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
          );
        }

        final activity = activities[index];
        final isLast = index == activities.length - 1;

        return _ActivityTimelineItem(
          activity: activity,
          isFirst: index == 0,
          isLast: isLast,
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
            );
          },
          onToggleComplete: () {
            travelProvider.toggleActivityCompletion(activity);
          },
          onDelete: () {
            travelProvider.deleteActivity(activity.id, activity.dayId);
          },
        );
      },
    );
  }
}

class _ActivityTimelineItem extends StatelessWidget {
  final ItineraryActivity activity;
  final bool isFirst;
  final bool isLast;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onToggleComplete;
  final VoidCallback onDelete;

  const _ActivityTimelineItem({
    required this.activity,
    required this.isFirst,
    required this.isLast,
    required this.isDark,
    required this.onTap,
    required this.onToggleComplete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final catColor = activity.category.color;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline Column: Time, Line & Circle Bead
          SizedBox(
            width: 58,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const SizedBox(height: 14),
                // Start time
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
            width: 24,
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
                      color: activity.isCompleted
                          ? AppColors.appleGreen
                          : catColor,
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
                    // Header Row: Category Badge & Status / Menu (Wrapped to prevent overflow)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Category pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: catColor.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(8),
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

                              // Booking status badge
                              if (activity.bookingStatus != BookingStatus.notNeeded)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: activity.bookingStatus.badgeColor
                                        .withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    activity.bookingStatus.displayName,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: activity.bookingStatus.badgeColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),

                        // Menu button with hit test padding
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _showItemActions(context),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 4),
                            child: Icon(
                              CupertinoIcons.ellipsis,
                              size: 15,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Title
                    Text(
                      activity.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                        decoration: activity.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),

                    // Place Name if present
                    if (activity.placeName != null) ...[
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
                              activity.placeName!,
                              style: TextStyle(
                                fontSize: 12,
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

                    // Warning if destination not confirmed (Day 3 prompt requirement)
                    if (!activity.isDestinationConfirmed) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.amberWarning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.amberWarning.withValues(alpha: 0.5),
                            width: 0.8,
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              CupertinoIcons.exclamationmark_triangle_fill,
                              size: 12,
                              color: AppColors.amberWarning,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Sightseeing destination awaiting confirmation (Tiger Hill excluded)',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.amberWarning,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Notes if present
                    if (activity.notes != null && activity.notes!.isNotEmpty) ...[
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

                    // Footer Row: Estimated Cost & Complete Toggle
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (activity.estimatedCost > 0)
                          Flexible(
                            child: Text(
                              'Est: ${CurrencyFormatter.format(activity.estimatedCost)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.appleGreen
                                    : AppColors.vividMint,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                        const SizedBox(width: 8),

                        // Completion checkmark button
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
        title: Text(activity.title),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              onTap();
            },
            child: const Text('Edit Activity'),
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
            child: const Text('Delete Activity'),
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
