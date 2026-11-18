import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../config/google_maps_config.dart';

class RouteWaypoint {
  final String title;
  final double latitude;
  final double longitude;
  final String? placeId;
  final String? address;
  final int? visitDurationMinutes;
  final String? stopType; // 'start', 'stop', 'end'
  final int? stopNumber;

  const RouteWaypoint({
    required this.title,
    required this.latitude,
    required this.longitude,
    this.placeId,
    this.address,
    this.visitDurationMinutes,
    this.stopType,
    this.stopNumber,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  String get formattedVisitDuration {
    if (visitDurationMinutes == null || visitDurationMinutes! <= 0) {
      return '';
    }
    final hours = visitDurationMinutes! ~/ 60;
    final mins = visitDurationMinutes! % 60;
    if (hours > 0 && mins > 0) {
      return '$hours hr $mins min';
    } else if (hours > 0) {
      return '$hours hr${hours > 1 ? 's' : ''}';
    }
    return '$mins min';
  }

  @override
  String toString() => '$title($latitude,$longitude)';
}

class RouteLegDetail {
  final String startTitle;
  final String endTitle;
  final int distanceMeters;
  final int durationSeconds;
  final int? endVisitDurationMinutes;
  final RouteWaypoint? startWaypoint;
  final RouteWaypoint? endWaypoint;

  const RouteLegDetail({
    required this.startTitle,
    required this.endTitle,
    required this.distanceMeters,
    required this.durationSeconds,
    this.endVisitDurationMinutes,
    this.startWaypoint,
    this.endWaypoint,
  });

  String get formattedVisitDuration {
    if (endVisitDurationMinutes == null || endVisitDurationMinutes! <= 0) {
      return '';
    }
    final hours = endVisitDurationMinutes! ~/ 60;
    final mins = endVisitDurationMinutes! % 60;
    if (hours > 0 && mins > 0) {
      return '$hours hr $mins min';
    } else if (hours > 0) {
      return '$hours hr${hours > 1 ? 's' : ''}';
    }
    return '$mins min';
  }

  String get formattedDistance {
    if (distanceMeters >= 1000) {
      final km = distanceMeters / 1000.0;
      return '${km.toStringAsFixed(1)} km';
    }
    return '$distanceMeters m';
  }

  String get formattedDuration {
    if (durationSeconds <= 0) return '0 min';
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '$hours hr${hours > 1 ? 's' : ''} $minutes min';
    }
    return '$minutes min';
  }
}

class RouteComputationResult {
  final List<LatLng> polylinePoints;
  final int totalDistanceMeters;
  final int totalDurationSeconds;
  final List<RouteLegDetail> legs;
  final String? errorMessage;

  const RouteComputationResult({
    required this.polylinePoints,
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
    required this.legs,
    this.errorMessage,
  });

  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;
  bool get isEmpty => polylinePoints.isEmpty;

  String get formattedTotalDistance {
    if (totalDistanceMeters >= 1000) {
      final km = totalDistanceMeters / 1000.0;
      return '${km.toStringAsFixed(1)} km';
    }
    return '$totalDistanceMeters m';
  }

  String get formattedTotalDuration {
    if (totalDurationSeconds <= 0) return '0 min';
    final hours = totalDurationSeconds ~/ 3600;
    final minutes = (totalDurationSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '$hours hr${hours > 1 ? 's' : ''} $minutes min';
    }
    return '$minutes min';
  }
}

class GoogleRoutesService {
  final http.Client _client;
  final Map<String, RouteComputationResult> _routeCache = {};

  GoogleRoutesService({http.Client? client}) : _client = client ?? http.Client();

  static final GoogleRoutesService instance = GoogleRoutesService();

