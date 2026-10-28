# Bottom Sheets & Modal Presentations

This guide documents presentation curves, gesture drag physics, and keyboard handling for modern bottom sheets in Flutter.

---

## 1. Cupertino & Glass Bottom Sheet Presentation

A premium bottom sheet features:
1. **Background Dimming Scrim**: Smooth fade of dark barrier with optional soft backdrop blur.
2. **Slide-Up Curve**: `Curves.easeOutCubic` or `IOSSpringCurve.gentle` over **320–360 ms**.
3. **Rounded Top Corners**: 24–32 dp radius.
4. **Drag Indicator**: A centered 36x5 dp pill indicator with rounded ends.

### Native Modal Configuration

In Flutter 3.22+, `showModalBottomSheet` supports `sheetAnimationStyle`:

```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  barrierColor: Colors.black.withOpacity(0.55),
  sheetAnimationStyle: AnimationStyle(
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 250),
  ),
  builder: (context) => const YourSheetContent(),
);
```

---

## 2. Velocity-Sensitive Drag Dismissal

When users swipe down on a sheet:
- Track vertical drag velocity with `onVerticalDragEnd(details)`.
- If velocity $> 700\text{ dp/s}$ downwards, dismiss immediately (`Navigator.pop(context)`).
- If displacement exceeds $40\%$ of sheet height, dismiss.
- Otherwise, animate back to original resting position with `IOSSpringCurve.snappy`.

---

## 3. Keyboard Inset Smooth Coordination

When a text field inside a bottom sheet gains focus:
- Wrap the contents in `SingleChildScrollView(physics: BouncingScrollPhysics())`.
- Add `MediaQuery.of(context).viewInsets.bottom` to padding.
- Flutter's engine automatically animates `viewInsets` at the keyboard curve; pairing this with a bouncing scroll prevents content clipping.

```dart
@override
Widget build(BuildContext context) {
  final bottomInset = MediaQuery.of(context).viewInsets.bottom;

  return Container(
    padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
    child: SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.35),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Form fields...
        ],
      ),
    ),
  );
}
```
