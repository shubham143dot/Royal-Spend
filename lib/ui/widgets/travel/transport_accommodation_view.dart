import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/glass_decorations.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/travel_accommodation.dart';
import '../../../data/models/travel_transport.dart';
import '../../../providers/travel_provider.dart';
import '../glass_button.dart';
import '../glass_card.dart';
import '../glass_text_field.dart';
import '../liquid_pop.dart';

class TransportAccommodationView extends StatelessWidget {
  final bool isDark;

  const TransportAccommodationView({super.key, required this.isDark});

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
              Text(
                'Transport & Transit Records',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              LiquidPop(
                onTap: () => _showAddTransportDialog(context, tripId),
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
              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: GlassCard(
                  isDark: isDark,
                  padding: const EdgeInsets.all(14.0),
                  borderRadius: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(t.type.icon,
                                    size: 16,
                                    color: isDark
                                        ? AppColors.appleBlue
                                        : AppColors.royalIndigo),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    t.provider ?? t.type.displayName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
                                  child: const Text(
                                    'Overnight',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.appleIndigo,
                                    ),
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
                              const SizedBox(width: 6),
                              LiquidPop(
                                pressedScale: 0.88,
                                onTap: () => travelProvider.deleteTransport(t.id),
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
                      const SizedBox(height: 10),

                      // Route
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.departurePlace,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary,
                                  ),
                                ),
                                Text(
                                  dateFormat.format(t.departureTime),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark
                                        ? AppColors.darkTextMuted
                                        : AppColors.lightTextMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            CupertinoIcons.arrow_right,
                            size: 14,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  t.arrivalPlace,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary,
                                  ),
                                ),
                                Text(
                                  dateFormat.format(t.arrivalTime),
                                  style: TextStyle(
                                    fontSize: 10,
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

                      if (t.notes != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          t.notes!,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],

                      if (t.cost > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Fare: ${CurrencyFormatter.format(t.cost)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.appleGreen
                                : AppColors.vividMint,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 24),

          // 2. Accommodations Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Accommodations & Stays',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              LiquidPop(
                onTap: () => _showAddStayDialog(context, tripId),
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
                child: GlassCard(
                  isDark: isDark,
                  padding: const EdgeInsets.all(14.0),
                  borderRadius: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  CupertinoIcons.bed_double_fill,
                                  size: 16,
                                  color: isDark
                                      ? AppColors.appleGreen
                                      : AppColors.vividMint,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    s.propertyName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
                          const SizedBox(width: 6),
                          LiquidPop(
                            pressedScale: 0.88,
                            onTap: () =>
                                travelProvider.deleteAccommodation(s.id),
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
                      if (s.address != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          s.address!,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),

                      // Dates & Nights
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Check-in: ${dateFormat.format(s.checkIn)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          Text(
                            '${s.nightsCount} nights',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.applePurple
                                  : AppColors.violetAccent,
                            ),
                          ),
                        ],
                      ),

                      if (s.notes != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          s.notes!,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                        ),
                      ],

                      if (s.cost > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Estimated Stay Cost: ${CurrencyFormatter.format(s.cost)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.appleGreen
                                : AppColors.vividMint,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showAddTransportDialog(BuildContext context, String tripId) {
    final depPlaceCtrl = TextEditingController();
    final arrPlaceCtrl = TextEditingController();
    final providerCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    TransportType type = TransportType.bus;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: GlassDecorations.glassModalDecoration(isDark: isDark),
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Text(
                  'Record Transport Connection',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 16),
                GlassTextField(
                  controller: depPlaceCtrl,
                  labelText: 'Departure Location',
                  hintText: 'e.g. Tenzing Norgay Central Bus Terminus, Siliguri',
                  prefixIcon: CupertinoIcons.arrow_up_right_circle,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                GlassTextField(
                  controller: arrPlaceCtrl,
                  labelText: 'Arrival Location',
                  hintText: 'e.g. Darjeeling Bus Stand',
                  prefixIcon: CupertinoIcons.arrow_down_left_circle,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                GlassTextField(
                  controller: providerCtrl,
                  labelText: 'Transport Provider / Train Name',
                  hintText: 'e.g. MAS NJP SF Express, North Bengal Transport',
                  prefixIcon: CupertinoIcons.tag,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                GlassTextField(
                  controller: costCtrl,
                  labelText: 'Estimated Fare (₹)',
                  hintText: '0',
                  prefixIcon: CupertinoIcons.money_dollar,
                  keyboardType: TextInputType.number,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                GlassTextField(
                  controller: notesCtrl,
                  labelText: 'Notes',
                  hintText: 'Transfer requirements, berth, scooty details...',
                  prefixIcon: CupertinoIcons.doc_text,
                  isDark: isDark,
                ),
                const SizedBox(height: 18),
                GlassButton(
                  label: 'Save Transport',
                  icon: CupertinoIcons.check_mark,
                  isDark: isDark,
                  onPressed: () {
                    if (depPlaceCtrl.text.trim().isEmpty ||
                        arrPlaceCtrl.text.trim().isEmpty) {
                      return;
                    }
                    final now = DateTime.now();
                    final transport = TravelTransport(
                      id: const Uuid().v4(),
                      tripId: tripId,
                      type: type,
                      provider: providerCtrl.text.trim().isNotEmpty
                          ? providerCtrl.text.trim()
                          : null,
                      departurePlace: depPlaceCtrl.text.trim(),
                      arrivalPlace: arrPlaceCtrl.text.trim(),
                      departureTime: now,
                      arrivalTime: now.add(const Duration(hours: 3)),
                      cost: double.tryParse(costCtrl.text.trim()) ?? 0.0,
                      notes: notesCtrl.text.trim().isNotEmpty
                          ? notesCtrl.text.trim()
                          : null,
                    );
                    context.read<TravelProvider>().addTransport(transport);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddStayDialog(BuildContext context, String tripId) {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    AccommodationStatus status = AccommodationStatus.savedPreference;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: GlassDecorations.glassModalDecoration(isDark: isDark),
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Text(
                  'Record Accommodation',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 16),
                GlassTextField(
                  controller: nameCtrl,
                  labelText: 'Property / Homestay Name',
                  hintText: 'e.g. Live In Nature Homestay',
                  prefixIcon: CupertinoIcons.house_fill,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                GlassTextField(
                  controller: addressCtrl,
                  labelText: 'Address or Area',
                  hintText: 'e.g. Lebong / Tukvar, Darjeeling',
                  prefixIcon: CupertinoIcons.placemark,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                GlassTextField(
                  controller: costCtrl,
                  labelText: 'Estimated Stay Cost (₹)',
                  hintText: '0',
                  prefixIcon: CupertinoIcons.money_dollar,
                  keyboardType: TextInputType.number,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                GlassTextField(
                  controller: notesCtrl,
                  labelText: 'Notes & Preferences',
                  hintText: 'Mountain view room, contact info...',
                  prefixIcon: CupertinoIcons.doc_text,
                  isDark: isDark,
                ),
                const SizedBox(height: 18),
                GlassButton(
                  label: 'Save Accommodation',
                  icon: CupertinoIcons.check_mark,
                  isDark: isDark,
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final now = DateTime.now();
                    final stay = TravelAccommodation(
                      id: const Uuid().v4(),
                      tripId: tripId,
                      propertyName: nameCtrl.text.trim(),
                      address: addressCtrl.text.trim().isNotEmpty
                          ? addressCtrl.text.trim()
                          : null,
                      checkIn: now,
                      checkOut: now.add(const Duration(days: 3)),
                      cost: double.tryParse(costCtrl.text.trim()) ?? 0.0,
                      bookingStatus: status,
                      notes: notesCtrl.text.trim().isNotEmpty
                          ? notesCtrl.text.trim()
                          : null,
                    );
                    context.read<TravelProvider>().addAccommodation(stay);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
