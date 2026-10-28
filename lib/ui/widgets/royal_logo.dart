import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import 'liquid_pop.dart';

/// Luxury 3D Royal Spend app logo widget with squircle curvature,
/// gold specular glow, and optional tactile spring feedback.
class RoyalLogo extends StatelessWidget {
  final double size;
  final bool showGlow;
  final bool interactive;
  final VoidCallback? onTap;

  const RoyalLogo({
    super.key,
    this.size = 54.0,
    this.showGlow = true,
    this.interactive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.223);

    Widget logoBox = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: const Color(0xFFFFC837).withValues(alpha: 0.35),
                  blurRadius: size * 0.25,
                  spreadRadius: 1,
                  offset: Offset(0, size * 0.08),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: size * 0.18,
                  offset: Offset(0, size * 0.06),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Image.asset(
          AppConstants.appLogoPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                borderRadius: radius,
                border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Color(0xFFFFD700),
              ),
            );
          },
        ),
      ),
    );

    if (interactive || onTap != null) {
      return LiquidPop(
        pressedScale: 0.94,
        onTap: onTap,
        child: logoBox,
      );
    }

    return logoBox;
  }
}

