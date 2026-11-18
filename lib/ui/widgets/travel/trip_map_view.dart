import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/services/maps/google_maps_launcher.dart';
import '../../../core/services/maps/google_routes_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../core/utils/map_marker_generator.dart';
import '../../../data/models/saved_place.dart';
import '../../../providers/travel_provider.dart';
import '../glass_button.dart';
import '../glass_card.dart';
import '../liquid_pop.dart';

enum MapDisplayMode { itineraryRoute, savedPlaces }

/// Production-ready, high-performance Google Maps & Route Management module for Royal Spend.
/// Features:
/// - KeepAlive state retention across tab switches (no re-initialization lag)
/// - Complete sequential itinerary route visualization (Start 'A' -> 1 -> 2 -> ... -> End 'B')
/// - Google Routes API road polylines with fallback and retry mechanisms
/// - Comprehensive Route Information Panel with transit duration vs planned visit duration distinction
/// - Automatic non-duplicating synchronization with Saved Places
/// - One-click deep link redirection to Google Maps
/// - Zero frame-drop marker rendering with fingerprint-based change detection
class TripMapView extends StatefulWidget {
  final bool isDark;
  final VoidCallback? onNavigateToItinerary;

  const TripMapView({
    super.key,
    required this.isDark,
    this.onNavigateToItinerary,
  });

  @override
  State<TripMapView> createState() => _TripMapViewState();
}

