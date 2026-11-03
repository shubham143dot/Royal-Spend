import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/auth_colors.dart';
import '../../../core/theme/spring_curves.dart';
import '../../../core/utils/haptic_helper.dart';
import '../liquid_pop.dart';

/// True Apple iOS-inspired Transparent Liquid Glass Card.
///
/// Features:
/// - 100% optical translucency: background video shines directly through the card.
/// - Hardware-accelerated Gaussian BackdropFilter blur.
/// - Specular molded glass hairline rim catching ambient light at 45-degree angle.
/// - Top bevel water bead highlight line simulating liquid glass refraction.
/// - Clean, diffuse ambient dispersion shadow with zero dark dirtiness.
/// - High-contrast accessibility compliance.
class BlueGlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double blurSigma;
  final double surfaceOpacity;
  final bool showSpecularBorder;

  const BlueGlassCard({
    super.key,
    required this.child,
    this.borderRadius = 28.0,
    this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 16),
    this.margin,
    this.blurSigma = 24.0,
    this.surfaceOpacity = 0.08,
    this.showSpecularBorder = true,
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
          stops: const [0.0, 0.50, 1.0],
          colors: highContrast
              ? const [
                  Color(0xFF0F1524),
                  Color(0xFF090E1A),
                  Color(0xFF050810),
                ]
              : [
                  Colors.white.withValues(alpha: surfaceOpacity + 0.05),
                  Colors.white.withValues(alpha: surfaceOpacity),
                  Colors.white.withValues(alpha: (surfaceOpacity - 0.03).clamp(0.01, 1.0)),
                ],
        ),
      ),
      child: child,
    );

    if (showSpecularBorder && !highContrast) {
      content = CustomPaint(
        foregroundPainter: _LiquidGlassSpecularBorderPainter(
          borderRadius: borderRadius,
          strokeWidth: 1.15,
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
                // Soft ambient dispersion shadow
                const BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 36,
                  spreadRadius: -4,
                  offset: Offset(0, 16),
                ),
                // Subtle electric cyan refractive illumination
                BoxShadow(
                  color: RoyalAuthColors.neonCyan.withValues(alpha: 0.12),
                  blurRadius: 30,
                  spreadRadius: -6,
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

/// CustomPainter rendering an authentic Apple-style specular liquid rim
/// and top curved water bead highlight.
class _LiquidGlassSpecularBorderPainter extends CustomPainter {
  final double borderRadius;
  final double strokeWidth;

  _LiquidGlassSpecularBorderPainter({
    required this.borderRadius,
    this.strokeWidth = 1.15,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(borderRadius),
    );

    // 1. Molded glass rim gradient: brightest top-left white sheen, blending into neon cyan, fading to subtle white
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0.0, 0.25, 0.65, 1.0],
        colors: [
          Colors.white.withValues(alpha: 0.70),
          RoyalAuthColors.neonCyan.withValues(alpha: 0.45),
          Colors.white.withValues(alpha: 0.12),
          RoyalAuthColors.iceBlue.withValues(alpha: 0.22),
        ],
      ).createShader(rect);

    canvas.drawRRect(rrect, rimPaint);

    // 2. Top bevel water bead highlight line - simulates liquid glass edge catching overhead key light
    final highlightPath = Path()
      ..moveTo(borderRadius, strokeWidth / 2)
      ..lineTo(size.width - borderRadius, strokeWidth / 2);

    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 1.3
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        stops: const [0.0, 0.20, 0.5, 0.80, 1.0],
        colors: [
          Colors.transparent,
          RoyalAuthColors.neonCyan.withValues(alpha: 0.50),
          Colors.white.withValues(alpha: 0.85),
          RoyalAuthColors.neonCyan.withValues(alpha: 0.50),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 4));

    canvas.drawPath(highlightPath, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _LiquidGlassSpecularBorderPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Transparent Liquid Glass Pill Input Field.
///
/// Recessed frosted translucent styling letting the background video shine through,
/// with animated electric cyan focus bloom and crisp iconography.
class BlueGlassTextField extends StatelessWidget {
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

  const BlueGlassTextField({
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
          borderColor = RoyalAuthColors.neonCyan.withValues(alpha: 0.85);
        } else {
          borderColor = Colors.white.withValues(alpha: 0.18);
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
                  ? const [Color(0xFF161E30), Color(0xFF0F1524)]
                  : (hasFocus
                      ? [
                          Colors.white.withValues(alpha: 0.15),
                          Colors.white.withValues(alpha: 0.08),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.08),
                          Colors.white.withValues(alpha: 0.03),
                        ]),
            ),
            border: Border.all(
              color: borderColor,
              width: borderWidth,
            ),
            boxShadow: (hasFocus && !highContrast)
                ? [
                    BoxShadow(
                      color: RoyalAuthColors.neonCyan.withValues(alpha: 0.28),
                      blurRadius: 16,
                      spreadRadius: -2,
                    ),
                    BoxShadow(
                      color: RoyalAuthColors.electricBlue.withValues(alpha: 0.15),
                      blurRadius: 22,
                      offset: const Offset(0, 3),
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
            cursorColor: RoyalAuthColors.neonCyan,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15.0,
              height: 1.3,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.40),
                fontSize: 14,
              ),
              labelStyle: TextStyle(
                color: hasFocus
                    ? RoyalAuthColors.neonCyan
                    : Colors.white.withValues(alpha: 0.70),
                fontSize: 14,
              ),
              floatingLabelStyle: const TextStyle(
                color: RoyalAuthColors.neonCyan,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              prefixIcon: Icon(
                icon,
                size: 20,
                color: hasFocus
                    ? RoyalAuthColors.neonCyan
                    : Colors.white.withValues(alpha: 0.75),
              ),
              suffixIcon: suffix,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              errorStyle: const TextStyle(
                color: RoyalAuthColors.errorRed,
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

/// Liquid Resin Primary Button with Electric Blue gradient and iOS Spring Pop.
class ElectricBlueButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double height;
  final double borderRadius;
  final IconData? icon;

  const ElectricBlueButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.height = 50.0,
    this.borderRadius = 16.0,
    this.icon,
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
                      Color(0xFF2E8CFF),
                      RoyalAuthColors.electricBlue,
                      RoyalAuthColors.royalBlue,
                    ]
                  : const [
                      Color(0xFF13294E),
                      Color(0xFF0F1E3A),
                    ],
            ),
            border: Border.all(
              color: enabled
                  ? RoyalAuthColors.neonCyan.withValues(alpha: 0.65)
                  : const Color(0x3336D9FF),
              width: 1.1,
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: RoyalAuthColors.electricBlue.withValues(alpha: 0.38),
                      blurRadius: 20,
                      offset: const Offset(0, 7),
                      spreadRadius: -2,
                    ),
                    BoxShadow(
                      color: RoyalAuthColors.neonCyan.withValues(alpha: 0.20),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              // Liquid resin top sheen highlight
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
                          color: Colors.white,
                        ),
                      )
                    : (icon != null
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.25,
                                  shadows: [
                                    Shadow(
                                      color: Color(0x88000000),
                                      blurRadius: 6,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.25,
                              shadows: [
                                Shadow(
                                  color: Color(0x88000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Transparent Liquid Glass Google Authentication Button.
class GoogleGlassButton extends StatelessWidget {
  final Widget? leading;
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double height;
  final double borderRadius;

  const GoogleGlassButton({
    super.key,
    this.leading,
    this.label = 'Continue with Google',
    required this.onPressed,
    this.isLoading = false,
    this.height = 50.0,
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
                  ? const [Color(0xFF141A29), Color(0xFF0A0F1A)]
                  : [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0.04),
                    ],
            ),
            border: Border.all(
              color: highContrast
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.24),
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

/// Floating translucent glass navigation pill for secondary actions.
class BlueGlassNavigationPill extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  const BlueGlassNavigationPill({
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
            ? const Color(0xFF141A29)
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

/// Premium horizontal divider with gradient fades and centered label.
class BlueGlassDivider extends StatelessWidget {
  final String label;

  const BlueGlassDivider({super.key, this.label = 'OR'});

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
            color: Colors.white.withValues(alpha: 0.65),
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

/// Smooth status message banner for errors and successes.
class StatusMessageBanner extends StatelessWidget {
  final String message;
  final bool isError;

  const StatusMessageBanner({
    super.key,
    required this.message,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 320),
      curve: IOSSpringCurve.gentle,
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * -6),
            child: child,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isError
              ? RoyalAuthColors.errorBg
              : RoyalAuthColors.successBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isError
                ? RoyalAuthColors.errorBorder
                : RoyalAuthColors.successBorder,
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: (isError
                      ? RoyalAuthColors.errorRed
                      : RoyalAuthColors.successGreen)
                  .withValues(alpha: 0.20),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              size: 19,
              color: isError
                  ? RoyalAuthColors.errorRed
                  : RoyalAuthColors.successGreen,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: isError
                      ? const Color(0xFFFFD4D4)
                      : const Color(0xFFD4F7E2),
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
