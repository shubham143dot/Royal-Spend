import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../widgets/splash/cinematic_particles_painter.dart';
import '../../widgets/splash/metallic_light_sweep.dart';

/// Top-level Gate that handles cold-start cinematic splash animation display
/// and seamless transition to the existing application gate.
///
/// Guaranteed behavior:
/// 1. Cold start: Displays full cinematic animation once.
/// 2. Resume / Backgrounding: NEVER replays; preserves the current screen state.
/// 3. Authentication & Security: Preserved 100%. Child is only mounted/revealed.
class CinematicSplashGate extends StatefulWidget {
  final Widget child;

  const CinematicSplashGate({
    super.key,
    required this.child,
  });

  @override
  State<CinematicSplashGate> createState() => _CinematicSplashGateState();
}

class _CinematicSplashGateState extends State<CinematicSplashGate> {
  static bool _hasCompletedSplash = false;

  void _onSplashFinished() {
    if (!mounted) return;
    setState(() {
      _hasCompletedSplash = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeIn,
      switchOutCurve: Curves.easeOut,
      child: _hasCompletedSplash
          ? widget.child
          : CinematicSplashScreen(
              key: const ValueKey('cinematic_splash_screen'),
              onComplete: _onSplashFinished,
            ),
    );
  }
}

/// Official Royal Spend Cinematic 2D + 3D Logo Opening Animation.
///
/// Implements a 6-scene sequential timeline with 60–120 FPS performance,
/// real-time 2.5D perspective depth, metallic gold light sweeps,
/// ambient golden dust particle simulation, and luxury serif typography.
class CinematicSplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const CinematicSplashScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<CinematicSplashScreen> createState() => _CinematicSplashScreenState();
}

