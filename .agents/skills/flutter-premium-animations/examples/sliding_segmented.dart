import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'spring_curves.dart';

/// Reusable sliding pill segmented control with spring physics.
///
/// Provides a floating pill indicator that glides smoothly behind the active tab.
class SlidingSegmentedControl<T> extends StatelessWidget {
  final List<T> values;
  final List<String> labels;
  final List<IconData>? icons;
  final T selectedValue;
  final ValueChanged<T> onValueChanged;
  final Color? backgroundColor;
  final Color? thumbColor;
  final Color? activeTextColor;
  final Color? inactiveTextColor;

  const SlidingSegmentedControl({
    super.key,
    required this.values,
    required this.labels,
    this.icons,
    required this.selectedValue,
    required this.onValueChanged,
    this.backgroundColor,
    this.thumbColor,
    this.activeTextColor,
    this.inactiveTextColor,
  }) : assert(values.length == labels.length, 'values and labels must have the same length');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = backgroundColor ?? (isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF1F5F9));
    final thumb = thumbColor ?? (isDark ? const Color(0xFF2C2C2E) : Colors.white);
    final activeText = activeTextColor ?? (isDark ? Colors.white : Colors.black87);
    final inactiveText = inactiveTextColor ?? (isDark ? const Color(0xFF8E8E93) : const Color(0xFF64748B));

    final selectedIndex = values.indexOf(selectedValue);
    final count = values.length;

    // Normalized X alignment: -1.0 (left) to 1.0 (right)
    final alignmentX = count > 1 ? -1.0 + (selectedIndex / (count - 1)) * 2.0 : 0.0;

    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0x22FFFFFF) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // Sliding Active Pill Indicator
              AnimatedAlign(
                duration: const Duration(milliseconds: 260),
                curve: IOSSpringCurve.snappy,
                alignment: Alignment(alignmentX, 0.0),
                child: FractionallySizedBox(
                  widthFactor: 1.0 / count,
                  child: Container(
                    decoration: BoxDecoration(
                      color: thumb,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Labels Row
              Row(
                children: List.generate(count, (index) {
                  final isSelected = index == selectedIndex;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (index != selectedIndex) {
                          HapticFeedback.selectionClick();
                          onValueChanged(values[index]);
                        }
                      },
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? activeText : inactiveText,
                            letterSpacing: -0.2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (icons != null && index < icons!.length) ...[
                                Icon(
                                  icons![index],
                                  size: 15,
                                  color: isSelected ? activeText : inactiveText,
                                ),
                                const SizedBox(width: 5),
                              ],
                              Text(labels[index]),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
