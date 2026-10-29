import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../widgets/liquid_pop.dart';
import '../../widgets/royal_glass_button.dart';
import '../auth/login_screen.dart';

/// Premier Royal Spend Intro Experience.
/// Plays the official intro video exactly once, ensures zero black flashes or layout jumps,
/// features graceful fallback on playback failure or low-end devices,
/// animates the luxurious glassmorphism 'Get Started' button upon completion,
/// and executes a coordinated Hero transition to the redesigned Login Screen.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  VideoPlayerController? _videoController;
  late final AnimationController _buttonAnimController;
  late final Animation<double> _buttonFadeAnim;
  late final Animation<Offset> _buttonSlideAnim;

  bool _isInitialized = false;
  bool _hasStartedPlaying = false;
  bool _hasFinished = false;
  bool _hasError = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _buttonAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _buttonFadeAnim = CurvedAnimation(
      parent: _buttonAnimController,
      curve: Curves.easeOutCubic,
    );

    _buttonSlideAnim = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _buttonAnimController,
      curve: Curves.easeOutCubic,
    ));

    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      final controller = VideoPlayerController.asset(
        AppConstants.introVideoPath,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      _videoController = controller;
      await controller.initialize();
      await controller.setLooping(false);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      controller.addListener(_videoListener);

      setState(() {
        _isInitialized = true;
      });

      if (!_hasFinished) {
        await controller.play();
        _hasStartedPlaying = true;
      }
    } catch (e, st) {
      debugPrint('[IntroScreen] Video initialization failed: $e\n$st');
      if (mounted) {
        setState(() {
          _hasError = true;
          _hasFinished = true;
        });
        _buttonAnimController.forward();
      }
    }
  }

  void _videoListener() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;

    final position = controller.value.position;
    final duration = controller.value.duration;

    // Detect completion within 200ms of the video duration or when playback stops
    if (!_hasFinished &&
        duration > Duration.zero &&
        (position >= duration - const Duration(milliseconds: 200) ||
            (!controller.value.isPlaying && position >= duration * 0.95))) {
      _onVideoCompleted();
    }
  }

  void _onVideoCompleted() {
    if (_hasFinished) return;

    _hasFinished = true;
    _videoController?.pause();

    if (mounted) {
      setState(() {});
      _buttonAnimController.forward();
    }
  }

  void _skipToEnd() {
    if (_hasFinished) return;
    HapticHelper.lightImpact();

    _videoController?.pause();
    _onVideoCompleted();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      controller.pause();
    } else if (state == AppLifecycleState.resumed && !_hasFinished && _hasStartedPlaying) {
      controller.play();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _videoController;
    if (controller != null) {
      controller.removeListener(_videoListener);
      controller.dispose();
    }
    _buttonAnimController.dispose();
    super.dispose();
  }

  Future<void> _handleGetStarted() async {
    if (_isNavigating) return;
    _isNavigating = true;

    // Super smooth custom transition into LoginScreen
    await Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 650),
        reverseTransitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fadeCurve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          );
          final slideCurve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(slideCurve),
            child: FadeTransition(
              opacity: fadeCurve,
              child: child,
            ),
          );
        },
      ),
    );

    // If user returns back to IntroScreen, reset navigation lock
    _isNavigating = false;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.black,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Layer 1: Pure Black Base with Video Player / Poster Fallback
            Container(color: Colors.black),

            if (_isInitialized && _videoController != null && !_hasError)
              Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _videoController!.value.size.width,
                    height: _videoController!.value.size.height,
                    child: VideoPlayer(_videoController!),
                  ),
                ),
              )
            else
              // Fallback Poster Image if video is initializing or fails
              Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Image.asset(
                    AppConstants.introPosterPath,
                    width: size.width,
                    height: size.height,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const SizedBox(),
                  ),
                ),
              ),

            // Layer 2: Top Skip Pill (Allows rapid testing & impatient users to skip)
            if (!_hasFinished)
              Positioned(
                top: topPadding + 14,
                right: 20,
                child: SafeArea(
                  child: LiquidPop(
                    onTap: _skipToEnd,
                    pressedScale: 0.94,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Skip',
                                style: TextStyle(
                                  fontFamily: 'SF Pro Display',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.75),
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 10,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Layer 3: Premium Transparent Glassmorphism 'Get Started' Button (iOS Style)
            // Smoothly fades in and slides upward upon video completion.
            Positioned(
              left: 24,
              right: 24,
              bottom: bottomPadding + 28,
              child: FadeTransition(
                opacity: _buttonFadeAnim,
                child: SlideTransition(
                  position: _buttonSlideAnim,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: RoyalGlassButton(
                        label: 'Get Started',
                        height: 56,
                        width: double.infinity,
                        isIosGlass: true,
                        trailing: const Icon(
                          CupertinoIcons.arrow_right,
                          color: Colors.white,
                          size: 19,
                        ),
                        onPressed: _handleGetStarted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
