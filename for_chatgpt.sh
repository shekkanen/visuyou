#!/bin/dash
#print all dart files under lib folder to single file flutter_dart.txt

find lib -name "*.dart" > /tmp/dart_files.txt
echo 'pubspec.yaml' >> /tmp/dart_files.txt
echo 'android/app/src/main/AndroidManifest.xml' >> /tmp/dart_files.txt
echo 'android/app/build.gradle' >> /tmp/dart_files.txt
echo 'android/settings.gradle' >> /tmp/dart_files.txt
echo 'android/app/proguard-rules.pro' >> /tmp/dart_files.txt
echo 'README.md' >> /tmp/dart_files.txt
echo 'CHANGELOG.md' >> /tmp/dart_files.txt
echo 'release_build_and_install.sh' >> /tmp/dart_files.txt
echo 'assets/.env.example' >> /tmp/dart_files.txt

# Append the content of each dart file to flutter_dart.txt
echo > /tmp/flutter_dart.txt
for file in $(cat /tmp/dart_files.txt); do
  echo "$file:" >> /tmp/flutter_dart.txt
  cat "$file" >> /tmp/flutter_dart.txt
  echo "\n" >> /tmp/flutter_dart.txt
done

# Copy the content of flutter_dart.txt to the clipboard
xclip -selection clipboard < /tmp/flutter_dart.txt
