#!/bin/dash
#print all dart files under lib folder to single file flutter_dart.txt

find lib -name "*.dart" > /tmp/dart_files.txt

# Append the content of each dart file to flutter_dart.txt
echo > /tmp/flutter_dart.txt
for file in $(cat /tmp/dart_files.txt); do
  echo "$file:" >> /tmp/flutter_dart.txt
  cat "$file" >> /tmp/flutter_dart.txt
  echo "\n" >> /tmp/flutter_dart.txt
done

# Copy the content of flutter_dart.txt to the clipboard
xclip -selection clipboard < /tmp/flutter_dart.txt
