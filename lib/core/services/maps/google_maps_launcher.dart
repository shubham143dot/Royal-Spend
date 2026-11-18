import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'google_routes_service.dart';

class GoogleMapsLauncher {
  GoogleMapsLauncher._();

  /// Launches Google Maps navigation with full itinerary sequence:
  /// Origin -> Stop 1 -> Stop 2 -> ... -> Destination.
  /// Falls back to browser if the Google Maps app is not installed.
  static Future<bool> launchItineraryDirections({
    required RouteWaypoint origin,
    required RouteWaypoint destination,
    List<RouteWaypoint> intermediates = const [],
  }) async {
    final originParam = '${origin.latitude},${origin.longitude}';
    final destParam = '${destination.latitude},${destination.longitude}';

    final queryParams = <String, String>{
      'api': '1',
      'origin': originParam,
      'destination': destParam,
      'travelmode': 'driving',
    };

    if (intermediates.isNotEmpty) {
      final waypointsParam = intermediates
          .map((w) => '${w.latitude},${w.longitude}')
          .join('|');
      queryParams['waypoints'] = waypointsParam;
    }

    final uri = Uri.https('www.google.com', '/maps/dir/', queryParams);

    return _launch(uri);
  }

  /// Launches Google Maps focused on a single place or location coordinate.
  static Future<bool> launchPlaceLocation({
    required double latitude,
    required double longitude,
    String? placeName,
    String? placeId,
  }) async {
    final queryParams = <String, String>{
      'api': '1',
      'query': '$latitude,$longitude',
    };

    if (placeId != null && placeId.isNotEmpty) {
      queryParams['query_place_id'] = placeId;
    }

    final uri = Uri.https('www.google.com', '/maps/search/', queryParams);

    return _launch(uri);
  }

  /// Convenient alias for opening coordinates in Google Maps
  static Future<bool> openCoordinates({
    required double latitude,
    required double longitude,
    String? placeName,
    String? placeId,
  }) =>
      launchPlaceLocation(
        latitude: latitude,
        longitude: longitude,
        placeName: placeName,
        placeId: placeId,
      );

  /// Convenient alias for opening itinerary route in Google Maps
  static Future<bool> openItineraryRoute({
    required RouteWaypoint origin,
    RouteWaypoint? destination,
    List<RouteWaypoint>? waypoints,
  }) {
    final dest = destination ?? origin;
    return launchItineraryDirections(
      origin: origin,
      destination: dest,
      intermediates: waypoints ?? const [],
    );
  }

  /// Launches turn-by-turn navigation or road directions for a specific sequential leg
  /// (e.g. Stop A -> Stop B, or Leg N).
  static Future<bool> launchLegDirections({
    required RouteWaypoint origin,
    required RouteWaypoint destination,
  }) =>
      launchItineraryDirections(
        origin: origin,
        destination: destination,
      );

  /// Launches Google Maps turn-by-turn navigation directly to target coordinates.
  static Future<bool> launchTurnByTurnNavigation({
    required double latitude,
    required double longitude,
    String? title,
  }) async {
    final nativeUri =
        Uri.parse('google.navigation:q=$latitude,$longitude&mode=d');
    try {
      if (await canLaunchUrl(nativeUri)) {
        final launched =
            await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
        if (launched) return true;
      }
    } catch (_) {}

    final queryParams = <String, String>{
      'api': '1',
      'destination': '$latitude,$longitude',
      'travelmode': 'driving',
    };
    final fallbackUri =
        Uri.https('www.google.com', '/maps/dir/', queryParams);
    return _launch(fallbackUri);
  }

  static Future<bool> _launch(Uri uri) async {
    try {
      final launchedApp = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launchedApp) return true;

      // Fallback to web browser
      return await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      );
    } catch (e) {
      debugPrint('GoogleMapsLauncher error: $e');
      try {
        return await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {
        return false;
      }
    }
  }
}
