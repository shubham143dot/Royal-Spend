import 'package:flutter/material.dart';

/// Extension on [Widget] for declarative entrance micro-interactions.
extension PremiumAnimationExtensions on Widget {
  /// Wraps this widget in a fluid fade + slide entrance with an optional stagger delay.
  Widget animateEntrance({
    Duration duration = const Duration(milliseconds: 380),
    Duration delay = Duration.zero,
    Offset beginOffset = const Offset(0.0, 0.12),
    Curve curve = Curves.easeOutCubic,
  }) {
    return _StaggeredItemWrapper(
      duration: duration,
      delay: delay,
      beginOffset: beginOffset,
      curve: curve,
      child: this,
    );
  }
}

class _StaggeredItemWrapper extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset beginOffset;
  final Curve curve;

  const _StaggeredItemWrapper({
    required this.child,
    required this.duration,
    required this.delay,
    required this.beginOffset,
    required this.curve,
  });

  @override
  State<_StaggeredItemWrapper> createState() => _StaggeredItemWrapperState();
}

class _StaggeredItemWrapperState extends State<_StaggeredItemWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
    _slide = Tween<Offset>(begin: widget.beginOffset, end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    if (disableAnimations) return widget.child;

    return RepaintBoundary(
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(
          position: _slide,
          child: widget.child,
        ),
      ),
    );
  }
}
