// lib/voice_command_utils.dart
// Copyright © 2024 Sami Hekkanen. All rights reserved.

import 'package:vosk_flutter/vosk_flutter.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'settings_model.dart'; // Import for SettingsModel
import 'settings_page.dart';


class VoiceCommandUtils {
  final Function(String) onCommandRecognized;
  final SettingsModel settingsModel; // Add SettingsModel as a parameter
  VoskFlutterPlugin? _vosk;
  Model? _model;
  Recognizer? _recognizer;
  SpeechService? _speechService;
  bool _isListening = false;

List<String> _getGrammar() {
  return [
    ...SettingsPage.viewChangeWords.map((word) => word.toLowerCase()),
    ...SettingsPage.backWords.map((word) => word.toLowerCase()),
    ...SettingsPage.muteMicWords.map((word) => word.toLowerCase()),
    ...SettingsPage.unmuteMicWords.map((word) => word.toLowerCase()),
    ...SettingsPage.muteSpeakerWords.map((word) => word.toLowerCase()),
    ...SettingsPage.unmuteSpeakerWords.map((word) => word.toLowerCase()),
    ...SettingsPage.fullVrModeWords.map((word) => word.toLowerCase()),
    ...SettingsPage.fullVrMode2Words.map((word) => word.toLowerCase()),
    ...SettingsPage.vr50_50ModeWords.map((word) => word.toLowerCase()),
    ...SettingsPage.pipVrModeWords.map((word) => word.toLowerCase()),
    ...SettingsPage.pipVrMode2Words.map((word) => word.toLowerCase()),
  ];
}

  VoiceCommandUtils({required this.onCommandRecognized, required this.settingsModel});

  Future<void> initSpeech() async {
  if (!await Permission.microphone.isGranted || !await Permission.camera.isGranted) {
    if (kDebugMode) {
      print('Permissions not granted. Speech recognition initialization aborted.');
    }
    return;
  }
    // Initialize the VoskFlutterPlugin instance
    _vosk = VoskFlutterPlugin.instance();

    // Load the model from assets
    String modelPath = await _loadModel();

    // Create the model
    _model = await _vosk!.createModel(modelPath);


  
    // Create the recognizer
  _recognizer = await _vosk!.createRecognizer(
    model: _model!,
    sampleRate: 16000,
    grammar: _getGrammar());
 




    // Initialize the SpeechService for recognition
    _speechService = await _vosk!.initSpeechService(_recognizer!);

    // Subscribe to recognition events
    _speechService!.onPartial().listen((partialResult) {
        // if (kDebugMode) {
        //   print('Partial result: $partialResult');
        // }
    });

    _speechService!.onResult().listen((finalResult) async {
        if (kDebugMode) {
          print('Final result: $finalResult');
        }
      await _processRecognizedText(finalResult);
    });

    // Start listening
    startListening();
  }

  Future<String> _loadModel() async {
    final modelLoader = ModelLoader();
    // Adjust the path according to where your model zip file is located
    final modelPath = await modelLoader.loadFromAssets('assets/models/vosk-model-small-en-us-0.15.zip');
    return modelPath;
  }

  void startListening() {
    if (!_isListening && _speechService != null) {
      // Start recognition
      _speechService!.start();
      _isListening = true;
      if (kDebugMode) {
        print('Started listening');
      }
    }
  }

  void stopListening() {
    if (_isListening && _speechService != null) {
      _speechService!.stop();
      _isListening = false;
      if (kDebugMode) {
        print('Stopped listening');
      }
    }
  }

Future<void> _processRecognizedText(String recognizedJson) async {
  // Parse the JSON result
  Map<String, dynamic> result = jsonDecode(recognizedJson);
  String recognizedText = result['text'] ?? '';

  recognizedText = recognizedText.toLowerCase();

  // Check for voice commands based on settings
  if (recognizedText == settingsModel.viewNextWord.toLowerCase()) {
    onCommandRecognized('view_next');
  } else if (recognizedText == settingsModel.viewBackWord.toLowerCase()) {
    onCommandRecognized('view_back');
  } else if (recognizedText == settingsModel.micEnabledWord.toLowerCase()) {
    onCommandRecognized('unmute_mic');
  } else if (recognizedText == settingsModel.micDisableWord.toLowerCase()) {
    onCommandRecognized('mute_mic');
  } else if (recognizedText == settingsModel.speakerEnabledWord.toLowerCase()) {
    onCommandRecognized('unmute_speaker');
  } else if (recognizedText == settingsModel.speakerDisableWord.toLowerCase()) {
    onCommandRecognized('mute_speaker');
  } else if (recognizedText == settingsModel.fullVrModeWord.toLowerCase()) {
    onCommandRecognized('full_vr_mode');
  } else if (recognizedText == settingsModel.fullVrMode2Word.toLowerCase()) {
    onCommandRecognized('full_vr_mode2');
  } else if (recognizedText == settingsModel.vr50_50ModeWord.toLowerCase()) {
    onCommandRecognized('vr50_50_mode');
  } else if (recognizedText == settingsModel.pipVrModeWord.toLowerCase()) {
    onCommandRecognized('pip_vr_mode');
  } else if (recognizedText == settingsModel.pipVrMode2Word.toLowerCase()) {
    onCommandRecognized('pip_vr_mode2');
  } else {
    if (kDebugMode) {
      print('Command not recognized: $recognizedText');
    }
  }
}


  void dispose() {
    if (_speechService != null) {
      _speechService!.stop(); // Stop listening
      _speechService!.cancel(); // Cancel any pending operations
      _speechService = null;
    }

    if (_recognizer != null) {
      _recognizer!.dispose(); // Dispose of the recognizer
      _recognizer = null;
    }

    if (_model != null) {
      _model!.dispose(); // Dispose of the model as per the plugin's example
      _model = null;
    }

    _isListening = false;
  }




}
