# Flutter WebRTC
-keep class com.cloudwebrtc.webrtc.** { *; }
-keep class org.webrtc.** { *; }

# vosk_flutter
-keep class com.sun.jna.* { *; }
-keepclassmembers class * extends com.sun.jna.* { public *; }

# Suppress warnings for JNA
-dontwarn com.sun.jna.**

# JSON Serialization
-keepattributes *Annotation*
-keep class com.samihekkanen.visuyou.models.** { *; }

# Permission Handler
-keep class com.baseflow.permissionhandler.** { *; }

# URL Launcher
-keep class io.flutter.plugins.urllauncher.** { *; }

# Shared Preferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# Camera Plugin
-keep class io.flutter.plugins.camera.** { *; }

# QR Flutter
-keep class io.github.luanbarbosa.qrcode.** { *; }

# Archive Package (if applicable)
# -keep class com.example.archive.** { *; } // Ensure correct package if needed

# Provider Package
# -keep class com.example.provider.** { *; } // Ensure correct package if needed

# Add more rules as needed based on your project structure and dependencies

# Vosk Flutter
-keep class org.vosk.** { *; }
-keep class com.alphacephei.vosk.** { *; }

# Keep JNA classes
-keep class com.sun.jna.* { *; }
-keepclassmembers class * extends com.sun.jna.* { public *; }

# Suppress warnings for JNA
-dontwarn com.sun.jna.**

# WebRTC (if used)
-keep class org.webrtc.** { *; }

# JSON Processing (if used)
-keep class com.google.gson.** { *; }

# Keep all classes in your package that interact with Vosk
-keep class com.samihekkanen.visuyou.** { *; }

# Prevent stripping of native methods
-keepclasseswithmembernames class * {
    native <methods>;
}