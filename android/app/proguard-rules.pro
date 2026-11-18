# ProGuard Rules for Royal Spend
# ==========================================

# Keep Flutter wrapper classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# SQLite / sqflite
-keep class org.sqlite.** { *; }
-keep class org.sqlite.database.** { *; }

# AndroidX Biometric & Local Authentication
-keep class androidx.biometric.** { *; }
-keep interface androidx.biometric.** { *; }

# Google Maps & Google Play Services
-keep class com.google.android.gms.maps.** { *; }
-keep interface com.google.android.gms.maps.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.libraries.places.** { *; }

# Firebase Core, Auth, Firestore, Storage
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.tasks.** { *; }

# Suppress common Android warnings
-dontwarn sun.misc.**
-dontwarn java.lang.instrument.**
