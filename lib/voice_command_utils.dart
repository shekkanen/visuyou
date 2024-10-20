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
    ...SettingsPage.enableAudioWords.map((word) => word.toLowerCase()),
    ...SettingsPage.fullVrModeWords.map((word) => word.toLowerCase()),
    ...SettingsPage.vr50_50ModeWords.map((word) => word.toLowerCase()),
    ...SettingsPage.pipVrModeWords.map((word) => word.toLowerCase()),
    ...SettingsPage.pipVrMode2Words.map((word) => word.toLowerCase()),
  ];
}

  VoiceCommandUtils({required this.onCommandRecognized, required this.settingsModel});

  Future<void> initSpeech() async {
    // Request microphone permission
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) {
        if (kDebugMode) {
          print('Microphone permission not granted');
        }
        return;
      }
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
        // if (kDebugMode) {
        //   print('Final result: $finalResult');
        // }
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
  } else if (recognizedText == settingsModel.enableAudioWord.toLowerCase()) {
    onCommandRecognized('toggle_audio');
  } else if (recognizedText == settingsModel.fullVrModeWord.toLowerCase()) {
    onCommandRecognized('full_vr_mode');
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


Future<void> dispose() async {
  if (_speechService != null) {
    await _speechService!.stop();
    await _speechService!.cancel();
    _speechService = null;
  }

  if (_recognizer != null) {
    await _recognizer!.dispose();
    _recognizer = null;
  }

  if (_model != null) {
    _model!.dispose(); // Removed 'await' here
    _model = null;
  }

  _isListening = false;
}



}
