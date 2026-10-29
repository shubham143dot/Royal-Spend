import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Premier iOS-grade input text field with theme-aware contrast,
/// glowing specular focus ring, and zero-jitter layout stability.
class GlassTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final String? labelText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool isDark;
  final TextInputType keyboardType;
  final bool autofocus;
  final int maxLines;
  final TextStyle? textStyle;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool warning;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  const GlassTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffix,
    required this.isDark,
    this.keyboardType = TextInputType.text,
    this.autofocus = false,
    this.maxLines = 1,
    this.textStyle,
    this.validator,
    this.onChanged,
    this.warning = false,
    this.obscureText = false,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  @override
  State<GlassTextField> createState() => _GlassTextFieldState();
}

class _GlassTextFieldState extends State<GlassTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool highContrast = MediaQuery.of(context).highContrast;
    final textColor = widget.isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final hintColor = widget.isDark
        ? AppColors.darkTextMuted
        : AppColors.lightTextMuted;
    final activeBorderColor = widget.isDark
        ? AppColors.appleBlue
        : AppColors.royalIndigo;
    final warningBorderColor = widget.isDark
        ? AppColors.amberWarning
        : const Color(0xFFB45309);
    final inactiveBorderColor = highContrast
        ? (widget.isDark ? Colors.white : const Color(0xFF64748B))
        : (widget.isDark
            ? const Color(0x2BFFFFFF)
            : const Color(0xFFCBD5E1));

    final surfaceColor = highContrast
        ? (widget.isDark ? AppColors.darkCard : const Color(0xFFFFFFFF))
        : (widget.isDark
            ? AppColors.darkSurface
            : const Color(0xFFF8FAFC));

    final fieldContainer = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: surfaceColor,
        border: Border.all(
          color: _isFocused
              ? activeBorderColor
              : (widget.warning ? warningBorderColor : inactiveBorderColor),
          width: _isFocused || widget.warning ? 1.4 : 0.8,
        ),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: activeBorderColor.withValues(
                    alpha: widget.isDark ? 0.35 : 0.20,
                  ),
                  blurRadius: 12,
                  spreadRadius: 0.5,
                ),
                if (!widget.isDark)
                  const BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 6,
                    offset: Offset(0, 1),
                  ),
              ]
            : [
                BoxShadow(
                  color: widget.isDark
                      ? Colors.black.withValues(alpha: 0.25)
                      : const Color(0xFF64748B).withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 1.5),
                ),
              ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        onFieldSubmitted: widget.onFieldSubmitted,
        obscureText: widget.obscureText,
        maxLines: widget.maxLines,
        style: widget.textStyle ??
            AppTextStyles.bodyLarge.copyWith(
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
        cursorColor: activeBorderColor,
        validator: widget.validator,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: InputBorder.none,
          hintText: widget.hintText,
          hintStyle: AppTextStyles.bodyLarge.copyWith(color: hintColor),
          prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          prefixIcon: widget.prefixIcon != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Icon(
                    widget.prefixIcon,
                    size: 19,
                    color: _isFocused ? activeBorderColor : hintColor,
                  ),
                )
              : null,
          suffixIcon: widget.suffix,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.labelText != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              widget.labelText!,
              style: AppTextStyles.labelUppercase.copyWith(
                color: widget.warning
                    ? warningBorderColor
                    : (widget.isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary),
              ),
            ),
          ),
        ],
        fieldContainer,
      ],
    );
  }
}
