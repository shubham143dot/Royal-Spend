---
name: flutter-premium-animations
description: >-
  Expert Flutter animation patterns inspired by iOS/SwiftUI springs, flutter_animate,
  and modern physics-based UI interaction craft. Use this skill whenever building,
  refactoring, or reviewing interactive UI elements in Flutter: spring and pop buttons,
  fluid cards, tactile selection states, sliding segmented controls, sheet/dialog transitions,
  staggered list entrances, gesture physics, and micro-interactions. Emphasizes 120Hz
  ProMotion smoothness, accessibility (reduced motion), zero-jank RepaintBoundary isolation,
  and native Apple/Flutter design fidelity without unnecessary dependencies.
---

# Flutter Premium Animations Skill

This skill provides production-ready, reusable Flutter animation patterns adapted from leading industry references:
- **`flutter/samples`** (Explicit/implicit animations, Hero choreography, physics simulations)
- **`bizz84/flutter_animations_gallery`** (Curves gallery, state-driven transitions, custom controllers)
- **`gskinner/flutter_animate`** (Declarative chaining, staggered cascades, shimmer/shake micro-interactions)
- **`GetStream/swiftui-spring-animations`** (iOS spring physics formulas, damping ratios, responsive timing)
- **`amosgyamfi/open-swiftui-animations`** (Modern interactive gestures, tactile pops, phase animations)

---

## Core Animation Principles

1. **Physical Authenticity (Mass, Damping, Stiffness)**:
   - Avoid linear or abrupt eases for user-initiated gestures.
   - Use spring curves (`IOSSpringCurve`) with calibrated response time ($T_0$) and damping ratio ($\zeta$).
   - Tap down: immediate, snappy shrinkage (80–120ms). Tap release: organic, fluid spring overshoot (300–450ms).

2. **Performance First (120 FPS / Impeller Friendly)**:
   - Only animate `Transform` (scale, translate, rotate) and `Opacity`.
   - Never animate layout properties (`width`, `height`, `margin`, `padding`) during high-frequency gestures.
   - Wrap animated subtrees in `RepaintBoundary` to isolate repaint regions from the parent scaffold.

3. **Subtle & Restrained Craft**:
   - Animations should provide tactile confirmation, not distraction.
   - Scale ranges for button press: `0.94` to `0.97` (never shrink into oblivion).
   - Bounciness: Keep $\zeta \ge 0.65$ for primary UI elements; reserve playful bounces ($\zeta \approx 0.5$) for celebrations or badge counts.

4. **Accessibility (Reduced Motion Support)**:
   - Always query `MediaQuery.of(context).disableAnimations`.
   - When reduced motion is requested, collapse springs to instant state changes or gentle fades (100ms).

---

## Reference Manuals Index

Detailed guides and mathematical formulas are stored in the `references/` directory:

| Reference Guide | Content & Procedures |
|---|---|
| [physics_springs.md](./references/physics_springs.md) | Analytical iOS spring equations, SwiftUI parameter conversion (`response`, `dampingFraction` $\to$ Flutter `SpringDescription`), and drop-in `Curve` classes. |
| [button_interactions.md](./references/button_interactions.md) | Tactile press-down scales, haptic triggers, cancelation recovery, squish/stretch, and FAB transitions. |
| [selection_and_toggles.md](./references/selection_and_toggles.md) | Sliding pill indicators for segmented controls, animated checkmarks, interactive chips, and liquid switches. |
| [cards_and_dialogs.md](./references/cards_and_dialogs.md) | Center pop modals (scale + fade + spring), 3D perspective tilts, card expansion, and scrim backdrop transitions. |
| [bottom_sheets.md](./references/bottom_sheets.md) | Smooth bottom sheet slide-ups, velocity-based fling dismissals, drag handle indicators, and dynamic keyboard insets. |
| [page_transitions.md](./references/page_transitions.md) | iOS fluid push/pop with parallax, zoom Hero choreography, and interactive edge-swipe dismiss gestures. |
| [gskinner_chaining.md](./references/gskinner_chaining.md) | Declarative chainable animation extensions without controller boilerplate (`.fadeIn()`, `.slideY()`, `.shimmer()`, `.shake()`). |
| [accessibility_perf.md](./references/accessibility_perf.md) | 120Hz ProMotion optimization, `RepaintBoundary` guidelines, and `prefers-reduced-motion` compliance. |

---

## Production-Ready Code Examples

Drop-in Flutter implementations ready to copy and use are located in `examples/`:

| Example File | Description |
|---|---|
| [spring_curves.dart](./examples/spring_curves.dart) | Pure Dart drop-in iOS spring curves (`IOSSpringCurve.snappy`, `bouncy`, `gentle`, `interactive`) with zero dependencies. |
| [spring_button.dart](./examples/spring_button.dart) | Reusable bouncy press widget with tactile haptics, scale recovery, and smooth release. |
| [spring_modal.dart](./examples/spring_modal.dart) | Fluid pop dialog and bottom sheet presentations with Cupertino curves and dimmed scrims. |
| [sliding_segmented.dart](./examples/sliding_segmented.dart) | Sliding pill segmented control with spring physics and responsive tab indicators. |
| [staggered_list.dart](./examples/staggered_list.dart) | Staggered cascade entrance for cards, list items, and dashboard tiles with interval delays. |

---

## Quick Reference: Standard Spring Values

| Interaction Type | Duration / Response | Damping Ratio ($\zeta$) | Flutter Implementation |
|---|---|---|---|
| **Button Tap Down** | 100 ms | 1.0 (Critically damped) | `Curves.easeOutCubic` |
| **Button Release Spring** | 350 ms | 0.70 (Organic snap) | `IOSSpringCurve.snappy` |
| **Modal / Dialog Pop** | 380 ms | 0.78 (Crisp overshoot) | `IOSSpringCurve.bouncy` |
| **Bottom Sheet Entrance** | 320 ms | 0.85 (Smooth settle) | `Curves.easeOutCubic` |
| **Segmented Pill Slide** | 260 ms | 0.80 (Fluid gliding) | `Curves.easeInOutCubicEmphasized` |
| **Error Shake** | 400 ms | 0.50 (Oscillating) | `Curves.elasticIn` / 4 Hz sinusoidal |
| **Success Badge Pop** | 450 ms | 0.55 (Playful bounce) | `Curves.elasticOut` |

---

## Future UI Development Checklist

When asked to build a new feature, screen, component, or interactive element:
1. **Identify the Interactive Elements**: Locate buttons, cards, list items, tabs, and modals.
2. **Apply Spring Touch Feedback**: Wrap tap targets in `SpringButton` or apply `IOSSpringCurve` to `onTapDown` / `onTapUp`.
3. **Use Staggered Cascade for Loading**: Stagger list items or grid cards by 35–50ms interval for natural entrance.
4. **Use Shared Design Tokens**: Retain existing app theme, colors, dark card surfaces, border radii, and glassmorphism.
5. **Enforce Zero-Jank & Accessibility**: Verify `disableAnimations` flag and ensure no layout properties are animated during gestures.
