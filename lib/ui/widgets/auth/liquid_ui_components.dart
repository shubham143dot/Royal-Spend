import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/liquid_auth_colors.dart';
import '../../../core/utils/haptic_helper.dart';
import '../google_brand_icon.dart';
import '../liquid_pop.dart';

/// Low-level Glass Effect primitive adapted from `tejapunna/glassmorphic_ui`.
/// Combines a [BackdropFilter] Gaussian blur, a translucent neutral tint overlay,
/// and a specular border highlight.
class LiquidGlassEffect extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final Color? tintColor;
  final double tintOpacity;
  final BorderRadius borderRadius;
  final double borderOpacity;
  final double elevation;
  final bool enableShadow;
  final Clip clipBehavior;

  const LiquidGlassEffect({
    super.key,
    required this.child,
    this.blurSigma = 24.0,
    this.tintColor,
    this.tintOpacity = 0.12,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.borderOpacity = 0.25,
    this.elevation = 8.0,
    this.enableShadow = true,
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  Widget build(BuildContext context) {
    final bool highContrast = MediaQuery.highContrastOf(context);
    final resolvedTint = tintColor ?? Colors.white;
    final double effectiveBlur = highContrast ? 0.0 : blurSigma;

    Widget glass = ClipRRect(
      borderRadius: borderRadius,
      clipBehavior: clipBehavior,
      child: effectiveBlur > 0
          ? BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: effectiveBlur,
                sigmaY: effectiveBlur,
                tileMode: TileMode.mirror,
              ),
              child: _LiquidGlassOverlay(
                tintColor: resolvedTint.withValues(alpha: tintOpacity),
                borderRadius: borderRadius,
                borderColor: Colors.white.withValues(
                  alpha: highContrast ? 0.8 : borderOpacity,
                ),
                child: child,
              ),
            )
          : _LiquidGlassOverlay(
              tintColor: resolvedTint.withValues(alpha: tintOpacity),
              borderRadius: borderRadius,
              borderColor: Colors.white.withValues(
                alpha: highContrast ? 0.8 : borderOpacity,
              ),
              child: child,
            ),
    );

    if (enableShadow && elevation > 0) {
      glass = Material(
        color: Colors.transparent,
        elevation: highContrast ? elevation * 1.5 : elevation,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        borderRadius: borderRadius,
        child: glass,
      );
    }

    return glass;
  }
}

class _LiquidGlassOverlay extends StatelessWidget {
  final Widget child;
  final Color tintColor;
  final BorderRadius borderRadius;
  final Color borderColor;

  const _LiquidGlassOverlay({
    required this.child,
    required this.tintColor,
    required this.borderRadius,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tintColor,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor, width: 1.0),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.14),
            Colors.white.withValues(alpha: 0.04),
          ],
        ),
      ),
      child: child,
    );
  }
}

/// Implicitly Animated Glass Effect adapted from `tejapunna/glassmorphic_ui`.
/// Smoothly animates blur sigma and tint opacity during focus and interaction transitions.
class AnimatedLiquidGlassEffect extends ImplicitlyAnimatedWidget {
  final Widget child;
  final double blurSigma;
  final Color? tintColor;
  final double tintOpacity;
  final BorderRadius borderRadius;
  final double borderOpacity;
  final double elevation;
  final bool enableShadow;

  const AnimatedLiquidGlassEffect({
    super.key,
    required this.child,
    this.blurSigma = 20.0,
    this.tintColor,
    this.tintOpacity = 0.12,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.borderOpacity = 0.25,
    this.elevation = 6.0,
    this.enableShadow = true,
    super.duration = const Duration(milliseconds: 250),
    super.curve = Curves.easeInOutCubic,
  });

  @override
  AnimatedLiquidGlassEffectState createState() =>
      AnimatedLiquidGlassEffectState();
}

