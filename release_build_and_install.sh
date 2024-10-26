#!/bin/bash

#flutter clean

#flutter pub get

# Build release APK
if flutter build apk --release; then
    echo "Build succeeded, installing APK..."

  # Install release APK to my Xiaomi phone
    flutter install --release -d e7d36532
    #flutter install --upgrade --release -d e7d36532

  # Install release APK to my Redmi 8 phone
    flutter install --release -d 18a3a90b9907
    #flutter install --upgrade --release -d 18a3a90b9907

else
  echo "Build failed, not installing APK."
fi

adb -s e7d36532 logcat | grep 'com.samihekkanen.visuyou' > xiaomi_logcat.log &
adb -s 18a3a90b9907 logcat | grep 'com.samihekkanen.visuyou' > redmi_logcat.log &