import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import 'liquid_pop.dart';

/// Luxury 3D Royal Spend app logo widget with transparent floating geometry,
/// gold ambient halo glow, and tactile spring feedback.
class RoyalLogo extends StatelessWidget {
  final double size;
  final bool showGlow;
  final bool interactive;
  final VoidCallback? onTap;
  final Color? glowColor;

  const RoyalLogo({
    super.key,
    this.size = 54.0,
    this.showGlow = true,
    this.interactive = false,
    this.onTap,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveGlowColor = glowColor ?? const Color(0xFFFFC837);

    Widget logoBox = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (showGlow)
            Container(
              width: size * 0.85,
              height: size * 0.85,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: effectiveGlowColor.withValues(alpha: 0.42),
                    blurRadius: size * 0.32,
                    spreadRadius: size * 0.05,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.40),
                    blurRadius: size * 0.16,
                  ),
                ],
              ),
            ),
          Image.asset(
            AppConstants.appLogoPath,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: const Color(0xFF141416),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Color(0xFFFFD700),
                ),
              );
            },
          ),
        ],
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
