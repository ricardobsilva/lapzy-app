# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# Google Maps
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Geolocator / Location services
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**

# shared_preferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# Kotlin coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-dontwarn kotlinx.coroutines.**

# Preserve generic signatures (needed for JSON serialization)
-keepattributes Signature
-keepattributes *Annotation*
