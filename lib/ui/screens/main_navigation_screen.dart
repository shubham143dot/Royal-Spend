import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/spring_curves.dart';
import '../../core/utils/haptic_helper.dart';
import '../../providers/settings_provider.dart';
import '../widgets/ambient_background.dart';
import '../widgets/glass_nav_bar.dart';
import '../widgets/liquid_pop.dart';
import '../widgets/travel/liquid_add_travel_expense_fab.dart';
import 'add_edit_expense_sheet.dart';
import 'analytics_screen.dart';
import 'dashboard_screen.dart';
import 'profile_settings_screen.dart';
import 'transactions_screen.dart';
import 'travel/travel_dashboard_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  void _onTabSelected(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDark = settings.isDarkMode(context);

    final screens = [
      DashboardScreen(
        key: const PageStorageKey('dashboard_screen'),
        onNavigateToHistory: () => _onTabSelected(1),
      ),
      const TransactionsScreen(
        key: PageStorageKey('transactions_screen'),
      ),
      const TravelDashboardScreen(
        key: PageStorageKey('travel_dashboard_screen'),
      ),
      const AnalyticsScreen(
        key: PageStorageKey('analytics_screen'),
      ),
      const ProfileSettingsScreen(
        key: PageStorageKey('profile_settings_screen'),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: AmbientBackground(
        isDark: isDark,
        child: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
      ),
      floatingActionButton: _currentIndex == 0
          ? _LiquidAddExpenseFab(isDark: isDark)
          : (_currentIndex == 2
              ? LiquidAddTravelExpenseFab(isDark: isDark)
              : null),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: GlassFloatingNavBar(
        currentIndex: _currentIndex,
        isDark: isDark,
        onTabSelected: _onTabSelected,
      ),
    );
  }
}

class _LiquidAddExpenseFab extends StatefulWidget {
  final bool isDark;
  const _LiquidAddExpenseFab({required this.isDark});

  @override
  State<_LiquidAddExpenseFab> createState() => _LiquidAddExpenseFabState();
}

class _LiquidAddExpenseFabState extends State<_LiquidAddExpenseFab>
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
    await AddEditExpenseSheet.show(context);
    if (mounted) {
      _animController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final jellyColor = widget.isDark ? AppColors.appleBlue : const Color(0xFFA855F7);
    final bool highContrast = MediaQuery.of(context).highContrast;

    return Padding(
      padding: const EdgeInsets.only(bottom: 82),
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
                    color: jellyColor.withValues(alpha: widget.isDark ? 0.45 : 0.30),
                    blurRadius: 20,
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
              child: Center(
                child: RepaintBoundary(
                  child: RotationTransition(
                    turns: _rotationAnim,
                    child: Icon(
                      CupertinoIcons.add,
                      size: 28,
                      color: jellyColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
