// lib/voice_command_utils.dart
// Copyright © 2024 Sami Hekkanen. All rights reserved.

import 'package:vosk_flutter/vosk_flutter.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'settings_model.dart'; // Import for SettingsModel

class VoiceCommandUtils {
  final Function(String) onCommandRecognized;
  final SettingsModel settingsModel; // Add SettingsModel as a parameter
  VoskFlutterPlugin? _vosk;
  Model? _model;
  Recognizer? _recognizer;
  SpeechService? _speechService;
  bool _isListening = false;

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
    _recognizer = await _vosk!.createRecognizer(model: _model!, sampleRate: 16000);

    // Initialize the SpeechService for recognition
    _speechService = await _vosk!.initSpeechService(_recognizer!);

    // Subscribe to recognition events
    _speechService!.onPartial().listen((partialResult) {
  //      if (kDebugMode) {
  //        print('Partial result: $partialResult');
  //      }
    });

    _speechService!.onResult().listen((finalResult) async {
  //      if (kDebugMode) {
  //        print('Final result: $finalResult');
  //      }
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
  //  if (kDebugMode) {
  //    print('Recognized command: $recognizedText');
  //  }

    // Get the view change word from SettingsModel
    String viewChangeWord = settingsModel.selectedViewChangeWord;

    if (recognizedText.contains(viewChangeWord.toLowerCase())) {
      onCommandRecognized('next');
    } else {
  //    if (kDebugMode) {
  //      print('Command not recognized');
  //    }
    }
  }
}
