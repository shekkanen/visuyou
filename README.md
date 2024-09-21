
# VisuYou
## VisuYou - True P2P VR Experience

VisuYou is a peer-to-peer (P2P) virtual reality (VR) application developed using Flutter. It enables users to share and experience the world from another person's perspective in real-time using VR headsets. The app establishes a direct connection between two devices without relying on any servers, ensuring complete privacy.

## Features
- **True P2P Connection**: Connect directly with another device using WebRTC technology, ensuring a private and secure connection without intermediary servers.
- **Multiple VR Modes**:
  - Full VR Mode: Immersive experience with the same video feed in both eyes.
  - 50/50 VR Mode: Split-screen view combining local and remote video streams.
  - PiP VR Mode: Picture-in-Picture mode to view one stream within another.
- **Voice Commands**: Navigate between VR modes using voice commands for a seamless hands-free experience.
- **QR Code Connection**: Easily establish connections by generating and scanning QR codes.
- **Audio Support**: Optional audio streaming that can be enabled or disabled in the settings.
- **Cross-Platform Compatibility**: Built with Flutter, VisuYou can be used across various devices supporting Flutter.

## Table of Contents
1. [Installation](#installation)
2. [Prerequisites](#prerequisites)
3. [Build Instructions](#build-instructions)
4. [Usage](#usage)
   - [Establishing Connection](#establishing-connection)
   - [Selecting VR Modes](#selecting-vr-modes)
   - [Settings](#settings)
   - [Permissions](#permissions)
5. [Troubleshooting](#troubleshooting)
6. [Dependencies](#dependencies)
7. [Contributing](#contributing)
8. [License](#license)
9. [Contact](#contact)

## Installation

### Prerequisites
- **Flutter SDK**: Ensure you have Flutter installed on your machine. [Install Flutter](https://flutter.dev/docs/get-started/install)
- **Android Device**: The app is currently built for Android devices.
- **VR Headset**: A compatible VR headset is recommended for the full experience.

### Build Instructions

#### Clone the Repository

```bash
git clone https://github.com/yourusername/visuyou.git
cd visuyou
```

#### Install Dependencies

Run the following command to install all required dependencies:

```bash
flutter pub get
```

#### Configure App Signing (For Release Builds)

##### Generate a Keystore

Use the following command to generate a keystore. Replace `your_alias` with your preferred alias.

```bash
keytool -genkey -v -keystore ~/visuyou_keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias your_alias
```

##### Create `key.properties` File

In your project root, create a file named `key.properties` and add the following:

```properties
storePassword=your_keystore_password
keyPassword=your_key_password
keyAlias=your_alias
storeFile=/path/to/visuyou_keystore.jks
```

Replace the placeholders with your actual passwords and keystore file path.

##### Update `android/app/build.gradle`

Ensure the signing configurations are added:

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    // ...

    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled false
            // ...
        }
    }
}
```

#### Build the App

##### For Debug Build (APK):

```bash
flutter build apk --debug
```

##### For Release Build (APK):

```bash
flutter build apk --release
```

##### For Release Build (App Bundle):

```bash
flutter build appbundle --release
```

#### Install the App on Your Device

Connect your Android device via USB and enable USB debugging.

Install the app using:

```bash
flutter install
```

## Usage

### Establishing Connection

1. **Launch the App**: Open VisuYou on both devices.
2. **Create Offer**:
   - On one device, tap **Create Offer**.
   - A QR code will be generated containing the connection offer.
3. **Scan QR Code**:
   - On the second device, tap **Scan QR Code**.
   - Scan the QR code displayed on the first device.
4. **Complete the Connection**: Follow any additional prompts to finalize the connection. The app will exchange necessary information to establish a P2P connection.

### Selecting VR Modes

Use the dropdown menu in the app bar to select your preferred VR mode:
- Full VR Mode
- 50/50 VR Mode
- PIP VR Mode
- PIP VR Mode2

### Voice Commands:
- Say "Next" to cycle through the available VR modes.
- Ensure that voice recognition permissions are granted.

### Settings

Access the settings by tapping the Settings icon in the app bar.
- **Enable Audio**: Toggle to stream audio along with video.
- **Enable Notifications**: Manage app notifications.
- **Privacy Policy**: Review the app's privacy policy.
- **Terms of Service**: Review the terms of service.

### Permissions

The app requires the following permissions:
- **Camera**: To capture and stream video.
- **Microphone**: (Optional) To capture and stream audio if enabled.
- **Internet**: To establish a P2P connection using WebRTC.
- **Bluetooth**: Required for network state changes on certain devices.
- **Audio Settings**: To modify audio configurations.
- **Network State**: To access and change network state.

Ensure you grant all necessary permissions when prompted to fully utilize the app's features.

## Troubleshooting

### Connection Issues:
- Ensure both devices have a stable internet connection.
- Verify that permissions are granted on both devices.

### Camera Not Found:
- If the back camera is not detected, the app will attempt to use the default camera.
- Check your device's camera settings.

### Voice Commands Not Working:
- Ensure microphone permissions are granted.
- Speak clearly and in a quiet environment.

### App Crashes or Freezes:
- Restart the app and try again.
- Check for any updates to the app or dependencies.

## Dependencies

VisuYou utilizes several Flutter packages:
- **flutter_webrtc**: WebRTC implementation for Flutter.
- **permission_handler**: Handles runtime permissions.
- **qr_flutter**: Generates QR codes.
- **flutter_barcode_scanner**: Scans QR codes.
- **speech_to_text**: Implements voice command recognition.
- **shared_preferences**: Stores user settings locally.
- **archive**: Handles data compression and decompression.
- **camera**: Accesses device cameras.
- **cupertino_icons**: Provides iOS style icons.

For a complete list, refer to the pubspec.yaml file.

## Contributing

Contributions are welcome! Please follow these steps:

1. **Fork the Repository**: Click the "Fork" button at the top right of the repository page.

2. **Create a Feature Branch**:
```bash
git checkout -b feature/YourFeature
```

3. **Commit Your Changes**:
```bash
git commit -am 'Add new feature'
```

4. **Push to the Branch**:
```bash
git push origin feature/YourFeature
```

5. **Open a Pull Request**: Submit your pull request for review.

## License

[Specify your license here, e.g., MIT License]

```text
MIT License

Copyright (c) 2023 Your Name

Permission is hereby granted, free of charge, to any person obtaining a copy...
```

## Contact

For any inquiries or support, please contact:
- Email: your.email@example.com
- GitHub: yourusername

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

# help
./adb kill-server
./adb tcpip 5555
./adb connect 192.168.0.109
./adb devices
./adb -s 192.168.0.113:5555 install -r /home/sami/sorsat/visuyou/build/app/outputs/apk/debug/app-debug.apk
flutter run -d 192.168.0.109

# icons
flutter pub run flutter_launcher_icons:main

# clean build
```
flutter clean
flutter pub get
flutter build apk --release
```

Your app offers a unique and private peer-to-peer VR experience that allows users to view the world from another person's perspective in real-time. This opens up a wide array of innovative use cases across various fields. Here are some ideas:

Shared Experiences for Couples: Couples can use the app to enhance their connection by sharing perspectives in intimate or everyday moments. This can deepen empathy and understanding between partners by literally seeing through each other's eyes.

Virtual Tourism and Exploration: Users can virtually explore new places by connecting with someone in a different location. This allows people to experience travel and cultural exchange without leaving their homes.

Education and Training: Teachers, mentors, or experts can provide real-time demonstrations from their perspective. For instance, a chef could show cooking techniques, or a mechanic could guide someone through a repair.

Remote Assistance and Support: Technicians or support personnel can see exactly what a user is encountering and guide them through troubleshooting steps, enhancing customer service experiences.

Medical and Healthcare Applications: Doctors could perform remote consultations by viewing a patient's environment. Similarly, patients could share their daily routines for better health monitoring.

Emergency Services and Safety: First responders can share live footage from their perspective during emergencies, aiding coordination and response efforts.

Sports and Training: Coaches can observe athletes' techniques in real-time or athletes can experience a coach's perspective, improving training efficiency.

Entertainment and Gaming: Gamers can share their live gameplay from a first-person perspective, or audiences can experience events like concerts or sports matches through the eyes of someone on the ground.

Artistic Collaboration: Artists and creators can collaborate remotely, sharing their creative process live to work together on projects such as painting, crafting, or music production.

Accessibility Enhancements: People with mobility issues can experience activities through someone else's perspective, like hiking or attending events, which they might not be able to do physically.

Research and Field Studies: Scientists and researchers can share live observations from the field with their teams or students, enhancing collaborative research efforts.

Family Connections: Families separated by distance can share moments like walking through a new home, attending a child's event, or celebrating holidays together.

Journalism and Reporting: Reporters can provide immersive coverage of events by sharing live perspectives from the scene, giving audiences a more engaging experience.

Psychological Therapy and Counseling: Therapists could use the app to better understand a client's environment and experiences, potentially aiding in treatments like exposure therapy.

Mindfulness and Empathy Exercises: Users can engage in activities that promote empathy by experiencing daily life from another person's perspective, fostering greater understanding and social connection.

Considerations for Implementation:

Privacy and Consent: Ensure that all users are fully informed and consent to sharing their perspectives. Implement robust privacy controls and data protection measures.

Security: As the app operates without servers, focus on securing peer-to-peer connections to protect against interception or unauthorized access.

User Experience: Provide intuitive controls for starting and ending sessions, switching perspectives, and handling connectivity issues.

Compliance with Regulations: Be mindful of legal considerations, such as data protection laws and regulations regarding streaming content, especially in different jurisdictions.


Additional Features to Enhance Use Cases:

Gesture Recognition: Use device sensors to capture gestures or movements, adding another layer of interaction.

Customization Options: Allow users to adjust video quality or switch between front and back cameras, tailoring the experience to their needs.

Session Recording: Offer the option to record sessions for later viewing, with clear consent from both parties.


# Android emulator
 emulator -avd Medium_Phone_API_35