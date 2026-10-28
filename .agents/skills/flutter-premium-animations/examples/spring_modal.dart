import 'package:flutter/material.dart';
import 'spring_curves.dart';

/// Shows a center pop dialog with coordinated scale + fade + spring entrance.
Future<T?> showSpringPopDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  Duration duration = const Duration(milliseconds: 340),
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dismiss Dialog',
    barrierColor: barrierColor ?? Colors.black.withOpacity(0.55),
    transitionDuration: duration,
    pageBuilder: (ctx, anim1, anim2) => builder(ctx),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final disableAnimations = MediaQuery.of(context).disableAnimations;

      if (disableAnimations) {
        return FadeTransition(opacity: animation, child: child);
      }

      final curved = CurvedAnimation(
        parent: animation,
        curve: IOSSpringCurve.bouncy,
        reverseCurve: Curves.easeInCubic,
      );

      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Shows a smooth bottom sheet modal configured with iOS Cupertino curves.
Future<T?> showSpringBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  Color barrierColor = const Color(0x8C000000),
  Duration duration = const Duration(milliseconds: 320),
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: barrierColor,
    sheetAnimationStyle: AnimationStyle(
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
      duration: duration,
    ),
    builder: builder,
  );
}
