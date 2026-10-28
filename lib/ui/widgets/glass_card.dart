import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/glass_decorations.dart';
import 'liquid_pop.dart';

/// Premier iOS Liquid Glassmorphic card widget with frosted blur,
/// specular rim highlights, and tactile spring pop interaction.
class GlassCard extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? borderColor;
  final Gradient? gradient;
  final double blurSigma;

  const GlassCard({
    super.key,
    required this.child,
    required this.isDark,
    this.borderRadius = GlassDecorations.defaultBorderRadius,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.onTap,
    this.onLongPress,
    this.borderColor,
    this.gradient,
    this.blurSigma = GlassDecorations.defaultBlurSigma,
  });

  @override
  Widget build(BuildContext context) {
    final bool highContrast = MediaQuery.of(context).highContrast;

    Widget cardBody = Container(
      padding: padding,
      decoration: GlassDecorations.glassCardDecoration(
        isDark: isDark,
        borderRadius: borderRadius,
        customBorderColor: borderColor,
        customGradient: gradient,
        highContrast: highContrast,
      ),
      child: child,
    );

    // In Dark Mode, Apple uses solid Secondary System Grouped (#1C1C1E) over OLED black (#000000).
    // Bypassing real-time BackdropFilter in dark mode completely eliminates rasterizer stalls
    // and guarantees 120 FPS lag-free scrolling across all elements.
    if (blurSigma > 0 && !highContrast && !isDark) {
      cardBody = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blurSigma,
            sigmaY: blurSigma,
          ),
          child: cardBody,
        ),
      );
    }

    if (onTap != null || onLongPress != null) {
      cardBody = LiquidPop(
        onTap: onTap,
        onLongPress: onLongPress,
        pressedScale: 0.97,
        child: cardBody,
      );
    }

    if (margin != null) {
      cardBody = Padding(
        padding: margin!,
        child: cardBody,
      );
    }

    return cardBody;
  }
}
