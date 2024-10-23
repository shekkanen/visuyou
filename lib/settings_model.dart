// lib/settings_model.dart
// Copyright © 2024 Sami Hekkanen. All rights reserved.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class SettingsModel extends ChangeNotifier {
  bool _micEnabled = false;
  bool _speakerEnabled = true;
  bool _enableVoiceCommands = true;

  // Voice command keywords
  String _viewNextWord = 'next';
  String _viewBackWord = 'back';
  String _micEnabledWord = 'unmute mic';
  String _micDisableWord = 'mute mic';
  String _speakerEnabledWord = 'unmute speaker';
  String _speakerDisableWord = 'mute speaker';
  String _fullVrModeWord = 'mode one';
  String _vr50_50ModeWord = 'mode two';
  String _pipVrModeWord = 'mode three';
  String _pipVrMode2Word = 'mode four';

  // Getters
  bool get micEnabled => _micEnabled;
  bool get speakerEnabled => _speakerEnabled;
  bool get enableVoiceCommands => _enableVoiceCommands;

  String get viewNextWord => _viewNextWord;
  String get viewBackWord => _viewBackWord;
  String get micEnabledWord => _micEnabledWord;
  String get micDisableWord => _micDisableWord;
  String get speakerEnabledWord => _speakerEnabledWord;
  String get speakerDisableWord => _speakerDisableWord;
  String get fullVrModeWord => _fullVrModeWord;
  String get vr50_50ModeWord => _vr50_50ModeWord;
  String get pipVrModeWord => _pipVrModeWord;
  String get pipVrMode2Word => _pipVrMode2Word;

  final Completer<void> _settingsLoadedCompleter = Completer<void>();

  SettingsModel() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _micEnabled = prefs.getBool('micEnabled') ?? false;
    _speakerEnabled = prefs.getBool('speakerEnabled') ?? true;
    _enableVoiceCommands = prefs.getBool('enableVoiceCommands') ?? true;

    _viewNextWord = prefs.getString('viewNextWord') ?? 'next';
    _viewBackWord = prefs.getString('viewBackWord') ?? 'back';
    _micEnabledWord = prefs.getString('micEnabledWord') ?? 'unmute mic';
    _micDisableWord = prefs.getString('micDisableWord') ?? 'mute mic';
    _speakerEnabledWord = prefs.getString('speakerEnabledWord') ?? 'unmute speaker';
    _fullVrModeWord = prefs.getString('fullVrModeWord') ?? 'mode one';
    _vr50_50ModeWord = prefs.getString('vr50_50ModeWord') ?? 'mode two';
    _pipVrModeWord = prefs.getString('pipVrModeWord') ?? 'mode three';
    _pipVrMode2Word = prefs.getString('pipVrMode2Word') ?? 'mode four';

    _settingsLoadedCompleter.complete(); // Signal that settings are loaded
    notifyListeners();
  }

  
  Future<void> get settingsLoaded => _settingsLoadedCompleter.future;

  // Update methods

  Future<void> updatemicEnabled(bool value) async {
    _micEnabled = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('micEnabled', value);
    notifyListeners();
  }

  Future<void> updateSpeakerEnabled(bool value) async {
  _speakerEnabled = value;
  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setBool('speakerEnabled', value);
  notifyListeners();
  }

  Future<void> updateEnableVoiceCommands(bool value) async {
    _enableVoiceCommands = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enableVoiceCommands', value);
    notifyListeners();
  }

  Future<void> updateViewNextWord(String value) async {
    _viewNextWord = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('viewNextWord', value);
    notifyListeners();
  }

  Future<void> updateViewBackWord(String value) async {
    _viewBackWord = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('viewBackWord', value);
    notifyListeners();
  }

  Future<void> updatemicEnabledWord(String value) async {
    _micEnabledWord = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('micEnabledWord', value);
    notifyListeners();
  }

  Future<void> updatemicDisableWord(String value) async {
    _micEnabledWord = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('micDisableWord', value);
    notifyListeners();
  }

  Future<void> updateSpeakerEnabledWord(String value) async {
    _micEnabledWord = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('speakerEnabledWord', value);
    notifyListeners();
  }

  Future<void> updateSpeakerDisableWord(String value) async {
    _micEnabledWord = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('speakerDisableWord', value);
    notifyListeners();
  }


  Future<void> updateFullVrModeWord(String value) async {
    _fullVrModeWord = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('fullVrModeWord', value);
    notifyListeners();
  }

  Future<void> updateVr50_50ModeWord(String value) async {
    _vr50_50ModeWord = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('vr50_50ModeWord', value);
    notifyListeners();
  }

  Future<void> updatePipVrModeWord(String value) async {
    _pipVrModeWord = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('pipVrModeWord', value);
    notifyListeners();
  }

  Future<void> updatePipVrMode2Word(String value) async {
    _pipVrMode2Word = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('pipVrMode2Word', value);
    notifyListeners();
  }
}
