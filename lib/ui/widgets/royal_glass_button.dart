import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/utils/haptic_helper.dart';

/// Premier Apple iOS Liquid Glassmorphism button.
/// Features true transparent frosted glass, specular hairline rim highlight,
/// crisp Apple typography, and physics-based spring press animation.
class RoyalGlassButton extends StatefulWidget {
  final String label;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double height;
  final double? width;
  final double borderRadius;
  final bool isIosGlass;
  final bool isSecondary;

  const RoyalGlassButton({
    super.key,
    required this.label,
    this.leading,
    this.trailing,
    required this.onPressed,
    this.isLoading = false,
    this.height = 56.0,
    this.width,
    this.borderRadius = 28.0,
    this.isIosGlass = true,
    this.isSecondary = false,
  });

  @override
  State<RoyalGlassButton> createState() => _RoyalGlassButtonState();
}

class _RoyalGlassButtonState extends State<RoyalGlassButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      reverseDuration: const Duration(milliseconds: 260),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.955).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed == null || widget.isLoading) return;
    setState(() => _isPressed = true);
    _scaleController.forward();
    HapticHelper.lightImpact();
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onPressed == null || widget.isLoading) return;
    setState(() => _isPressed = false);
    _scaleController.reverse();
    HapticHelper.mediumImpact();
    widget.onPressed!();
  }

  void _handleTapCancel() {
    if (widget.onPressed == null || widget.isLoading) return;
    setState(() => _isPressed = false);
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = widget.onPressed == null || widget.isLoading;
    final bool highContrast = MediaQuery.of(context).highContrast;

    // Authentic iOS Transparent Glass styling
    final BoxDecoration decoration;
    final Color textColor;

    if (widget.isIosGlass) {
      decoration = BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        gradient: LinearGradient(
          colors: _isPressed
              ? [
                  Colors.white.withValues(alpha: 0.24),
                  Colors.white.withValues(alpha: 0.10),
                ]
              : [
                  Colors.white.withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.05),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: highContrast
              ? Colors.white.withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: _isPressed ? 0.45 : 0.28),
          width: highContrast ? 1.5 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.40),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
          if (!_isPressed)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.08),
              blurRadius: 10,
              spreadRadius: -2,
              offset: const Offset(0, -1),
            ),
        ],
      );
      textColor = Colors.white;
    } else if (widget.isSecondary) {
      decoration = BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        color: const Color(0xFF1C1C1E).withValues(alpha: 0.85),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      );
      textColor = Colors.white.withValues(alpha: 0.85);
    } else {
      // Metallic Gold variant
      decoration = BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFD700).withValues(alpha: 0.22),
            const Color(0xFF0F0F12).withValues(alpha: 0.65),
            const Color(0xFFB8860B).withValues(alpha: 0.18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: highContrast ? 0.95 : 0.65),
          width: highContrast ? 1.8 : 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: highContrast ? 0.35 : 0.20),
            blurRadius: 20,
            spreadRadius: -2,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      );
      textColor = const Color(0xFFFFF7D6);
    }

    Widget content = Container(
      width: widget.width,
      height: widget.height,
      decoration: decoration,
      child: Center(
        child: widget.isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.leading != null) ...[
                    widget.leading!,
                    const SizedBox(width: 10),
                  ],
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      fontSize: 17.0,
                    ),
                  ),
                  if (widget.trailing != null) ...[
                    const SizedBox(width: 8),
                    widget.trailing!,
                  ],
                ],
              ),
      ),
    );

    // High performance localized backdrop blur
    content = ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: content,
      ),
    );

    return Semantics(
      button: true,
      enabled: !isDisabled,
      label: widget.label,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          behavior: HitTestBehavior.opaque,
          child: Opacity(
            opacity: isDisabled ? 0.55 : 1.0,
            child: content,
          ),
        ),
      ),
    );
  }
}
