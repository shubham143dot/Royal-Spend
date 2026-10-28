import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../data/models/saved_place.dart';
import '../../../providers/travel_provider.dart';
import '../glass_card.dart';
import '../liquid_pop.dart';

class TripMapView extends StatefulWidget {
  final bool isDark;

  const TripMapView({super.key, required this.isDark});

  @override
  State<TripMapView> createState() => _TripMapViewState();
}

class _TripMapViewState extends State<TripMapView> {
  SavedPlace? _selectedPlace;

  @override
  Widget build(BuildContext context) {
    final travelProvider = context.watch<TravelProvider>();
    final places = travelProvider.currentSavedPlaces;
    final isDark = widget.isDark;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Visual Route Canvas
          GlassCard(
            isDark: isDark,
            padding: EdgeInsets.zero,
            borderRadius: 24,
            child: SizedBox(
              height: 260,
              width: double.infinity,
              child: Stack(
                children: [
                  // Map Background with Grid & Topo Contours
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFE2E8F0),
                      ),
                      child: CustomPaint(
                        painter: _MountainMapPainter(isDark: isDark),
                      ),
                    ),
                  ),

                  // Pins for key places
                  if (places.isNotEmpty)
                    ...places.take(8).toList().asMap().entries.map((entry) {
                      final idx = entry.key;
                      final p = entry.value;

                      // Map relative positions
                      final offsets = [
                        const Offset(0.48, 0.35), // Pagoda / Mall Road
                        const Offset(0.32, 0.45), // Batasia / Ghoom
                        const Offset(0.68, 0.50), // Lamahatta
                        const Offset(0.52, 0.75), // Dow Hills / Kurseong
                        const Offset(0.78, 0.88), // Siliguri / NJP
                        const Offset(0.20, 0.60), // Sukhiapokhri
                        const Offset(0.40, 0.28), // Orange Valley
                        const Offset(0.85, 0.32), // Lover's Meet
                      ];

                      final pos = offsets[idx % offsets.length];
                      final isSelected = _selectedPlace?.id == p.id;

                      return LayoutBuilder(builder: (ctx, constraints) {
                        return Positioned(
                          left: constraints.maxWidth * pos.dx - 16,
                          top: 260 * pos.dy - 24,
                          child: GestureDetector(
                            onTap: () {
                              HapticHelper.selectionClick();
                              setState(() => _selectedPlace = p);
                            },
                            child: AnimatedScale(
                              scale: isSelected ? 1.25 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? AppColors.appleGreen
                                          : (isDark
                                              ? AppColors.appleBlue
                                              : AppColors.royalIndigo),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      CupertinoIcons.placemark_fill,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black
                                          .withValues(alpha: 0.70),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      p.name.split(',').first,
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      });
                    }),

                  // Map Overlay Header
                  Positioned(
                    top: 12,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.20),
                          width: 0.8,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.compass,
                              size: 13, color: Colors.white),
                          SizedBox(width: 5),
                          Text(
                            'Darjeeling & North Bengal Geographic Route',
                            style: TextStyle(
                              fontSize: 10,
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
          ),
          const SizedBox(height: 16),

          // Selected Place Card or Guide
          if (_selectedPlace != null) ...[
            GlassCard(
              isDark: isDark,
              padding: const EdgeInsets.all(16.0),
              borderRadius: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _selectedPlace!.name,
                          style: AppTextStyles.titleMedium.copyWith(
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isDark
                                  ? AppColors.appleBlue
                                  : AppColors.royalIndigo)
                              .withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _selectedPlace!.category,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.appleBlue
                                : AppColors.royalIndigo,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_selectedPlace!.locationNotes != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _selectedPlace!.locationNotes!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (_selectedPlace!.latitude != null &&
                          _selectedPlace!.longitude != null)
                        Text(
                          '${_selectedPlace!.latitude!.toStringAsFixed(4)}° N, ${_selectedPlace!.longitude!.toStringAsFixed(4)}° E',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                        ),
                      const Spacer(),
                      LiquidPop(
                        onTap: () {
                          HapticHelper.mediumImpact();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Ready to launch navigation to ${_selectedPlace!.name}'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.appleBlue
                                : AppColors.royalIndigo,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.location_fill,
                                  size: 13, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Directions',
                                style: TextStyle(
                                  fontSize: 11,
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
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Route Places Breakdown
          Text(
            'Route Highlights (${places.length} Spots)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 10),

          ...places.take(6).map((p) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: GlassCard(
                isDark: isDark,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14.0, vertical: 10.0),
                borderRadius: 14,
                onTap: () {
                  HapticHelper.selectionClick();
                  setState(() => _selectedPlace = p);
                },
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.placemark,
                      size: 16,
                      color: isDark
                          ? AppColors.appleBlue
                          : AppColors.royalIndigo,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        p.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                    Text(
                      p.category,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MountainMapPainter extends CustomPainter {
  final bool isDark;

  _MountainMapPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Grid
    final gridPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.04)
          : Colors.black.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 2. Mountain Ridges / Contours
    final contourPaint = Paint()
      ..color = isDark
          ? const Color(0xFF1E293B).withValues(alpha: 0.7)
          : const Color(0xFFCBD5E1).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 1; i <= 4; i++) {
      final path = Path();
      final base = size.height * (i * 0.22);
      path.moveTo(0, base);
      path.cubicTo(
        size.width * 0.25,
        base - 20 * i,
        size.width * 0.65,
        base + 15 * i,
        size.width,
        base - 10 * i,
      );
      canvas.drawPath(path, contourPaint);
    }

    // 3. Winding Scenic Hill Highway (Siliguri -> Kurseong -> Darjeeling)
    final roadPaint = Paint()
      ..color = (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
          .withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final road = Path();
    road.moveTo(size.width * 0.80, size.height * 0.90); // Siliguri
    road.cubicTo(
      size.width * 0.60,
      size.height * 0.75, // Rohini / Kurseong
      size.width * 0.40,
      size.height * 0.60, // Ghoom / Batasia
      size.width * 0.50,
      size.height * 0.35, // Darjeeling
    );
    canvas.drawPath(road, roadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
