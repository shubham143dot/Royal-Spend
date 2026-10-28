import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/spring_curves.dart';
import '../../../core/utils/haptic_helper.dart';
import '../liquid_pop.dart';
import 'quick_travel_expense_sheet.dart';

/// Floating action button dedicated to travel expenses.
/// Distinct solar amber/orange hue, organic liquid animation, and haptic feedback.
class LiquidAddTravelExpenseFab extends StatefulWidget {
  final bool isDark;
  final String? currentTripId;
  final double bottomPadding;

  const LiquidAddTravelExpenseFab({
    super.key,
    required this.isDark,
    this.currentTripId,
    this.bottomPadding = 82,
  });

  @override
  State<LiquidAddTravelExpenseFab> createState() =>
      _LiquidAddTravelExpenseFabState();
}

class _LiquidAddTravelExpenseFabState extends State<LiquidAddTravelExpenseFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _rotationAnim;
  late final Animation<double> _pulseScaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _rotationAnim = Tween<double>(begin: 0.0, end: 0.25).animate(
      CurvedAnimation(
        parent: _animController,
        curve: IOSSpringCurve.snappy,
        reverseCurve: Curves.easeOutCubic,
      ),
    );
    _pulseScaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.06)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.06, end: 1.0)
            .chain(CurveTween(curve: IOSSpringCurve.snappy)),
        weight: 60,
      ),
    ]).animate(_animController);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    HapticHelper.mediumImpact();
    _animController.forward(from: 0.0);
    // Yield a frame micro-pause so the spring pop renders its first frame with zero raster jank
    await Future.delayed(const Duration(milliseconds: 40));
    if (!mounted) return;
    await QuickTravelExpenseSheet.show(
      context,
      initialTripId: widget.currentTripId,
    );
    if (mounted) {
      _animController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Distinct solar orange / amber palette for travel
    final travelColor =
        widget.isDark ? AppColors.appleOrange : const Color(0xFFF97316);
    final bool highContrast = MediaQuery.of(context).highContrast;

    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomPadding),
      child: RepaintBoundary(
        child: LiquidPop(
          pressedScale: 0.91,
          onTap: _handleTap,
          child: ScaleTransition(
            scale: _pulseScaleAnim,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: highContrast
                    ? (widget.isDark ? AppColors.darkCard : const Color(0xFFFFFFFF))
                    : (widget.isDark
                        ? AppColors.darkCard
                        : const Color(0xF0FFFFFF)),
                border: Border.all(
                  color: highContrast
                      ? (widget.isDark ? Colors.white : const Color(0xFF334155))
                      : (widget.isDark
                          ? AppColors.darkGlassHighlight
                          : const Color(0xFFFFFFFF)),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: travelColor.withValues(alpha: widget.isDark ? 0.48 : 0.35),
                    blurRadius: 22,
                    offset: const Offset(0, 6),
                  ),
                  if (!widget.isDark)
                    const BoxShadow(
                      color: Color(0x80FFFFFF),
                      blurRadius: 8,
                      offset: Offset(0, -2),
                    ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: widget.isDark ? 0.35 : 0.10),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Subtle glowing radial backdrop in travel amber
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          travelColor.withValues(alpha: widget.isDark ? 0.28 : 0.20),
                          travelColor.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                  RepaintBoundary(
                    child: RotationTransition(
                      turns: _rotationAnim,
                      child: Icon(
                        CupertinoIcons.add,
                        size: 28,
                        color: travelColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
