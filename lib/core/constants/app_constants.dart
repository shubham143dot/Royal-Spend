class AppConstants {
  static const String appName = 'Royal Spend';
  static const String appTagline = 'Expense Tracker & Travel Planner';
  static const String brandName = 'Royal Shubham Pixel Labs';
  static const String appVersion = '1.0.0';

  // Assets
  static const String appLogoPath = 'assets/images/app_logo.png';
  static const String appIconPath = 'assets/icons/app_icon.png';
  static const String introVideoPath = 'assets/videos/intro_video.mp4';
  static const String introPosterPath = 'assets/images/intro_poster.jpg';
  static const String loginVideoPath = 'assets/videos/login_background.mp4';
  static const String loginPosterPath = 'assets/images/login_poster.jpg';

  // Feature Flags
  /// Toggle to enable or disable the development auth bypass ('Skip for now').
  /// Set to false before production release once Firebase Auth is live.
  static const bool enableDevAuthBypass = true;

  // Storage Keys
  static const String keyThemeMode = 'theme_mode';
  static const String keyCurrencySymbol = 'currency_symbol';
  static const String keyCurrencyCode = 'currency_code';
  static const String keyUserName = 'user_name';
  static const String keyMonthlyBudget = 'monthly_budget';
  static const String keyHasSeededDemoData = 'has_seeded_demo_data';
  static const String keyHapticsEnabled = 'haptics_enabled';
  static const String keyHasCompletedIntro = 'has_completed_intro';
  static const String keyIsAuthenticated = 'is_authenticated';

  // Default values
  static const String defaultCurrencySymbol = '₹';
  static const String defaultCurrencyCode = 'INR';
  static const double defaultMonthlyBudget = 35000.0;
  static const String defaultUserName = 'Shubham';
}
