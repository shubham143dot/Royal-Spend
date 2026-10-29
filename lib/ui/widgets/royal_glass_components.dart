import 'dart:ui';
import 'package:flutter/material.dart';

/// Ultra-premium iOS Liquid Glassmorphic Panel.
///
/// Features:
/// - Real hardware-accelerated BackdropFilter blur (default 26.0 sigma).
/// - Translucent obsidian-sapphire tint (10-16% opacity) allowing the background video to remain clearly visible.
/// - Specular gradient hairline rim catching ambient light from top-left.
/// - Inner specular bevel highlight simulating glass curvature and refraction.
/// - Multi-tier floating ambient drop shadows with subtle royal gold refraction halo.
/// - Full high-contrast accessibility support (falls back to solid dark surface with high contrast border).
class RoyalGlassPanel extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double blurSigma;
  final double surfaceOpacity;
  final bool showSpecularBorder;
  final Color? customAccentColor;

  const RoyalGlassPanel({
    super.key,
    required this.child,
    this.borderRadius = 28.0,
    this.padding = const EdgeInsets.fromLTRB(22, 24, 22, 20),
    this.margin,
    this.blurSigma = 26.0,
    this.surfaceOpacity = 0.14,
    this.showSpecularBorder = true,
    this.customAccentColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool highContrast = MediaQuery.highContrastOf(context);
    final radius = BorderRadius.circular(borderRadius);

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.45, 1.0],
          colors: highContrast
              ? const [Color(0xFF0E1118), Color(0xFF090B10), Color(0xFF06070B)]
              : [
                  Colors.white.withValues(alpha: surfaceOpacity + 0.04),
                  const Color(0xFF141926).withValues(alpha: surfaceOpacity + 0.16),
                  const Color(0xFF0A0D15).withValues(alpha: surfaceOpacity + 0.28),
                ],
        ),
      ),
      child: child,
    );

    if (showSpecularBorder && !highContrast) {
      content = CustomPaint(
        foregroundPainter: RoyalGlassSpecularBorderPainter(
          borderRadius: borderRadius,
          strokeWidth: 1.1,
          accentColor: customAccentColor ?? const Color(0xFFD4AF37),
        ),
        child: content,
      );
    } else if (highContrast) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: Colors.white,
            width: 1.5,
          ),
        ),
        child: content,
      );
    }

    final double effectiveBlur = highContrast ? 0.0 : blurSigma;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: highContrast
            ? const [
                BoxShadow(
                  color: Colors.black,
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ]
            : [
                // Deep ambient contact shadow
                const BoxShadow(
                  color: Color(0x8C000000),
                  blurRadius: 46,
                  spreadRadius: -6,
                  offset: Offset(0, 22),
                ),
                // Soft directional shadow
                const BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 22,
                  spreadRadius: -2,
                  offset: Offset(0, 10),
                ),
                // Subtle royal gold specular refraction aura
                BoxShadow(
                  color: (customAccentColor ?? const Color(0xFFD4AF37))
                      .withValues(alpha: 0.12),
                  blurRadius: 40,
                  spreadRadius: -10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: effectiveBlur > 0
            ? BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: effectiveBlur,
                  sigmaY: effectiveBlur,
                ),
                child: content,
              )
            : content,
      ),
    );
  }
}

/// CustomPainter rendering an authentic Apple-style specular gradient rim
/// and top bevel highlight reflection.
class RoyalGlassSpecularBorderPainter extends CustomPainter {
  final double borderRadius;
  final double strokeWidth;
  final Color accentColor;

  RoyalGlassSpecularBorderPainter({
    required this.borderRadius,
    this.strokeWidth = 1.1,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(borderRadius),
    );

    // 1. Specular rim gradient: brightest at top-left (light entry), fading to subtle gold at bottom-right
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0.0, 0.35, 0.70, 1.0],
        colors: [
          Colors.white.withValues(alpha: 0.55),
          accentColor.withValues(alpha: 0.42),
          Colors.white.withValues(alpha: 0.16),
          accentColor.withValues(alpha: 0.22),
        ],
      ).createShader(rect);

    canvas.drawRRect(rrect, rimPaint);

    // 2. Top bevel highlight arc - simulates glass edge catching overhead key light
    final highlightPath = Path()
      ..moveTo(borderRadius, strokeWidth / 2)
      ..lineTo(size.width - borderRadius, strokeWidth / 2);

    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 1.2
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.45),
          const Color(0xFFFFF2D0).withValues(alpha: 0.75),
          Colors.white.withValues(alpha: 0.45),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 4));

    canvas.drawPath(highlightPath, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant RoyalGlassSpecularBorderPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.accentColor != accentColor;
  }
}

/// Translucent inset frosted container for input fields.
class RoyalGlassInputWell extends StatelessWidget {
  final Widget child;
  final bool hasFocus;
  final bool hasError;
  final double borderRadius;
  final Color accentColor;

  const RoyalGlassInputWell({
    super.key,
    required this.child,
    required this.hasFocus,
    this.hasError = false,
    this.borderRadius = 16.0,
    this.accentColor = const Color(0xFFD4AF37),
  });

  @override
  Widget build(BuildContext context) {
    final bool highContrast = MediaQuery.highContrastOf(context);

    final Color borderColor;
    if (highContrast) {
      borderColor = hasError
          ? const Color(0xFFFF453A)
          : (hasFocus ? Colors.white : Colors.white70);
    } else if (hasError) {
      borderColor = const Color(0xFFFF5252);
    } else if (hasFocus) {
      borderColor = accentColor;
    } else {
      borderColor = Colors.white.withValues(alpha: 0.20);
    }

    final double borderWidth = (hasFocus || hasError || highContrast) ? 1.35 : 1.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: highContrast
              ? [const Color(0xFF161922), const Color(0xFF0F121A)]
              : (hasFocus
                  ? [
                      Colors.white.withValues(alpha: 0.16),
                      const Color(0xFF161B29).withValues(alpha: 0.42),
                      const Color(0xFF0C101A).withValues(alpha: 0.55),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.08),
                      const Color(0xFF121622).withValues(alpha: 0.28),
                      const Color(0xFF0A0D15).withValues(alpha: 0.40),
                    ]),
        ),
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
        boxShadow: (hasFocus && !highContrast)
            ? [
                BoxShadow(
                  color: hasError
                      ? const Color(0x40FF5252)
                      : accentColor.withValues(alpha: 0.28),
                  blurRadius: 16,
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

/// Translucent frosted pill for secondary actions, badges, or skip controls.
class RoyalGlassPill extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  const RoyalGlassPill({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 24.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool highContrast = MediaQuery.highContrastOf(context);

    Widget pill = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: highContrast
            ? const Color(0xFF1C1E26)
            : Colors.white.withValues(alpha: 0.10),
        border: Border.all(
          color: borderColor ??
              (highContrast
                  ? Colors.white70
                  : Colors.white.withValues(alpha: 0.25)),
          width: highContrast ? 1.2 : 0.8,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: pill,
      );
    }

    return pill;
  }
}
