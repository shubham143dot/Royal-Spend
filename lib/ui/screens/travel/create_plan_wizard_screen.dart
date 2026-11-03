import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

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
  final _formKey = GlobalKey<FormState>();

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
  bool _showAdvancedOptions = false;
  bool _isSubmitting = false;

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

    _titleController = TextEditingController(text: t?.title ?? '');
    _destinationController = TextEditingController(text: t?.destination ?? '');
    _departureController = TextEditingController(text: t?.departureCity ?? '');
    _descriptionController = TextEditingController(text: t?.description ?? '');
    _travelersController = TextEditingController(
      text: t != null ? t.travelersCount.toString() : '1',
    );

    _budgetController = TextEditingController(
      text: t != null && t.budget > 0 ? t.budget.toStringAsFixed(0) : '',
    );
    _transportBudgetController = TextEditingController(
      text: t != null && t.transportBudget > 0
          ? t.transportBudget.toStringAsFixed(0)
          : '',
    );
    _stayBudgetController = TextEditingController(
      text: t != null && t.accommodationBudget > 0
          ? t.accommodationBudget.toStringAsFixed(0)
          : '',
    );
    _foodBudgetController = TextEditingController(
      text: t != null && t.foodBudget > 0
          ? t.foodBudget.toStringAsFixed(0)
          : '',
    );

    // Default dates: today to +7 days, or trip dates if editing
    final now = DateTime.now();
    _startDate = t?.startDate ?? DateTime(now.year, now.month, now.day);
    _endDate = t?.endDate ?? _startDate.add(const Duration(days: 6));

    if (t != null) {
      _selectedPreferences.addAll(t.preferences);
      _showAdvancedOptions = t.budget > 0 || t.preferences.isNotEmpty;
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

  Future<void> _submitPlan() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      HapticHelper.heavyImpact();
      return;
    }

    if (_endDate.isBefore(_startDate)) {
      HapticHelper.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('End date cannot be earlier than start date'),
          backgroundColor: AppColors.roseExpense,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return;
    }

    final travelersCount = int.tryParse(_travelersController.text.trim()) ?? 1;
    if (travelersCount < 1) {
      HapticHelper.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter at least 1 traveller'),
          backgroundColor: AppColors.roseExpense,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    HapticHelper.success();

    try {
      final travelProvider = context.read<TravelProvider>();
      const uuid = Uuid();
      final tripId = widget.tripToEdit?.id ?? uuid.v4();

      final totalBudget = double.tryParse(_budgetController.text.trim()) ?? 0.0;
      final transBudget =
          double.tryParse(_transportBudgetController.text.trim()) ?? 0.0;
      final stayBudget =
          double.tryParse(_stayBudgetController.text.trim()) ?? 0.0;
      final foodBudget =
          double.tryParse(_foodBudgetController.text.trim()) ?? 0.0;

      final trip = Trip(
        id: tripId,
        title: _titleController.text.trim(),
        destination: _destinationController.text.trim(),
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
        status: widget.tripToEdit?.status ?? TripStatus.upcoming,
      );

      if (widget.tripToEdit != null) {
        await travelProvider.updateTrip(trip);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Travel plan updated successfully!'),
              backgroundColor: AppColors.royalIndigo,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          );
        }
        return;
      }

      // Build trip with automatically generated itinerary calendar days
      await travelProvider.createTrip(trip);

      if (!mounted) return;

      // Select newly created trip and navigate to workspace
      await travelProvider.selectTrip(trip.id);
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        CupertinoPageRoute(
          builder: (_) => TripWorkspaceScreen(tripId: trip.id),
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Plan "${trip.title}" created successfully!'),
          backgroundColor: AppColors.royalIndigo,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating travel plan: $e'),
            backgroundColor: AppColors.roseExpense,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDark = settings.isDarkMode(context);
    final dateFormat = DateFormat('d MMM yyyy');
    final calendarDays = _endDate.difference(_startDate).inDays + 1;
    final isEditing = widget.tripToEdit != null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientBackground(
        isDark: isDark,
        child: SafeArea(
          child: Column(
            children: [
              // Top Navigation Bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                child: Row(
                  children: [
                    LiquidPop(
                      onTap: () {
                        HapticHelper.selectionClick();
                        Navigator.pop(context);
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
                            isEditing ? 'Edit Travel Plan' : 'Create New Plan',
                            style: AppTextStyles.titleMedium.copyWith(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 19,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            isEditing
                                ? 'Update trip details and dates'
                                : 'Where are you going?',
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

              // Form Scroll Body
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 12.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section 1: Trip Essentials
                        _buildSectionHeader(
                          title: 'TRIP ESSENTIALS',
                          icon: CupertinoIcons.compass,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 10),

                        GlassTextField(
                          controller: _titleController,
                          labelText: 'Trip Name *',
                          hintText: 'e.g. Darjeeling Mountain Retreat, Goa Beach Trip',
                          prefixIcon: CupertinoIcons.tag_fill,
                          isDark: isDark,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter a trip name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        GlassTextField(
                          controller: _destinationController,
                          labelText: 'Destination *',
                          hintText: 'e.g. Darjeeling, West Bengal, India',
                          prefixIcon: CupertinoIcons.placemark_fill,
                          isDark: isDark,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter a destination';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        GlassTextField(
                          controller: _departureController,
                          labelText: 'Starting Location (Optional)',
                          hintText: 'e.g. Hijli, Kolkata, New Delhi',
                          prefixIcon: CupertinoIcons.arrow_up_right_circle,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 22),

                        // Section 2: Dates & Travellers
                        _buildSectionHeader(
                          title: 'DATES & TRAVELLERS',
                          icon: CupertinoIcons.calendar,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 10),

                        // Date Range Picker Card
                        LiquidPop(
                          onTap: () => _selectDateRange(context),
                          child: GlassCard(
                            isDark: isDark,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            borderRadius: 16,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (isDark
                                            ? AppColors.appleBlue
                                            : AppColors.royalIndigo)
                                        .withValues(alpha: 0.16),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    CupertinoIcons.calendar,
                                    size: 20,
                                    color: isDark
                                        ? AppColors.appleBlue
                                        : AppColors.royalIndigo,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                        '$calendarDays calendar days • Tap to change',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: isDark
                                              ? AppColors.appleBlue
                                              : AppColors.royalIndigo,
                                        ),
                                      ),
                                    ],
                                  ),
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
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Travellers Count Input
                        Row(
                          children: [
                            Expanded(
                              child: GlassTextField(
                                controller: _travelersController,
                                labelText: 'Number of Travellers',
                                hintText: '1',
                                prefixIcon: CupertinoIcons.person_2_fill,
                                keyboardType: TextInputType.number,
                                isDark: isDark,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  final num = int.tryParse(v.trim());
                                  if (num == null || num < 1) {
                                    return 'Min 1';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Quick Stepper Buttons
                            Container(
                              height: 52,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkSurface
                                    : Colors.white.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0x22FFFFFF)
                                      : const Color(0xFFCBD5E1),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(CupertinoIcons.minus,
                                        size: 16),
                                    onPressed: () {
                                      final current = int.tryParse(
                                              _travelersController.text) ??
                                          1;
                                      if (current > 1) {
                                        HapticHelper.selectionClick();
                                        _travelersController.text =
                                            (current - 1).toString();
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon:
                                        const Icon(CupertinoIcons.plus, size: 16),
                                    onPressed: () {
                                      final current = int.tryParse(
                                              _travelersController.text) ??
                                          1;
                                      HapticHelper.selectionClick();
                                      _travelersController.text =
                                          (current + 1).toString();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),

                        // Section 3: Trip Description
                        _buildSectionHeader(
                          title: 'TRIP DESCRIPTION (OPTIONAL)',
                          icon: CupertinoIcons.doc_text,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 10),

                        GlassTextField(
                          controller: _descriptionController,
                          labelText: 'Trip Description / Overview Notes',
                          hintText:
                              'e.g. Family vacation exploring scenic tea estates and high-altitude Himalayan viewpoints...',
                          prefixIcon: CupertinoIcons.pencil,
                          maxLines: 3,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 18),

                        // Advanced Options Toggle (Budget & Preferences)
                        LiquidPop(
                          pressedScale: 0.96,
                          onTap: () {
                            HapticHelper.selectionClick();
                            setState(
                                () => _showAdvancedOptions = !_showAdvancedOptions);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSurface.withValues(alpha: 0.6)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _showAdvancedOptions
                                      ? CupertinoIcons.chevron_up
                                      : CupertinoIcons.chevron_down,
                                  size: 14,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _showAdvancedOptions
                                        ? 'Hide Budget & Travel Preferences'
                                        : 'Add Budget & Travel Preferences (Optional)',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (_showAdvancedOptions) ...[
                          const SizedBox(height: 16),
                          _buildSectionHeader(
                            title: 'ESTIMATED TRIP BUDGET',
                            icon: CupertinoIcons.money_dollar,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 10),

                          GlassTextField(
                            controller: _budgetController,
                            labelText: 'Overall Target Budget (₹)',
                            hintText: 'e.g. 25000',
                            prefixIcon: CupertinoIcons.money_dollar_circle,
                            keyboardType: TextInputType.number,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 12),

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
                          const SizedBox(height: 12),

                          GlassTextField(
                            controller: _foodBudgetController,
                            labelText: 'Food & Dining Budget (₹)',
                            hintText: '5000',
                            prefixIcon: CupertinoIcons.sparkles,
                            keyboardType: TextInputType.number,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 18),

                          _buildSectionHeader(
                            title: 'TRAVEL PREFERENCES',
                            icon: CupertinoIcons.heart,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 8),

                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availablePreferences.map((pref) {
                              final isSelected =
                                  _selectedPreferences.contains(pref);
                              return FilterChip(
                                label: Text(pref),
                                selected: isSelected,
                                selectedColor: (isDark
                                        ? AppColors.appleBlue
                                        : AppColors.royalIndigo)
                                    .withValues(alpha: 0.25),
                                checkmarkColor: isDark
                                    ? AppColors.appleBlue
                                    : AppColors.royalIndigo,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? (isDark
                                          ? Colors.white
                                          : AppColors.royalIndigo)
                                      : (isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary),
                                ),
                                onSelected: (sel) {
                                  HapticHelper.selectionClick();
                                  setState(() {
                                    if (sel) {
                                      _selectedPreferences.add(pref);
                                    } else {
                                      _selectedPreferences.remove(pref);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                        const SizedBox(height: 28),

                        // Primary Action Button: Create Plan / Update Plan
                        GlassButton(
                          label: isEditing ? 'Update Plan' : 'Create Plan',
                          icon: isEditing
                              ? CupertinoIcons.check_mark_circled_solid
                              : CupertinoIcons.add_circled_solid,
                          variant: GlassButtonVariant.primary,
                          isDark: isDark,
                          isLoading: _isSubmitting,
                          onPressed: _submitPlan,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 13,
          color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: AppTextStyles.labelUppercase.copyWith(
            fontSize: 11,
            color:
                isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}
