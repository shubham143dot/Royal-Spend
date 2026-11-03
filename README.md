<div align="center">

# 👑 Royal Spend
### *Autonomous Financial Intelligence, Transparent Liquid Glass & Smart Travel Workspace*

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11+-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Release](https://img.shields.io/badge/Release-v2.0.0-115BFF?style=for-the-badge&logo=android&logoColor=white)](https://github.com/shubham143dot/Royal-Spend/releases/latest)
[![Tests](https://img.shields.io/badge/Tests-162%20Passing%20(100%25)-36D9FF?style=for-the-badge&logo=checkmarx&logoColor=black)](https://github.com/shubham143dot/Royal-Spend/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-white.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)
[![Impeller 120 FPS](https://img.shields.io/badge/Impeller-120%20FPS-1677FF?style=for-the-badge&logo=speedtest&logoColor=white)](https://flutter.dev)

<p align="center">
  <b>A luxury mobile financial operating system built with Flutter.</b><br>
  Featuring authentic <b>iOS-inspired Transparent Liquid Glassmorphism</b>, an interactive <b>3D Holographic Crystal Engine</b>, <b>AI Smart Receipt OCR</b>, <b>Multi-Plan Travel Workspaces</b>, and <b>Offline-First Cloud Firestore Synchronization</b>.
</p>

[📥 Download APK](#-direct-apk-download) • [✨ Key Features](#-key-features) • [🏛️ Architecture](#-system-architecture) • [🚀 Getting Started](#-getting-started) • [🧪 Testing](#-testing--verification)

---

</div>

## 📥 Direct APK Download

Download the production-ready Android application directly from GitHub Releases:

| Package Variant | Target Architecture | Recommended Devices | Direct Download |
| :--- | :--- | :--- | :---: |
| ⚡ **Optimized ARM64** *(Recommended)* | `arm64-v8a` | 99% of modern Android smartphones (Galaxy, Pixel, OnePlus, Xiaomi) | [**Download APK (~76MB)**](https://github.com/shubham143dot/Royal-Spend/releases/latest/download/Royal-Spend-v2.0.0-arm64.apk) |
| 📦 **Universal Release** | Universal (`fat-apk`) | All Android hardware & custom architectures | [**Download APK (~134MB)**](https://github.com/shubham143dot/Royal-Spend/releases/latest/download/Royal-Spend-v2.0.0-universal.apk) |
| 📱 **Legacy ARMv7a** | `armeabi-v7a` | Older 32-bit Android devices | [**Download APK (~70MB)**](https://github.com/shubham143dot/Royal-Spend/releases/latest/download/Royal-Spend-v2.0.0-armeabi-v7a.apk) |
| 💻 **x86_64 Binary** | `x86_64` | Android Emulators & ChromeOS | [**Download APK (~78MB)**](https://github.com/shubham143dot/Royal-Spend/releases/latest/download/Royal-Spend-v2.0.0-x86_64.apk) |

> [!TIP]
> **Quick Android Installation**:
> 1. Tap **Download APK** on your Android device.
> 2. Open the downloaded `.apk` file from your notifications or Files app.
> 3. If prompted, toggle *“Allow from this source”* in your browser/file manager settings.
> 4. Tap **Install** and experience Royal Spend!

---

## ✨ Key Features

### 🌊 Transparent Liquid Glassmorphism (iOS 18 Inspired)
* **Water-Like Optical Clarity**: Pure translucent glass surfaces (`Colors.white.withValues(alpha: 0.08)`) coupled with hardware-accelerated Gaussian backdrop blur (`sigma: 24.0`), allowing the cinematic video background to ripple directly through cards.
* **Specular Molded Glass Rims**: Dual-strike hairline rim shader capturing overhead specular illumination at a $45^\circ$ angle with electric cyan (`#36D9FF`) and ice blue (`#B8E8FF`) refraction.
* **Top Bevel Highlight**: Curved water-bead light arcs simulating physical molded glass.
* **Liquid Pill Inputs**: Seamless, recessed frosted pills with animated cyan refraction focus bloom and integrated password reveal interactions.
* **Liquid Resin Buttons**: Electric blue core with high-gloss liquid reflections and tactile iOS spring physics (`LiquidPop`).

### 🔮 Interactive 3D Holographic Crystal Hero
* **Custom 3D Geometry**: 12-vertex, 20-face regular icosahedron crystal suspended in 3D viewport space.
* **Realtime Shading Engine**: Depth-sorted Painter’s algorithm with normal vector surface lighting and Fresnel refraction.
* **Orbital Ring System**: 3 independent 3D rings inclined at $28^\circ$, $-18^\circ$, and $48^\circ$ with synchronized planetary energy satellites.
* **Volumetric Swarm**: 36 depth-scaled particles with dynamic touch-responsive velocity boosts.
* **Interactive Physics**: Pan/drag gestures rotate the 3D crystal in real time, dampening into continuous levitation with `IOSSpringCurve.gentle`.

### 🧾 AI-Powered Smart Receipt OCR
* **On-Device Vision**: Google ML Kit text recognition with intelligent heuristic parsing.
* **Automated Extraction**: Instant line-by-line categorization identifying merchant name, transaction date, and grand total amounts.
* **Manual & Auto Overrides**: Edit parsed line items before storing.

### ✈️ Multi-Trip Travel Workspace & Daily Itineraries
* **Plan Isolation**: Independent budget tracking per trip. Expenses incurred in Tokyo never collide with a trip to Paris or domestic spending.
* **Day-by-Day Timeline**: Chronological scheduling with departure times, maps, activity notes, and cost breakdowns.
* **Multi-Currency Auto-Conversion**: Native currency calculations updating overall trip budgets in real time.
* **Quick Travel Expense Modal**: Fast logging drawer tailored for on-the-go travelers.

### 📊 Real-Time Financial Intelligence
* **Interactive Data Visualization**: Fluid `fl_chart` spending graphs, category breakdown rings, and burn-rate velocity meters.
* **Smart Budget Thresholds**: Dynamic visual alerts when spending reaches 80% and 100% of defined monthly limits.
* **Discretionary Spending Calculator**: Real-time remaining daily allowance calculations based on pay periods.

### 🔄 Offline-First SQLite + Cloud Firestore Sync
* **Zero Latency**: Local database persistence via SQLite (`sqflite` / `sqflite_common_ffi`) ensures 100% app functionality without internet connectivity.
* **Realtime Two-Way Cloud Sync**: Background listeners and sync queues mirror changes to Firebase Firestore when connectivity is restored.
* **Multi-Device Profile Sync**: Seamless cross-device data continuity.

### 🔒 Enterprise Security & Privacy
* **Secure Authentication**: Firebase Email/Password, Google OAuth, and Password Reset.
* **Offline Demo / Guest Bypass**: Instant evaluation mode with sample datasets.
* **Zero Telemetry Leaks**: Strict privacy boundaries where personal financial data remains under user ownership.

---

## 🏛️ System Architecture

```
lib/
├── core/
│   ├── constants/             # Spatial dimensions, animation tokens, typography
│   ├── services/
│   │   ├── auth/              # RoyalAuthGateway, FirebaseAuthGateway, demo providers
│   │   └── firestore/         # FirestoreSyncService (two-way background sync)
│   ├── theme/                 # RoyalAuthColors, AppColors, SpringCurves, AppTheme
│   └── utils/                 # HapticHelper, CurrencyFormatter, ReceiptParser
├── data/
│   ├── database/              # DatabaseHelper (SQLite schema migrations & queries)
│   ├── models/                # Expense, Budget, Category, Trip, ItineraryDay, Activity
│   └── repositories/          # ExpenseRepository, TravelRepository, SettingsRepository
├── providers/                 # State management (ExpenseProvider, TravelProvider, SettingsProvider)
└── ui/
    ├── screens/
    │   ├── auth/              # Liquid Glass LoginScreen, CreateAccount, ForgotPassword
    │   ├── intro/             # Cinematic Onboarding Video flow
    │   ├── travel/            # TravelDashboard, TripWorkspace, CreatePlanWizard, Itinerary
    │   ├── auth_gate.dart     # Centralized declarative authentication routing
    │   ├── dashboard_screen.dart # Main analytics hub & expense list
    │   └── profile_settings_screen.dart # Multi-currency, cloud backup & themes
    └── widgets/
        ├── auth/              # Holographic3DHero, BlueGlassCard, BlueGlassTextField
        ├── travel/            # ItineraryTimelineView, QuickTravelExpenseSheet
        ├── liquid_pop.dart    # Apple iOS spring physics press handler
        ├── login_video_background.dart # Hardware-accelerated sheer video player
        └── royal_logo.dart    # Procedural illuminated brand emblem
```

---

## 🚀 Getting Started

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.19.0` / Dart `>= 3.3.0`)
* [Java Development Kit (JDK 17)](https://adoptium.net)
* [Android SDK](https://developer.android.com/studio) (API 34 / compileSdk 34)

### Quick Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/shubham143dot/Royal-Spend.git
   cd Royal-Spend
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the test suite:**
   ```bash
   flutter test
   ```
   *Expected result: `All 162 tests passed!`*

4. **Launch the app:**
   ```bash
   # Run on connected Android device
   flutter run -d android

   # Run on Windows Desktop
   flutter run -d windows
   ```

---

## 🛠️ Building Releases

To assemble release APKs with optimized resources:

```bash
# 1. Build Universal Release APK
flutter build apk --release --no-tree-shake-icons

# 2. Build Split-per-ABI Release APKs (Optimized file sizes)
flutter build apk --release --split-per-abi --no-tree-shake-icons
```

Output binaries will be generated at:
* `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
* `build/app/outputs/flutter-apk/app-release.apk`

---

## 🧪 Testing & Verification

Royal Spend enforces strict quality gates with comprehensive test coverage:

```bash
flutter analyze
flutter test
```

| Test Suite | Scope | Status |
| :--- | :--- | :---: |
| **Static Code Quality** | Impeller rendering, lint rules, accessibility | `0 Warnings, 0 Errors` |
| **Authentication & Video** | Sheer scrim contrast, video playback, form validation | `21 / 21 Passed` |
| **Travel & Multi-Trip Hub** | Trip budget isolation, itinerary CRUD, timeline rendering | `34 / 34 Passed` |
| **Receipt OCR & Extraction** | Smart receipt parsing, total detection, currency logic | `25 / 25 Passed` |
| **Core UI & State** | SQLite persistence, Firestore synchronization, Provider state | `82 / 82 Passed` |
| **Total Test Suite** | **Comprehensive end-to-end verification** | **162 / 162 Passed (100%)** |

---

## ⚙️ Automated GitHub CI/CD

This repository is equipped with an automated GitHub Actions release pipeline (`.github/workflows/release.yml`). 

Whenever a release tag is pushed:
```bash
git tag v2.0.0
git push origin v2.0.0
```
The automated workflow will:
1. Verify the entire test suite on clean cloud runners.
2. Build all production APK variants (`universal`, `arm64`, `armeabi-v7a`, `x86_64`).
3. Publish a new GitHub Release with attached download assets.

---

## 📄 License

This project is open-source software licensed under the [MIT License](LICENSE).

---

<div align="center">
  <b>Designed with precision for modern Android & iOS.</b><br>
  Crafted by <a href="https://github.com/shubham143dot">Shubham</a>
</div>