class _CinematicSplashScreenState extends State<CinematicSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<GoldenParticle> _particles;

  // Scene 1: Royal Darkness (0.00 – 0.15 | 0–400ms)
  late final Animation<double> _leatherBgOpacity;
  late final Animation<double> _ambientHaloOpacity;

  // Scene 2: Crown Crest Emergence (0.15 – 0.33 | 400–900ms)
  late final Animation<double> _crownGlowOpacity;
  late final Animation<double> _particlesMasterAlpha;

  // Scene 3: 2D + 3D RS Monogram Reveal (0.25 – 0.55 | 700–1500ms)
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoPitch;
  late final Animation<double> _logoYaw;
  late final Animation<double> _firstSweepProgress;
  late final Animation<double> _firstSweepIntensity;

  // Scene 4: ROYAL SPEND Typography Reveal (0.48 – 0.70 | 1300–1900ms)
  late final Animation<double> _titleOpacity;
  late final Animation<double> _titleSlide;
  late final Animation<double> _subtitleOpacity;
  late final Animation<double> _subtitleSlide;

  // Scene 5: Final Signature Effect (0.70 – 0.88 | 1900–2400ms)
  late final Animation<double> _crownGlintProgress;
  late final Animation<double> _secondSweepProgress;
  late final Animation<double> _secondSweepIntensity;
  late final Animation<double> _signaturePulseScale;

  // Scene 6: Seamless Application Transition (0.88 – 1.00 | 2400–2700ms)
  late final Animation<double> _exitOpacity;
  late final Animation<double> _exitPushScale;

  bool _isDisposed = false;
  bool _didTriggerComplete = false;

  @override
  void initState() {
    super.initState();
    _particles = GoldenParticle.createParticlePool(count: 28);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2700),
    );

    // Setup animation curves
    _leatherBgOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.00, 0.15, curve: Curves.easeIn),
      ),
    );

    _ambientHaloOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.05, 0.25, curve: Curves.easeOut),
      ),
    );

    _crownGlowOpacity = Tween<double>(begin: 0.0, end: 0.85).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 0.35, curve: Curves.easeOut),
      ),
    );

    _particlesMasterAlpha = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 0.90)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.90, end: 1.0)
            .chain(CurveTween(curve: Curves.linear)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
    ]).animate(_controller);

    _logoScale = Tween<double>(begin: 0.84, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.24, 0.54, curve: Curves.easeOutCubic),
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.24, 0.44, curve: Curves.easeIn),
      ),
    );

    _logoPitch = Tween<double>(begin: -0.09, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.24, 0.56, curve: Curves.easeOutCubic),
      ),
    );

    _logoYaw = Tween<double>(begin: 0.04, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.24, 0.56, curve: Curves.easeOutCubic),
      ),
    );

    _firstSweepProgress = Tween<double>(begin: -0.2, end: 1.3).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.32, 0.54, curve: Curves.easeInOut),
      ),
    );

    _firstSweepIntensity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 0.95),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.95, end: 0.0),
        weight: 70,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.32, 0.54),
      ),
    );

    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.48, 0.65, curve: Curves.easeOut),
      ),
    );

    _titleSlide = Tween<double>(begin: 14.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.48, 0.68, curve: Curves.easeOutCubic),
      ),
    );

    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 0.70, curve: Curves.easeOut),
      ),
    );

    _subtitleSlide = Tween<double>(begin: 8.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 0.70, curve: Curves.easeOutCubic),
      ),
    );

    _crownGlintProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.70, 0.85, curve: Curves.easeInOut),
      ),
    );

    _secondSweepProgress = Tween<double>(begin: -0.3, end: 1.4).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.72, 0.88, curve: Curves.easeInOut),
      ),
    );

    _secondSweepIntensity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0),
        weight: 65,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.72, 0.88),
      ),
    );

    _signaturePulseScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.03)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.03, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 60,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.70, 0.88),
      ),
    );

    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.88, 1.00, curve: Curves.easeIn),
      ),
    );

    _exitPushScale = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.88, 1.00, curve: Curves.easeIn),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _finishSplash();
      }
    });

    // Start playback immediately on frame 0
    _startAnimation();
  }

  void _startAnimation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.of(context).disableAnimations) {
        _finishSplash();
      } else {
        HapticHelper.lightImpact();
        _controller.forward();
      }
    });
  }

  void _finishSplash() {
    if (_didTriggerComplete) return;
    _didTriggerComplete = true;
    widget.onComplete();
  }

  void _skipToApp() {
    if (_didTriggerComplete || _isDisposed) return;
    HapticHelper.selectionClick();
    _controller.animateTo(
      1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precache assets for instantaneous hardware GPU texture binding
    precacheImage(const AssetImage(AppConstants.appLogoPath), context);
    precacheImage(const AssetImage(AppConstants.royalLeatherBgPath), context);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _skipToApp,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final double masterExitAlpha = _exitOpacity.value.clamp(0.0, 1.0);
            final double masterExitScale = _exitPushScale.value;

            return Opacity(
              opacity: masterExitAlpha,
              child: Transform.scale(
                scale: masterExitScale,
                child: Scaffold(
                  backgroundColor: const Color(0xFF080808), // Royal Black
                  body: Stack(
                    fit: StackFit.expand,
                    children: [
                      // SCENE 1: Genuine Leather Texture + Deep Ambient Vignette
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: Opacity(
                            opacity: _leatherBgOpacity.value,
                            child: Image.asset(
                              AppConstants.royalLeatherBgPath,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const ColoredBox(
                                color: Color(0xFF080808),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // SCENE 1: Golden Ambient Radial Aura from Center
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: Opacity(
                            opacity: _ambientHaloOpacity.value,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: Alignment.center,
                                  radius: 0.75,
                                  colors: [
                                    const Color(0xFFF5B82E).withValues(alpha: 0.18),
                                    const Color(0xFFE88A00).withValues(alpha: 0.08),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.45, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Ambient Floating Golden Dust Particles
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: CinematicParticlesPainter(
                              particles: _particles,
                              progress: _controller.value,
                              masterAlpha: _particlesMasterAlpha.value,
                            ),
                          ),
                        ),
                      ),

                      // Main Logo & Typography Presentation Composition
                      SafeArea(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final maxDim = math.min(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            );
                            final logoSize = (maxDim * 0.48).clamp(160.0, 240.0);

                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // 2D + 3D Dimensional RS Logo with Bevel Light Sweeps
                                  _buildDimensionalLogo(logoSize),
                                  const SizedBox(height: 24),
                                  // ROYAL SPEND Typography with Gold Shimmer
                                  _buildBrandTypography(),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      // Skip hint indicator (subtle champagne gold dot in bottom corner)
                      Positioned(
                        right: 20,
                        bottom: 24,
                        child: SafeArea(
                          child: Opacity(
                            opacity: (_controller.value > 0.35 &&
                                    _controller.value < 0.88)
                                ? 0.35
                                : 0.0,
                            child: const Text(
                              'Tap to skip',
                              style: TextStyle(
                                color: Color(0xFFFFE6A0),
                                fontSize: 11,
                                letterSpacing: 1.0,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Builds the 2.5D perspective-transformed RS logo with multi-layered shadows
  /// and dynamic metallic specular reflections.
  Widget _buildDimensionalLogo(double size) {
    final double scale = _logoScale.value * _signaturePulseScale.value;
    final double pitch = _logoPitch.value;
    final double yaw = _logoYaw.value;

    // 2.5D perspective projection matrix (simulates real camera depth)
    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.0018)
      ..rotateX(pitch)
      ..rotateY(yaw)
      ..scaleByDouble(scale, scale, 1.0, 1.0);

    // Active light sweep parameters
    final sweepProgress = _controller.value < 0.65
        ? _firstSweepProgress.value
        : _secondSweepProgress.value;
    final sweepIntensity = _controller.value < 0.65
        ? _firstSweepIntensity.value
        : _secondSweepIntensity.value;

    return Transform(
      alignment: Alignment.center,
      transform: matrix,
      child: Opacity(
        opacity: _logoOpacity.value.clamp(0.0, 1.0),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Layer 1: Crown ambient warm radiance
              Positioned(
                top: -size * 0.15,
                child: Opacity(
                  opacity: _crownGlowOpacity.value.clamp(0.0, 1.0),
                  child: Container(
                    width: size * 0.8,
                    height: size * 0.45,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.38),
                          blurRadius: size * 0.35,
                          spreadRadius: size * 0.05,
                        ),
                        BoxShadow(
                          color: const Color(0xFFE88A00).withValues(alpha: 0.25),
                          blurRadius: size * 0.50,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Layer 2: Deep Ambient Leather Cast Shadow (Physical Depth)
              Positioned(
                top: 14,
                left: 0,
                right: 0,
                bottom: -14,
                child: Image.asset(
                  AppConstants.appLogoPath,
                  color: Colors.black.withValues(alpha: 0.80),
                  filterQuality: FilterQuality.low,
                ),
              ),

              // Layer 3: Elevated Key Drop Shadow
              Positioned(
                top: 6,
                left: 0,
                right: 0,
                bottom: -6,
                child: Image.asset(
                  AppConstants.appLogoPath,
                  color: Colors.black.withValues(alpha: 0.45),
                  filterQuality: FilterQuality.low,
                ),
              ),

              // Layer 4: Original Pristine Royal Spend Artwork with Metallic Sweep
              Positioned.fill(
                child: MetallicLightSweep(
                  sweepProgress: sweepProgress,
                  intensity: sweepIntensity,
                  child: Image.asset(
                    AppConstants.appLogoPath,
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // Layer 5: Crown Apex Specular Diamond Glint (Scene 5 Climax)
              Positioned(
                top: size * 0.09,
                child: SpecularCrownGlint(
                  progress: _crownGlintProgress.value,
                  size: size * 0.36,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the elegant luxury serif brand typography with smooth upward slide
  /// and champagne gold gradient illumination.
  Widget _buildBrandTypography() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // "ROYAL SPEND"
        Transform.translate(
          offset: Offset(0, _titleSlide.value),
          child: Opacity(
            opacity: _titleOpacity.value.clamp(0.0, 1.0),
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFFFFF), // Crisp White Highlight
                    Color(0xFFFFE6A0), // Champagne Gold
                    Color(0xFFFFD700), // Royal Gold
                    Color(0xFFF5B82E), // Metallic Gold
                    Color(0xFFE88A00), // Golden Orange
                  ],
                  stops: [0.0, 0.25, 0.55, 0.80, 1.0],
                ).createShader(bounds);
              },
              child: const Text(
                'ROYAL SPEND',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 5.5,
                  height: 1.1,
                  shadows: [
                    Shadow(
                      color: Color(0x99000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // "EXPENSE TRACKER & TRAVEL PLANNER"
        Transform.translate(
          offset: Offset(0, _subtitleSlide.value),
          child: Opacity(
            opacity: _subtitleOpacity.value.clamp(0.0, 1.0),
            child: const Text(
              'EXPENSE TRACKER & TRAVEL PLANNER',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 3.2,
                color: Color(0xCCFFE6A0), // Champagne Gold with subtle transparency
                shadows: [
                  Shadow(
                    color: Color(0x88000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
