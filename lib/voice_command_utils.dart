import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/material.dart';

class VoiceCommandUtils {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  final Function(String) onCommandRecognized;

  VoiceCommandUtils({required this.onCommandRecognized}) {
    _speech = stt.SpeechToText();
  }

  Future<void> initSpeech() async {
    bool available = await _speech.initialize(
      onStatus: _statusListener,
      onError: _errorListener,
    );
    if (available) {
      startListening();
    } else {
      print("Speech recognition not available");
    }
  }

  void startListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: _statusListener,
        onError: _errorListener,
      );

      if (available) {
        _speech.listen(
          listenFor: Duration(seconds: 120), // Increase the listening duration
          onResult: (val) {
            _processRecognizedText(val.recognizedWords);
          },
          cancelOnError: false,
        );
        _isListening = true;
        print("Started listening");
      } else {
        print("Speech recognition not available");
      }
    }
  }

  void stopListening() {
    if (_isListening) {
      _speech.stop();
      _isListening = false;
      print("Stopped listening");
    }
  }

  void _processRecognizedText(String recognizedText) {
    recognizedText = recognizedText.toLowerCase();
    print("Recognized command: $recognizedText");

    if (recognizedText.contains('next')) {
      onCommandRecognized('next');
    } else {
      print("Command not recognized");
    }
  }

  void _statusListener(String status) {
    print('Speech status: $status');
    if (status == 'done' || status == 'notListening') {
      // Automatically restart listening if it stops or times out
      _isListening = false;
      startListening();
    }
  }

  void _errorListener(dynamic error) {
    print('Speech error: $error');
    // Attempt to restart listening on any error
    _isListening = false;
    startListening();
  }
}
