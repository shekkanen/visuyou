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
// View Change Words
static const List<String> viewChangeWords = ['next', 'forward'];
static const List<String> backWords = ['back', 'previous'];

// Mute/Unmute Mic Words
static const List<String> muteMicWords = ['mic off', 'disable mic'];
static const List<String> unmuteMicWords = ['mic on', 'enable mic'];

// Mute/Unmute Speaker Words
static const List<String> muteSpeakerWords = ['speaker off', 'disable speaker'];
static const List<String> unmuteSpeakerWords = ['speaker on', 'disable speaker'];

// Full VR Mode
static const List<String> fullVrModeWords = ['mode one','screen one'];

// 50/50 VR Mode
static const List<String> vr50_50ModeWords = ['mode two', 'screen two'];

// Picture in Picture VR Mode
static const List<String> pipVrModeWords = ['mode three', 'screen three'];

// Alternate Picture in Picture VR Mode
static const List<String> pipVrMode2Words = ['mode four', 'screen four'];


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
      title: const Text(
        'Settings',
        style: TextStyle(color: Colors.white),
      ),
      backgroundColor: Colors.black, // Match your app's theme
      iconTheme: const IconThemeData(color: Colors.grey), // Set back icon color to gray
      ),
      body: ListView(
          children: [
            SwitchListTile(
            title: const Text('Enable Mic'),
            value: settingsModel.micEnabled,
            onChanged: (value) => settingsModel.updatemicEnabled(value),
          ),
          SwitchListTile(
            title: const Text('Enable Speaker'),
            value: settingsModel.speakerEnabled,
            onChanged: (value) => settingsModel.updateSpeakerEnabled(value),
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
                    children: viewChangeWords.map((String word) {
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
                    children: backWords.map((String word) {
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
            title: const Text('Enable Mic Word'),
            subtitle: Text('Current: ${settingsModel.micEnabledWord}'),
            onTap: () async {
              String? selectedWord = await showDialog<String>(
                context: context,
                builder: (BuildContext context) {
                  return SimpleDialog(
                    title: const Text('Select Enable Mic Word'),
                    children: unmuteMicWords.map((String word) {
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
                await settingsModel.updatemicEnabledWord(selectedWord);
              }
            },
          ),
          ListTile(
            title: const Text('Disable Mic Word'),
            subtitle: Text('Current: ${settingsModel.micDisableWord}'),
            onTap: () async {
              String? selectedWord = await showDialog<String>(
                context: context,
                builder: (BuildContext context) {
                  return SimpleDialog(
                    title: const Text('Select Disable Mic Word'),
                    children: muteMicWords.map((String word) {
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
                await settingsModel.updatemicDisableWord(selectedWord);
              }
            },
          ),
          ListTile(
            title: const Text('Enable Speaker Word'),
            subtitle: Text('Current: ${settingsModel.speakerEnabledWord}'),
            onTap: () async {
              String? selectedWord = await showDialog<String>(
                context: context,
                builder: (BuildContext context) {
                  return SimpleDialog(
                    title: const Text('Select Enable Speaker Word'),
                    children: muteSpeakerWords.map((String word) {
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
                await settingsModel.updateSpeakerEnabledWord(selectedWord);
              }
            },
          ),
          ListTile(
            title: const Text('Disable Speaker Word'),
            subtitle: Text('Current: ${settingsModel.speakerDisableWord}'),
            onTap: () async {
              String? selectedWord = await showDialog<String>(
                context: context,
                builder: (BuildContext context) {
                  return SimpleDialog(
                    title: const Text('Select Disable Speaker Word'),
                    children: unmuteSpeakerWords.map((String word) {
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
                await settingsModel.updateSpeakerDisableWord(selectedWord);
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
                    children: fullVrModeWords.map((String word) {
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
                    children: vr50_50ModeWords.map((String word) {
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
                    children: pipVrModeWords.map((String word) {
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
                    children: pipVrMode2Words.map((String word) {
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
