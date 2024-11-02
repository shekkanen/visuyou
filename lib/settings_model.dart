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
  String _micEnabledWord = 'mic on';
  String _micDisableWord = 'mic off';
  String _speakerEnabledWord = 'speaker on';
  String _speakerDisableWord = 'speaker off';
  String _fullVrModeWord = 'mode one';
  String _fullVrMode2Word = 'mode two';
  String _vr50_50ModeWord = 'mode three';
  String _pipVrModeWord = 'mode four';
  String _pipVrMode2Word = 'mode five';

  // New boolean flags for enabling/disabling individual voice commands
  bool _viewNextCommandEnabled = true;
  bool _viewBackCommandEnabled = true;
  bool _micEnabledCommandEnabled = true;
  bool _micDisableCommandEnabled = true;
  bool _speakerEnabledCommandEnabled = true;
  bool _speakerDisableCommandEnabled = true;
  bool _fullVrModeCommandEnabled = true;
  bool _fullVrMode2CommandEnabled = true;
  bool _vr50_50ModeCommandEnabled = true;
  bool _pipVrModeCommandEnabled = true;
  bool _pipVrMode2CommandEnabled = true;

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
  String get fullVrMode2Word => _fullVrMode2Word;
  String get vr50_50ModeWord => _vr50_50ModeWord;
  String get pipVrModeWord => _pipVrModeWord;
  String get pipVrMode2Word => _pipVrMode2Word;

  // Getters for the new boolean flags
  bool get viewNextCommandEnabled => _viewNextCommandEnabled;
  bool get viewBackCommandEnabled => _viewBackCommandEnabled;
  bool get micEnabledCommandEnabled => _micEnabledCommandEnabled;
  bool get micDisableCommandEnabled => _micDisableCommandEnabled;
  bool get speakerEnabledCommandEnabled => _speakerEnabledCommandEnabled;
  bool get speakerDisableCommandEnabled => _speakerDisableCommandEnabled;
  bool get fullVrModeCommandEnabled => _fullVrModeCommandEnabled;
  bool get fullVrMode2CommandEnabled => _fullVrMode2CommandEnabled;
  bool get vr50_50ModeCommandEnabled => _vr50_50ModeCommandEnabled;
  bool get pipVrModeCommandEnabled => _pipVrModeCommandEnabled;
  bool get pipVrMode2CommandEnabled => _pipVrMode2CommandEnabled;

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
    _micEnabledWord = prefs.getString('micEnabledWord') ?? 'mic on';
    _micDisableWord = prefs.getString('micDisableWord') ?? 'mic off';
    _speakerEnabledWord = prefs.getString('speakerEnabledWord') ?? 'speaker on';
    _speakerDisableWord = prefs.getString('speakerDisableWord') ?? 'speaker off';
    _fullVrModeWord = prefs.getString('fullVrModeWord') ?? 'mode one';
    _fullVrMode2Word = prefs.getString('fullVrMode2Word') ?? 'mode two';
    _vr50_50ModeWord = prefs.getString('vr50_50ModeWord') ?? 'mode three';
    _pipVrModeWord = prefs.getString('pipVrModeWord') ?? 'mode four';
    _pipVrMode2Word = prefs.getString('pipVrMode2Word') ?? 'mode five';

    // Load the boolean flags for individual voice commands
    _viewNextCommandEnabled = prefs.getBool('viewNextCommandEnabled') ?? true;
    _viewBackCommandEnabled = prefs.getBool('viewBackCommandEnabled') ?? true;
    _micEnabledCommandEnabled = prefs.getBool('micEnabledCommandEnabled') ?? true;
    _micDisableCommandEnabled = prefs.getBool('micDisableCommandEnabled') ?? true;
    _speakerEnabledCommandEnabled = prefs.getBool('speakerEnabledCommandEnabled') ?? true;
    _speakerDisableCommandEnabled = prefs.getBool('speakerDisableCommandEnabled') ?? true;
    _fullVrModeCommandEnabled = prefs.getBool('fullVrModeCommandEnabled') ?? true;
    _fullVrMode2CommandEnabled = prefs.getBool('fullVrMode2CommandEnabled') ?? true;
    _vr50_50ModeCommandEnabled = prefs.getBool('vr50_50ModeCommandEnabled') ?? true;
    _pipVrModeCommandEnabled = prefs.getBool('pipVrModeCommandEnabled') ?? true;
    _pipVrMode2CommandEnabled = prefs.getBool('pipVrMode2CommandEnabled') ?? true;

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
    _micDisableWord = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('micDisableWord', value);
    notifyListeners();
  }

  Future<void> updateSpeakerEnabledWord(String value) async {
    _speakerEnabledWord = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('speakerEnabledWord', value);
    notifyListeners();
  }

  Future<void> updateSpeakerDisableWord(String value) async {
    _speakerDisableWord = value;
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

  Future<void> updateFullVrMode2Word(String value) async {
    _fullVrMode2Word = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('fullVrMode2Word', value);
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

  // New update methods for individual command enable flags
  Future<void> updateViewNextCommandEnabled(bool value) async {
    _viewNextCommandEnabled = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('viewNextCommandEnabled', value);
    notifyListeners();
  }

  Future<void> updateViewBackCommandEnabled(bool value) async {
    _viewBackCommandEnabled = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('viewBackCommandEnabled', value);
    notifyListeners();
  }

  Future<void> updateMicEnabledCommandEnabled(bool value) async {
    _micEnabledCommandEnabled = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('micEnabledCommandEnabled', value);
    notifyListeners();
  }

  Future<void> updateMicDisableCommandEnabled(bool value) async {
    _micDisableCommandEnabled = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('micDisableCommandEnabled', value);
    notifyListeners();
  }

  Future<void> updateSpeakerEnabledCommandEnabled(bool value) async {
    _speakerEnabledCommandEnabled = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('speakerEnabledCommandEnabled', value);
    notifyListeners();
  }

  Future<void> updateSpeakerDisableCommandEnabled(bool value) async {
    _speakerDisableCommandEnabled = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('speakerDisableCommandEnabled', value);
    notifyListeners();
  }

  Future<void> updateFullVrModeCommandEnabled(bool value) async {
    _fullVrModeCommandEnabled = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fullVrModeCommandEnabled', value);
    notifyListeners();
  }

  Future<void> updateFullVrMode2CommandEnabled(bool value) async {
    _fullVrMode2CommandEnabled = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fullVrMode2CommandEnabled', value);
    notifyListeners();
  }

  Future<void> updateVr50_50ModeCommandEnabled(bool value) async {
    _vr50_50ModeCommandEnabled = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vr50_50ModeCommandEnabled', value);
    notifyListeners();
  }

  Future<void> updatePipVrModeCommandEnabled(bool value) async {
    _pipVrModeCommandEnabled = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pipVrModeCommandEnabled', value);
    notifyListeners();
  }

  Future<void> updatePipVrMode2CommandEnabled(bool value) async {
    _pipVrMode2CommandEnabled = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pipVrMode2CommandEnabled', value);
    notifyListeners();
  }
}
