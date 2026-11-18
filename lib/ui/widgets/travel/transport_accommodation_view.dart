import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../data/models/travel_accommodation.dart';
import '../../../data/models/travel_transport.dart';
import '../../../providers/travel_provider.dart';
import '../glass_card.dart';
import '../liquid_pop.dart';
import 'add_edit_stay_sheet.dart';
import 'add_edit_transport_sheet.dart';

class TransportAccommodationView extends StatelessWidget {
  final bool isDark;

  const TransportAccommodationView({super.key, required this.isDark});

  String _formatDuration(DateTime dep, DateTime arr) {
    final diff = arr.difference(dep);
    if (diff.isNegative) return '';
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;
    if (hours == 0) return '${mins}m';
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  void _confirmDeleteTransport(
    BuildContext context,
    TravelProvider travelProvider,
    TravelTransport t,
  ) {
    HapticHelper.heavyImpact();
    showCupertinoDialog(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('Delete Transport Connection?'),
        content: Text(
          'Are you sure you want to delete this transport record for ${t.provider ?? t.type.displayName} (${t.departurePlace} → ${t.arrivalPlace})?\n\nThis action cannot be undone.',
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
              travelProvider.deleteTransport(t.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccommodation(
    BuildContext context,
    TravelProvider travelProvider,
    TravelAccommodation s,
  ) {
    HapticHelper.heavyImpact();
    showCupertinoDialog(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('Delete Accommodation?'),
        content: Text(
          'Are you sure you want to delete "${s.propertyName}" from your stays?\n\nThis action cannot be undone.',
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
              travelProvider.deleteAccommodation(s.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _editTransport(
    BuildContext context,
    TravelProvider travelProvider,
    TravelTransport t,
  ) {
    HapticHelper.selectionClick();
    AddEditTransportSheet.show(
      context,
      tripId: t.tripId,
      transportToEdit: t,
      isDark: isDark,
      onSave: (updated) => travelProvider.updateTransport(updated),
      onDelete: () => travelProvider.deleteTransport(t.id),
    );
  }

  void _editAccommodation(
    BuildContext context,
    TravelProvider travelProvider,
    TravelAccommodation s,
  ) {
    HapticHelper.selectionClick();
    AddEditStaySheet.show(
      context,
      tripId: s.tripId,
      accommodationToEdit: s,
      isDark: isDark,
      onSave: (updated) => travelProvider.updateAccommodation(updated),
      onDelete: () => travelProvider.deleteAccommodation(s.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final travelProvider = context.watch<TravelProvider>();
    final transports = travelProvider.currentTransports;
    final stays = travelProvider.currentAccommodations;
    final tripId = travelProvider.selectedTrip?.id ?? '';

    final dateFormat = DateFormat('d MMM, h:mm a');

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Transports Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Transport & Transit Records',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              LiquidPop(
                onTap: () {
                  HapticHelper.selectionClick();
                  AddEditTransportSheet.show(
                    context,
                    tripId: tripId,
                    isDark: isDark,
                    onSave: (transport) =>
                        travelProvider.addTransport(transport),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                        size: 14,
                        color: isDark
                            ? AppColors.appleBlue
                            : AppColors.royalIndigo,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Add Transport',
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
          const SizedBox(height: 10),

          if (transports.isEmpty)
            GlassCard(
              isDark: isDark,
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'No transport journeys recorded yet.\nAdd trains, buses, flights, or scooty rentals.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            )
          else
            ...transports.map((t) {
              final durationStr = _formatDuration(t.departureTime, t.arrivalTime);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: LiquidPop(
                  pressedScale: 0.98,
                  onTap: () => _editTransport(context, travelProvider, t),
                  child: GlassCard(
                    isDark: isDark,
                    padding: const EdgeInsets.all(14.0),
                    borderRadius: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: Icon + Provider/Type + Overnight + Status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: (isDark
                                              ? AppColors.appleBlue
                                              : AppColors.royalIndigo)
                                          .withValues(alpha: 0.16),
                                    ),
                                    child: Icon(
                                      t.type.icon,
                                      size: 15,
                                      color: isDark
                                          ? AppColors.appleBlue
                                          : AppColors.royalIndigo,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          t.provider != null &&
                                                  t.provider!.isNotEmpty
                                              ? t.provider!
                                              : t.type.displayName,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          t.type.displayName,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? AppColors.darkTextMuted
                                                : AppColors.lightTextMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              children: [
                                if (t.isOvernight) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.appleIndigo
                                          .withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          CupertinoIcons.moon_fill,
                                          size: 9,
                                          color: AppColors.appleIndigo,
                                        ),
                                        SizedBox(width: 3),
                                        Text(
                                          'Overnight',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.appleIndigo,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: t.bookingStatus.badgeColor
                                        .withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    t.bookingStatus.displayName,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: t.bookingStatus.badgeColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Route & Timings Container
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0x14FFFFFF)
                                : const Color(0x0A000000),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0x18FFFFFF)
                                  : const Color(0x0F000000),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Departure
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'DEPARTURE',
                                      style: AppTextStyles.labelUppercase
                                          .copyWith(
                                        fontSize: 9,
                                        letterSpacing: 0.5,
                                        color: isDark
                                            ? AppColors.darkTextMuted
                                            : AppColors.lightTextMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      t.departurePlace,
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
                                    const SizedBox(height: 2),
                                    Text(
                                      dateFormat.format(t.departureTime),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? AppColors.appleBlue
                                            : AppColors.royalIndigo,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),

                              // Duration Indicator & Arrow
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6.0),
                                child: Column(
                                  children: [
                                    Icon(
                                      CupertinoIcons.arrow_right,
                                      size: 14,
                                      color: isDark
                                          ? AppColors.darkTextMuted
                                          : AppColors.lightTextMuted,
                                    ),
                                    if (durationStr.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0x22FFFFFF)
                                              : const Color(0x14000000),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          durationStr,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? AppColors.darkTextSecondary
                                                : AppColors.lightTextSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Arrival
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'ARRIVAL',
                                      style: AppTextStyles.labelUppercase
                                          .copyWith(
                                        fontSize: 9,
                                        letterSpacing: 0.5,
                                        color: isDark
                                            ? AppColors.darkTextMuted
                                            : AppColors.lightTextMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      t.arrivalPlace,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? AppColors.darkTextPrimary
                                            : AppColors.lightTextPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.end,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      dateFormat.format(t.arrivalTime),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? AppColors.appleGreen
                                            : AppColors.vividMint,
                                      ),
                                      textAlign: TextAlign.end,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Booking Reference / PNR
                        if (t.bookingReference != null &&
                            t.bookingReference!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.barcode,
                                size: 12,
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'PNR / Ref: ${t.bookingReference}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],

                        // Notes
                        if (t.notes != null && t.notes!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                CupertinoIcons.doc_plaintext,
                                size: 12,
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  t.notes!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 10),

                        // Actions Row: Fare + Edit & Delete Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (t.cost > 0)
                              Text(
                                'Fare: ${CurrencyFormatter.format(t.cost)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppColors.appleGreen
                                      : AppColors.vividMint,
                                ),
                              )
                            else
                              const SizedBox.shrink(),

                            Row(
                              children: [
                                // Edit Button
                                LiquidPop(
                                  pressedScale: 0.90,
                                  onTap: () => _editTransport(
                                      context, travelProvider, t),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: (isDark
                                              ? AppColors.appleBlue
                                              : AppColors.royalIndigo)
                                          .withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          CupertinoIcons.pencil,
                                          size: 12,
                                          color: isDark
                                              ? AppColors.appleBlue
                                              : AppColors.royalIndigo,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Edit',
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
                                const SizedBox(width: 8),

                                // Delete Button
                                LiquidPop(
                                  pressedScale: 0.90,
                                  onTap: () => _confirmDeleteTransport(
                                      context, travelProvider, t),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.appleRed
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          CupertinoIcons.trash,
                                          size: 12,
                                          color: AppColors.appleRed,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Delete',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.appleRed,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          const SizedBox(height: 24),

          // 2. Accommodations Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Accommodations & Stays',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              LiquidPop(
                onTap: () {
                  HapticHelper.selectionClick();
                  AddEditStaySheet.show(
                    context,
                    tripId: tripId,
                    isDark: isDark,
                    onSave: (stay) => travelProvider.addAccommodation(stay),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.appleGreen : AppColors.vividMint)
                        .withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.add,
                        size: 14,
                        color: isDark
                            ? AppColors.appleGreen
                            : AppColors.vividMint,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Add Stay',
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
            ],
          ),
          const SizedBox(height: 10),

          if (stays.isEmpty)
            GlassCard(
              isDark: isDark,
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'No accommodations recorded yet.\nAdd homestays, hotels, or resort preferences.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            )
          else
            ...stays.map((s) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: LiquidPop(
                  pressedScale: 0.98,
                  onTap: () => _editAccommodation(context, travelProvider, s),
                  child: GlassCard(
                    isDark: isDark,
                    padding: const EdgeInsets.all(14.0),
                    borderRadius: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: Bed Icon + Property Name + Booking Status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: (isDark
                                              ? AppColors.appleGreen
                                              : AppColors.vividMint)
                                          .withValues(alpha: 0.16),
                                    ),
                                    child: Icon(
                                      CupertinoIcons.bed_double_fill,
                                      size: 15,
                                      color: isDark
                                          ? AppColors.appleGreen
                                          : AppColors.vividMint,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s.propertyName,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (s.address != null &&
                                            s.address!.isNotEmpty)
                                          Row(
                                            children: [
                                              Icon(
                                                CupertinoIcons.placemark,
                                                size: 11,
                                                color: isDark
                                                    ? AppColors
                                                        .darkTextMuted
                                                    : AppColors
                                                        .lightTextMuted,
                                              ),
                                              const SizedBox(width: 3),
                                              Expanded(
                                                child: Text(
                                                  s.address!,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.w500,
                                                    color: isDark
                                                        ? AppColors
                                                            .darkTextSecondary
                                                        : AppColors
                                                            .lightTextSecondary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: s.bookingStatus.badgeColor
                                    .withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                s.bookingStatus.displayName,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: s.bookingStatus.badgeColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Check-in & Check-out timing banner
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0x14FFFFFF)
                                : const Color(0x0A000000),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0x18FFFFFF)
                                  : const Color(0x0F000000),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Check-in
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'CHECK-IN',
                                      style: AppTextStyles.labelUppercase
                                          .copyWith(
                                        fontSize: 9,
                                        letterSpacing: 0.5,
                                        color: isDark
                                            ? AppColors.darkTextMuted
                                            : AppColors.lightTextMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      dateFormat.format(s.checkIn),
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
                                  ],
                                ),
                              ),

                              // Nights badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (isDark
                                          ? AppColors.applePurple
                                          : AppColors.violetAccent)
                                      .withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      CupertinoIcons.moon_stars_fill,
                                      size: 11,
                                      color: isDark
                                          ? AppColors.applePurple
                                          : AppColors.violetAccent,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${s.nightsCount} ${s.nightsCount == 1 ? "Night" : "Nights"}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? AppColors.applePurple
                                            : AppColors.violetAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Check-out
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'CHECK-OUT',
                                      style: AppTextStyles.labelUppercase
                                          .copyWith(
                                        fontSize: 9,
                                        letterSpacing: 0.5,
                                        color: isDark
                                            ? AppColors.darkTextMuted
                                            : AppColors.lightTextMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      dateFormat.format(s.checkOut),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? AppColors.applePurple
                                            : AppColors.violetAccent,
                                      ),
                                      textAlign: TextAlign.end,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Booking Reference & Contact Info
                        if ((s.bookingReference != null &&
                                s.bookingReference!.isNotEmpty) ||
                            (s.contactInfo != null &&
                                s.contactInfo!.isNotEmpty)) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (s.bookingReference != null &&
                                  s.bookingReference!.isNotEmpty) ...[
                                Icon(
                                  CupertinoIcons.barcode,
                                  size: 12,
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.lightTextMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Ref: ${s.bookingReference}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                ),
                                if (s.contactInfo != null &&
                                    s.contactInfo!.isNotEmpty)
                                  const SizedBox(width: 12),
                              ],
                              if (s.contactInfo != null &&
                                  s.contactInfo!.isNotEmpty) ...[
                                Icon(
                                  CupertinoIcons.phone_fill,
                                  size: 11,
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.lightTextMuted,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    s.contactInfo!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],

                        // Notes
                        if (s.notes != null && s.notes!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                CupertinoIcons.doc_plaintext,
                                size: 12,
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  s.notes!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 10),

                        // Actions Row: Cost + Edit & Delete Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (s.cost > 0)
                              Text(
                                'Rate: ${CurrencyFormatter.format(s.cost)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppColors.appleGreen
                                      : AppColors.vividMint,
                                ),
                              )
                            else
                              const SizedBox.shrink(),

                            Row(
                              children: [
                                // Edit Button
                                LiquidPop(
                                  pressedScale: 0.90,
                                  onTap: () => _editAccommodation(
                                      context, travelProvider, s),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: (isDark
                                              ? AppColors.appleGreen
                                              : AppColors.vividMint)
                                          .withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          CupertinoIcons.pencil,
                                          size: 12,
                                          color: isDark
                                              ? AppColors.appleGreen
                                              : AppColors.vividMint,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Edit',
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
                                const SizedBox(width: 8),

                                // Delete Button
                                LiquidPop(
                                  pressedScale: 0.90,
                                  onTap: () => _confirmDeleteAccommodation(
                                      context, travelProvider, s),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.appleRed
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          CupertinoIcons.trash,
                                          size: 12,
                                          color: AppColors.appleRed,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Delete',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.appleRed,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
