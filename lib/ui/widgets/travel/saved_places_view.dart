import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/glass_decorations.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../data/models/saved_place.dart';
import '../../../providers/travel_provider.dart';
import '../glass_button.dart';
import '../glass_card.dart';
import '../glass_text_field.dart';
import '../liquid_pop.dart';

class SavedPlacesView extends StatefulWidget {
  final bool isDark;

  const SavedPlacesView({super.key, required this.isDark});

  @override
  State<SavedPlacesView> createState() => _SavedPlacesViewState();
}

class _SavedPlacesViewState extends State<SavedPlacesView> {
  String _filter = 'All'; // 'All', 'Want to Visit', 'Visited'

  @override
  Widget build(BuildContext context) {
    final travelProvider = context.watch<TravelProvider>();
    final places = travelProvider.currentSavedPlaces;
    final isDark = widget.isDark;

    final filtered = places.where((p) {
      if (_filter == 'Visited') return p.isVisited;
      if (_filter == 'Want to Visit') return !p.isVisited;
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Chips and Add Place Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Filters
              Row(
                children: ['All', 'Want to Visit', 'Visited'].map((f) {
                  final isSel = _filter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: LiquidPop(
                      pressedScale: 0.93,
                      onTap: () {
                        HapticHelper.selectionClick();
                        setState(() => _filter = f);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSel
                              ? (isDark
                                  ? AppColors.appleBlue
                                  : AppColors.royalIndigo)
                              : (isDark
                                  ? AppColors.darkSurface
                                  : Colors.black.withValues(alpha: 0.04)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          f,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                            color: isSel
                                ? Colors.white
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

              // Add Place button
              LiquidPop(
                onTap: () => _showAddPlaceDialog(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
                        .withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.add,
                        size: 13,
                        color: isDark
                            ? AppColors.appleBlue
                            : AppColors.royalIndigo,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Add Place',
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
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Places count header
          Text(
            '${filtered.length} Saved Destinations',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.darkTextMuted
                  : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 10),

          // Places list
          if (filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Text(
                  'No saved places match this filter.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final place = filtered[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: GlassCard(
                    isDark: isDark,
                    padding: const EdgeInsets.all(14.0),
                    borderRadius: 16,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Visited Toggle Checkbox
                        GestureDetector(
                          onTap: () {
                            HapticHelper.selectionClick();
                            travelProvider.toggleSavedPlaceVisited(place);
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2.0, right: 10.0),
                            child: Icon(
                              place.isVisited
                                  ? CupertinoIcons.check_mark_circled_solid
                                  : CupertinoIcons.circle,
                              size: 20,
                              color: place.isVisited
                                  ? AppColors.appleGreen
                                  : (isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.lightTextMuted),
                            ),
                          ),
                        ),

                        // Place Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                place.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                  decoration: place.isVisited
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              if (place.locationNotes != null) ...[
                                const SizedBox(height: 3),
                                Text(
                                  place.locationNotes!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isDark
                                          ? AppColors.applePurple
                                          : AppColors.violetAccent)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  place.category,
                                  style: TextStyle(
                                    fontSize: 9,
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

                        // Quick action: Add to Day
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            LiquidPop(
                              onTap: () =>
                                  _showAddToDaySheet(context, place, travelProvider),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 6),
                                decoration: BoxDecoration(
                                  color: (isDark
                                          ? AppColors.appleBlue
                                          : AppColors.royalIndigo)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: (isDark
                                            ? AppColors.appleBlue
                                            : AppColors.royalIndigo)
                                        .withValues(alpha: 0.3),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      CupertinoIcons.calendar_badge_plus,
                                      size: 13,
                                      color: isDark
                                          ? AppColors.appleBlue
                                          : AppColors.royalIndigo,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Add to Day',
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
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () {
                                HapticHelper.mediumImpact();
                                travelProvider.deleteSavedPlace(place.id);
                              },
                              child: Icon(
                                CupertinoIcons.trash,
                                size: 14,
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showAddPlaceDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String category = 'Sightseeing';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Container(
          decoration:
              GlassDecorations.glassModalDecoration(isDark: widget.isDark),
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? const Color(0x40FFFFFF)
                        : const Color(0x33000000),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Save a Destination',
                style: AppTextStyles.titleMedium.copyWith(
                  color: widget.isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              GlassTextField(
                controller: nameCtrl,
                labelText: 'Place Name',
                hintText: 'e.g. Batasia Loop, Darjeeling',
                prefixIcon: CupertinoIcons.placemark,
                isDark: widget.isDark,
              ),
              const SizedBox(height: 12),
              GlassTextField(
                controller: notesCtrl,
                labelText: 'Location Notes / Description',
                hintText: 'Scenic views, mountain trail tips...',
                prefixIcon: CupertinoIcons.doc_text,
                isDark: widget.isDark,
              ),
              const SizedBox(height: 16),
              GlassButton(
                label: 'Save Place',
                icon: CupertinoIcons.check_mark,
                isDark: widget.isDark,
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final tripId =
                      context.read<TravelProvider>().selectedTrip?.id;
                  if (tripId == null) return;

                  final place = SavedPlace(
                    id: const Uuid().v4(),
                    tripId: tripId,
                    name: nameCtrl.text.trim(),
                    locationNotes: notesCtrl.text.trim().isNotEmpty
                        ? notesCtrl.text.trim()
                        : null,
                    category: category,
                  );
                  context.read<TravelProvider>().addSavedPlace(place);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddToDaySheet(
      BuildContext context, SavedPlace place, TravelProvider provider) {
    final days = provider.currentDays;
    final timeCtrl = TextEditingController(text: '10:00 AM');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration:
            GlassDecorations.glassModalDecoration(isDark: widget.isDark),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Schedule ${place.name}',
              style: AppTextStyles.titleMedium.copyWith(
                color: widget.isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select which itinerary day to place this destination in:',
              style: TextStyle(
                fontSize: 12,
                color: widget.isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 14),
            GlassTextField(
              controller: timeCtrl,
              labelText: 'Preferred Start Time',
              hintText: 'e.g. 10:00 AM',
              prefixIcon: CupertinoIcons.time,
              isDark: widget.isDark,
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 160,
              child: ListView.builder(
                itemCount: days.length,
                itemBuilder: (ctx, idx) {
                  final day = days[idx];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (widget.isDark
                                ? AppColors.appleBlue
                                : AppColors.royalIndigo)
                            .withValues(alpha: 0.16),
                      ),
                      child: Center(
                        child: Text(
                          '${day.dayNumber}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: widget.isDark
                                ? AppColors.appleBlue
                                : AppColors.royalIndigo,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      day.title ?? 'Day ${day.dayNumber}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: widget.isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '${day.date.day}/${day.date.month}/${day.date.year}',
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                    trailing: const Icon(CupertinoIcons.add, size: 16),
                    onTap: () {
                      HapticHelper.success();
                      provider.promoteSavedPlaceToActivity(
                        place: place,
                        dayId: day.id,
                        startTime: timeCtrl.text.trim(),
                      );
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Added ${place.name} to Day ${day.dayNumber}'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
