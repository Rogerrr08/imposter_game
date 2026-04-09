# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Supabase / Realtime (uses reflection for serialization)
-keep class io.supabase.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# Drift / SQLite
-keep class app.cash.sqldelight.** { *; }

# Play Core (referenced by Flutter engine for deferred components)
-dontwarn com.google.android.play.core.**

# Keep R8 from stripping needed classes
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
