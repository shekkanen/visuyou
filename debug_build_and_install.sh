#!/bin/bash

flutter clean

flutter pub get

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

adb -s e7d36532 logcat | grep 'com.samihekkanen.visuyou' > xiaomi_logcat.txt &
adb -s 18a3a90b9907 logcat | grep 'com.samihekkanen.visuyou' > redmi_logcat.txt &