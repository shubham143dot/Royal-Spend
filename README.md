<div align="center">

# 👑 Royal Spend
### *Opulent Expense Tracking & Intelligent Travel Planner*

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Tests](https://img.shields.io/badge/Tests-136%20Passing-brightgreen?logo=checkmarx)](https://github.com)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Windows%20%7C%20macOS-blue)](https://flutter.dev)

A modern, high-performance Flutter application combining **luxury glassmorphic aesthetics**, **real-time financial analytics**, **smart receipt OCR**, and **itinerary-driven travel budget management**.

</div>

---

## 🌟 Key Highlights

- 💎 **Royal Glassmorphic UI**: High-fidelity dark theme with deep obsidian backgrounds, royal gold accents, frosted glass textures, and physics-based tactile springs (`LiquidPop`).
- 📊 **Real-Time Financial Intelligence**: Interactive `fl_chart` visual analytics, daily burn-rate monitors, category distribution, and instant budget overage warnings.
- ✈️ **Travel Planner & Multi-Trip Hub**:
  - Independent multi-trip budget isolation.
  - Day-by-day itinerary scheduling with activity tracking.
  - Quick travel expense logging with automated multi-currency conversion.
- 🧾 **Smart Receipt OCR Scanner**: Integrated `google_mlkit_text_recognition` with heuristic line parsing to automatically extract merchant, date, and grand total amounts.
- 🌌 **Cinematic Onboarding**: Immersive looping video background, animated galaxy starfields, and fluid sheet transitions.
- ⚡ **Offline-First Architecture**: High-reliability local storage powered by SQLite (`sqflite` / `sqflite_common_ffi`) and `shared_preferences`.

---

## 🏛️ Project Architecture

```
lib/
├── core/
│   ├── constants/       # App-wide dimension tokens, typography & keys
│   ├── services/auth/   # Abstract auth boundary & provider gateways
│   ├── theme/           # AppColors (Obsidian, Royal Gold, Glass Gradients)
│   └── utils/           # Haptic helpers, currency formatters & physics curves
├── data/
│   ├── models/          # Expense, Budget, Category, and Travel entities
│   └── repositories/    # SQLite persistence, queries & settings stores
├── providers/           # Provider-based state management (Expense, Travel, Settings)
└── ui/
    ├── screens/
    │   ├── auth/        # Video & galaxy login, account creation, password reset
    │   ├── intro/       # Cinematic welcome onboarding flow
    │   ├── travel/      # Travel dashboard, trip creator, itinerary & day sheets
    │   ├── dashboard_screen.dart        # Main overview & quick logs
    │   └── profile_settings_screen.dart # Currency selector, theme & backup
    └── widgets/         # Reusable glass text fields, buttons & charts
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`^3.11.3` or latest stable)
- [Dart SDK](https://dart.dev/get-dart)
- An Android Emulator, iOS Simulator, or Desktop Development Environment (Windows/macOS)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/shubham143dot/Royal-Spend.git
   cd Royal-Spend
   ```

2. **Fetch dependencies:**
   ```bash
   flutter pub get
   ```

3. **Verify the test suite:**
   ```bash
   flutter test
   ```
   *(All 136 unit, widget, and theme audit tests should pass cleanly)*

4. **Launch the application:**
   ```bash
   # Android
   flutter run -d android

   # Windows Desktop
   flutter run -d windows

   # macOS Desktop
   flutter run -d macos
   ```

---

## 🧪 Testing & Code Quality

Royal Spend maintains comprehensive test coverage across data parsing, state isolation, and UI accessibility:
```bash
flutter test
```
- **136 automated test cases** covering:
  - Smart receipt OCR extraction edge cases.
  - Multi-plan travel budget isolation.
  - Physics-based spring animations (`LiquidPop`).
  - Form validation, haptics, and theme consistency audits.

---

## 🛠️ Tech Stack

| Component | Library / Framework |
| :--- | :--- |
| **Framework** | Flutter (Dart 3) |
| **State Management** | `provider` |
| **Database** | SQLite (`sqflite`, `sqflite_common_ffi`) |
| **Analytics Charts** | `fl_chart` |
| **OCR & Vision** | `google_mlkit_text_recognition`, `image_picker` |
| **Media & Audio** | `video_player` |
| **Navigation** | `liquid_glass_floating_nav` |
| **Formatting** | `intl`, `uuid` |

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
