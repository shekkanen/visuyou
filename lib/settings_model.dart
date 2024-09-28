// lib/settings_model.dart
// Copyright © 2024 Sami Hekkanen. All rights reserved.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsModel extends ChangeNotifier {
  bool _enableAudio = false;
  bool _enableVoiceCommands = true;
  String _selectedViewChangeWord = 'next';

  bool get enableAudio => _enableAudio;
  bool get enableVoiceCommands => _enableVoiceCommands;
  String get selectedViewChangeWord => _selectedViewChangeWord;

  SettingsModel() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _enableAudio = prefs.getBool('enableAudio') ?? false;
    _enableVoiceCommands = prefs.getBool('enableVoiceCommands') ?? true;
    _selectedViewChangeWord = prefs.getString('viewChangeWord') ?? 'next';
    notifyListeners();
  }

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

  Future<void> updateViewChangeWord(String value) async {
    _selectedViewChangeWord = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('viewChangeWord', value);
    notifyListeners();
  }
}
