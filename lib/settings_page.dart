// lib/settings_page.dart
// Copyright © 2024 Sami Hekkanen. All rights reserved.

import 'package:flutter/material.dart';
import 'policy_page.dart'; // Import the PolicyPage widget
import 'policies.dart'; // Import the privacy policy and terms of service text
import 'package:provider/provider.dart'; // Import provider
import 'settings_model.dart'; // Import settings model

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  // New: View Change Words
  final List<String> _viewChangeWords = ['next', 'green', 'red', 'one', 'six'];

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
            title: const Text('View Change Word'),
            subtitle: Text('Current: ${settingsModel.selectedViewChangeWord}'),
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
              if (selectedWord != null) {
                await settingsModel.updateViewChangeWord(selectedWord);
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
