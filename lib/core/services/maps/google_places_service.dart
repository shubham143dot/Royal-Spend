import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../config/google_maps_config.dart';

class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;
  final List<String> types;

  const PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
    this.types = const [],
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    final prediction = json['placePrediction'] as Map<String, dynamic>? ?? json;

    final placeIdRaw = (prediction['placeId'] ?? prediction['place'] ?? '').toString();
    final cleanPlaceId = placeIdRaw.startsWith('places/')
        ? placeIdRaw.substring(7)
        : placeIdRaw;

    final textObj = prediction['text'] as Map<String, dynamic>?;
    final fullText = textObj?['text']?.toString() ??
        prediction['description']?.toString() ??
        '';

    final structured = prediction['structuredFormat'] as Map<String, dynamic>?;
    final mainTextObj = structured?['mainText'] as Map<String, dynamic>?;
    final secondaryTextObj = structured?['secondaryText'] as Map<String, dynamic>?;

    final mainText = mainTextObj?['text']?.toString() ??
        (fullText.contains(',') ? fullText.split(',').first.trim() : fullText);

    final secondaryText = secondaryTextObj?['text']?.toString() ??
        (fullText.contains(',')
            ? fullText.substring(fullText.indexOf(',') + 1).trim()
            : '');

    final rawTypes = prediction['types'] as List<dynamic>? ?? [];
    final types = rawTypes.map((t) => t.toString()).toList();

    return PlacePrediction(
      placeId: cleanPlaceId,
      description: fullText.isNotEmpty ? fullText : mainText,
      mainText: mainText,
      secondaryText: secondaryText,
      types: types,
    );
  }
}

class PlaceDetails {
  final String id;
  final String name;
  final String formattedAddress;
  final double latitude;
  final double longitude;
  final List<String> types;

  const PlaceDetails({
    required this.id,
    required this.name,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    this.types = const [],
  });

  String get bestCategory {
    final lowerTypes = types.map((t) => t.toLowerCase()).toSet();
    if (lowerTypes.any((t) =>
        t.contains('cafe') || t.contains('coffee'))) {
      return 'Cafes';
    }
    if (lowerTypes.any((t) =>
        t.contains('restaurant') ||
        t.contains('food') ||
        t.contains('meal') ||
        t.contains('bakery') ||
        t.contains('bar'))) {
      return 'Restaurants';
    }
    if (lowerTypes.any((t) =>
        t.contains('hotel') ||
        t.contains('lodging') ||
        t.contains('resort') ||
        t.contains('motel') ||
        t.contains('bed_and_breakfast'))) {
      return 'Hotels';
    }
    if (lowerTypes.any((t) =>
        t.contains('shopping') ||
        t.contains('store') ||
        t.contains('supermarket') ||
        t.contains('mall'))) {
      return 'Shopping';
    }
    if (lowerTypes.any((t) =>
        t.contains('tourist_attraction') ||
        t.contains('museum') ||
        t.contains('park') ||
        t.contains('point_of_interest') ||
        t.contains('natural_feature') ||
        t.contains('monument') ||
        t.contains('place_of_worship'))) {
      return 'Tourist Attractions';
    }
    return 'Other Saved Places';
  }

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final idRaw = (json['id'] ?? '').toString();
    final cleanId = idRaw.startsWith('places/') ? idRaw.substring(7) : idRaw;

    String name = '';
    final displayName = json['displayName'];
    if (displayName is Map) {
      name = displayName['text']?.toString() ?? '';
    } else if (displayName is String) {
      name = displayName;
    }

    final formattedAddress = (json['formattedAddress'] ?? '').toString();

    double lat = 0.0;
    double lng = 0.0;
    final location = json['location'] as Map<String, dynamic>?;
    if (location != null) {
      lat = (location['latitude'] as num?)?.toDouble() ?? 0.0;
      lng = (location['longitude'] as num?)?.toDouble() ?? 0.0;
    }

    final rawTypes = json['types'] as List<dynamic>? ?? [];
    final types = rawTypes.map((t) => t.toString()).toList();

    return PlaceDetails(
      id: cleanId,
      name: name.isNotEmpty ? name : formattedAddress.split(',').first.trim(),
      formattedAddress: formattedAddress,
      latitude: lat,
      longitude: lng,
      types: types,
    );
  }
}

class GooglePlacesService {
  final http.Client _client;
  final Map<String, PlaceDetails> _detailsCache = {};
  final Map<String, List<PlacePrediction>> _autocompleteCache = {};
  String? _currentSessionToken;

  GooglePlacesService({http.Client? client}) : _client = client ?? http.Client();

  static final GooglePlacesService instance = GooglePlacesService();

  String get _sessionToken {
    _currentSessionToken ??= const Uuid().v4();
    return _currentSessionToken!;
  }

  void resetSessionToken() {
    _currentSessionToken = const Uuid().v4();
  }

  void clearCache() {
    _detailsCache.clear();
    _autocompleteCache.clear();
  }

  /// Searches for real-world place suggestions using Places API (New) Autocomplete.
  Future<List<PlacePrediction>> getAutocompleteSuggestions(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    if (_autocompleteCache.containsKey(trimmed)) {
      return _autocompleteCache[trimmed]!;
    }

    final apiKey = GoogleMapsConfig.apiKey;
    if (apiKey.isEmpty) {
      debugPrint('GooglePlacesService: Missing Google Maps API Key');
      return [];
    }

    final url = Uri.parse('https://places.googleapis.com/v1/places:autocomplete');

    try {
      final response = await _client.post(
        url,
        headers: GoogleMapsConfig.apiHeaders,
        body: jsonEncode({
          'input': trimmed,
          'sessionToken': _sessionToken,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint(
            'GooglePlacesService: Autocomplete failed (${response.statusCode}): ${response.body}');
        return [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final suggestions = data['suggestions'] as List<dynamic>? ?? [];

      final results = suggestions
          .whereType<Map<String, dynamic>>()
          .map((item) => PlacePrediction.fromJson(item))
          .where((p) => p.placeId.isNotEmpty)
          .toList();

      if (results.isNotEmpty) {
        _autocompleteCache[trimmed] = results;
      }
      return results;
    } catch (e) {
      debugPrint('GooglePlacesService.getAutocompleteSuggestions error: $e');
      return [];
    }
  }

  /// Retrieves place details (coordinates, formatted address, name, types) using Places API (New).
  Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    final cleanId = placeId.startsWith('places/') ? placeId.substring(7) : placeId;
    if (cleanId.isEmpty) return null;

    // Check in-memory cache to save API costs
    if (_detailsCache.containsKey(cleanId)) {
      return _detailsCache[cleanId];
    }

    final apiKey = GoogleMapsConfig.apiKey;
    if (apiKey.isEmpty) {
      debugPrint('GooglePlacesService: Missing Google Maps API Key');
      return null;
    }

    final url = Uri.parse('https://places.googleapis.com/v1/places/$cleanId');

    try {
      final response = await _client.get(
        url,
        headers: {
          ...GoogleMapsConfig.apiHeaders,
          'X-Goog-FieldMask':
              'id,displayName,formattedAddress,location,types',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint(
            'GooglePlacesService: Place details failed (${response.statusCode}): ${response.body}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final details = PlaceDetails.fromJson(data);

      if (details.latitude != 0.0 || details.longitude != 0.0) {
        _detailsCache[cleanId] = details;
      }

      // After a details fetch concludes the selection, refresh session token for the next query
      resetSessionToken();

      return details;
    } catch (e) {
      debugPrint('GooglePlacesService.getPlaceDetails error: $e');
      return null;
    }
  }
}
