import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth/firebase_auth_gateway.dart';
import '../../../core/services/auth/royal_auth_gateway.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../../core/theme/spring_curves.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../providers/settings_provider.dart';
import '../../widgets/google_brand_icon.dart';
import '../../widgets/liquid_pop.dart';
import '../../widgets/login_video_background.dart';
import '../../widgets/royal_glass_components.dart';
import '../../widgets/royal_logo.dart';
import '../main_navigation_screen.dart';

/// Ultra-Premium iOS Liquid Glassmorphism Login & Registration Experience.
///
/// Features:
/// - Continuous background video playback with hardware-accelerated decoding.
/// - Calibrated translucent glass panels letting the background video shine through.
/// - Authentic Apple-style specular gradient rim and top bevel highlight reflection.
/// - Inset frosted glass auth fields with smooth animated gold focus bloom.
/// - Liquid iOS physics-based spring button press feedback and tactile haptics.
/// - Multi-tier floating ambient drop shadows with royal gold refraction aura.
/// - Automatic lifecycle management (battery saving background pause/resume).
/// - Comprehensive accessibility: full support for Reduce Motion and High Contrast.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.authGateway,
    this.videoController,
  });

  /// Optional provider boundary for production auth or widget tests.
  final RoyalAuthGateway? authGateway;

  /// Optional video controller for widget testing or custom video injection.
  final VideoPlayerController? videoController;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _gold = Color(0xFFD4AF37);
  static const _champagne = Color(0xFFF3D98B);

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
  bool _showLoginPassword = false;
  bool _showCreatePassword = false;
  bool _showConfirmPassword = false;
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
      duration: const Duration(milliseconds: 720),
      animationBehavior: AnimationBehavior.normal,
    );

    _logoFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
    );

    _logoScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.50, curve: IOSSpringCurve.gentle),
      ),
    );

    _titleFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.12, 0.55, curve: Curves.easeOutCubic),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.12, 0.55, curve: Curves.easeOutCubic),
      ),
    );

    _cardFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.22, 0.80, curve: Curves.easeOutCubic),
    );

    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.22, 0.80, curve: IOSSpringCurve.gentle),
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
    final reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .reduceMotion;
    if (reduceMotion) {
      _entranceController.value = 1.0;
    } else if (_entranceController.value == 0 &&
        !_entranceController.isAnimating) {
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
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: AlertDialog(
          backgroundColor: const Color(0xE810131E),
          surfaceTintColor: Colors.transparent,
          icon: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _gold.withValues(alpha: 0.14),
              border: Border.all(color: _gold.withValues(alpha: 0.65)),
              boxShadow: [
                BoxShadow(
                  color: _gold.withValues(alpha: 0.25),
                  blurRadius: 16,
                ),
              ],
            ),
            child: const Icon(
              Icons.cloud_sync_rounded,
              color: _champagne,
              size: 26,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: _gold.withValues(alpha: 0.45)),
          ),
          title: const Text(
            'Google sign-in isn’t connected',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'This build has no authentication provider configured. You can still explore the app with its demo workspace.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: Colors.white70,
              ),
              child: const Text('Cancel'),
            ),
            SizedBox(
              width: 132,
              child: _RoyalGoldButton(
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
    final resetFormKey = GlobalKey<FormState>();
    final resetEmailController = TextEditingController(
      text: _loginEmailController.text,
    );
    final resetEmailFocus = FocusNode();
    bool loading = false;
    String? dialogMessage;
    bool dialogError = true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: AlertDialog(
            backgroundColor: const Color(0xE810131E),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
              side: BorderSide(color: _gold.withValues(alpha: 0.45)),
            ),
            title: const Text(
              'Reset your password',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Form(
              key: resetFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter the email address for your account.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _PremiumAuthField(
                    controller: resetEmailController,
                    focusNode: resetEmailFocus,
                    label: 'Email address',
                    hint: 'name@example.com',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    validator: _validateEmail,
                    onFieldSubmitted: (_) => _sendPasswordReset(
                      dialogContext,
                      resetFormKey,
                      resetEmailController,
                      setDialogState,
                      () => loading,
                      (value) => loading = value,
                      (message, isError) {
                        dialogMessage = message;
                        dialogError = isError;
                      },
                    ),
                  ),
                  if (dialogMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      dialogMessage!,
                      style: TextStyle(
                        color: dialogError
                            ? const Color(0xFFFF9292)
                            : const Color(0xFFA4E3BE),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: loading
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                child: const Text('Cancel'),
              ),
              _DialogActionButton(
                label: loading ? 'Sending…' : 'Send reset link',
                isLoading: loading,
                onPressed: loading
                    ? null
                    : () => _sendPasswordReset(
                        dialogContext,
                        resetFormKey,
                        resetEmailController,
                        setDialogState,
                        () => loading,
                        (value) => loading = value,
                        (message, isError) {
                          dialogMessage = message;
                          dialogError = isError;
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
    resetEmailController.dispose();
    resetEmailFocus.dispose();
  }

  Future<void> _sendPasswordReset(
    BuildContext dialogContext,
    GlobalKey<FormState> formKey,
    TextEditingController emailController,
    StateSetter setDialogState,
    bool Function() isLoading,
    void Function(bool value) setLoading,
    void Function(String message, bool isError) setMessage,
  ) async {
    if (isLoading() || !(formKey.currentState?.validate() ?? false)) return;
    setDialogState(() {
      setLoading(true);
      setMessage('', true);
    });
    try {
      await _authGateway.sendPasswordReset(email: emailController.text.trim());
      if (!dialogContext.mounted) return;
      Navigator.of(dialogContext).pop();
      _setStatus('Password reset instructions were sent.', isError: false);
    } on AuthProviderNotConfigured {
      if (!dialogContext.mounted) return;
      setDialogState(() {
        setLoading(false);
        setMessage(
          'Password reset is unavailable until sign-in is connected.',
          true,
        );
      });
    } catch (e) {
      if (!dialogContext.mounted) return;
      final raw = e.toString().replaceAll('Exception: ', '').trim();
      setDialogState(() {
        setLoading(false);
        setMessage(
          raw.isNotEmpty ? raw : 'We couldn’t send a reset link. Please try again.',
          true,
        );
      });
    }
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
    await settings.setHasCompletedIntro(true);
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
              // 1. High-Performance Looping Video Background with Calibrated Scrim
              LoginVideoBackground(
                controller: widget.videoController,
              ),

              // 2. Interactive Scrollable Foreground Content
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final horizontalPadding = constraints.maxWidth < 360
                        ? 16.0
                        : 24.0;
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        16,
                        horizontalPadding,
                        24,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (constraints.maxHeight - 40).clamp(
                            0.0,
                            double.infinity,
                          ),
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 8),

                                // Luxury Branding Header with Staggered Entrance
                                FadeTransition(
                                  opacity: _logoFade,
                                  child: ScaleTransition(
                                    scale: _logoScale,
                                    child: const Center(
                                      child: RoyalLogo(
                                        size: 68,
                                        showGlow: true,
                                        interactive: true,
                                      ),
                                    ),
                                  ),
                                ),

                                FadeTransition(
                                  opacity: _titleFade,
                                  child: SlideTransition(
                                    position: _titleSlide,
                                    child: Column(
                                      children: [
                                        const SizedBox(height: 14),

                                        // Heading
                                        const Text(
                                          'Welcome Back',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 29,
                                            height: 1.15,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.6,
                                            shadows: [
                                              Shadow(
                                                color: Color(0xCC000000),
                                                blurRadius: 18,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),

                                        // Subtitle
                                        Text(
                                          'Your finances, beautifully organized.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.88,
                                            ),
                                            fontSize: 14.5,
                                            height: 1.4,
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
                                const SizedBox(height: 22),

                                // iOS Translucent Frosted Glass Auth Card
                                FadeTransition(
                                  opacity: _cardFade,
                                  child: SlideTransition(
                                    position: _cardSlide,
                                    child: _GlassAuthCard(
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
                                const SizedBox(height: 16),

                                // Skip for now action
                                if (!_isCreatingAccount &&
                                    AppConstants.enableDevAuthBypass)
                                  _buildDemoAction(),

                                const SizedBox(height: 16),

                                // Privacy & Legal Notice with High Contrast Protection
                                FadeTransition(
                                  opacity: _secondaryFade,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text(
                                      'By continuing, you agree to our Terms of Service & Privacy Policy.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.65,
                                        ),
                                        fontSize: 11.5,
                                        height: 1.45,
                                        shadows: const [
                                          Shadow(
                                            color: Colors.black,
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
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

  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        key: const ValueKey('login-form'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCardEyebrow('SIGN IN'),
          const SizedBox(height: 20),
          _PremiumAuthField(
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
          const SizedBox(height: 14),
          _PremiumAuthField(
            controller: _loginPasswordController,
            focusNode: _loginPasswordFocus,
            label: 'Password',
            hint: 'Enter your password',
            icon: Icons.lock_outline_rounded,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            obscureText: !_showLoginPassword,
            suffix: _PasswordVisibilityButton(
              isVisible: _showLoginPassword,
              onPressed: () =>
                  setState(() => _showLoginPassword = !_showLoginPassword),
            ),
            validator: _validatePassword,
            onFieldSubmitted: (_) => _submitSignIn(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isSubmitting ? null : _showPasswordResetDialog,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              child: const Text(
                'Forgot Password?',
                style: TextStyle(
                  color: _champagne,
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
            _StatusMessage(message: _statusMessage!, isError: _statusIsError),
            const SizedBox(height: 12),
          ],
          _RoyalGoldButton(
            label: 'Sign In',
            isLoading: _isSubmitting,
            onPressed: _isSubmitting || _isGoogleLoading || _isNavigating
                ? null
                : _submitSignIn,
          ),
          const SizedBox(height: 18),
          const _OrDivider(),
          const SizedBox(height: 16),
          _GoogleSignInButton(
            isLoading: _isGoogleLoading,
            onPressed: _isGoogleLoading || _isSubmitting || _isNavigating
                ? null
                : _handleGoogleSignIn,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _isSubmitting ? null : () => _switchMode(true),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
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
          const SizedBox(height: 20),
          _PremiumAuthField(
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
          const SizedBox(height: 12),
          _PremiumAuthField(
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
          const SizedBox(height: 12),
          _PremiumAuthField(
            controller: _createPasswordController,
            focusNode: _createPasswordFocus,
            label: 'Password',
            hint: 'At least 8 characters',
            icon: Icons.lock_outline_rounded,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            obscureText: !_showCreatePassword,
            suffix: _PasswordVisibilityButton(
              isVisible: _showCreatePassword,
              onPressed: () =>
                  setState(() => _showCreatePassword = !_showCreatePassword),
            ),
            validator: _validateNewPassword,
            onFieldSubmitted: (_) => _confirmPasswordFocus.requestFocus(),
          ),
          const SizedBox(height: 12),
          _PremiumAuthField(
            controller: _confirmPasswordController,
            focusNode: _confirmPasswordFocus,
            label: 'Confirm password',
            hint: 'Re-enter your password',
            icon: Icons.lock_reset_rounded,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            obscureText: !_showConfirmPassword,
            suffix: _PasswordVisibilityButton(
              isVisible: _showConfirmPassword,
              onPressed: () =>
                  setState(() => _showConfirmPassword = !_showConfirmPassword),
            ),
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
            const SizedBox(height: 14),
            _StatusMessage(message: _statusMessage!, isError: _statusIsError),
          ],
          const SizedBox(height: 18),
          _RoyalGoldButton(
            label: 'Create Account',
            isLoading: _isSubmitting,
            onPressed: _isSubmitting || _isNavigating
                ? null
                : _submitCreateAccount,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isSubmitting ? null : () => _switchMode(false),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
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
              width: 24,
              height: 2,
              decoration: BoxDecoration(
                color: _gold,
                borderRadius: BorderRadius.circular(1),
                boxShadow: [
                  BoxShadow(
                    color: _gold.withValues(alpha: 0.6),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: _champagne,
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
                color: _gold.withValues(alpha: 0.45),
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
                  color: _champagne,
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

  Widget _buildDemoAction() => FadeTransition(
    opacity: _secondaryFade,
    child: TextButton.icon(
      onPressed: _isNavigating || _isSubmitting ? null : _handleSkipBypass,
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: Colors.white.withValues(alpha: 0.90),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.22),
            width: 0.8,
          ),
        ),
      ),
      icon: const Icon(
        Icons.arrow_forward_rounded,
        size: 16,
        color: _champagne,
      ),
      label: const Text(
        'Skip for now',
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.1,
          shadows: [
            Shadow(color: Colors.black, blurRadius: 8),
          ],
        ),
      ),
    ),
  );
}

/// Ultra-refined iOS Frosted Glass container powered by [RoyalGlassPanel].
class _GlassAuthCard extends StatelessWidget {
  const _GlassAuthCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RoyalGlassPanel(
      borderRadius: 28,
      blurSigma: 34,
      surfaceOpacity: 0.10,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      customAccentColor: const Color(0xFFD4AF37),
      child: child,
    );
  }
}

/// Translucent, frosted input field with animated gold focus bloom and hairline rim.
class _PremiumAuthField extends StatelessWidget {
  const _PremiumAuthField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.icon,
    required this.textInputAction,
    required this.validator,
    this.keyboardType,
    this.autofillHints,
    this.obscureText = false,
    this.suffix,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final Widget? suffix;
  final String? Function(String?) validator;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, child) {
        final hasFocus = focusNode.hasFocus;
        return RoyalGlassInputWell(
          hasFocus: hasFocus,
          hasError: false,
          borderRadius: 16,
          accentColor: const Color(0xFFD4AF37),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            autofillHints: autofillHints,
            obscureText: obscureText,
            autocorrect: !obscureText,
            enableSuggestions: !obscureText,
            textCapitalization: TextCapitalization.none,
            validator: validator,
            onFieldSubmitted: onFieldSubmitted,
            cursorColor: const Color(0xFFF3D98B),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15.5,
              height: 1.3,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 14,
              ),
              labelStyle: TextStyle(
                color: hasFocus
                    ? const Color(0xFFF3D98B)
                    : Colors.white.withValues(alpha: 0.72),
                fontSize: 14,
              ),
              floatingLabelStyle: const TextStyle(
                color: Color(0xFFF3D98B),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              prefixIcon: Icon(
                icon,
                size: 20,
                color: hasFocus
                    ? const Color(0xFFF3D98B)
                    : const Color(0xFFD4AF37).withValues(alpha: 0.85),
              ),
              suffixIcon: suffix,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              errorStyle: const TextStyle(
                color: Color(0xFFFF8E8E),
                height: 1.3,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PasswordVisibilityButton extends StatelessWidget {
  const _PasswordVisibilityButton({
    required this.isVisible,
    required this.onPressed,
  });

  final bool isVisible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: isVisible ? 'Hide password' : 'Show password',
    onPressed: onPressed,
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    icon: Icon(
      isVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      color: Colors.white.withValues(alpha: 0.75),
      size: 20,
    ),
  );
}

/// Royal Brushed Gold Button with iOS Spring Pop Tactile Feedback.
class _RoyalGoldButton extends StatelessWidget {
  const _RoyalGoldButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.height = 54,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    return LiquidPop(
      pressedScale: 0.96,
      onTap: enabled ? onPressed : null,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: enabled
                  ? const [
                      Color(0xFFFCE9B6),
                      Color(0xFFE5C158),
                      Color(0xFFB88A22),
                    ]
                  : const [Color(0xFF76663D), Color(0xFF62552F)],
            ),
            border: Border.all(
              color: enabled ? const Color(0xCCFFF6DC) : const Color(0x40FFFFFF),
              width: 1.0,
            ),
            boxShadow: enabled
                ? const [
                    BoxShadow(
                      color: Color(0x4DD4AF37),
                      blurRadius: 22,
                      offset: Offset(0, 8),
                      spreadRadius: -2,
                    ),
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              // Subtle specular top line highlight
              if (enabled)
                Positioned(
                  top: 1,
                  left: 16,
                  right: 16,
                  height: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.65),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              Center(
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Color(0xFF141005),
                        ),
                      )
                    : Text(
                        label,
                        style: const TextStyle(
                          color: Color(0xFF141005),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.25,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Google Sign-In with frosted glass aesthetic and spring bounce.
class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final highContrast = MediaQuery.highContrastOf(context);

    return LiquidPop(
      pressedScale: 0.96,
      onTap: enabled ? onPressed : null,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: 'Continue with Google',
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: highContrast
                  ? const [Color(0xFF1A1D27), Color(0xFF131620)]
                  : [
                      Colors.white.withValues(alpha: 0.15),
                      const Color(0xFF141926).withValues(alpha: 0.35),
                    ],
            ),
            border: Border.all(
              color: highContrast
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.30),
              width: highContrast ? 1.4 : 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Specular top highlight line
              if (!highContrast)
                Positioned(
                  top: 1,
                  left: 20,
                  right: 20,
                  height: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.40),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              Center(
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GoogleBrandIcon(size: 20),
                          SizedBox(width: 12),
                          Text(
                            'Continue with Google',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.1,
                              shadows: [
                                Shadow(
                                  color: Color(0x99000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.22),
              ],
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          'OR',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.52),
            fontSize: 10.5,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      Expanded(
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.22),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 320),
      curve: IOSSpringCurve.gentle,
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * -6),
            child: child,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isError
              ? const Color(0xFFE53935).withValues(alpha: 0.16)
              : const Color(0xFF2E7D32).withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isError
                ? const Color(0xFFEF5350).withValues(alpha: 0.60)
                : const Color(0xFF66BB6A).withValues(alpha: 0.60),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: (isError
                      ? const Color(0xFFEF5350)
                      : const Color(0xFF66BB6A))
                  .withValues(alpha: 0.20),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              size: 19,
              color: isError
                  ? const Color(0xFFFF8E8E)
                  : const Color(0xFFA4E3BE),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: isError
                      ? const Color(0xFFFFCDCD)
                      : const Color(0xFFD4F7E2),
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DialogActionButton extends StatelessWidget {
  const _DialogActionButton({
    required this.label,
    required this.onPressed,
    required this.isLoading,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(foregroundColor: const Color(0xFFF3D98B)),
    child: isLoading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label),
  );
}
