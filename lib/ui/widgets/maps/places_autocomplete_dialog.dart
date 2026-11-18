import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/services/maps/google_places_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/glass_decorations.dart';
import '../../../core/utils/haptic_helper.dart';
import '../glass_card.dart';
import '../liquid_pop.dart';

class PlacesAutocompleteDialog extends StatefulWidget {
  final String title;
  final String hintText;
  final bool isDark;

  const PlacesAutocompleteDialog({
    super.key,
    this.title = 'Search Location',
    this.hintText = 'Enter city, hotel, restaurant, or spot...',
    required this.isDark,
  });

  /// Displays the Places Autocomplete modal and returns the chosen [PlaceDetails] or null if dismissed.
  static Future<PlaceDetails?> show(
    BuildContext context, {
    String title = 'Search Location',
    String hintText = 'Enter city, hotel, restaurant, or spot...',
    required bool isDark,
  }) {
    HapticHelper.selectionClick();
    return showModalBottomSheet<PlaceDetails>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => PlacesAutocompleteDialog(
        title: title,
        hintText: hintText,
        isDark: isDark,
      ),
    );
  }

  @override
  State<PlacesAutocompleteDialog> createState() =>
      _PlacesAutocompleteDialogState();
}

class _PlacesAutocompleteDialogState extends State<PlacesAutocompleteDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _debounceTimer;
  bool _isLoading = false;
  bool _isFetchingDetails = false;
  String? _fetchingPlaceId;
  String? _errorMessage;
  List<PlacePrediction> _suggestions = [];

  @override
  void initState() {
    super.initState();
    // Auto-focus search input shortly after bottom sheet slides up
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      setState(() {
        _suggestions = [];
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 320), () async {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final results = await GooglePlacesService.instance
            .getAutocompleteSuggestions(trimmed);

        if (!mounted) return;
        setState(() {
          _suggestions = results;
          _isLoading = false;
          if (results.isEmpty && trimmed.length >= 3) {
            _errorMessage = 'No location suggestions found for "$trimmed".';
          }
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to fetch suggestions. Please check network.';
        });
      }
    });
  }

  Future<void> _selectPrediction(PlacePrediction prediction) async {
    HapticHelper.mediumImpact();
    setState(() {
      _isFetchingDetails = true;
      _fetchingPlaceId = prediction.placeId;
    });

    try {
      final details = await GooglePlacesService.instance
          .getPlaceDetails(prediction.placeId);

      if (!mounted) return;

      if (details != null &&
          (details.latitude != 0.0 || details.longitude != 0.0)) {
        Navigator.pop(context, details);
      } else {
        setState(() {
          _isFetchingDetails = false;
          _fetchingPlaceId = null;
          _errorMessage =
              'Could not retrieve coordinates for this spot. Please select another.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isFetchingDetails = false;
        _fetchingPlaceId = null;
        _errorMessage = 'Error retrieving place details: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.85,
      decoration: GlassDecorations.glassModalDecoration(isDark: isDark),
      padding: EdgeInsets.fromLTRB(18, 12, 18, 16 + viewInsets),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0x40FFFFFF)
                    : const Color(0x33000000),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: (isDark
                              ? AppColors.appleBlue
                              : AppColors.royalIndigo)
                          .withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CupertinoIcons.location_fill,
                      size: 15,
                      color: isDark
                          ? AppColors.appleBlue
                          : AppColors.royalIndigo,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.title,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
              LiquidPop(
                pressedScale: 0.90,
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0x1AFFFFFF)
                        : const Color(0x0F000000),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.clear,
                    size: 14,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Search Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B).withValues(alpha: 0.70)
                  : Colors.white.withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
                    .withValues(alpha: 0.35),
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.search,
                  size: 18,
                  color: isDark
                      ? AppColors.appleBlue
                      : AppColors.royalIndigo,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    onChanged: _onQueryChanged,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_isLoading)
                  const CupertinoActivityIndicator(radius: 8)
                else if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      _onQueryChanged('');
                    },
                    child: Icon(
                      CupertinoIcons.clear_circled_solid,
                      size: 16,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Error / Status Message
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.roseExpense,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          // Suggestions List
          Expanded(
            child: _buildSuggestionsBody(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsBody(bool isDark) {
    if (_suggestions.isEmpty) {
      if (_isLoading) {
        return const Center(
          child: CupertinoActivityIndicator(radius: 14),
        );
      }

      if (_searchController.text.trim().isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.map_pin_ellipse,
                size: 40,
                color: isDark
                    ? const Color(0x33FFFFFF)
                    : const Color(0x33000000),
              ),
              const SizedBox(height: 10),
              Text(
                'Type a place or address to search Google Places',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextMuted
                      : AppColors.lightTextMuted,
                ),
              ),
            ],
          ),
        );
      }

      return const SizedBox.shrink();
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: _suggestions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final suggestion = _suggestions[index];
        final isSelectedFetching =
            _isFetchingDetails && _fetchingPlaceId == suggestion.placeId;

        return GlassCard(
          isDark: isDark,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          borderRadius: 14,
          onTap: _isFetchingDetails ? null : () => _selectPrediction(suggestion),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isDark
                          ? AppColors.appleBlue
                          : AppColors.royalIndigo)
                      .withValues(alpha: 0.14),
                ),
                child: Icon(
                  CupertinoIcons.placemark,
                  size: 16,
                  color: isDark
                      ? AppColors.appleBlue
                      : AppColors.royalIndigo,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.mainText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (suggestion.secondaryText.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        suggestion.secondaryText,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelectedFetching)
                const CupertinoActivityIndicator(radius: 8)
              else
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: isDark
                      ? AppColors.darkTextMuted
                      : AppColors.lightTextMuted,
                ),
            ],
          ),
        );
      },
    );
  }
}
