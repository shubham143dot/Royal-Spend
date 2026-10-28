import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/travel/darjeeling_sample_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../data/models/trip.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/travel_provider.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/glass_button.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/glass_text_field.dart';
import '../../widgets/liquid_pop.dart';
import 'trip_workspace_screen.dart';

class CreatePlanWizardScreen extends StatefulWidget {
  final Trip? tripToEdit;

  const CreatePlanWizardScreen({super.key, this.tripToEdit});

  @override
  State<CreatePlanWizardScreen> createState() => _CreatePlanWizardScreenState();
}

class _CreatePlanWizardScreenState extends State<CreatePlanWizardScreen> {
  int _currentStep = 0; // 0: Details, 1: Preferences, 2: Budget & Transport, 3: How to Plan

  // Form Controllers
  late TextEditingController _titleController;
  late TextEditingController _destinationController;
  late TextEditingController _departureController;
  late TextEditingController _descriptionController;
  late TextEditingController _travelersController;

  late TextEditingController _budgetController;
  late TextEditingController _transportBudgetController;
  late TextEditingController _stayBudgetController;
  late TextEditingController _foodBudgetController;

  late DateTime _startDate;
  late DateTime _endDate;
  final Set<String> _selectedPreferences = {};

  final List<String> _availablePreferences = [
    'Mountains',
    'Nature',
    'Adventure',
    'Scenic viewpoints',
    'Food',
    'Shopping',
    'Cultural sites',
    'Historical destinations',
    'Relaxation',
    'Family activities',
  ];

