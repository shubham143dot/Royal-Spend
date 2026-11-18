import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapMarkerGenerator {
  MapMarkerGenerator._();

  static final Map<String, BitmapDescriptor> _markerCache = {};

  /// Creates a crisp, modern circular pin with label (e.g. 'A', '1', '2', 'B')
  static Future<BitmapDescriptor> createNumberedMarker({
    required String label,
    required Color backgroundColor,
    Color textColor = Colors.white,
    double size = 96.0,
  }) async {
    final cacheKey =
        'num_${label}_${backgroundColor.toARGB32()}_${textColor.toARGB32()}';
    if (_markerCache.containsKey(cacheKey)) {
      return _markerCache[cacheKey]!;
    }

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final radius = size / 2;

      // Draw subtle shadow
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(radius, radius + 3), radius - 6, shadowPaint);

      // Draw outer white border
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(radius, radius), radius - 4, borderPaint);

      // Draw inner colored circle
      final fillPaint = Paint()
        ..color = backgroundColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(radius, radius), radius - 8, fillPaint);

      // Draw text
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: label.length > 2 ? size * 0.28 : size * 0.36,
            fontWeight: FontWeight.w900,
            color: textColor,
            fontFamily: 'sans-serif',
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          radius - (textPainter.width / 2),
          radius - (textPainter.height / 2),
        ),
      );

      final picture = recorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final descriptor = BitmapDescriptor.bytes(byteData.buffer.asUint8List());
        _markerCache[cacheKey] = descriptor;
        return descriptor;
      }
    } catch (e) {
      debugPrint('MapMarkerGenerator error: $e');
    }

    // Fallback standard marker with appropriate hue
    if (label == 'A') {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    } else if (label == 'B') {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
  }

  /// Pre-warms the marker cache so initial rendering has zero frame drops
  static Future<void> prewarmCache() async {
    const categories = [
      'Restaurants',
      'Hotels',
      'Tourist Attractions',
      'Shopping',
      'Cafes',
      'Transport',
      'Other Saved Places',
    ];
    for (final cat in categories) {
      await createCategoryMarker(category: cat);
    }
    // Numbered markers
    await createNumberedMarker(label: 'A', backgroundColor: const Color(0xFF34C759));
    await createNumberedMarker(label: 'B', backgroundColor: const Color(0xFFFF3B30));
    for (int i = 1; i <= 15; i++) {
      await createNumberedMarker(label: '$i', backgroundColor: const Color(0xFF007AFF));
    }
  }

  /// Creates a category-colored marker for Saved Places
  static Future<BitmapDescriptor> createCategoryMarker({
    required String category,
    double size = 80.0,
  }) async {
    Color color;
    String letter;

    switch (category.toLowerCase()) {
      case 'restaurants':
      case 'food':
        color = const Color(0xFFFF9500); // Apple Orange
        letter = '🍽️';
        break;
      case 'cafes':
        color = const Color(0xFFFF2D55); // Pink/Coffee
        letter = '☕';
        break;
      case 'hotels':
      case 'lodging':
        color = const Color(0xFF34C759); // Apple Green
        letter = '🏨';
        break;
      case 'shopping':
        color = const Color(0xFFAF52DE); // Apple Purple
        letter = '🛍️';
        break;
      case 'tourist attractions':
      case 'sightseeing':
        color = const Color(0xFF007AFF); // Apple Blue
        letter = '⭐';
        break;
      default:
        color = const Color(0xFF5856D6); // Apple Indigo
        letter = '📍';
    }

    final cacheKey = 'cat_${category}_${color.toARGB32()}';
    if (_markerCache.containsKey(cacheKey)) {
      return _markerCache[cacheKey]!;
    }

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final radius = size / 2;

      // Draw shadow
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(Offset(radius, radius + 2), radius - 6, shadowPaint);

      // Draw white ring
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(radius, radius), radius - 4, borderPaint);

      // Inner fill
      final fillPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(radius, radius), radius - 8, fillPaint);

      // Text / symbol
      final textPainter = TextPainter(
        text: TextSpan(
          text: letter,
          style: TextStyle(
            fontSize: size * 0.38,
            fontFamily: 'sans-serif',
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          radius - (textPainter.width / 2),
          radius - (textPainter.height / 2),
        ),
      );

      final picture = recorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final descriptor = BitmapDescriptor.bytes(byteData.buffer.asUint8List());
        _markerCache[cacheKey] = descriptor;
        return descriptor;
      }
    } catch (_) {}

    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
  }
}