class _TripMapViewState extends State<TripMapView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  MapDisplayMode _displayMode = MapDisplayMode.savedPlaces;
  GoogleMapController? _mapController;

  // --- Saved Places State ---
  String _selectedCategory = 'All';
  SavedPlace? _selectedPlace;
  Set<Marker> _savedPlacesMarkers = {};
  final ScrollController _listScrollController = ScrollController();
  int? _lastSavedPlacesHash;
  bool _isSyncingSavedMarkers = false;

  final List<String> _categories = [
    'All',
    'Restaurants',
    'Hotels',
    'Tourist Attractions',
    'Shopping',
    'Cafes',
    'Transport',
    'Other Saved Places',
  ];

  // --- Itinerary Route State ---
  String _selectedDayFilter = 'all'; // 'all' or dayId
  bool _isRouteCalculating = false;
  RouteComputationResult? _routeResult;
  Set<Marker> _itineraryMarkers = {};
  Set<Polyline> _itineraryPolylines = {};
  RouteWaypoint? _selectedWaypoint;
  int? _selectedLegIndex;
  int? _lastWaypointsHash;
  int _routeComputationToken = 0;

  // --- Map Controls ---
  bool _isMapExpanded = false;

  // Google Maps Dark Theme JSON
  static const String _darkMapStyle = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#1E293B"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#94A3B8"}]},
    {"elementType": "labels.text.stroke", "stylers": [{"color": "#0F172A"}]},
    {"featureType": "administrative", "elementType": "geometry", "stylers": [{"color": "#334155"}]},
    {"featureType": "administrative.country", "elementType": "geometry.stroke", "stylers": [{"color": "#475569"}]},
    {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#1E293B"}]},
    {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#64748B"}]},
    {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#14282B"}]},
    {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#334155"}]},
    {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#1E293B"}]},
    {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#94A3B8"}]},
    {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#2563EB"}]},
    {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#1D4ED8"}]},
    {"featureType": "transit", "elementType": "geometry", "stylers": [{"color": "#1E293B"}]},
    {"featureType": "transit.station", "elementType": "labels.text.fill", "stylers": [{"color": "#64748B"}]},
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#0B192C"}]},
    {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#3B82F6"}]}
  ]
  ''';

  @override
  void initState() {
    super.initState();
    // Pre-warm marker caches in background
    MapMarkerGenerator.prewarmCache();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = widget.isDark;
    final travelProvider = context.watch<TravelProvider>();
    final trip = travelProvider.selectedTrip;

    if (trip == null) {
      return Center(
        child: Text(
          'No trip selected.',
          style: TextStyle(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
      );
    }

    return Column(
      children: [
        // 1. Sleek Mode Selector: Itinerary Route (Default) vs Saved Places
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: _buildModeSegmentedControl(isDark),
        ),

        // 2. Active Mode Content with KeepAlive state
        Expanded(
          child: _displayMode == MapDisplayMode.itineraryRoute
              ? _buildItineraryRouteMode(context, travelProvider, isDark)
              : _buildSavedPlacesMode(context, travelProvider, isDark),
        ),
      ],
    );
  }

  // =========================================================================
  // TOP SELECTOR: ITINERARY ROUTE vs SAVED PLACES
  // =========================================================================

  Widget _buildModeSegmentedControl(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.70)
            : const Color(0xFFE2E8F0).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModeTabButton(
              title: 'Saved Places',
              icon: CupertinoIcons.bookmark_fill,
              isSelected: _displayMode == MapDisplayMode.savedPlaces,
              isDark: isDark,
              onTap: () {
                if (_displayMode != MapDisplayMode.savedPlaces) {
                  HapticHelper.selectionClick();
                  setState(() => _displayMode = MapDisplayMode.savedPlaces);
                }
              },
            ),
          ),
          Expanded(
            child: _buildModeTabButton(
              title: 'Itinerary Route',
              icon: CupertinoIcons.map_fill,
              isSelected: _displayMode == MapDisplayMode.itineraryRoute,
              isDark: isDark,
              onTap: () {
                if (_displayMode != MapDisplayMode.itineraryRoute) {
                  HapticHelper.selectionClick();
                  setState(() => _displayMode = MapDisplayMode.itineraryRoute);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTabButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return LiquidPop(
      pressedScale: 0.96,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
                        .withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? Colors.white
                    : (isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // ITINERARY ROUTE MODE: SEQUENTIAL ROAD ROUTE & ROUTE INFO PANEL
  // =========================================================================

  Widget _buildItineraryRouteMode(
    BuildContext context,
    TravelProvider travelProvider,
    bool isDark,
  ) {
    final days = travelProvider.currentDays;
    final waypoints =
        _extractItineraryWaypoints(travelProvider, _selectedDayFilter);

    // Fast integer hash check: Zero string allocation, pure CPU hash comparison
    int waypointsHash = _selectedDayFilter.hashCode ^ waypoints.length;
    for (int i = 0; i < waypoints.length; i++) {
      final w = waypoints[i];
      waypointsHash =
          Object.hash(waypointsHash, w.title, w.latitude, w.longitude);
    }

    if (_lastWaypointsHash != waypointsHash) {
      _lastWaypointsHash = waypointsHash;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _ensureItineraryRouteComputed(waypoints);
        }
      });
    }

    final hasWaypoints = waypoints.isNotEmpty;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day filter chips
          if (days.length > 1) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildDayFilterChip(
                    label: 'All Stops (Trip)',
                    isSelected: _selectedDayFilter == 'all',
                    isDark: isDark,
                    onTap: () {
                      HapticHelper.selectionClick();
                      setState(() {
                        _selectedDayFilter = 'all';
                        _selectedLegIndex = null;
                        _lastWaypointsHash = null;
                      });
                    },
                  ),
                  ...days.map((day) {
                    final isSel = _selectedDayFilter == day.id;
                    return Padding(
                      padding: const EdgeInsets.only(left: 6.0),
                      child: _buildDayFilterChip(
                        label: 'Day ${day.dayNumber}',
                        isSelected: isSel,
                        isDark: isDark,
                        onTap: () {
                          HapticHelper.selectionClick();
                          setState(() {
                            _selectedDayFilter = day.id;
                            _selectedLegIndex = null;
                            _lastWaypointsHash = null;
                          });
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Interactive Google Map Container
          _buildItineraryMapContainer(waypoints, isDark),
          const SizedBox(height: 12),

          // Calculating Indicator
          if (_isRouteCalculating)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
                    .withValues(alpha: 0.30),
                  width: 0.8,
                ),
              ),
              child: const Row(
                children: [
                  CupertinoActivityIndicator(radius: 8),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Calculating road route via Google Routes API...',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          // Selected Marker Quick Action Card
          if (_selectedWaypoint != null) ...[
            _buildSelectedWaypointCard(_selectedWaypoint!, isDark),
            const SizedBox(height: 12),
          ],

          // Comprehensive Route Information Panel
          _buildRouteInformationPanel(waypoints, isDark),
          const SizedBox(height: 14),

          if (!hasWaypoints) ...[
            _buildEmptyItineraryMapPrompt(isDark),
            const SizedBox(height: 14),
          ],

          // Itinerary Navigation Info Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0x18FFFFFF) : const Color(0x14000000),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.info_circle_fill,
                  size: 20,
                  color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Itinerary Management',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Add, edit, or reorder daily stops and schedules in the Itinerary tab.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.onNavigateToItinerary != null) ...[
                  const SizedBox(width: 8),
                  LiquidPop(
                    onTap: widget.onNavigateToItinerary!,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.appleBlue
                            : AppColors.royalIndigo,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildEmptyItineraryMapPrompt(bool isDark) {
    return GlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(24),
      borderRadius: 20,
      child: Center(
        child: Column(
          children: [
            Icon(
              CupertinoIcons.map_pin_ellipse,
              size: 40,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              'No Itinerary Stops Found',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add starting points, stops, or destinations in the Itinerary section to visualize the sequential road journey on the map.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
                height: 1.35,
              ),
            ),
            if (widget.onNavigateToItinerary != null) ...[
              const SizedBox(height: 14),
              GlassButton(
                label: 'Go to Itinerary',
                icon: CupertinoIcons.calendar,
                isDark: isDark,
                onPressed: widget.onNavigateToItinerary!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDayFilterChip({
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return LiquidPop(
      pressedScale: 0.94,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
              : (isDark
                  ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                  : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
                : (isDark ? const Color(0x22FFFFFF) : const Color(0x14000000)),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildItineraryMapContainer(
      List<RouteWaypoint> waypoints, bool isDark) {
    final mapHeight = _isMapExpanded ? 420.0 : 260.0;

    final initialCenter = waypoints.isNotEmpty
        ? waypoints.first.latLng
        : const LatLng(27.0420, 88.2610); // Fallback to Darjeeling region

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161618) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0x2AFFFFFF) : const Color(0x1F000000),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
          height: mapHeight,
          width: double.infinity,
          child: Stack(
            children: [
              RepaintBoundary(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: initialCenter,
                    zoom: waypoints.isNotEmpty ? 13.5 : 9.0,
                  ),
                  style: widget.isDark ? _darkMapStyle : null,
                  markers: _itineraryMarkers,
                  polylines: _itineraryPolylines,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: true,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    if (waypoints.isNotEmpty) {
                      _fitItineraryCameraBounds(waypoints);
                    }
                  },
                ),
              ),

              // Top Badges: Stops Count & Map Controls
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Stops count pill
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
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
                              CupertinoIcons.map_pin,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                waypoints.isEmpty
                                    ? 'No Route Stops'
                                    : (waypoints.length == 1
                                        ? '1 Itinerary Point'
                                        : '${waypoints.length} Sequential Stops'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Controls: Recenter & Expand
                    Row(
                      children: [
                        if (waypoints.isNotEmpty)
                          LiquidPop(
                            onTap: () {
                              HapticHelper.selectionClick();
                              _fitItineraryCameraBounds(waypoints);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.20),
                                  width: 0.8,
                                ),
                              ),
                              child: const Icon(CupertinoIcons.scope,
                                  size: 15, color: Colors.white),
                            ),
                          ),
                        const SizedBox(width: 6),
                        LiquidPop(
                          onTap: () {
                            HapticHelper.selectionClick();
                            setState(() => _isMapExpanded = !_isMapExpanded);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.20),
                                  width: 0.8),
                            ),
                            child: Icon(
                              _isMapExpanded
                                  ? CupertinoIcons.arrow_down_right_arrow_up_left
                                  : CupertinoIcons.arrow_up_left_arrow_down_right,
                              size: 15,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Sequential Leg Navigation Floating Banner over Map
              if (_selectedLegIndex != null &&
                  _routeResult != null &&
                  _routeResult!.legs.isNotEmpty &&
                  _selectedLegIndex! < _routeResult!.legs.length) ...[
                Positioned(
                  bottom: 10,
                  left: 10,
                  right: 10,
                  child: _buildActiveLegMapOverlay(
                    _routeResult!.legs[_selectedLegIndex!],
                    _selectedLegIndex!,
                    _routeResult!.legs.length,
                    waypoints,
                    isDark,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveLegMapOverlay(
    RouteLegDetail leg,
    int legIndex,
    int totalLegs,
    List<RouteWaypoint> waypoints,
    bool isDark,
  ) {
    final startWp = leg.startWaypoint ??
        (legIndex < waypoints.length ? waypoints[legIndex] : null);
    final endWp = leg.endWaypoint ??
        ((legIndex + 1) < waypoints.length ? waypoints[legIndex + 1] : null);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xF21E293B)
            : Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
              .withValues(alpha: 0.45),
          width: 1.0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Leg Step indicator & Close button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isDark
                                ? AppColors.appleBlue
                                : AppColors.royalIndigo)
                            .withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'LEG ${legIndex + 1} OF $totalLegs',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color:
                              isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${leg.formattedDistance} • ${leg.formattedDuration}',
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
                ),
              ),
              const SizedBox(width: 6),
              // Close / Reset to full route
              LiquidPop(
                onTap: () {
                  HapticHelper.selectionClick();
                  setState(() => _selectedLegIndex = null);
                  _fitItineraryCameraBounds(waypoints);
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.xmark,
                    size: 11,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),

          // Route Segment Title: From -> To
          Row(
            children: [
              Expanded(
                child: Text(
                  '${leg.startTitle} → ${leg.endTitle}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Navigation Controls Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Prev Leg
                    if (legIndex > 0)
                      LiquidPop(
                        onTap: () {
                          HapticHelper.selectionClick();
                          final newIdx = legIndex - 1;
                          final prevLeg = _routeResult!.legs[newIdx];
                          final s = prevLeg.startWaypoint ??
                              (newIdx < waypoints.length ? waypoints[newIdx] : null);
                          final e = prevLeg.endWaypoint ??
                              ((newIdx + 1) < waypoints.length
                                  ? waypoints[newIdx + 1]
                                  : null);
                          setState(() {
                            _selectedLegIndex = newIdx;
                            if (e != null) _selectedWaypoint = e;
                          });
                          if (s != null && e != null) _fitSequentialLegBounds(s, e);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0x18FFFFFF)
                                : const Color(0x0C000000),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.chevron_left,
                                  size: 11,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary),
                              const SizedBox(width: 3),
                              Text(
                                'Prev',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (legIndex > 0 && legIndex < totalLegs - 1)
                      const SizedBox(width: 6),

                    // Next Leg
                    if (legIndex < totalLegs - 1)
                      LiquidPop(
                        onTap: () {
                          HapticHelper.selectionClick();
                          final newIdx = legIndex + 1;
                          final nextLeg = _routeResult!.legs[newIdx];
                          final s = nextLeg.startWaypoint ??
                              (newIdx < waypoints.length ? waypoints[newIdx] : null);
                          final e = nextLeg.endWaypoint ??
                              ((newIdx + 1) < waypoints.length
                                  ? waypoints[newIdx + 1]
                                  : null);
                          setState(() {
                            _selectedLegIndex = newIdx;
                            if (e != null) _selectedWaypoint = e;
                          });
                          if (s != null && e != null) _fitSequentialLegBounds(s, e);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0x18FFFFFF)
                                : const Color(0x0C000000),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Next',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(CupertinoIcons.chevron_right,
                                  size: 11,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Direct Redirect in Google Maps Button
              if (startWp != null && endWp != null)
                Flexible(
                  child: LiquidPop(
                    onTap: () {
                      HapticHelper.selectionClick();
                      GoogleMapsLauncher.launchLegDirections(
                        origin: startWp,
                        destination: endWp,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [AppColors.appleBlue, const Color(0xFF2563EB)]
                              : [AppColors.royalIndigo, const Color(0xFF4338CA)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: (isDark
                                    ? AppColors.appleBlue
                                    : AppColors.royalIndigo)
                                .withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            CupertinoIcons.arrow_up_right_diamond_fill,
                            size: 11,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Navigate in Maps',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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

  Widget _buildSelectedWaypointCard(RouteWaypoint waypoint, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
              .withValues(alpha: 0.4),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
                  .withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.location_solid,
              color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  waypoint.title,
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
                Text(
                  waypoint.address ??
                      '${waypoint.latitude.toStringAsFixed(4)}, ${waypoint.longitude.toStringAsFixed(4)}',
                  style: TextStyle(
                    fontSize: 11,
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
          LiquidPop(
            onTap: () {
              HapticHelper.selectionClick();
              GoogleMapsLauncher.openCoordinates(
                latitude: waypoint.latitude,
                longitude: waypoint.longitude,
                placeName: waypoint.title,
                placeId: waypoint.placeId,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Navigate',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // ROUTE INFORMATION PANEL: DISTANCE, TRAVEL TIME & VISIT DURATION
  // =========================================================================

  Widget _buildRouteInformationPanel(
      List<RouteWaypoint> waypoints, bool isDark) {
    final route = _routeResult;

    // Calculate total planned visit duration from waypoints
    final totalVisitMinutes = waypoints.fold<int>(
      0,
      (sum, w) => sum + (w.visitDurationMinutes ?? 0),
    );

    String formattedVisitDuration = '0 min';
    if (totalVisitMinutes > 0) {
      final hours = totalVisitMinutes ~/ 60;
      final mins = totalVisitMinutes % 60;
      if (hours > 0 && mins > 0) {
        formattedVisitDuration = '$hours hr $mins min';
      } else if (hours > 0) {
        formattedVisitDuration = '$hours hr${hours > 1 ? 's' : ''}';
      } else {
        formattedVisitDuration = '$mins min';
      }
    }

    // Total combined duration (transit + visit)
    final totalTransitSeconds = route?.totalDurationSeconds ?? 0;
    final totalCombinedMinutes = (totalTransitSeconds ~/ 60) + totalVisitMinutes;
    String formattedCombinedDuration = formattedVisitDuration;
    if (totalCombinedMinutes > 0) {
      final hours = totalCombinedMinutes ~/ 60;
      final mins = totalCombinedMinutes % 60;
      if (hours > 0 && mins > 0) {
        formattedCombinedDuration = '$hours hr $mins min';
      } else if (hours > 0) {
        formattedCombinedDuration = '$hours hr${hours > 1 ? 's' : ''}';
      } else {
        formattedCombinedDuration = '$mins min';
      }
    }

    return GlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Open in Google Maps Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.compass_fill,
                      size: 18,
                      color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Journey Route Overview',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Open in Google Maps Action Button
              if (waypoints.isNotEmpty)
                LiquidPop(
                  onTap: () {
                    HapticHelper.selectionClick();
                    GoogleMapsLauncher.openItineraryRoute(
                      origin: waypoints.first,
                      destination: waypoints.length > 1 ? waypoints.last : null,
                      waypoints: waypoints.length > 2
                          ? waypoints.sublist(1, waypoints.length - 1)
                          : null,
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                            .withValues(alpha: 0.35),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.arrow_up_right_square,
                          size: 13,
                          color: isDark
                              ? AppColors.appleBlue
                              : AppColors.royalIndigo,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Open in Google Maps',
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

          // Error / Quota / Offline Notice if Routes API failed
          if (route != null && route.hasError) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.appleOrange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.appleOrange.withValues(alpha: 0.35),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.exclamationmark_triangle_fill,
                      color: AppColors.appleOrange, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Road route estimation note: ${route.errorMessage}',
                      style: const TextStyle(fontSize: 11, height: 1.3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  LiquidPop(
                    onTap: () {
                      HapticHelper.selectionClick();
                      GoogleRoutesService.instance.clearCache();
                      _lastWaypointsHash = null;
                      _ensureItineraryRouteComputed(waypoints);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.appleOrange,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Retry',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 4-Column Key Metrics Grid
          Row(
            children: [
              // Total Road Distance
              Expanded(
                child: _buildMetricTile(
                  title: 'Road Distance',
                  value: route?.formattedTotalDistance ??
                      (waypoints.length < 2 ? '0 km' : 'Calculating...'),
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),

              // Total Transit Travel Time
              Expanded(
                child: _buildMetricTile(
                  title: 'Travel Time',
                  value: route?.formattedTotalDuration ??
                      (waypoints.length < 2 ? '0 min' : 'Calculating...'),
                  color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              // Planned Visit Duration
              Expanded(
                child: _buildMetricTile(
                  title: 'Planned Visit',
                  value: formattedVisitDuration,
                  color: isDark ? AppColors.appleGreen : AppColors.vividMint,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),

              // Total Combined Time
              Expanded(
                child: _buildMetricTile(
                  title: 'Total Journey',
                  value: formattedCombinedDuration,
                  color: const Color(0xFFAF52DE), // Apple Purple
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Consecutive Route Segments Table Breakdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Sequential Route Breakdown (${waypoints.length} Stops)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_selectedLegIndex != null) ...[
                const SizedBox(width: 8),
                LiquidPop(
                  onTap: () {
                    HapticHelper.selectionClick();
                    setState(() => _selectedLegIndex = null);
                    _fitItineraryCameraBounds(waypoints);
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isDark
                              ? AppColors.appleBlue
                              : AppColors.royalIndigo)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: (isDark
                                ? AppColors.appleBlue
                                : AppColors.royalIndigo)
                            .withValues(alpha: 0.35),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.arrow_counterclockwise,
                          size: 10,
                          color: isDark
                              ? AppColors.appleBlue
                              : AppColors.royalIndigo,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Show Full Route',
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
              ] else ...[
                const SizedBox(width: 8),
                Text(
                  'START → END',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          if (route != null && route.legs.isNotEmpty) ...[
            ...route.legs.asMap().entries.map((entry) {
              final idx = entry.key;
              final leg = entry.value;
              final isSelected = _selectedLegIndex == idx;
              final startWp = leg.startWaypoint ??
                  (idx < waypoints.length ? waypoints[idx] : null);
              final endWp = leg.endWaypoint ??
                  ((idx + 1) < waypoints.length ? waypoints[idx + 1] : null);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark
                            ? AppColors.appleBlue.withValues(alpha: 0.16)
                            : AppColors.royalIndigo.withValues(alpha: 0.08))
                        : (isDark
                            ? const Color(0x11FFFFFF)
                            : const Color(0x08000000)),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? (isDark
                              ? AppColors.appleBlue
                              : AppColors.royalIndigo)
                          : (isDark
                              ? const Color(0x14FFFFFF)
                              : const Color(0x0E000000)),
                      width: isSelected ? 1.5 : 0.8,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        HapticHelper.selectionClick();
                        setState(() {
                          _selectedLegIndex = idx;
                          if (endWp != null) _selectedWaypoint = endWp;
                        });
                        if (startWp != null && endWp != null) {
                          _fitSequentialLegBounds(startWp, endWp);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Step Number Badge
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: isSelected
                                          ? [
                                              isDark
                                                  ? AppColors.appleBlue
                                                  : AppColors.royalIndigo,
                                              isDark
                                                  ? const Color(0xFF60A5FA)
                                                  : const Color(0xFF4F46E5),
                                            ]
                                          : [
                                              (isDark
                                                      ? AppColors.appleBlue
                                                      : AppColors.royalIndigo)
                                                  .withValues(alpha: 0.20),
                                              (isDark
                                                      ? AppColors.appleBlue
                                                      : AppColors.royalIndigo)
                                                  .withValues(alpha: 0.08),
                                            ],
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: (isDark
                                                      ? AppColors.appleBlue
                                                      : AppColors.royalIndigo)
                                                  .withValues(alpha: 0.35),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${idx + 1}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected
                                            ? Colors.white
                                            : (isDark
                                                ? AppColors.appleBlue
                                                : AppColors.royalIndigo),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Leg Segment Description
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${leg.startTitle} → ${leg.endTitle}',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? AppColors.darkTextPrimary
                                              : AppColors.lightTextPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Text(
                                            '${leg.formattedDistance} • ${leg.formattedDuration} travel',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? AppColors.appleBlue
                                                  : AppColors.royalIndigo,
                                            ),
                                          ),
                                          if (leg.endVisitDurationMinutes !=
                                                  null &&
                                              leg.endVisitDurationMinutes! >
                                                  0) ...[
                                            Text(
                                              ' • ${leg.formattedVisitDuration} visit',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: isDark
                                                    ? AppColors.appleGreen
                                                    : AppColors.vividMint,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            // Map & Redirection Action Buttons
                            Align(
                              alignment: Alignment.centerRight,
                              child: Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  // Option 1: Map View (In-App camera zoom & preview)
                                  if (startWp != null && endWp != null)
                                    LiquidPop(
                                      onTap: () {
                                        HapticHelper.selectionClick();
                                        setState(() {
                                          _selectedLegIndex = idx;
                                          _selectedWaypoint = endWp;
                                        });
                                        _fitSequentialLegBounds(startWp, endWp);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 9, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0x1FFFFFFF)
                                              : const Color(0x0D000000),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isDark
                                                ? const Color(0x28FFFFFF)
                                                : const Color(0x18000000),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              CupertinoIcons.map,
                                              size: 12,
                                              color: isDark
                                                  ? AppColors.darkTextPrimary
                                                  : AppColors.lightTextPrimary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'View on Map',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: isDark
                                                    ? AppColors.darkTextPrimary
                                                    : AppColors.lightTextPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                  // Option 2: Redirect in Google Maps for this Leg
                                  if (startWp != null && endWp != null)
                                    LiquidPop(
                                      onTap: () {
                                        HapticHelper.selectionClick();
                                        GoogleMapsLauncher.launchLegDirections(
                                          origin: startWp,
                                          destination: endWp,
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: isDark
                                                ? [
                                                    AppColors.appleBlue,
                                                    const Color(0xFF2563EB)
                                                  ]
                                                : [
                                                    AppColors.royalIndigo,
                                                    const Color(0xFF4338CA)
                                                  ],
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: [
                                            BoxShadow(
                                              color: (isDark
                                                      ? AppColors.appleBlue
                                                      : AppColors.royalIndigo)
                                                  .withValues(alpha: 0.3),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1.5),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Icon(
                                              CupertinoIcons
                                                  .arrow_up_right_diamond_fill,
                                              size: 12,
                                              color: Colors.white,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Navigate in Maps',
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
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ] else if (waypoints.length > 1 && _isRouteCalculating) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CupertinoActivityIndicator(radius: 8),
                    const SizedBox(width: 8),
                    Text(
                      'Calculating consecutive road segments...',
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
          ] else ...[
            // Simple sequential list when route response hasn't arrived
            ...waypoints.asMap().entries.map((entry) {
              final idx = entry.key;
              final wp = entry.value;
              final isFirst = idx == 0;
              final isLast = idx == waypoints.length - 1;
              final prevWp = idx > 0 ? waypoints[idx - 1] : null;

              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0x0CFFFFFF)
                        : const Color(0x06000000),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isFirst
                                  ? AppColors.appleGreen
                                  : (isLast
                                      ? AppColors.appleRed
                                      : AppColors.appleBlue))
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isFirst ? 'START' : (isLast ? 'DEST' : 'STOP $idx'),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: isFirst
                                ? AppColors.appleGreen
                                : (isLast
                                    ? AppColors.appleRed
                                    : AppColors.appleBlue),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          wp.title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // View on Map
                      LiquidPop(
                        onTap: () {
                          HapticHelper.selectionClick();
                          setState(() => _selectedWaypoint = wp);
                          _mapController?.animateCamera(
                            CameraUpdate.newLatLngZoom(wp.latLng, 14.5),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            CupertinoIcons.map,
                            size: 15,
                            color: isDark
                                ? AppColors.appleBlue
                                : AppColors.royalIndigo,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Redirect in Maps
                      LiquidPop(
                        onTap: () {
                          HapticHelper.selectionClick();
                          if (prevWp != null) {
                            GoogleMapsLauncher.launchLegDirections(
                              origin: prevWp,
                              destination: wp,
                            );
                          } else {
                            GoogleMapsLauncher.openCoordinates(
                              latitude: wp.latitude,
                              longitude: wp.longitude,
                              placeName: wp.title,
                              placeId: wp.placeId,
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            CupertinoIcons.arrow_up_right_diamond_fill,
                            size: 15,
                            color: isDark
                                ? AppColors.appleBlue
                                : AppColors.royalIndigo,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.6)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0x14FFFFFF) : const Color(0x0A000000),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SAVED PLACES MODE: MAP + CATEGORY TILES + AUTOMATIC SYNCHRONIZATION
  // =========================================================================

  Widget _buildSavedPlacesMode(
    BuildContext context,
    TravelProvider travelProvider,
    bool isDark,
  ) {
    final allPlaces = travelProvider.currentSavedPlaces;

    final filteredPlaces = allPlaces.where((p) {
      if (_selectedCategory == 'All') return true;
      return p.category.toLowerCase() == _selectedCategory.toLowerCase();
    }).toList();

    // Collect valid coordinates for map markers
    final validPlaces = filteredPlaces
        .where((p) => p.latitude != null && p.longitude != null)
        .toList();

    // Fast integer hash check to prevent infinite post-frame rebuild churn and zero string allocation
    int placesHash = _selectedCategory.hashCode ^ validPlaces.length;
    for (int i = 0; i < validPlaces.length; i++) {
      final p = validPlaces[i];
      placesHash = Object.hash(
          placesHash, p.id, p.latitude, p.longitude, p.name, p.category);
    }

    if (_lastSavedPlacesHash != placesHash && !_isSyncingSavedMarkers) {
      _lastSavedPlacesHash = placesHash;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _syncSavedPlacesMarkers(filteredPlaces);
        }
      });
    }

    return Column(
      children: [
        // Category Filter Chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _categories.map((cat) {
                final isSel = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: LiquidPop(
                    pressedScale: 0.94,
                    onTap: () {
                      HapticHelper.selectionClick();
                      setState(() {
                        _selectedCategory = cat;
                        _lastSavedPlacesHash = null;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSel
                            ? (isDark
                                ? AppColors.appleBlue
                                : AppColors.royalIndigo)
                            : (isDark
                                ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                                : Colors.black.withValues(alpha: 0.05)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSel
                              ? (isDark
                                  ? AppColors.appleBlue
                                  : AppColors.royalIndigo)
                              : (isDark
                                  ? const Color(0x22FFFFFF)
                                  : const Color(0x14000000)),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
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
          ),
        ),
        const SizedBox(height: 6),

        // Interactive Google Map Container
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: _buildInteractivePlacesMap(validPlaces, isDark),
        ),
        const SizedBox(height: 10),

        // Floating Selected Place Action Card (if a marker was tapped)
        if (_selectedPlace != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: _buildSelectedPlaceQuickPreview(_selectedPlace!, isDark),
          ),

        // Saved Places List View
        Expanded(
          child: _buildSavedPlacesCardsList(
            filteredPlaces,
            validPlaces,
            isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildInteractivePlacesMap(List<SavedPlace> validPlaces, bool isDark) {
    final mapHeight = _isMapExpanded ? 420.0 : 250.0;

    final initialCenter = validPlaces.isNotEmpty
        ? LatLng(validPlaces.first.latitude!, validPlaces.first.longitude!)
        : const LatLng(20.5937, 78.9629); // Center of India fallback

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161618) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0x2AFFFFFF) : const Color(0x1F000000),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
          height: mapHeight,
          width: double.infinity,
          child: Stack(
            children: [
              RepaintBoundary(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: initialCenter,
                    zoom: validPlaces.isNotEmpty ? 13.0 : 5.0,
                  ),
                  style: widget.isDark ? _darkMapStyle : null,
                  markers: _savedPlacesMarkers,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: true,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    if (validPlaces.isNotEmpty) {
                      _fitPlacesBounds(validPlaces);
                    }
                  },
                ),
              ),

              // Overlay: Top Badges & Map Control Buttons
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Location Count Badge
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
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
                              CupertinoIcons.location_solid,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                '${validPlaces.length} Saved on Map',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Controls: Recenter & Expand
                    Row(
                      children: [
                        if (validPlaces.isNotEmpty)
                          LiquidPop(
                            onTap: () {
                              HapticHelper.selectionClick();
                              _fitPlacesBounds(validPlaces);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.20),
                                  width: 0.8,
                                ),
                              ),
                              child: const Icon(CupertinoIcons.scope,
                                  size: 15, color: Colors.white),
                            ),
                          ),
                        const SizedBox(width: 6),
                        LiquidPop(
                          onTap: () {
                            HapticHelper.selectionClick();
                            setState(() => _isMapExpanded = !_isMapExpanded);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.20),
                                width: 0.8,
                              ),
                            ),
                            child: Icon(
                              _isMapExpanded
                                  ? CupertinoIcons.arrow_down_right_arrow_up_left
                                  : CupertinoIcons.arrow_up_left_arrow_down_right,
                              size: 15,
                              color: Colors.white,
                            ),
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
      ),
    );
  }

  Widget _buildSelectedPlaceQuickPreview(SavedPlace place, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
              .withValues(alpha: 0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getCategoryColor(place.category).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getCategoryIcon(place.category),
              color: _getCategoryColor(place.category),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        place.name,
                        style: AppTextStyles.titleMedium.copyWith(
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
                    const SizedBox(width: 4),
                    Text(
                      'SELECTED',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color:
                            isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  place.address ?? place.category,
                  style: TextStyle(
                    fontSize: 11,
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
          const SizedBox(width: 10),

          // Open in Google Maps Action Button
          LiquidPop(
            onTap: () {
              HapticHelper.selectionClick();
              if (place.latitude != null && place.longitude != null) {
                GoogleMapsLauncher.openCoordinates(
                  latitude: place.latitude!,
                  longitude: place.longitude!,
                  placeName: place.name,
                  placeId: place.placeId,
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.location_fill,
                      size: 12, color: Colors.white),
                  SizedBox(width: 5),
                  Text(
                    'Navigate',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedPlacesCardsList(
    List<SavedPlace> places,
    List<SavedPlace> validPlaces,
    bool isDark,
  ) {
    if (places.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.map_pin_ellipse,
                size: 42,
                color: isDark
                    ? const Color(0x33FFFFFF)
                    : const Color(0x33000000),
              ),
              const SizedBox(height: 10),
              Text(
                'No Saved Places in this Category',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Destinations added to your Itinerary automatically appear here with full GPS navigation.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                  height: 1.35,
                ),
              ),
              if (widget.onNavigateToItinerary != null) ...[
                const SizedBox(height: 14),
                GlassButton(
                  label: 'Go to Itinerary',
                  icon: CupertinoIcons.calendar,
                  isDark: isDark,
                  onPressed: widget.onNavigateToItinerary!,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      controller: _listScrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      itemCount: places.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final place = places[index];
        final isSelected = _selectedPlace?.id == place.id;
        final hasCoordinates =
            place.latitude != null && place.longitude != null;

        return RepaintBoundary(
          child: LiquidPop(
            pressedScale: 0.98,
            onTap: () {
              HapticHelper.selectionClick();
              _focusPlaceOnMap(place);
            },
            child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? (isSelected
                      ? const Color(0xFF1E293B)
                      : const Color(0xFF141E2E).withValues(alpha: 0.75))
                  : (isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.85)),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
                    : (isDark
                        ? const Color(0x18FFFFFF)
                        : const Color(0x12000000)),
                width: isSelected ? 1.5 : 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Category Icon Badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(place.category)
                        .withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      _getCategoryIcon(place.category),
                      color: _getCategoryColor(place.category),
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name & Address Details
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
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        place.address ?? place.category,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),

                      // Category, Itinerary association, & GPS status chips
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(place.category)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              place.category,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: _getCategoryColor(place.category),
                              ),
                            ),
                          ),
                          if (place.locationNotes != null &&
                              place.locationNotes!.contains('Itinerary:')) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isDark
                                        ? AppColors.appleBlue
                                        : AppColors.royalIndigo)
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    CupertinoIcons.calendar,
                                    size: 8,
                                    color: isDark
                                        ? AppColors.appleBlue
                                        : AppColors.royalIndigo,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Itinerary Destination',
                                    style: TextStyle(
                                      fontSize: 9,
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
                          if (hasCoordinates) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isDark
                                        ? AppColors.appleGreen
                                        : AppColors.vividMint)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    CupertinoIcons.location_solid,
                                    size: 8,
                                    color: isDark
                                        ? AppColors.appleGreen
                                        : AppColors.vividMint,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'GPS Verified',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? AppColors.appleGreen
                                          : AppColors.vividMint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Open in Google Maps Action Button
                if (hasCoordinates)
                  LiquidPop(
                    onTap: () {
                      HapticHelper.selectionClick();
                      GoogleMapsLauncher.openCoordinates(
                        latitude: place.latitude!,
                        longitude: place.longitude!,
                        placeName: place.name,
                        placeId: place.placeId,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: (isDark
                                ? AppColors.appleBlue
                                : AppColors.royalIndigo)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        CupertinoIcons.map,
                        size: 16,
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
      );
    },
    );
  }

  void _focusPlaceOnMap(SavedPlace place) {
    setState(() => _selectedPlace = place);

    if (place.latitude != null &&
        place.longitude != null &&
        _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(place.latitude!, place.longitude!),
          15.5,
        ),
      );
    }
  }

  // =========================================================================
  // ROUTE EXTRACTION & ROAD COMPUTATION HELPERS
  // =========================================================================

  List<RouteWaypoint> _extractItineraryWaypoints(
    TravelProvider travelProvider,
    String dayFilter,
  ) {
    final List<RouteWaypoint> waypoints = [];
    final days = travelProvider.currentDays;

    final targetDays = dayFilter == 'all'
        ? days
        : days.where((d) => d.id == dayFilter).toList();

    int stopCounter = 0;

    for (final day in targetDays) {
      if (day.hasStartingPoint && day.hasStartingCoordinates) {
        waypoints.add(RouteWaypoint(
          title: day.startPlaceName!.trim(),
          latitude: day.startLatitude!,
          longitude: day.startLongitude!,
          placeId: day.startPlaceId,
          address: day.startAddress,
          stopType: 'start',
          stopNumber: null,
          visitDurationMinutes: null,
        ));
      }

      final activities = travelProvider.activitiesByDay[day.id] ?? [];
      for (final act in activities) {
        if (act.latitude != null && act.longitude != null) {
          stopCounter++;
          waypoints.add(RouteWaypoint(
            title: act.placeName?.isNotEmpty == true
                ? act.placeName!
                : act.title,
            latitude: act.latitude!,
            longitude: act.longitude!,
            placeId: act.placeId,
            address: act.address,
            visitDurationMinutes: act.durationMinutes,
            stopType: 'stop',
            stopNumber: stopCounter,
          ));
        }
      }

      if (day.hasEndPoint && day.hasEndCoordinates) {
        waypoints.add(RouteWaypoint(
          title: day.endPlaceName!.trim(),
          latitude: day.endLatitude!,
          longitude: day.endLongitude!,
          placeId: day.endPlaceId,
          address: day.endAddress,
          stopType: 'end',
          stopNumber: null,
          visitDurationMinutes: null,
        ));
      }
    }

    return waypoints;
  }

  Future<void> _ensureItineraryRouteComputed(
      List<RouteWaypoint> waypoints) async {
    if (waypoints.length < 2) {
      if (_itineraryMarkers.isNotEmpty || _itineraryPolylines.isNotEmpty) {
        if (mounted) {
          setState(() {
            _itineraryMarkers = waypoints.isNotEmpty
                ? {
                    Marker(
                      markerId: const MarkerId('single_point'),
                      position: waypoints.first.latLng,
                      infoWindow: InfoWindow(title: waypoints.first.title),
                    )
                  }
                : {};
            _itineraryPolylines = {};
            _routeResult = null;
          });
        }
      }
      return;
    }

    final currentToken = ++_routeComputationToken;
    if (mounted) {
      setState(() {
        _isRouteCalculating = true;
        _selectedLegIndex = null;
      });
    }

    final origin = waypoints.first;
    final destination = waypoints.last;
    final intermediates = waypoints.length > 2
        ? waypoints.sublist(1, waypoints.length - 1)
        : <RouteWaypoint>[];

    final result = await GoogleRoutesService.instance.computeRoute(
      origin: origin,
      destination: destination,
      intermediates: intermediates,
    );

    if (currentToken != _routeComputationToken || !mounted) return;

    // Build custom sequential markers
    final Set<Marker> newMarkers = {};
    for (int i = 0; i < waypoints.length; i++) {
      final wp = waypoints[i];
      final isStart = i == 0;
      final isEnd = i == waypoints.length - 1;

      String label;
      Color color;
      if (isStart) {
        label = 'A';
        color = const Color(0xFF34C759); // Green Start
      } else if (isEnd) {
        label = 'B';
        color = const Color(0xFFFF3B30); // Red Destination
      } else {
        label = '$i';
        color = const Color(0xFF007AFF); // Blue Stop
      }

      final icon = await MapMarkerGenerator.createNumberedMarker(
        label: label,
        backgroundColor: color,
      );

      newMarkers.add(Marker(
        markerId: MarkerId('waypoint_$i'),
        position: wp.latLng,
        icon: icon,
        infoWindow: InfoWindow(
          title: isStart
              ? 'Starting Point: ${wp.title}'
              : (isEnd ? 'Destination: ${wp.title}' : 'Stop $i: ${wp.title}'),
          snippet: wp.address ??
              (wp.visitDurationMinutes != null
                  ? 'Planned visit: ${wp.formattedVisitDuration}'
                  : null),
          onTap: () {
            GoogleMapsLauncher.openCoordinates(
              latitude: wp.latitude,
              longitude: wp.longitude,
              placeName: wp.title,
              placeId: wp.placeId,
            );
          },
        ),
        onTap: () {
          HapticHelper.selectionClick();
          setState(() => _selectedWaypoint = wp);
        },
      ));
    }

    // Build polyline from computed road route
    final Set<Polyline> newPolylines = {};
    if (result.polylinePoints.isNotEmpty) {
      newPolylines.add(Polyline(
        polylineId: const PolylineId('itinerary_road_route'),
        points: result.polylinePoints,
        color: const Color(0xFF0A84FF),
        width: 5,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ));
    }

    if (mounted) {
      setState(() {
        _isRouteCalculating = false;
        _routeResult = result;
        _itineraryMarkers = newMarkers;
        _itineraryPolylines = newPolylines;
      });

      _fitItineraryCameraBounds(waypoints);
    }
  }

  Future<void> _syncSavedPlacesMarkers(List<SavedPlace> places) async {
    if (_isSyncingSavedMarkers) return;
    _isSyncingSavedMarkers = true;

    try {
      final validPlaces = places
          .where((p) => p.latitude != null && p.longitude != null)
          .toList();

      final Set<Marker> newMarkers = {};

      for (final p in validPlaces) {
        final icon = await MapMarkerGenerator.createCategoryMarker(
          category: p.category,
        );

        newMarkers.add(
          Marker(
            markerId: MarkerId('saved_place_${p.id}'),
            position: LatLng(p.latitude!, p.longitude!),
            icon: icon,
            infoWindow: InfoWindow(
              title: p.name,
              snippet: p.address ?? p.category,
              onTap: () {
                GoogleMapsLauncher.openCoordinates(
                  latitude: p.latitude!,
                  longitude: p.longitude!,
                  placeName: p.name,
                  placeId: p.placeId,
                );
              },
            ),
            onTap: () {
              HapticHelper.selectionClick();
              setState(() => _selectedPlace = p);
              _mapController?.animateCamera(
                CameraUpdate.newLatLng(LatLng(p.latitude!, p.longitude!)),
              );
            },
          ),
        );
      }

      if (mounted) {
        setState(() => _savedPlacesMarkers = newMarkers);
      }
    } finally {
      _isSyncingSavedMarkers = false;
    }
  }

  void _fitItineraryCameraBounds(List<RouteWaypoint> waypoints) {
    if (waypoints.isEmpty || _mapController == null) return;

    if (waypoints.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(waypoints.first.latLng, 14),
      );
      return;
    }

    double minLat = waypoints.first.latitude;
    double maxLat = waypoints.first.latitude;
    double minLng = waypoints.first.longitude;
    double maxLng = waypoints.first.longitude;

    for (final wp in waypoints) {
      if (wp.latitude < minLat) minLat = wp.latitude;
      if (wp.latitude > maxLat) maxLat = wp.latitude;
      if (wp.longitude < minLng) minLng = wp.longitude;
      if (wp.longitude > maxLng) maxLng = wp.longitude;
    }

    if (minLat == maxLat && minLng == maxLng) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(minLat, minLng), 14.0),
      );
      return;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 55.0),
    );
  }

  void _fitSequentialLegBounds(RouteWaypoint start, RouteWaypoint end) {
    if (_mapController == null) return;

    final latDiff = (start.latitude - end.latitude).abs();
    final lngDiff = (start.longitude - end.longitude).abs();

    if (latDiff < 0.0001 && lngDiff < 0.0001) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(start.latLng, 15.0),
      );
      return;
    }

    final minLat = math.min(start.latitude, end.latitude);
    final maxLat = math.max(start.latitude, end.latitude);
    final minLng = math.min(start.longitude, end.longitude);
    final maxLng = math.max(start.longitude, end.longitude);

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 65.0),
    );
  }

  void _fitPlacesBounds(List<SavedPlace> places) {
    if (places.isEmpty || _mapController == null) return;

    final points = places
        .where((p) => p.latitude != null && p.longitude != null)
        .map((p) => LatLng(p.latitude!, p.longitude!))
        .toList();

    if (points.isEmpty) return;

    if (points.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 15.0),
      );
      return;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final pt in points) {
      if (pt.latitude < minLat) minLat = pt.latitude;
      if (pt.latitude > maxLat) maxLat = pt.latitude;
      if (pt.longitude < minLng) minLng = pt.longitude;
      if (pt.longitude > maxLng) maxLng = pt.longitude;
    }

    if (minLat == maxLat && minLng == maxLng) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(minLat, minLng), 15.0),
      );
      return;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50.0),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'restaurants':
      case 'food':
        return const Color(0xFFFF9500); // Orange
      case 'cafes':
        return const Color(0xFFFF2D55); // Pink
      case 'hotels':
      case 'lodging':
        return const Color(0xFF34C759); // Green
      case 'shopping':
        return const Color(0xFFAF52DE); // Purple
      case 'tourist attractions':
      case 'sightseeing':
        return const Color(0xFF007AFF); // Blue
      case 'transport':
        return const Color(0xFF5856D6); // Indigo
      default:
        return const Color(0xFF64748B); // Slate
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'restaurants':
      case 'food':
        return CupertinoIcons.cart_fill;
      case 'cafes':
        return CupertinoIcons.circle_grid_hex_fill;
      case 'hotels':
      case 'lodging':
        return CupertinoIcons.bed_double_fill;
      case 'shopping':
        return CupertinoIcons.bag_fill;
      case 'tourist attractions':
      case 'sightseeing':
        return CupertinoIcons.star_fill;
      case 'transport':
        return CupertinoIcons.bus;
      default:
        return CupertinoIcons.map_pin_ellipse;
    }
  }
}
