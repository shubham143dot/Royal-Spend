import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../data/models/trip.dart';
import '../../../providers/travel_provider.dart';
import '../glass_card.dart';
import '../liquid_pop.dart';

class TripCard extends StatelessWidget {
  final Trip trip;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  const TripCard({
    super.key,
    required this.trip,
    required this.isDark,
    required this.onTap,
    required this.onEdit,
    required this.onDuplicate,
    required this.onArchive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM yyyy');
    final dateRangeStr =
        '${dateFormat.format(trip.startDate)} – ${dateFormat.format(trip.endDate)}';
    final calendarDays = trip.calendarDaysCount;

    final travelProvider = context.watch<TravelProvider>();
    final activitiesCount =
        travelProvider.activitiesByDay.values.fold<int>(
      0,
      (sum, list) =>
          sum + list.where((a) => a.tripId == trip.id).length,
    );

    // Fallback gradient based on destination
    final gradient = _getDestinationGradient(trip.destination);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18.0),
      child: GlassCard(
        isDark: isDark,
        padding: EdgeInsets.zero,
        borderRadius: 24,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Cover Banner with Gradient & Badges
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                gradient: gradient,
              ),
              child: Stack(
                children: [
                  // Subtle topographic line / pattern overlay
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.12,
                      child: CustomPaint(
                        painter: _TopographicPatternPainter(),
                      ),
                    ),
                  ),

                  // Status & Countdown Badges
                  Positioned(
                    top: 14,
                    left: 16,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: trip.status.badgeColor.withValues(alpha: 0.8),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                trip.status.icon,
                                size: 12,
                                color: trip.status.badgeColor,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                trip.status.displayName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: trip.status.badgeColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Countdown / Active Day badge
                        if (trip.isActiveNow && trip.currentTripDayNumber != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.appleGreen.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              'Day ${trip.currentTripDayNumber} of $calendarDays',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          )
                        else if (trip.daysUntilTrip > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.40),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              'In ${trip.daysUntilTrip} days',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Actions menu button
                  Positioned(
                    top: 10,
                    right: 12,
                    child: LiquidPop(
                      pressedScale: 0.88,
                      onTap: () => _showTripOptionsMenu(context),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: const Icon(
                          CupertinoIcons.ellipsis,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),

                  // Days counter badge on bottom right of cover
                  Positioned(
                    bottom: 12,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.50),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.20),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            CupertinoIcons.calendar,
                            size: 12,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$calendarDays calendar days',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
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

            // Card Content Section
            Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    trip.title,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 19,
                    ),
                  ),
                  const SizedBox(height: 5),

                  // Destination with pin
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.placemark,
                        size: 14,
                        color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          trip.destination,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Date range label
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.time,
                        size: 13,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        dateRangeStr,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Budget & Activities summary bar
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurface
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? const Color(0x1AFFFFFF)
                            : const Color(0x1A000000),
                        width: 0.6,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Planned budget
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Trip Budget',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              trip.budget > 0
                                  ? CurrencyFormatter.format(trip.budget)
                                  : 'Not specified',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                            ),
                          ],
                        ),

                        // Activities planned
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Planned Stops',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.map_pin_ellipse,
                                  size: 13,
                                  color: isDark
                                      ? AppColors.applePurple
                                      : AppColors.violetAccent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  activitiesCount > 0
                                      ? '$activitiesCount stops'
                                      : 'Tap to build',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Open Plan CTA
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Preferences preview chips
                      if (trip.preferences.isNotEmpty)
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: trip.preferences.take(2).map((pref) {
                                return Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (isDark
                                            ? AppColors.appleBlue
                                            : AppColors.royalIndigo)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    pref,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppColors.appleBlue
                                          : AppColors.royalIndigo,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        )
                      else
                        const Spacer(),

                      // Open trip button
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Open Trip',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.appleBlue
                                  : AppColors.royalIndigo,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            CupertinoIcons.chevron_right,
                            size: 14,
                            color: isDark
                                ? AppColors.appleBlue
                                : AppColors.royalIndigo,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTripOptionsMenu(BuildContext context) {
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
              onTap();
            },
            child: const Text('Open Trip Workspace'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              onEdit();
            },
            child: const Text('Edit Trip Details'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              onDuplicate();
            },
            child: const Text('Duplicate Trip Template'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              onArchive();
            },
            child: Text(trip.status == TripStatus.archived
                ? 'Unarchive Trip'
                : 'Archive Trip'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
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

  LinearGradient _getDestinationGradient(String dest) {
    final lower = dest.toLowerCase();
    if (lower.contains('darjeeling') || lower.contains('mountain')) {
      return const LinearGradient(
        colors: [Color(0xFF1E3A8A), Color(0xFF0284C7), Color(0xFF0D9488)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (lower.contains('araku') || lower.contains('valley')) {
      return const LinearGradient(
        colors: [Color(0xFF065F46), Color(0xFF059669), Color(0xFF10B981)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (lower.contains('kolkata') || lower.contains('city')) {
      return const LinearGradient(
        colors: [Color(0xFF581C87), Color(0xFF7C3AED), Color(0xFFC026D3)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (lower.contains('goa') || lower.contains('beach')) {
      return const LinearGradient(
        colors: [Color(0xFF0369A1), Color(0xFF0EA5E9), Color(0xFFF59E0B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return const LinearGradient(
      colors: [Color(0xFF4338CA), Color(0xFF6366F1), Color(0xFF38BDF8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}

class _TopographicPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (double y = 20; y < size.height; y += 30) {
      final path = Path();
      path.moveTo(0, y);
      path.quadraticBezierTo(
        size.width * 0.25,
        y - 12,
        size.width * 0.5,
        y + 6,
      );
      path.quadraticBezierTo(
        size.width * 0.75,
        y + 14,
        size.width,
        y - 4,
      );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
