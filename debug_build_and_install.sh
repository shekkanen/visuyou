#!/bin/bash

# Kill all previous logcat processes
pkill -f "adb -s e7d36532 logcat"
pkill -f "adb -s 18a3a90b9907 logcat"

#flutter clean

#flutter pub get

dart scripts/generate_dependencies.dart

# Build debug APK
if flutter build apk --debug; then
    echo "Build succeeded, installing APK..."

  # Install debug APK to my Xiaomi phone
    flutter install --debug -d e7d36532
    #flutter install --upgrade --debug -d e7d36532

  # Install debug APK to my Redmi 8 phone
    flutter install --debug -d 18a3a90b9907
    #flutter install --upgrade --debug -d 18a3a90b9907

else
  echo "Build failed, not installing APK."
fi

adb -s e7d36532 logcat | grep 'com.samihekkanen.visuyou' > xiaomi_logcat.log &
adb -s 18a3a90b9907 logcat | grep 'com.samihekkanen.visuyou' > redmi_logcat.log &