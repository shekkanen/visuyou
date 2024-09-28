// lib/settings_page.dart
// Copyright © 2024 Sami Hekkanen. All rights reserved.

import 'package:flutter/material.dart';
import 'policy_page.dart'; // Import the PolicyPage widget
import 'policies.dart'; // Import the privacy policy and terms of service text
import 'package:provider/provider.dart'; // Import provider
import 'settings_model.dart'; // Import settings model

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  // View Change Words
  static const List<String> _viewChangeWords = ['next', 'green', 'red', 'one', 'six'];
  static const List<String> _backWords = ['back', 'previous', 'reverse', 'left', 'right'];
  static const List<String> _enableAudioWords = ['enable audio', 'audio on', 'mute', 'unmute'];
  static const List<String> _fullVrModeWords = ['full vr mode', 'full mode', 'full screen'];
  static const List<String> _vr50_50ModeWords = ['50/50 vr mode', 'split screen', 'half mode'];
  static const List<String> _pipVrModeWords = ['pip vr mode', 'picture in picture', 'pip mode'];
  static const List<String> _pipVrMode2Words = ['pip vr mode2', 'pip mode2', 'alternate pip'];

  void _navigateToPolicyPage(BuildContext context, String title, String content) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PolicyPage(title: title, content: content),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsModel = Provider.of<SettingsModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.black, // Match your app's theme
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Enable Audio'),
            value: settingsModel.enableAudio,
            onChanged: (value) => settingsModel.updateEnableAudio(value),
          ),
          SwitchListTile(
            title: const Text('Enable Voice Commands'),
            value: settingsModel.enableVoiceCommands,
            onChanged: (value) => settingsModel.updateEnableVoiceCommands(value),
          ),
          ListTile(
            title: const Text('View Next Word'),
            subtitle: Text('Current: ${settingsModel.viewNextWord}'),
            onTap: () async {
              String? selectedWord = await showDialog<String>(
                context: context,
                builder: (BuildContext context) {
                  return SimpleDialog(
                    title: const Text('Select View Next Word'),
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
              if (selectedWord != null) {
                await settingsModel.updateViewNextWord(selectedWord);
              }
            },
          ),
          ListTile(
            title: const Text('View Back Word'),
            subtitle: Text('Current: ${settingsModel.viewBackWord}'),
            onTap: () async {
              String? selectedWord = await showDialog<String>(
                context: context,
                builder: (BuildContext context) {
                  return SimpleDialog(
                    title: const Text('Select View Back Word'),
                    children: _backWords.map((String word) {
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
              if (selectedWord != null) {
                await settingsModel.updateViewBackWord(selectedWord);
              }
            },
          ),
          ListTile(
            title: const Text('Enable Audio Word'),
            subtitle: Text('Current: ${settingsModel.enableAudioWord}'),
            onTap: () async {
              String? selectedWord = await showDialog<String>(
                context: context,
                builder: (BuildContext context) {
                  return SimpleDialog(
                    title: const Text('Select Enable Audio Word'),
                    children: _enableAudioWords.map((String word) {
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
              if (selectedWord != null) {
                await settingsModel.updateEnableAudioWord(selectedWord);
              }
            },
          ),
          ListTile(
            title: const Text('Full VR Mode Word'),
            subtitle: Text('Current: ${settingsModel.fullVrModeWord}'),
            onTap: () async {
              String? selectedWord = await showDialog<String>(
                context: context,
                builder: (BuildContext context) {
                  return SimpleDialog(
                    title: const Text('Select Full VR Mode Word'),
                    children: _fullVrModeWords.map((String word) {
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
              if (selectedWord != null) {
                await settingsModel.updateFullVrModeWord(selectedWord);
              }
            },
          ),
          ListTile(
            title: const Text('50/50 VR Mode Word'),
            subtitle: Text('Current: ${settingsModel.vr50_50ModeWord}'),
            onTap: () async {
              String? selectedWord = await showDialog<String>(
                context: context,
                builder: (BuildContext context) {
                  return SimpleDialog(
                    title: const Text('Select 50/50 VR Mode Word'),
                    children: _vr50_50ModeWords.map((String word) {
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
              if (selectedWord != null) {
                await settingsModel.updateVr50_50ModeWord(selectedWord);
              }
            },
          ),
          ListTile(
            title: const Text('PiP VR Mode Word'),
            subtitle: Text('Current: ${settingsModel.pipVrModeWord}'),
            onTap: () async {
              String? selectedWord = await showDialog<String>(
                context: context,
                builder: (BuildContext context) {
                  return SimpleDialog(
                    title: const Text('Select PiP VR Mode Word'),
                    children: _pipVrModeWords.map((String word) {
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
              if (selectedWord != null) {
                await settingsModel.updatePipVrModeWord(selectedWord);
              }
            },
          ),
          ListTile(
            title: const Text('PiP VR Mode2 Word'),
            subtitle: Text('Current: ${settingsModel.pipVrMode2Word}'),
            onTap: () async {
              String? selectedWord = await showDialog<String>(
                context: context,
                builder: (BuildContext context) {
                  return SimpleDialog(
                    title: const Text('Select PiP VR Mode2 Word'),
                    children: _pipVrMode2Words.map((String word) {
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
              if (selectedWord != null) {
                await settingsModel.updatePipVrMode2Word(selectedWord);
              }
            },
          ),
          ListTile(
            title: const Text('Privacy Policy'),
            onTap: () {
              _navigateToPolicyPage(context, 'Privacy Policy', privacyPolicy);
            },
          ),
          ListTile(
            title: const Text('Terms of Service'),
            onTap: () {
              _navigateToPolicyPage(context, 'Terms of Service', termsOfService);
            },
          ),
        ],
      ),
    );
  }
}
