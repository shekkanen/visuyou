# Flutter WebRTC
-keep class com.cloudwebrtc.webrtc.** { *; }
-keep class org.webrtc.** { *; }

# vosk_flutter
# Suppress warnings for JNA classes referencing AWT
-dontwarn com.sun.jna.**
-keep class com.sun.jna.* { *; }
-keepclassmembers class * extends com.sun.jna.* { public *; }