// lib/settings_model.dart
// Copyright © 2024 Sami Hekkanen. All rights reserved.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class SettingsModel extends ChangeNotifier {
  bool _enableAudio = false;
  bool _enableVoiceCommands = true;

  // Voice command keywords
  String _viewNextWord = 'next';
  String _viewBackWord = 'back';
  String _enableAudioWord = 'enable audio voice command';
  String _fullVrModeWord = 'full vr mode';
  String _vr50_50ModeWord = '50/50 vr mode';
  String _pipVrModeWord = 'pip vr mode';
  String _pipVrMode2Word = 'pip vr mode2';

  // Getters
  bool get enableAudio => _enableAudio;
  bool get enableVoiceCommands => _enableVoiceCommands;

  String get viewNextWord => _viewNextWord;
  String get viewBackWord => _viewBackWord;
  String get enableAudioWord => _enableAudioWord;
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
    _enableAudio = prefs.getBool('enableAudio') ?? false;
    _enableVoiceCommands = prefs.getBool('enableVoiceCommands') ?? true;

    _viewNextWord = prefs.getString('viewNextWord') ?? 'next';
    _viewBackWord = prefs.getString('viewBackWord') ?? 'back';
    _enableAudioWord = prefs.getString('enableAudioWord') ?? 'enable audio voice command';
    _fullVrModeWord = prefs.getString('fullVrModeWord') ?? 'full vr mode';
    _vr50_50ModeWord = prefs.getString('vr50_50ModeWord') ?? '50/50 vr mode';
    _pipVrModeWord = prefs.getString('pipVrModeWord') ?? 'pip vr mode';
    _pipVrMode2Word = prefs.getString('pipVrMode2Word') ?? 'pip vr mode2';

    _settingsLoadedCompleter.complete(); // Signal that settings are loaded
    notifyListeners();
  }

  
  Future<void> get settingsLoaded => _settingsLoadedCompleter.future;

  // Update methods

  Future<void> updateEnableAudio(bool value) async {
    _enableAudio = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enableAudio', value);
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

  Future<void> updateEnableAudioWord(String value) async {
    _enableAudioWord = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('enableAudioWord', value);
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
