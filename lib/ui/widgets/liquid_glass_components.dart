import 'dart:ui';
import 'package:flutter/material.dart';

import '../../core/theme/spring_curves.dart';
import '../../core/utils/haptic_helper.dart';
import 'liquid_pop.dart';

/// Gold and champagne color constants for Apple-inspired Royal Glass aesthetics.
class LiquidGlassColors {
  static const Color gold = Color(0xFFD4AF37);
  static const Color champagne = Color(0xFFF3D98B);
  static const Color lightGold = Color(0xFFFDE8AD);
  static const Color deepGold = Color(0xFFB3861B);
  static const Color darkGlassBacking = Color(0xFF0A0D14);
}

/// Floating, multilayer Liquid Glass authentication container.
///
/// Features:
/// - Real hardware-accelerated BackdropFilter blur (default 26.0 sigma).
/// - Translucent obsidian-sapphire glass letting the background galaxy video shine through.
/// - Specular gradient hairline rim catching ambient overhead light.
/// - Top bevel highlight arc simulating glass refraction and depth.
/// - Multi-tier floating ambient drop shadows with subtle royal gold refraction aura.
/// - High-contrast accessibility fallback (solid dark surface with crisp border, zero blur).
class LiquidGlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double blurSigma;
  final double surfaceOpacity;
  final bool showSpecularBorder;
  final Color accentColor;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 28.0,
    this.padding = const EdgeInsets.fromLTRB(22, 24, 22, 20),
    this.margin,
    this.blurSigma = 26.0,
    this.surfaceOpacity = 0.12,
    this.showSpecularBorder = true,
    this.accentColor = LiquidGlassColors.gold,
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
        foregroundPainter: _LiquidGlassSpecularBorderPainter(
          borderRadius: borderRadius,
          strokeWidth: 1.1,
          accentColor: accentColor,
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
                  color: Color(0x99000000),
                  blurRadius: 46,
                  spreadRadius: -6,
                  offset: Offset(0, 22),
                ),
                // Soft directional shadow
                const BoxShadow(
                  color: Color(0x44000000),
                  blurRadius: 22,
                  spreadRadius: -2,
                  offset: Offset(0, 10),
                ),
                // Subtle royal gold specular refraction aura
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.14),
                  blurRadius: 40,
                  spreadRadius: -8,
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
class _LiquidGlassSpecularBorderPainter extends CustomPainter {
  final double borderRadius;
  final double strokeWidth;
  final Color accentColor;

  _LiquidGlassSpecularBorderPainter({
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

    // 1. Specular rim gradient: brightest at top-left, fading to subtle gold at bottom-right
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0.0, 0.35, 0.70, 1.0],
        colors: [
          Colors.white.withValues(alpha: 0.58),
          accentColor.withValues(alpha: 0.45),
          Colors.white.withValues(alpha: 0.16),
          accentColor.withValues(alpha: 0.25),
        ],
      ).createShader(rect);

    canvas.drawRRect(rrect, rimPaint);

    // 2. Top bevel highlight line - simulates glass edge catching overhead key light
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
  bool shouldRepaint(covariant _LiquidGlassSpecularBorderPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.accentColor != accentColor;
  }
}

