# Selection, Toggles & Segmented Controls

This guide covers state-driven transition patterns for tabs, segmented controls, chips, and toggles, adapted from **`GetStream/swiftui-spring-animations`** and Flutter's material/cupertino design samples.

---

## 1. Sliding Pill Segmented Control

Rather than individually coloring each tab or button, iOS-style segmented controls use a single floating indicator (pill) that smoothly slides behind the selected segment.

### Architecture

```text
┌──────────────────────────────────────────────┐
│  ┌───────────────┐                           │
│  │ Active Pill   │    Tab 2        Tab 3     │
│  └───────────────┘                           │
└──────────────────────────────────────────────┘
```

### Flutter Implementation Technique

Use a `Stack` where:
1. The bottom layer is an `AnimatedAlign` containing the white/card pill with subtle drop shadow.
2. The top layer is a `Row` of transparent tap targets that change the `selectedIndex`.
3. Alignment formula:
   $$\text{alignmentX} = -1.0 + \left( \frac{2.0 \times \text{selectedIndex}}{\text{itemCount} - 1} \right)$$

```dart
AnimatedAlign(
  duration: const Duration(milliseconds: 260),
  curve: Curves.easeInOutCubicEmphasized, // or IOSSpringCurve.snappy
  alignment: Alignment(
    -1.0 + (selectedIndex / (items.length - 1)) * 2.0,
    0.0,
  ),
  child: FractionallySizedBox(
    widthFactor: 1.0 / items.length,
    child: Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: activeColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    ),
  ),
);
```

---

## 2. Spring Checkmark & Radio Animation

When checking a checkbox or selecting a radio item:
1. **Background**: Expands with scale spring (`0.0 -> 1.15 -> 1.0`).
2. **Icon**: Custom path or stroke draws forward with `Curves.easeOutBack`.
3. **Haptics**: `HapticFeedback.selectionClick()` immediately.

```dart
class SpringCheckbox extends StatelessWidget {
  final bool isChecked;
  final ValueChanged<bool> onChanged;

  const SpringCheckbox({super.key, required this.isChecked, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!isChecked);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: IOSSpringCurve.snappy,
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: isChecked ? AppColors.royalIndigo : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: isChecked ? AppColors.royalIndigo : Colors.grey.withOpacity(0.4),
            width: 1.8,
          ),
        ),
        child: AnimatedScale(
          scale: isChecked ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          curve: IOSSpringCurve.bouncy,
          child: const Icon(Icons.check, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}
```

---

## 3. Interactive Filter & Category Chips

When chips transition between selected and unselected states:
- Use `AnimatedContainer` with `200ms` duration.
- Animate border color, background opacity, and text style simultaneously.
- Pair with `SpringButton` wrap for press tactile scale.