class AnimatedLiquidGlassEffectState
    extends AnimatedWidgetBaseState<AnimatedLiquidGlassEffect> {
  Tween<double>? _blurTween;
  Tween<double>? _opacityTween;
  Tween<double>? _borderOpacityTween;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _blurTween = visitor(
      _blurTween,
      widget.blurSigma,
      (v) => Tween<double>(begin: v as double),
    ) as Tween<double>?;
    _opacityTween = visitor(
      _opacityTween,
      widget.tintOpacity,
      (v) => Tween<double>(begin: v as double),
    ) as Tween<double>?;
    _borderOpacityTween = visitor(
      _borderOpacityTween,
      widget.borderOpacity,
      (v) => Tween<double>(begin: v as double),
    ) as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) {
    return LiquidGlassEffect(
      blurSigma: _blurTween?.evaluate(animation) ?? widget.blurSigma,
      tintColor: widget.tintColor,
      tintOpacity: _opacityTween?.evaluate(animation) ?? widget.tintOpacity,
      borderRadius: widget.borderRadius,
      borderOpacity:
          _borderOpacityTween?.evaluate(animation) ?? widget.borderOpacity,
      elevation: widget.elevation,
      enableShadow: widget.enableShadow,
      child: widget.child,
    );
  }
}

/// Premium iOS Liquid Glass Card Container.
///
/// Features:
/// - Pure neutral palette: Transparent white, soft silver, charcoal, graphite.
/// - BackdropFilter Gaussian blur (24-28 sigma).
/// - Top specular dome catch and dual-strike hairline rim painter.
/// - Dual depth shadow (soft white ambient glow + dark depth shadow) adapted from Ag1rin/login_glass_app.
class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double blurSigma;
  final double surfaceOpacity;
  final bool showSpecularBorder;

  const LiquidGlassCard({
    super.key,
    required this.child,
    this.borderRadius = 28.0,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 20),
    this.margin,
    this.blurSigma = 26.0,
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
          stops: const [0.0, 0.45, 1.0],
          colors: highContrast
              ? const [
                  Color(0xFF16181D),
                  Color(0xFF101216),
                  Color(0xFF090A0D),
                ]
              : [
                  Colors.white.withValues(alpha: surfaceOpacity + 0.06),
                  Colors.white.withValues(alpha: surfaceOpacity),
                  Colors.white.withValues(
                    alpha: (surfaceOpacity - 0.04).clamp(0.01, 1.0),
                  ),
                ],
        ),
      ),
      child: child,
    );

    if (showSpecularBorder && !highContrast) {
      content = CustomPaint(
        foregroundPainter: _LiquidGlassSpecularRimPainter(
          borderRadius: borderRadius,
          strokeWidth: 1.15,
        ),
        child: content,
      );
    } else if (highContrast) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: Colors.white, width: 1.5),
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
                // Dual shadow system adapted from Ag1rin/login_glass_app:
                // 1) Soft ambient white diffusion
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.06),
                  blurRadius: 32,
                  spreadRadius: -4,
                  offset: const Offset(0, 0),
                ),
                // 2) Dark depth shadow
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.38),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
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
                  tileMode: TileMode.mirror,
                ),
                child: content,
              )
            : content,
      ),
    );
  }
}

/// Specular Hairline Rim Painter for Liquid Glass surfaces.
/// Emulates light catching the glass at a 45-degree angle.
class _LiquidGlassSpecularRimPainter extends CustomPainter {
  final double borderRadius;
  final double strokeWidth;

  _LiquidGlassSpecularRimPainter({
    required this.borderRadius,
    this.strokeWidth = 1.15,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // Top-left specular highlight catch
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0.0, 0.30, 0.70, 1.0],
        colors: [
          LiquidAuthColors.specularWhite,
          LiquidAuthColors.specularRim,
          LiquidAuthColors.softSilver.withValues(alpha: 0.16),
          Colors.white.withValues(alpha: 0.03),
        ],
      ).createShader(rect);

    canvas.drawRRect(rrect.deflate(strokeWidth / 2), rimPaint);