/// Translucent, frosted input field with animated gold focus bloom and hairline rim.
class LiquidGlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final Widget? suffix;
  final String? Function(String?) validator;
  final ValueChanged<String>? onFieldSubmitted;
  final Color accentColor;

  const LiquidGlassTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.icon,
    required this.textInputAction,
    required this.validator,
    this.keyboardType,
    this.autofillHints,
    this.obscureText = false,
    this.suffix,
    this.onFieldSubmitted,
    this.accentColor = LiquidGlassColors.gold,
  });

  @override
  Widget build(BuildContext context) {
    final bool highContrast = MediaQuery.highContrastOf(context);

    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, _) {
        final hasFocus = focusNode.hasFocus;

        final Color borderColor;
        if (highContrast) {
          borderColor = hasFocus ? Colors.white : Colors.white70;
        } else if (hasFocus) {
          borderColor = accentColor;
        } else {
          borderColor = Colors.white.withValues(alpha: 0.20);
        }

        final double borderWidth = (hasFocus || highContrast) ? 1.35 : 1.0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: IOSSpringCurve.snappy,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: highContrast
                  ? const [Color(0xFF161922), Color(0xFF0F121A)]
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
                      color: accentColor.withValues(alpha: 0.28),
                      blurRadius: 16,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            autofillHints: autofillHints,
            obscureText: obscureText,
            autocorrect: !obscureText,
            enableSuggestions: !obscureText,
            textCapitalization: TextCapitalization.none,
            validator: validator,
            onFieldSubmitted: onFieldSubmitted,
            cursorColor: LiquidGlassColors.champagne,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15.5,
              height: 1.3,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 14,
              ),
              labelStyle: TextStyle(
                color: hasFocus
                    ? LiquidGlassColors.champagne
                    : Colors.white.withValues(alpha: 0.72),
                fontSize: 14,
              ),
              floatingLabelStyle: const TextStyle(
                color: LiquidGlassColors.champagne,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              prefixIcon: Icon(
                icon,
                size: 20,
                color: hasFocus
                    ? LiquidGlassColors.champagne
                    : accentColor.withValues(alpha: 0.85),
              ),
              suffixIcon: suffix,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              errorStyle: const TextStyle(
                color: Color(0xFFFF8E8E),
                height: 1.3,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Royal Brushed Champagne Gold Button with iOS Spring Pop Tactile Feedback.
class GoldGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double height;
  final double borderRadius;

  const GoldGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.height = 54.0,
    this.borderRadius = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;

    return LiquidPop(
      pressedScale: 0.96,
      onTap: enabled
          ? () {
              HapticHelper.mediumImpact();
              onPressed!();
            }
          : null,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: enabled
                  ? const [
                      Color(0xFFFDE8AD),
                      Color(0xFFE5C058),
                      Color(0xFFB3861B),
                    ]
                  : const [Color(0xFF76663D), Color(0xFF62552F)],
            ),
            border: Border.all(
              color: enabled ? const Color(0xCCFFF6DC) : const Color(0x40FFFFFF),
              width: 1.0,
            ),
            boxShadow: enabled
                ? const [
                    BoxShadow(
                      color: Color(0x50D4AF37),
                      blurRadius: 22,
                      offset: Offset(0, 8),
                      spreadRadius: -2,
                    ),
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              // Subtle specular top line highlight
              if (enabled)
                Positioned(
                  top: 1,
                  left: 16,
                  right: 16,
                  height: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.65),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              Center(
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Color(0xFF141005),
                        ),
                      )
                    : Text(
                        label,
                        style: const TextStyle(
                          color: Color(0xFF141005),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.25,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Translucent Liquid Glass button for secondary actions like Google Sign-In.
class LiquidGlassButton extends StatelessWidget {
  final Widget? leading;
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double height;
  final double borderRadius;

  const LiquidGlassButton({
    super.key,
    this.leading,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.height = 54.0,
    this.borderRadius = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final highContrast = MediaQuery.highContrastOf(context);

    return LiquidPop(
      pressedScale: 0.96,
      onTap: enabled
          ? () {
              HapticHelper.lightImpact();
              onPressed!();
            }
          : null,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: highContrast
                  ? const [Color(0xFF1A1D27), Color(0xFF131620)]
                  : [
                      Colors.white.withValues(alpha: 0.15),
                      const Color(0xFF141926).withValues(alpha: 0.35),
                    ],
            ),
            border: Border.all(
              color: highContrast
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.30),
              width: highContrast ? 1.4 : 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Specular top highlight line
              if (!highContrast)
                Positioned(
                  top: 1,
                  left: 20,
                  right: 20,
                  height: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.40),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              Center(
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (leading != null) ...[
                            leading!,
                            const SizedBox(width: 12),
                          ],
                          Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.1,
                              shadows: [
                                Shadow(
                                  color: Color(0x99000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
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
}

/// Floating translucent glass pill for secondary navigation, mode switches, or skips.
class GlassNavigationPill extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  const GlassNavigationPill({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 22.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
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
            : Colors.white.withValues(alpha: 0.08),
        border: Border.all(
          color: borderColor ??
              (highContrast
                  ? Colors.white70
                  : Colors.white.withValues(alpha: 0.22)),
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
      return LiquidPop(
        pressedScale: 0.94,
        onTap: () {
          HapticHelper.lightImpact();
          onTap!();
        },
        child: pill,
      );
    }

    return pill;
  }
}

/// Premium horizontal divider with smooth gradient fades and centered label.
class PremiumGlassDivider extends StatelessWidget {
  final String label;

  const PremiumGlassDivider({super.key, this.label = 'OR'});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.22),
              ],
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.52),
            fontSize: 10.5,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      Expanded(
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.22),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
