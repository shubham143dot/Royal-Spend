import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AmbientBackground extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const AmbientBackground({
    super.key,
    required this.child,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (isDark) {
      // Pure True OLED Black background (iOS Settings reference)
      // Zero-cost hardware accelerated solid background with no fill-rate drag
      return Container(
        color: AppColors.darkBackground,
        child: child,
      );
    }

    return Stack(
      children: [
        // Base solid background
        Positioned.fill(
          child: Container(
            color: AppColors.lightBackground,
          ),
        ),

        // Ambient Orb 1 - Top Left (Royal Indigo) with zero-cost radial diffusion
        Positioned(
          top: -120,
          left: -100,
          child: IgnorePointer(
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (isDark ? AppColors.royalIndigo : AppColors.royalIndigoLight)
                        .withValues(alpha: isDark ? 0.22 : 0.16),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Ambient Orb 2 - Top Right (Electric Cyan)
        Positioned(
          top: 40,
          right: -100,
          child: IgnorePointer(
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.electricCyan.withValues(alpha: isDark ? 0.18 : 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Ambient Orb 3 - Center / Mid-Screen (Violet Accent)
        Positioned(
          top: 340,
          left: -80,
          child: IgnorePointer(
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.violetAccent.withValues(alpha: isDark ? 0.14 : 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Ambient Orb 4 - Bottom Right (Vivid Mint)
        Positioned(
          bottom: 20,
          right: -80,
          child: IgnorePointer(
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.vividMint.withValues(alpha: isDark ? 0.12 : 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Child Content
        child,
      ],
    );
  }
}
