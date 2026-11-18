import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../data/models/trip.dart';
import '../../../providers/expense_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/travel_provider.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/liquid_pop.dart';
import '../../widgets/stat_badge.dart';
import '../../widgets/transaction_detail_modal.dart';
import '../../widgets/transaction_tile.dart';
import '../../widgets/travel/trip_card.dart';
import 'create_plan_wizard_screen.dart';
import 'trip_workspace_screen.dart';

class TravelDashboardScreen extends StatefulWidget {
  const TravelDashboardScreen({super.key});

  @override
  State<TravelDashboardScreen> createState() => _TravelDashboardScreenState();
}

class _TravelDashboardScreenState extends State<TravelDashboardScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openTrip(String tripId) {
    HapticHelper.mediumImpact();
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => TripWorkspaceScreen(tripId: tripId),
      ),
    );
  }

  void _openCreatePlan({
    String? initialTitle,
    String? initialDestination,
    String? initialPreference,
  }) {
    HapticHelper.mediumImpact();
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => CreatePlanWizardScreen(
          initialTitle: initialTitle,
          initialDestination: initialDestination,
          initialPreference: initialPreference,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDark = settings.isDarkMode(context);
    final currency = settings.currencySymbol;
    final travelProvider = context.watch<TravelProvider>();
    final expenseProvider = context.watch<ExpenseProvider>();

    if (travelProvider.isAdmin != settings.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) travelProvider.setAdminStatus(settings.isAdmin);
      });
    }
    final trips = travelProvider.filteredTrips;

    // Travel financial data
    final allTravelExpenses = expenseProvider.allExpenses
        .where((e) => !e.isIncome && e.tripId != null && e.tripId!.isNotEmpty)
        .toList();
    final totalTravelSpent =
        allTravelExpenses.fold(0.0, (sum, e) => sum + e.amount);
    final recentTravelExpenses = allTravelExpenses.take(4).toList();

    // Active or upcoming trip for spotlight
    final activeTrip = trips
            .where((t) => t.isActiveNow || t.status == TripStatus.inProgress)
            .firstOrNull ??
        trips.where((t) => t.status == TripStatus.upcoming).firstOrNull;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientBackground(
        isDark: isDark,
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            cacheExtent: 1200.0,
            slivers: [
              // Header Sliver
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Header: App Brand & Subtitle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Travel Hub',
                                  style: AppTextStyles.titleLarge.copyWith(
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 26,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Explore, schedule, and track trips effortlessly.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatBadge(
                            label: '${trips.length} Plans',
                            icon: CupertinoIcons.airplane,
                            color: isDark
                                ? const Color(0xFF10B981)
                                : const Color(0xFF0D9488),
                            isDark: isDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Travel Overview Stats Card
                      GlassCard(
                        isDark: isDark,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildQuickStatItem(
                              'Travel Spent',
                              CurrencyFormatter.format(totalTravelSpent,
                                  symbol: currency),
                              CupertinoIcons.creditcard,
                              isDark,
                            ),
                            Container(
                              height: 30,
                              width: 0.8,
                              color: isDark
                                  ? const Color(0x22FFFFFF)
                                  : const Color(0x18000000),
                            ),
                            _buildQuickStatItem(
                              'Active / Planned',
                              '${trips.where((t) => t.status != TripStatus.completed).length}',
                              CupertinoIcons.map_pin_ellipse,
                              isDark,
                            ),
                            Container(
                              height: 30,
                              width: 0.8,
                              color: isDark
                                  ? const Color(0x22FFFFFF)
                                  : const Color(0x18000000),
                            ),
                            _buildQuickStatItem(
                              'Completed',
                              '${trips.where((t) => t.status == TripStatus.completed).length}',
                              CupertinoIcons.checkmark_seal_fill,
                              isDark,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Active Trip Spotlight Card (if present)
                      if (activeTrip != null) ...[
                        _buildActiveTripSpotlightCard(
                            context, activeTrip, isDark, currency),
                      ],

                      // Prominent "+ Create New Plan" Banner Button
                      LiquidPop(
                        onTap: _openCreatePlan,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 14),
                          decoration: BoxDecoration(
                            gradient: AppColors.royalGradient,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.royalIndigo
                                    .withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.add_circled_solid,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                '+ Plan New Adventure',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Search Bar
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurface
                              : Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? const Color(0x1AFFFFFF)
                                : const Color(0x1A000000),
                            width: 0.6,
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => travelProvider.setSearchQuery(v),
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search trips by title or destination...',
                            hintStyle: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                            prefixIcon: Icon(
                              CupertinoIcons.search,
                              size: 16,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                      travelProvider.setSearchQuery('');
                                    },
                                    child: const Icon(
                                      CupertinoIcons.clear_circled_solid,
                                      size: 16,
                                    ),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Status Filter Tabs
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _FilterPill(
                              label: 'All Plans',
                              isSelected: travelProvider.statusFilter == null,
                              isDark: isDark,
                              onTap: () {
                                HapticHelper.selectionClick();
                                travelProvider.setStatusFilter(null);
                              },
                            ),
                            ...TripStatus.values.map((status) {
                              return _FilterPill(
                                label: status.displayName,
                                isSelected:
                                    travelProvider.statusFilter == status,
                                isDark: isDark,
                                onTap: () {
                                  HapticHelper.selectionClick();
                                  travelProvider.setStatusFilter(status);
                                },
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Section Header: Planned Journeys
              if (trips.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22.0, 10.0, 22.0, 6.0),
                    child: Text(
                      'PLANNED JOURNEYS (${trips.length})',
                      style: AppTextStyles.labelUppercase.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                        fontSize: 11,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),

              // Trips List or Empty State
              if (trips.isEmpty)
                SliverToBoxAdapter(
                  child: _AnimatedEmptyTravelCard(
                    isDark: isDark,
                    onCreatePlan: _openCreatePlan,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final trip = trips[index];
                        return TripCard(
                          trip: trip,
                          isDark: isDark,
                          onTap: () => _openTrip(trip.id),
                          onEdit: () {
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (_) =>
                                    CreatePlanWizardScreen(tripToEdit: trip),
                              ),
                            );
                          },
                          onDuplicate: () async {
                            await travelProvider.duplicateTrip(trip.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Trip duplicated as independent plan'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          onArchive: () {
                            travelProvider.toggleTripArchive(trip.id);
                          },
                          onDelete: () {
                            _confirmDeleteTrip(context, trip, travelProvider);
                          },
                        );
                      },
                      childCount: trips.length,
                    ),
                  ),
                ),

              // Recent Travel Expenses Section
              if (recentTravelExpenses.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22.0, 24.0, 22.0, 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'RECENT TRAVEL EXPENSES (${allTravelExpenses.length})',
                          style: AppTextStyles.labelUppercase.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                            fontSize: 11,
                            letterSpacing: 0.6,
                          ),
                        ),
                        Text(
                          'By Date',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final expense = recentTravelExpenses[index];
                        return TransactionTile(
                          expense: expense,
                          currencySymbol: currency,
                          isDark: isDark,
                          onTap: () =>
                              TransactionDetailModal.show(context, expense),
                        );
                      },
                      childCount: recentTravelExpenses.length,
                    ),
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStatItem(
      String label, String value, IconData icon, bool isDark) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            size: 15,
            color: isDark ? const Color(0xFF10B981) : const Color(0xFF0D9488),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTripSpotlightCard(
    BuildContext context,
    Trip trip,
    bool isDark,
    String currency,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: LiquidPop(
        pressedScale: 0.98,
        onTap: () => _openTrip(trip.id),
        child: GlassCard(
          isDark: isDark,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.appleGreen,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        trip.isActiveNow ? 'ACTIVE EXPEDITION' : 'NEXT ADVENTURE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: isDark
                              ? const Color(0xFF10B981)
                              : const Color(0xFF0D9488),
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 14,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                trip.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    CupertinoIcons.location_solid,
                    size: 13,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      trip.destination,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('•',
                      style: TextStyle(
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted)),
                  const SizedBox(width: 8),
                  Text(
                    '${DateFormatter.formatMedium(trip.startDate)} - ${DateFormatter.formatMedium(trip.endDate)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Budget: ${CurrencyFormatter.format(trip.budget, symbol: currency)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isDark
                              ? AppColors.appleBlue
                              : AppColors.royalIndigo)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Open Workspace →',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.appleBlue
                            : AppColors.royalIndigo,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteTrip(
      BuildContext context, Trip trip, TravelProvider provider) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Delete "${trip.title}"?'),
        content: const Text(
            'This action permanently deletes this travel plan and its day-by-day itinerary. Financial expense records will remain safe.'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.deleteTrip(trip.id);
            },
            child: const Text('Delete Plan'),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: LiquidPop(
        pressedScale: 0.94,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
                : (isDark
                    ? AppColors.darkSurface
                    : Colors.black.withValues(alpha: 0.04)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : (isDark
                      ? const Color(0x1AFFFFFF)
                      : const Color(0x1A000000)),
              width: 0.6,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : (isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

/// Clean, simple animated empty state card for Travel Hub.
class _AnimatedEmptyTravelCard extends StatefulWidget {
  final bool isDark;
  final VoidCallback onCreatePlan;

  const _AnimatedEmptyTravelCard({
    required this.isDark,
    required this.onCreatePlan,
  });

  @override
  State<_AnimatedEmptyTravelCard> createState() =>
      _AnimatedEmptyTravelCardState();
}

class _AnimatedEmptyTravelCardState extends State<_AnimatedEmptyTravelCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _floatAnim;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _tiltAnim;

  bool get _isTestEnvironment =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    );

    _floatAnim = Tween<double>(begin: -7.0, end: 7.0).animate(curved);
    _pulseAnim = Tween<double>(begin: 0.88, end: 1.12).animate(curved);
    _tiltAnim = Tween<double>(begin: -0.05, end: 0.05).animate(curved);

    if (!_isTestEnvironment &&
        !WidgetsBinding
            .instance.platformDispatcher.accessibilityFeatures.reduceMotion) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 26.0),
        child: GlassCard(
          isDark: isDark,
          borderRadius: 26,
          borderColor: isDark
              ? AppColors.royalGold.withValues(alpha: 0.22)
              : AppColors.royalIndigo.withValues(alpha: 0.18),
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated Floating & Pulsing Travel Emblem
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulsing Ambient Glow Aura
                      Transform.scale(
                        scale: _pulseAnim.value,
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.royalIndigo.withValues(
                                    alpha: isDark ? 0.38 : 0.22),
                                AppColors.royalGold.withValues(
                                    alpha: isDark ? 0.20 : 0.12),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.65, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // Floating & Tilting Emblem Squircle
                      Transform.translate(
                        offset: Offset(0, _floatAnim.value),
                        child: Transform.rotate(
                          angle: _tiltAnim.value,
                          child: Container(
                            width: 78,
                            height: 78,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: LinearGradient(
                                colors: isDark
                                    ? [
                                        const Color(0xFF1E1E2E),
                                        const Color(0xFF101018),
                                      ]
                                    : [
                                        Colors.white,
                                        const Color(0xFFF1F5F9),
                                      ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.royalGold
                                        .withValues(alpha: 0.45)
                                    : AppColors.royalIndigo
                                        .withValues(alpha: 0.25),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.royalIndigo.withValues(
                                      alpha: isDark ? 0.30 : 0.18),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: ShaderMask(
                                shaderCallback: (bounds) => AppColors
                                    .luxuryGoldGradient
                                    .createShader(bounds),
                                blendMode: BlendMode.srcIn,
                                child: const Icon(
                                  CupertinoIcons.paperplane_fill,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // Simple & Inspiring Title
              Text(
                'Create Your First Plan',
                textAlign: TextAlign.center,
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  letterSpacing: -0.4,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),

              const SizedBox(height: 10),

              // Simple Subtitle
              Text(
                'Plan itineraries, set trip budgets, and organize your expenses effortlessly in one place.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),

              const SizedBox(height: 28),

              // Sleek CTA Action Button
              LiquidPop(
                onTap: widget.onCreatePlan,
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF6366F1),
                        Color(0xFF4F46E5),
                        Color(0xFF38BDF8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.royalIndigo.withValues(alpha: 0.38),
                        blurRadius: 16,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.add_circled_solid,
                        size: 19,
                        color: Colors.white,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '+ Create Your First Plan',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        CupertinoIcons.arrow_right,
                        size: 15,
                        color: Colors.white70,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Reassurance & Privacy Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.shield_fill,
                    size: 12,
                    color: AppColors.vividMint.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Offline-First • 100% Private On Device',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