  /// Calculates actual road routes connecting starting point, intermediate stops, and destination
  /// using Google Routes API (computeRoutes).
  Future<RouteComputationResult> computeRoute({
    required RouteWaypoint origin,
    required RouteWaypoint destination,
    List<RouteWaypoint> intermediates = const [],
  }) async {
    final apiKey = GoogleMapsConfig.apiKey;
    if (apiKey.isEmpty) {
      return const RouteComputationResult(
        polylinePoints: [],
        totalDistanceMeters: 0,
        totalDurationSeconds: 0,
        legs: [],
        errorMessage: 'Google Maps API key not configured.',
      );
    }

    // Cache key based on sequential coordinates
    final cacheKey = [
      origin.toString(),
      ...intermediates.map((w) => w.toString()),
      destination.toString(),
    ].join('-->');

    if (_routeCache.containsKey(cacheKey)) {
      return _routeCache[cacheKey]!;
    }

    final url =
        Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes');

    final body = {
      'origin': {
        'location': {
          'latLng': {
            'latitude': origin.latitude,
            'longitude': origin.longitude,
          }
        }
      },
      'destination': {
        'location': {
          'latLng': {
            'latitude': destination.latitude,
            'longitude': destination.longitude,
          }
        }
      },
      if (intermediates.isNotEmpty)
        'intermediates': intermediates
            .map((stop) => {
                  'location': {
                    'latLng': {
                      'latitude': stop.latitude,
                      'longitude': stop.longitude,
                    }
                  }
                })
            .toList(),
      'travelMode': 'DRIVE',
      'routingPreference': 'TRAFFIC_AWARE',
      'computeAlternativeRoutes': false,
      'polylineQuality': 'OVERVIEW',
    };

    try {
      http.Response response;
      try {
        response = await _client.post(
          url,
          headers: {
            ...GoogleMapsConfig.apiHeaders,
            'X-Goog-FieldMask':
                'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.legs',
          },
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 14));
      } catch (_) {
        // One retry with backoff for transient network issues
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        response = await _client.post(
          url,
          headers: {
            ...GoogleMapsConfig.apiHeaders,
            'X-Goog-FieldMask':
                'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.legs',
          },
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 14));
      }

      if (response.statusCode != 200) {
        debugPrint(
            'GoogleRoutesService: computeRoutes failed (${response.statusCode}): ${response.body}');
        return RouteComputationResult(
          polylinePoints: [],
          totalDistanceMeters: 0,
          totalDurationSeconds: 0,
          legs: [],
          errorMessage:
              'Routes API returned error code ${response.statusCode}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        return const RouteComputationResult(
          polylinePoints: [],
          totalDistanceMeters: 0,
          totalDurationSeconds: 0,
          legs: [],
          errorMessage: 'No road route found between selected points.',
        );
      }

      final route = routes.first as Map<String, dynamic>;
      final totalDistance = (route['distanceMeters'] as num?)?.toInt() ?? 0;

      // Duration string from API is e.g. "3600s"
      final durationStr = (route['duration'] ?? '').toString();
      final totalSeconds = _parseSeconds(durationStr);

      final polylineObj = route['polyline'] as Map<String, dynamic>?;
      final encodedPolyline = polylineObj?['encodedPolyline'] as String? ?? '';
      final points = decodePolyline(encodedPolyline);

      // Parse individual leg details
      final rawLegs = route['legs'] as List<dynamic>? ?? [];
      final List<RouteWaypoint> allStopsInOrder = [
        origin,
        ...intermediates,
        destination,
      ];

      final List<RouteLegDetail> legDetails = [];
      for (int i = 0; i < rawLegs.length; i++) {
        final legMap = rawLegs[i] as Map<String, dynamic>;
        final legDist = (legMap['distanceMeters'] as num?)?.toInt() ?? 0;
        final legDurSec = _parseSeconds((legMap['duration'] ?? '').toString());

        final startWp = i < allStopsInOrder.length
            ? allStopsInOrder[i]
            : null;
        final startTitle = startWp?.title ?? 'Stop $i';
        final endWp = (i + 1) < allStopsInOrder.length
            ? allStopsInOrder[i + 1]
            : null;
        final endTitle = endWp?.title ?? 'Stop ${i + 1}';

        legDetails.add(RouteLegDetail(
          startTitle: startTitle,
          endTitle: endTitle,
          distanceMeters: legDist,
          durationSeconds: legDurSec,
          endVisitDurationMinutes: endWp?.visitDurationMinutes,
          startWaypoint: startWp,
          endWaypoint: endWp,
        ));
      }

      final result = RouteComputationResult(
        polylinePoints: points,
        totalDistanceMeters: totalDistance,
        totalDurationSeconds: totalSeconds,
        legs: legDetails,
      );

      _routeCache[cacheKey] = result;
      return result;
    } catch (e) {
      debugPrint('GoogleRoutesService.computeRoute error: $e');
      return RouteComputationResult(
        polylinePoints: [],
        totalDistanceMeters: 0,
        totalDurationSeconds: 0,
        legs: [],
        errorMessage: 'Network error connecting to Routes API: $e',
      );
    }
  }

  void clearCache() {
    _routeCache.clear();
  }

  static int _parseSeconds(String raw) {
    if (raw.endsWith('s')) {
      final numStr = raw.substring(0, raw.length - 1);
      return int.tryParse(numStr) ?? 0;
    }
    return int.tryParse(raw) ?? 0;
  }

  /// Decodes a Google Maps encoded polyline string into a list of LatLng coordinates.
  static List<LatLng> decodePolyline(String encoded) {
    final List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return poly;
  }
}