  @override
  void initState() {
    super.initState();
    final t = widget.tripToEdit;

    _titleController = TextEditingController(text: t?.title ?? 'Darjeeling Trip');
    _destinationController = TextEditingController(
        text: t?.destination ?? 'Darjeeling, West Bengal, India');
    _departureController =
        TextEditingController(text: t?.departureCity ?? 'Hijli');
    _descriptionController =
        TextEditingController(text: t?.description ?? '');
    _travelersController = TextEditingController(
        text: t != null ? t.travelersCount.toString() : '1');

    _budgetController = TextEditingController(
        text: t != null && t.budget > 0 ? t.budget.toStringAsFixed(0) : '25000');
    _transportBudgetController = TextEditingController(
        text: t != null && t.transportBudget > 0
            ? t.transportBudget.toStringAsFixed(0)
            : '6000');
    _stayBudgetController = TextEditingController(
        text: t != null && t.accommodationBudget > 0
            ? t.accommodationBudget.toStringAsFixed(0)
            : '9000');
    _foodBudgetController = TextEditingController(
        text: t != null && t.foodBudget > 0
            ? t.foodBudget.toStringAsFixed(0)
            : '5000');

    // Default dates from prompt: 10 to 18 December 2026 or tripToEdit dates
    _startDate = t?.startDate ?? DateTime(2026, 12, 10);
    _endDate = t?.endDate ?? DateTime(2026, 12, 18);

    if (t != null) {
      _selectedPreferences.addAll(t.preferences);
    } else {
      _selectedPreferences.addAll(['Mountains', 'Nature', 'Scenic viewpoints']);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _destinationController.dispose();
    _departureController.dispose();
    _descriptionController.dispose();
    _travelersController.dispose();
    _budgetController.dispose();
    _transportBudgetController.dispose();
    _stayBudgetController.dispose();
    _foodBudgetController.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange(BuildContext context) async {
    HapticHelper.selectionClick();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.royalIndigo,
              brightness: Theme.of(context).brightness,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _commitTripCreation({required String planMethod}) async {
    HapticHelper.success();
    final travelProvider = context.read<TravelProvider>();
    const uuid = Uuid();
    final tripId = widget.tripToEdit?.id ?? uuid.v4();

    final travelersCount = int.tryParse(_travelersController.text.trim()) ?? 1;
    final totalBudget = double.tryParse(_budgetController.text.trim()) ?? 0.0;
    final transBudget =
        double.tryParse(_transportBudgetController.text.trim()) ?? 0.0;
    final stayBudget =
        double.tryParse(_stayBudgetController.text.trim()) ?? 0.0;
    final foodBudget =
        double.tryParse(_foodBudgetController.text.trim()) ?? 0.0;

    final trip = Trip(
      id: tripId,
      title: _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : 'My Trip to ${_destinationController.text.trim()}',
      destination: _destinationController.text.trim().isNotEmpty
          ? _destinationController.text.trim()
          : 'Darjeeling, India',
      departureCity: _departureController.text.trim().isNotEmpty
          ? _departureController.text.trim()
          : null,
      startDate: _startDate,
      endDate: _endDate,
      travelersCount: travelersCount,
      budget: totalBudget,
      transportBudget: transBudget,
      accommodationBudget: stayBudget,
      foodBudget: foodBudget,
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      preferences: _selectedPreferences.toList(),
      status: TripStatus.upcoming,
    );

    if (widget.tripToEdit != null) {
      await travelProvider.updateTrip(trip);
      if (mounted) Navigator.pop(context);
      return;
    }

    if (planMethod == 'template') {
      // Build Darjeeling sample package
      final package = DarjeelingSampleData.buildPackage(customTripId: tripId);
      await travelProvider.createTrip(
        trip,
        days: package.days,
        activities: package.activities,
        savedPlaces: package.savedPlaces,
        transports: package.transports,
        accommodations: package.accommodations,
        checklists: package.checklist,
      );
    } else {
      // Build empty manual days
      await travelProvider.createTrip(trip);
    }

    if (!mounted) return;

    // Navigate to workspace for newly created trip
    await travelProvider.selectTrip(trip.id);
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      CupertinoPageRoute(
        builder: (_) => TripWorkspaceScreen(tripId: trip.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDark = settings.isDarkMode(context);
    final dateFormat = DateFormat('d MMM yyyy');
    final calendarDays = _endDate.difference(_startDate).inDays + 1;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientBackground(
        isDark: isDark,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    LiquidPop(
                      onTap: () {
                        HapticHelper.selectionClick();
                        if (_currentStep > 0) {
                          setState(() => _currentStep--);
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurface
                              : Colors.white.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.back, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.tripToEdit == null
                                ? 'Create New Plan'
                                : 'Edit Trip Details',
                            style: AppTextStyles.titleMedium.copyWith(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            'Step ${_currentStep + 1} of 4: ${_getStepTitle(_currentStep)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Step Progress Indicator
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Row(
                  children: List.generate(4, (index) {
                    final isCompleted = index <= _currentStep;
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(right: index < 3 ? 6.0 : 0.0),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? (isDark
                                  ? AppColors.appleBlue
                                  : AppColors.royalIndigo)
                              : (isDark
                                  ? AppColors.darkSurface
                                  : Colors.black.withValues(alpha: 0.08)),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // Wizard Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20.0),
                  child: _buildStepContent(isDark, dateFormat, calendarDays),
                ),
              ),

              // Bottom Navigation Buttons
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    if (_currentStep > 0) ...[
                      Expanded(
                        child: GlassButton(
                          label: 'Back',
                          isDark: isDark,
                          onPressed: () {
                            HapticHelper.selectionClick();
                            setState(() => _currentStep--);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: 2,
                      child: GlassButton(
                        label: _currentStep == 3
                            ? 'Plan Manually'
                            : 'Continue',
                        icon: _currentStep == 3
                            ? CupertinoIcons.check_mark
                            : CupertinoIcons.arrow_right,
                        isDark: isDark,
                        onPressed: () {
                          if (_currentStep < 3) {
                            HapticHelper.selectionClick();
                            setState(() => _currentStep++);
                          } else {
                            _commitTripCreation(planMethod: 'manual');
                          }
                        },
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

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Trip Details';
      case 1:
        return 'Travel Preferences';
      case 2:
        return 'Budget & Information';
      case 3:
        return 'Choose How to Plan';
      default:
        return '';
    }
  }

  Widget _buildStepContent(bool isDark, DateFormat dateFormat, int calendarDays) {
    switch (_currentStep) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Where are you going?',
              style: AppTextStyles.titleMedium.copyWith(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Give your adventure a recognizable title and destination.',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 16),

            GlassTextField(
              controller: _titleController,
              labelText: 'Trip Title',
              hintText: 'e.g. Darjeeling Trip',
              prefixIcon: CupertinoIcons.tag,
              isDark: isDark,
            ),
            const SizedBox(height: 14),

            GlassTextField(
              controller: _destinationController,
              labelText: 'Primary Destination',
              hintText: 'e.g. Darjeeling, West Bengal, India',
              prefixIcon: CupertinoIcons.placemark,
              isDark: isDark,
            ),
            const SizedBox(height: 14),

            GlassTextField(
              controller: _departureController,
              labelText: 'Departure City / Location (Optional)',
              hintText: 'e.g. Hijli / Kolkata',
              prefixIcon: CupertinoIcons.arrow_up_right_circle,
              isDark: isDark,
            ),
            const SizedBox(height: 18),

            // Date Range Picker Card
            Text(
              'Travel Dates ($calendarDays Calendar Days)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 8),

            LiquidPop(
              onTap: () => _selectDateRange(context),
              child: GlassCard(
                isDark: isDark,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                borderRadius: 16,
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.calendar,
                      size: 20,
                      color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${dateFormat.format(_startDate)}  →  ${dateFormat.format(_endDate)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tap to change dates',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(CupertinoIcons.chevron_right, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            GlassTextField(
              controller: _travelersController,
              labelText: 'Number of Travelers',
              hintText: '1',
              prefixIcon: CupertinoIcons.person_2,
              keyboardType: TextInputType.number,
              isDark: isDark,
            ),
            const SizedBox(height: 14),

            GlassTextField(
              controller: _descriptionController,
              labelText: 'Trip Notes / Summary (Optional)',
              hintText: 'Rented scooty, homestay preferences, scenic spots...',
              prefixIcon: CupertinoIcons.pencil,
              maxLines: 2,
              isDark: isDark,
            ),
          ],
        );

      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What do you love most?',
              style: AppTextStyles.titleMedium.copyWith(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Select optional travel styles. These help curate relevant stops and organize your workspace.',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 20),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _availablePreferences.map((pref) {
                final isSelected = _selectedPreferences.contains(pref);
                return LiquidPop(
                  pressedScale: 0.94,
                  onTap: () {
                    HapticHelper.selectionClick();
                    setState(() {
                      if (isSelected) {
                        _selectedPreferences.remove(pref);
                      } else {
                        _selectedPreferences.add(pref);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark
                              ? AppColors.appleBlue.withValues(alpha: 0.25)
                              : AppColors.royalIndigo.withValues(alpha: 0.15))
                          : (isDark
                              ? AppColors.darkSurface
                              : Colors.black.withValues(alpha: 0.04)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? (isDark
                                ? AppColors.appleBlue
                                : AppColors.royalIndigo)
                            : (isDark
                                ? const Color(0x1AFFFFFF)
                                : const Color(0x1A000000)),
                        width: isSelected ? 1.4 : 0.6,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected
                              ? CupertinoIcons.check_mark_circled_solid
                              : CupertinoIcons.circle,
                          size: 15,
                          color: isSelected
                              ? (isDark
                                  ? AppColors.appleBlue
                                  : AppColors.royalIndigo)
                              : (isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          pref,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );

      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trip Budget & Estimates (Optional)',
              style: AppTextStyles.titleMedium.copyWith(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Set spending targets for your journey. You can adjust these anytime.',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 16),

            GlassTextField(
              controller: _budgetController,
              labelText: 'Overall Trip Budget (₹)',
              hintText: 'e.g. 25000',
              prefixIcon: CupertinoIcons.money_dollar,
              keyboardType: TextInputType.number,
              isDark: isDark,
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: GlassTextField(
                    controller: _transportBudgetController,
                    labelText: 'Transport (₹)',
                    hintText: '6000',
                    prefixIcon: CupertinoIcons.bus,
                    keyboardType: TextInputType.number,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GlassTextField(
                    controller: _stayBudgetController,
                    labelText: 'Stay (₹)',
                    hintText: '9000',
                    prefixIcon: CupertinoIcons.bed_double,
                    keyboardType: TextInputType.number,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            GlassTextField(
              controller: _foodBudgetController,
              labelText: 'Food & Dining Budget (₹)',
              hintText: '5000',
              prefixIcon: CupertinoIcons.sparkles,
              keyboardType: TextInputType.number,
              isDark: isDark,
            ),
          ],
        );

      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose how to plan',
              style: AppTextStyles.titleMedium.copyWith(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Select how you would like to initialize your itinerary.',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 18),

            // Option A: Plan Manually
            _PlanMethodCard(
              title: 'Option A — Plan Manually',
              subtitle:
                  'Create the trip with $calendarDays empty calendar days and build each day yourself stop by stop.',
              icon: CupertinoIcons.hammer_fill,
              color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
              isDark: isDark,
              onTap: () => _commitTripCreation(planMethod: 'manual'),
            ),
            const SizedBox(height: 14),

            // Option B: Start with a Template
            _PlanMethodCard(
              title: 'Option B — Start with Darjeeling Itinerary',
              subtitle:
                  'Initialize with complete 9-day Darjeeling schedule, MAS NJP SF Express, scooty rental, Live In Nature homestay, and 17 saved spots.',
              icon: CupertinoIcons.sparkles,
              color: AppColors.appleGreen,
              isDark: isDark,
              onTap: () => _commitTripCreation(planMethod: 'template'),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

class _PlanMethodCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _PlanMethodCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(18.0),
      borderRadius: 18,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            CupertinoIcons.chevron_right,
            size: 16,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ],
      ),
    );
  }
}
