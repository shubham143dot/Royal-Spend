import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth/firebase_auth_gateway.dart';
import '../../../core/services/auth/royal_auth_gateway.dart';
import '../../../core/services/firestore/firestore_sync_service.dart';
import '../../../data/database/database_helper.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../core/theme/liquid_auth_colors.dart';
import '../../../core/theme/spring_curves.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../providers/expense_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/travel_provider.dart';
import '../../widgets/auth/forgot_password_dialog.dart';
import '../../widgets/auth/liquid_glass_particle_field.dart';
import '../../widgets/auth/liquid_ui_components.dart';
import '../../widgets/liquid_pop.dart';
import '../../widgets/login_video_background.dart';
import '../../../core/utils/privacy_launcher.dart';
import '../../widgets/royal_logo.dart';
import '../main_navigation_screen.dart';

/// Royal Spend – Master iOS Liquid Glass Authentication Experience.
///
/// Implemented according to the MASTER IMPLEMENTATION PROMPT using references:
/// - Repository 1: https://github.com/Ag1rin/login_glass_app (Particle mechanics & repulsion)
/// - Repository 2: https://github.com/tejapunna/glassmorphic_ui (Liquid Glass components)
///
/// STRICT DESIGN CONSTRAINTS:
/// - Preserves the exact background video looping underneath.
/// - Sophisticated neutral color palette: Transparent white, soft silver, charcoal, graphite.
/// - Absolutely ZERO BLUE, ZERO GOLDEN, and no gaming neon aesthetics.
/// - 100% preservation of existing Firebase authentication logic and backend synchronization.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.authGateway,
    this.videoController,
    this.subtitle,
  });

  /// Optional provider boundary for production auth or widget tests.
  final RoyalAuthGateway? authGateway;

  /// Optional video controller for widget testing or custom video injection.
  final VideoPlayerController? videoController;

  /// Optional custom subtitle (defaults to 'Your money. Your journey. Your control.').
  final String? subtitle;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _loginFormKey = GlobalKey<FormState>();
  final _createFormKey = GlobalKey<FormState>();

  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _createNameController = TextEditingController();
  final _createEmailController = TextEditingController();
  final _createPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _loginEmailFocus = FocusNode();
  final _loginPasswordFocus = FocusNode();
  final _createNameFocus = FocusNode();
  final _createEmailFocus = FocusNode();
  final _createPasswordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  late final AnimationController _entranceController;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _cardFade;
  late final Animation<Offset> _cardSlide;
  late final Animation<double> _secondaryFade;

  bool _isCreatingAccount = false;
  bool _isSubmitting = false;
  bool _isGoogleLoading = false;
  bool _isNavigating = false;
  String? _statusMessage;
  bool _statusIsError = true;

  RoyalAuthGateway get _authGateway {
    if (widget.authGateway != null) return widget.authGateway!;
    if (Firebase.apps.isNotEmpty) {
      return FirebaseAuthGateway();
    }
    return const UnconfiguredRoyalAuthGateway();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
      animationBehavior: AnimationBehavior.normal,
    );

    _logoFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.40, curve: Curves.easeOutCubic),
    );

    _logoScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.45, curve: IOSSpringCurve.gentle),
      ),
    );

    _titleFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.10, 0.55, curve: Curves.easeOutCubic),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.10, 0.55, curve: Curves.easeOutCubic),
      ),
    );

    _cardFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.20, 0.80, curve: Curves.easeOutCubic),
    );

    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.20, 0.80, curve: IOSSpringCurve.gentle),
      ),
    );

    _secondaryFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.48, 1.0, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyMotionPreference();
  }

  @override
  void didChangeAccessibilityFeatures() => _applyMotionPreference();

  void _applyMotionPreference() {
    if (!mounted) return;
    final reduceMotion = MediaQuery.disableAnimationsOf(context) ||
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.reduceMotion;
    if (reduceMotion) {
      _entranceController.value = 1.0;
    } else if (_entranceController.value == 0 && !_entranceController.isAnimating) {
      _entranceController.forward();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _entranceController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _createNameController.dispose();
    _createEmailController.dispose();
    _createPasswordController.dispose();
    _confirmPasswordController.dispose();
    _loginEmailFocus.dispose();
    _loginPasswordFocus.dispose();
    _createNameFocus.dispose();
    _createEmailFocus.dispose();
    _createPasswordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email address.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password.';
    return null;
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) return 'Create a password.';
    if (value.length < 8) return 'Use at least 8 characters.';
    return null;
  }

  void _setStatus(String message, {bool isError = true}) {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      _statusIsError = isError;
    });
  }

  Future<void> _submitSignIn() async {
    if (_isSubmitting || _isNavigating) return;
    if (!(_loginFormKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
    });

    try {
      await _authGateway.signIn(
        email: _loginEmailController.text.trim(),
        password: _loginPasswordController.text,
      );
      if (!mounted) return;
      await _navigateToHome(authenticated: true);
    } on AuthProviderNotConfigured {
      _setStatus(
        'Email sign-in is not connected yet. Connect an authentication provider to sign in.',
      );
    } catch (e) {
      final raw = e.toString().replaceAll('Exception: ', '').trim();
      _setStatus(
        raw.isNotEmpty
            ? raw
            : 'We couldn’t sign you in. Check your details and try again.',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitCreateAccount() async {
    if (_isSubmitting || _isNavigating) return;
    if (!(_createFormKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
    });

    try {
      await _authGateway.createAccount(
        name: _createNameController.text.trim(),
        email: _createEmailController.text.trim(),
        password: _createPasswordController.text,
      );
      if (!mounted) return;
      await _navigateToHome(authenticated: true);
    } on AuthProviderNotConfigured {
      _setStatus(
        'Account creation is not connected yet. Connect an authentication provider to continue.',
      );
    } catch (e) {
      final raw = e.toString().replaceAll('Exception: ', '').trim();
      _setStatus(
        raw.isNotEmpty
            ? raw
            : 'We couldn’t create your account. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isGoogleLoading || _isNavigating) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isGoogleLoading = true;
      _statusMessage = null;
    });
    HapticHelper.mediumImpact();

    try {
      await _authGateway.signInWithGoogle();
      if (!mounted) return;
      await _navigateToHome(authenticated: true);
    } on AuthProviderNotConfigured {
      if (!mounted) return;
      setState(() => _isGoogleLoading = false);
      _showAuthNoticeDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGoogleLoading = false);
      final raw = e.toString().replaceAll('Exception: ', '').trim();
      if (raw.isNotEmpty &&
          !raw.contains('sign_in_canceled') &&
          !raw.contains('canceled') &&
          !raw.contains('cancelled')) {
        _setStatus(raw);
      }
    } finally {
      if (mounted && _isGoogleLoading) setState(() => _isGoogleLoading = false);
    }
  }

  void _showAuthNoticeDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: AlertDialog(
          backgroundColor: Colors.white.withValues(alpha: 0.09),
          surfaceTintColor: Colors.transparent,
          icon: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.50),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 18,
                ),
              ],
            ),
            child: const Icon(
              Icons.cloud_sync_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.28),
              width: 1.1,
            ),
          ),
          title: const Text(
            'Google sign-in isn’t connected',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: LiquidAuthColors.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          content: const Text(
            'This build has no authentication provider configured. You can still explore the app with its demo workspace.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: LiquidAuthColors.textSecondary,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: LiquidAuthColors.textMuted,
              ),
              child: const Text('Cancel'),
            ),
            SizedBox(
              width: 132,
              child: LiquidGlassPrimaryButton(
                label: 'Use Demo',
                height: 48,
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _handleSkipBypass();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPasswordResetDialog() async {
    await showLiquidForgotPasswordDialog(
      context: context,
      authGateway: _authGateway,
      initialEmail: _loginEmailController.text,
      onStatusChanged: (message, {bool isError = true}) =>
          _setStatus(message, isError: isError),
    );
  }

  Future<void> _handleSkipBypass() async {
    if (_isNavigating) return;
    FocusScope.of(context).unfocus();
    HapticHelper.lightImpact();
    await _navigateToHome();
  }

  Future<void> _navigateToHome({bool authenticated = false}) async {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);

    final settings = context.read<SettingsProvider>();
    if (authenticated) await settings.setIsAuthenticated(true);
    await settings.setHasSeenIntro(true);
    await settings.setHasCompletedIntro(true);

    if (authenticated && Firebase.apps.isNotEmpty) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          if (user.email != null) {
            await settings.setUserEmail(user.email);
          }
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          if (doc.exists) {
            final data = doc.data();
            final name = data?['name'] as String?;
            final photoURL = data?['photoURL'] as String?;
            final prefs = data?['preferences'] as Map<String, dynamic>?;

            if (name != null && name.isNotEmpty) await settings.setUserName(name);
            if (photoURL != null && photoURL.isNotEmpty) {
              await settings.setProfilePhotoUrl(photoURL);
            }
            if (prefs != null) {
              final symbol = prefs['currencySymbol'] as String?;
              final code = prefs['currencyCode'] as String?;
              if (symbol != null && code != null) {
                await settings.setCurrency(symbol, code);
              }
              final budget = prefs['monthlyBudget'];
              if (budget is num) {
                await settings.setMonthlyBudget(budget.toDouble());
              }
            }
          }

          if (mounted) {
            final settingsRepo = SettingsRepository();
            final lastUserId = await settingsRepo.getLastUserId();
            if (lastUserId == null || lastUserId != user.uid) {
              await DatabaseHelper.instance.clearAllData();
              if (mounted) {
                context.read<ExpenseProvider>().clearAllDataInMemory();
                context.read<TravelProvider>().clearAllDataInMemory();
              }
              await settingsRepo.setLastUserId(user.uid);
            }

            if (!mounted) return;
            final expenseProv = context.read<ExpenseProvider>();
            final travelProv = context.read<TravelProvider>();
            travelProv.setAdminStatus(AppConstants.isAdmin(user.email));
            FirestoreSyncService.instance.syncAll(
              user.uid,
              userEmail: user.email,
              onRefresh: () {
                expenseProv.refresh();
                travelProv.refresh();
              },
            );
            FirestoreSyncService.instance.setupRealtimeListeners(
              user.uid,
              userEmail: user.email,
              onDataChanged: () {
                expenseProv.refresh();
                travelProv.refresh();
              },
            );
          }
        }
      } catch (e) {
        debugPrint('Profile restore note on login: $e');
      }
    }

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 520),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MainNavigationScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          );
          return FadeTransition(opacity: curve, child: child);
        },
      ),
      (route) => false,
    );
  }

  void _switchMode(bool createAccount) {
    FocusScope.of(context).unfocus();
    HapticHelper.selectionClick();
    setState(() {
      _isCreatingAccount = createAccount;
      _isSubmitting = false;
      _statusMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final effectiveSubtitle =
        widget.subtitle ?? 'Your money. Your journey. Your control.';

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: true,
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
              // 1. High-Performance Looping Video Background (Unchanged asset)
              LoginVideoBackground(
                controller: widget.videoController,
              ),

              // 2. Interactive Liquid Glass Floating Particle Field (Adapted from Ag1rin/login_glass_app)
              const InteractiveGlassParticleField(),

              // 3. Scrollable Liquid Glass Foreground
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxHeight < 720;
                    final horizontalPadding = constraints.maxWidth < 360
                        ? 16.0
                        : 20.0;

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        isCompact ? 10 : 20,
                        horizontalPadding,
                        isCompact ? 16 : 24,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (constraints.maxHeight - 24).clamp(
                            0.0,
                            double.infinity,
                          ),
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Top Section: Minimal Royal Spend Brand Identity
                                FadeTransition(
                                  opacity: _logoFade,
                                  child: ScaleTransition(
                                    scale: _logoScale,
                                    child: _buildTopBrandHeader(
                                      isCompact: isCompact,
                                    ),
                                  ),
                                ),

                                SizedBox(height: isCompact ? 10 : 16),

                                // Welcome Back & Subtitle
                                FadeTransition(
                                  opacity: _titleFade,
                                  child: SlideTransition(
                                    position: _titleSlide,
                                    child: Column(
                                      children: [
                                        Text(
                                          'Welcome Back',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: LiquidAuthColors.textPrimary,
                                            fontSize: isCompact ? 24 : 27,
                                            height: 1.15,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.5,
                                            shadows: const [
                                              Shadow(
                                                color: Color(0xCC000000),
                                                blurRadius: 18,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          effectiveSubtitle,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: LiquidAuthColors.textSecondary,
                                            fontSize: isCompact ? 12.5 : 13.5,
                                            height: 1.35,
                                            letterSpacing: -0.1,
                                            shadows: const [
                                              Shadow(
                                                color: Color(0x99000000),
                                                blurRadius: 12,
                                                offset: Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                SizedBox(height: isCompact ? 14 : 20),

                                // Compact Floating Liquid Glass Authentication Panel
                                FadeTransition(
                                  opacity: _cardFade,
                                  child: SlideTransition(
                                    position: _cardSlide,
                                    child: LiquidGlassCard(
                                      borderRadius: 26,
                                      blurSigma: 26,
                                      surfaceOpacity: 0.08,
                                      padding: EdgeInsets.fromLTRB(
                                        18,
                                        isCompact ? 14 : 18,
                                        18,
                                        isCompact ? 14 : 18,
                                      ),
                                      child: AnimatedSize(
                                        duration: const Duration(
                                          milliseconds: 280,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        alignment: Alignment.topCenter,
                                        child: AnimatedSwitcher(
                                          duration: const Duration(
                                            milliseconds: 240,
                                          ),
                                          switchInCurve: Curves.easeOutCubic,
                                          switchOutCurve: Curves.easeInCubic,
                                          transitionBuilder:
                                              (child, animation) =>
                                                  FadeTransition(
                                                    opacity: animation,
                                                    child: SlideTransition(
                                                      position: Tween<Offset>(
                                                        begin: const Offset(
                                                          0,
                                                          0.025,
                                                        ),
                                                        end: Offset.zero,
                                                      ).animate(animation),
                                                      child: child,
                                                    ),
                                                  ),
                                          child: _isCreatingAccount
                                              ? _buildCreateAccountForm()
                                              : _buildLoginForm(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                SizedBox(height: isCompact ? 12 : 16),

                                // Privacy & Legal Notice
                                FadeTransition(
                                  opacity: _secondaryFade,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: GestureDetector(
                                      onTap: () => PrivacyLauncher.openPrivacyPolicy(context),
                                      child: const Text(
                                        'By continuing, you agree to our Terms of Service & Privacy Policy.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: LiquidAuthColors.textMuted,
                                          fontSize: 11,
                                          height: 1.45,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black,
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBrandHeader({bool isCompact = false}) {
    final logoSize = isCompact ? 68.0 : 82.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RoyalLogo(
          size: logoSize,
          showGlow: true,
          interactive: true,
          glowColor: const Color(0xFFFFC837),
        ),
        SizedBox(height: isCompact ? 6 : 9),
        Text(
          'ROYAL SPEND',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.95),
            fontSize: isCompact ? 12.5 : 14.0,
            fontWeight: FontWeight.w800,
            letterSpacing: 3.2,
            shadows: const [
              Shadow(
                color: Color(0xCC000000),
                blurRadius: 12,
                offset: Offset(0, 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        key: const ValueKey('login-form'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCardEyebrow('SIGN IN'),
          const SizedBox(height: 14),
          LiquidGlassTextField(
            controller: _loginEmailController,
            focusNode: _loginEmailFocus,
            label: 'Email address',
            hint: 'name@example.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            validator: _validateEmail,
            onFieldSubmitted: (_) => _loginPasswordFocus.requestFocus(),
          ),
          const SizedBox(height: 10),
          LiquidGlassTextField(
            controller: _loginPasswordController,
            focusNode: _loginPasswordFocus,
            label: 'Password',
            hint: 'Enter your password',
            icon: Icons.lock_outline_rounded,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            isPassword: true,
            validator: _validatePassword,
            onFieldSubmitted: (_) => _submitSignIn(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isSubmitting ? null : _showPasswordResetDialog,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 36),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              ),
              child: const Text(
                'Forgot Password?',
                style: TextStyle(
                  color: LiquidAuthColors.softSilver,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(color: Colors.black54, blurRadius: 4),
                  ],
                ),
              ),
            ),
          ),
          if (_statusMessage != null) ...[
            LiquidStatusBanner(
              message: _statusMessage!,
              isError: _statusIsError,
              onDismiss: () => setState(() => _statusMessage = null),
            ),
            const SizedBox(height: 10),
          ],
          LiquidGlassPrimaryButton(
            label: 'Sign In',
            height: 50,
            isLoading: _isSubmitting,
            onPressed: _isSubmitting || _isGoogleLoading || _isNavigating
                ? null
                : _submitSignIn,
          ),
          const SizedBox(height: 12),
          const LiquidGlassDivider(label: 'OR'),
          const SizedBox(height: 12),
          LiquidGlassGoogleButton(
            isLoading: _isGoogleLoading,
            onPressed: _isGoogleLoading || _isSubmitting || _isNavigating
                ? null
                : _handleGoogleSignIn,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isSubmitting ? null : () => _switchMode(true),
            style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
            child: const Text(
              'Don’t have an account? Create one',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(color: Colors.black87, blurRadius: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateAccountForm() {
    return Form(
      key: _createFormKey,
      child: Column(
        key: const ValueKey('create-account-form'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCardEyebrow('CREATE YOUR ACCOUNT'),
          const SizedBox(height: 16),
          LiquidGlassTextField(
            controller: _createNameController,
            focusNode: _createNameFocus,
            label: 'Full name',
            hint: 'Your name',
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter your name.'
                : null,
            onFieldSubmitted: (_) => _createEmailFocus.requestFocus(),
          ),
          const SizedBox(height: 10),
          LiquidGlassTextField(
            controller: _createEmailController,
            focusNode: _createEmailFocus,
            label: 'Email address',
            hint: 'name@example.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            validator: _validateEmail,
            onFieldSubmitted: (_) => _createPasswordFocus.requestFocus(),
          ),
          const SizedBox(height: 10),
          LiquidGlassTextField(
            controller: _createPasswordController,
            focusNode: _createPasswordFocus,
            label: 'Password',
            hint: 'At least 8 characters',
            icon: Icons.lock_outline_rounded,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            isPassword: true,
            validator: _validateNewPassword,
            onFieldSubmitted: (_) => _confirmPasswordFocus.requestFocus(),
          ),
          const SizedBox(height: 10),
          LiquidGlassTextField(
            controller: _confirmPasswordController,
            focusNode: _confirmPasswordFocus,
            label: 'Confirm password',
            hint: 'Re-enter your password',
            icon: Icons.lock_reset_rounded,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            isPassword: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Confirm your password.';
              }
              if (value != _createPasswordController.text) {
                return 'Passwords don’t match.';
              }
              return null;
            },
            onFieldSubmitted: (_) => _submitCreateAccount(),
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 12),
            LiquidStatusBanner(
              message: _statusMessage!,
              isError: _statusIsError,
              onDismiss: () => setState(() => _statusMessage = null),
            ),
          ],
          const SizedBox(height: 16),
          LiquidGlassPrimaryButton(
            label: 'Create Account',
            height: 50,
            isLoading: _isSubmitting,
            onPressed: _isSubmitting || _isNavigating
                ? null
                : _submitCreateAccount,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isSubmitting ? null : () => _switchMode(false),
            style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
            child: const Text(
              'Already have an account? Sign in',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(color: Colors.black87, blurRadius: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardEyebrow(String label) {
    final isCreate = label.contains('CREATE');
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            Container(
              width: 20,
              height: 2,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.4),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: LiquidAuthColors.softSilver,
                fontSize: 11.5,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w700,
                shadows: [
                  Shadow(color: Colors.black, blurRadius: 6),
                ],
              ),
            ),
          ],
        ),
        LiquidPop(
          pressedScale: 0.94,
          onTap: () => _switchMode(!isCreate),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isCreate ? Icons.login_rounded : Icons.person_add_outlined,
                  size: 13,
                  color: Colors.white,
                ),
                const SizedBox(width: 5),
                Text(
                  isCreate ? 'Existing User' : 'New User',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.90),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