    // Top bevel water highlight line
    final topHighlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        stops: const [0.0, 0.15, 0.50, 0.85, 1.0],
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.40),
          Colors.white.withValues(alpha: 0.75),
          Colors.white.withValues(alpha: 0.40),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 2.0));

    final topPath = Path()
      ..moveTo(borderRadius, 0.5)
      ..lineTo(size.width - borderRadius, 0.5);

    canvas.drawPath(topPath, topHighlightPaint);
  }

  @override
  bool shouldRepaint(covariant _LiquidGlassSpecularRimPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// Liquid Glass Text Field adapted from `tejapunna/glassmorphic_ui` (`glass_text_field.dart`)
/// and `Ag1rin/login_glass_app`.
///
/// Features:
/// - Recessed frosted glass body with subtle background translucency.
/// - Dynamic animated focus bloom with pure neutral silver-white glow.
/// - Password toggle with explicit tooltip 'Show password'/'Hide password'.
/// - Full validation and error handling support.
class LiquidGlassTextField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String label;
  final String? hint;
  final IconData? icon;
  final bool isPassword;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;
  final Key? fieldKey;

  const LiquidGlassTextField({
    super.key,
    this.controller,
    this.focusNode,
    required this.label,
    this.hint,
    this.icon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.validator,
    this.onFieldSubmitted,
    this.enabled = true,
    this.fieldKey,
  });

  @override
  State<LiquidGlassTextField> createState() => _LiquidGlassTextFieldState();
}

