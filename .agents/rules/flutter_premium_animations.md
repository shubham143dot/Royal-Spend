# Future Development Rules: Flutter Premium Animations

Whenever asked to create a new feature, screen, button, component, or interactive element in this project:

1. **Automatic Skill Activation**:
   - Automatically activate and apply the `flutter-premium-animations` skill.
   - Employ appropriate, polished animations wherever they enhance the user experience.
   - Examples: Spring and pop effects for buttons (`SpringButton`), smooth selection transitions (`SlidingSegmentedControl`), tactile haptic feedback (`HapticFeedback`), and fluid modal opening/closing transitions.

2. **Design System & Theme Preservation**:
   - Strictly preserve existing dark/light themes, brand colors (`AppColors`), typography (`AppTextStyles`), spacing (16/20px gutters), glassmorphism (`GlassDecorations`), and card aesthetics.
   - Follow the existing visual language and reuse established components and patterns consistently.

3. **Restraint & Native Fidelity**:
   - Do not add unnecessary animations or external animation packages.
   - Use Flutter-native implementations (`IOSSpringCurve`, `CurvedAnimation`, `Transform.scale`, `AnimatedAlign`).
   - Prioritize 120 FPS performance (GPU transform/opacity only, `RepaintBoundary` isolation) and accessibility (`MediaQuery.disableAnimations` support).

4. **Autonomous Adherence**:
   - Apply these animation guidelines automatically across all future development tasks without requiring the user to repeat these instructions.
