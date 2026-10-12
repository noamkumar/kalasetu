# ==============================================================================
# KalaSetu - ProGuard / R8 Rules
# ==============================================================================

# Flutter Engine & Plugins
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.plugins.** { *; }

# Application code & custom MainActivity
-keep class com.kalasetu.app.** { *; }

# AndroidX WorkManager (fixes startup crash in WorkManagerInitializer)
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**
-keep class androidx.work.impl.** { *; }
-keep class androidx.work.impl.WorkDatabase** { *; }
-keep class * extends androidx.work.impl.WorkDatabase { *; }
-keep class * extends androidx.work.ListenableWorker { *; }

# AndroidX Room (WorkManager uses Room internally to instantiate WorkDatabase)
-keep class androidx.room.** { *; }
-dontwarn androidx.room.**
-keep class * extends androidx.room.RoomDatabase { *; }
-keep @androidx.room.Entity class * { *; }
-keepclassmembers class * {
    @androidx.room.* <methods>;
}
-dontwarn androidx.room.paging.**

# AndroidX Startup (InitializationProvider)
-keep class androidx.startup.** { *; }
-dontwarn androidx.startup.**

# Flutter Community Workmanager Plugin
-keep class dev.fluttercommunity.workmanager.** { *; }
-dontwarn dev.fluttercommunity.workmanager.**

# Preserve annotations and native JNI methods
-keepattributes *Annotation*
-keepclassmembers class * {
    @androidx.annotation.Keep <fields>;
    @androidx.annotation.Keep <methods>;
}
-keepclasseswithmembernames class * {
    native <methods>;
}