class _LiquidGlassTextFieldState extends State<LiquidGlassTextField> {
  late bool _obscured;
  late FocusNode _effectiveFocusNode;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _obscured = widget.isPassword;
    _effectiveFocusNode = widget.focusNode ?? FocusNode();
    _effectiveFocusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant LiquidGlassTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode?.removeListener(_handleFocusChange);
      _effectiveFocusNode = widget.focusNode ?? FocusNode();
      _effectiveFocusNode.addListener(_handleFocusChange);
    }
  }

  void _handleFocusChange() {
    if (mounted && _hasFocus != _effectiveFocusNode.hasFocus) {
      setState(() {
        _hasFocus = _effectiveFocusNode.hasFocus;
      });
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _effectiveFocusNode.dispose();
    } else {
      _effectiveFocusNode.removeListener(_handleFocusChange);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool highContrast = MediaQuery.highContrastOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label above field
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 6.0),
          child: Text(
            widget.label,
            style: TextStyle(
              color: _hasFocus
                  ? Colors.white
                  : LiquidAuthColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ),

        // Animated Glass Input Container (adapted from GlassTextField in glassmorphic_ui)
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: highContrast
                ? const Color(0xFF16181D)
                : Colors.white.withValues(alpha: _hasFocus ? 0.09 : 0.05),
            border: Border.all(
              color: highContrast
                  ? (_hasFocus ? Colors.white : Colors.white60)
                  : (_hasFocus
                      ? Colors.white.withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: 0.18)),
              width: _hasFocus ? 1.4 : 1.0,
            ),
            boxShadow: _hasFocus && !highContrast
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.18),
                      blurRadius: 14,
                      spreadRadius: 1,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: TextFormField(
                key: widget.fieldKey,
                controller: widget.controller,
                focusNode: _effectiveFocusNode,
                obscureText: _obscured,
                keyboardType: widget.keyboardType,
                textInputAction: widget.textInputAction,
                autofillHints: widget.autofillHints,
                validator: widget.validator,
                onFieldSubmitted: widget.onFieldSubmitted,
                enabled: widget.enabled,
                style: const TextStyle(
                  color: LiquidAuthColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                ),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: TextStyle(
                    color: LiquidAuthColors.textMuted.withValues(alpha: 0.65),
                    fontSize: 14,
                  ),
                  prefixIcon: widget.icon != null
                      ? Icon(
                          widget.icon,
                          size: 20,
                          color: _hasFocus
                              ? Colors.white
                              : LiquidAuthColors.textMuted,
                        )
                      : null,
                  suffixIcon: widget.isPassword
                      ? IconButton(
                          tooltip: _obscured ? 'Show password' : 'Hide password',
                          icon: Icon(
                            _obscured
                                ? CupertinoIcons.eye_slash
                                : CupertinoIcons.eye,
                            size: 20,
                            color: _hasFocus
                                ? Colors.white
                                : LiquidAuthColors.textMuted,
                          ),
                          onPressed: () {
                            HapticHelper.lightImpact();
                            setState(() {
                              _obscured = !_obscured;
                            });
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  errorStyle: const TextStyle(
                    color: LiquidAuthColors.errorRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Liquid Glass Primary Action Button.
///
/// Adapted from `tejapunna/glassmorphic_ui` (`glass_button.dart`):
/// - Press scale animation (0.96) with spring curve.
/// - Pure neutral Liquid Mercury & Polished White Glass finish.
/// - Top specular light highlight arc catching light.
/// - 48dp minimum accessible touch target.
class LiquidGlassPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double height;

  const LiquidGlassPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.height = 52.0,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !isLoading;
    final bool highContrast = MediaQuery.highContrastOf(context);

    return LiquidPop(
      pressedScale: 0.96,
      onTap: enabled
          ? () {
              HapticHelper.mediumImpact();
              onPressed!();
            }
          : null,
      child: Container(
        height: height,
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: highContrast
                ? const [Colors.white, Color(0xFFE2E8F0)]
                : (enabled
                    ? [
                        Colors.white.withValues(alpha: 0.94),
                        const Color(0xFFE2E8F0).withValues(alpha: 0.90),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.35),
                        Colors.white.withValues(alpha: 0.20),
                      ]),
          ),
          boxShadow: enabled && !highContrast
              ? [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.22),
                    blurRadius: 18,
                    spreadRadius: -2,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
          border: Border.all(
            color: enabled
                ? Colors.white
                : Colors.white.withValues(alpha: 0.15),
            width: 1.1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Top specular highlight line
              if (enabled && !highContrast)
                Positioned(
                  top: 0,
                  left: 20,
                  right: 20,
                  height: 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white,
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),

              // Button Content
              Center(
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            LiquidAuthColors.charcoalDark,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            Icon(
                              icon,
                              size: 19,
                              color: LiquidAuthColors.charcoalDark,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            label,
                            style: const TextStyle(
                              color: LiquidAuthColors.charcoalDark,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
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

/// Pure Optical Water Glass Google Authentication Button.
///
/// Features:
/// - 100% translucent water glass body allowing video to flow underneath.
/// - Crisply renders official [GoogleBrandIcon].
/// - Specular hairline rim and tactile [LiquidPop] spring physics.
/// - Minimum 48dp height for mobile accessibility.
class LiquidGlassGoogleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const LiquidGlassGoogleButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !isLoading;
    final bool highContrast = MediaQuery.highContrastOf(context);

    return LiquidPop(
      pressedScale: 0.96,
      onTap: enabled
          ? () {
              HapticHelper.lightImpact();
              onPressed!();
            }
          : null,
      child: Container(
        height: 52,
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: highContrast
              ? const Color(0xFF16181D)
              : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: highContrast
                ? Colors.white
                : Colors.white.withValues(alpha: 0.22),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Top specular highlight
                if (!highContrast)
                  Positioned(
                    top: 0,
                    left: 24,
                    right: 24,
                    height: 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white.withValues(alpha: 0.6),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Button Content
                Center(
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GoogleBrandIcon(size: 20),
                              SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  'Continue with Google',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: LiquidAuthColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.2,
                                  ),
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
      ),
    );
  }
}

/// Liquid Glass Status and Error Banner.
class LiquidStatusBanner extends StatelessWidget {
  final String message;
  final bool isError;
  final VoidCallback? onDismiss;

  const LiquidStatusBanner({
    super.key,
    required this.message,
    this.isError = false,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isError ? LiquidAuthColors.errorRed : LiquidAuthColors.successGreen;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
          if (onDismiss != null)
            GestureDetector(
              onTap: onDismiss,
              child: Icon(
                Icons.close_rounded,
                color: color.withValues(alpha: 0.7),
                size: 16,
              ),
            ),
        ],
      ),
    );
  }
}

/// Frosted liquid glass divider with optional label.
class LiquidGlassDivider extends StatelessWidget {
  final String label;

  const LiquidGlassDivider({
    super.key,
    this.label = 'or',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.0),
                  Colors.white.withValues(alpha: 0.20),
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
              color: LiquidAuthColors.textMuted.withValues(alpha: 0.75),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.20),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
