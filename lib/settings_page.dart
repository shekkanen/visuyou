// Copyright © 2024 Sami Hekkanen. All rights reserved.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'policy_page.dart'; // Import the PolicyPage widget
import 'policies.dart'; // Import the privacy policy and terms of service text

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _enableAudio = false;
  bool _enableVoiceCommands = true;
  late SharedPreferences prefs;

  // New: View Change Words
  final List<String> _viewChangeWords = ['next', 'green', 'red', 'one', 'six'];
  String _selectedViewChangeWord = 'next';


  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {
      _enableAudio = prefs.getBool('enableAudio') ?? false;
      _enableVoiceCommands = prefs.getBool('enableVoiceCommands') ?? true; // default is on
      _selectedViewChangeWord = prefs.getString('viewChangeWord') ?? 'next'; // Load saved word or default
    });
  }

  Future<void> _updateAudioSetting(bool value) async {
    setState(() {
      _enableAudio = value;
    });
    await prefs.setBool('enableAudio', value);
  }

  Future<void> _updateVoiceCommandSetting(bool value) async {
    setState(() {
      _enableVoiceCommands = value;
    });
    await prefs.setBool('enableVoiceCommands', value);
  }

  Future<void> _updateViewChangeWord(String? newWord) async {
    if (newWord != null) {
      setState(() {
        _selectedViewChangeWord = newWord;
      });
      await prefs.setString('viewChangeWord', newWord);
    }
  }

  void _navigateToPolicyPage(String title, String content) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PolicyPage(title: title, content: content),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.black, // Match your app's theme
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Enable Audio'),
            value: _enableAudio,
            onChanged: _updateAudioSetting,
          ),
          SwitchListTile(
            title: const Text('Enable Voice Commands'),
            value: _enableVoiceCommands,
            onChanged: _updateVoiceCommandSetting,
          ),
          ListTile(
            title: const Text('View Change Word'),
            subtitle: Text('Current: $_selectedViewChangeWord'),
            onTap: () async {
              String? selectedWord = await showDialog<String>(
                context: context,
                builder: (BuildContext context) {
                  return SimpleDialog(
                    title: const Text('Select View Change Word'),
                    children: _viewChangeWords.map((String word) {
                      return SimpleDialogOption(
                        onPressed: () {
                          Navigator.pop(context, word);
                        },
                        child: Text(word),
                      );
                    }).toList(),
                  );
                },
              );
              await _updateViewChangeWord(selectedWord);
            },
          ),
          ListTile(
            title: const Text('Privacy Policy'),
            onTap: () {
              _navigateToPolicyPage('Privacy Policy', privacyPolicy);
            },
          ),
          ListTile(
            title: const Text('Terms of Service'),
            onTap: () {
              _navigateToPolicyPage('Terms of Service', termsOfService);
            },
          ),
        ],
      ),
    );
  }
}
