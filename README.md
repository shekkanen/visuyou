# visuyou

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

./adb kill-server
./adb tcpip 5555
./adb connect 192.168.0.109
./adb devices
./adb -s 192.168.0.113:5555 install -r /home/sami/sorsat/visuyou/build/app/outputs/apk/debug/app-debug.apk
flutter run -d 192.168.0.109

#icons
flutter pub run flutter_launcher_icons:main
