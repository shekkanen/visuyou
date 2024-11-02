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
  static const List<String> viewNextWords = ['next', 'forward'];
  static const List<String> viewBackWords = ['back', 'previous'];

  // Mute/Unmute Mic Words
  static const List<String> micOffWords = ['mic off', 'disable mic'];
  static const List<String> micOnWords = ['mic on', 'enable mic'];

  // Mute/Unmute Speaker Words
  static const List<String> speakerOffWords = ['speaker off', 'disable speaker'];
  static const List<String> speakerOnWords = ['speaker on', 'enable speaker'];

  // VR Mode Words
  static const List<String> fullVrModeWords = ['mode one', 'screen one'];
  static const List<String> fullVrMode2Words = ['mode two', 'screen two'];
  static const List<String> vr50_50ModeWords = ['mode three', 'screen three'];

  // Picture in Picture VR Mode
  static const List<String> pipVrModeWords = ['mode four', 'screen four'];

  // Alternate Picture in Picture VR Mode
  static const List<String> pipVrMode2Words = ['mode five', 'screen five'];

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
          const Divider(),
          const ListTile(
            title: Text(
              'Voice Command Settings',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          // View Next Command
          SwitchListTile(
            title: const Text('Enable "View Next" Command'),
            value: settingsModel.viewNextCommandEnabled,
            onChanged: (value) => settingsModel.updateViewNextCommandEnabled(value),
          ),
          ListTile(
            title: const Text('View Next Word'),
            subtitle: Text('Current: ${settingsModel.viewNextWord}'),
            enabled: settingsModel.viewNextCommandEnabled,
            onTap: settingsModel.viewNextCommandEnabled
                ? () async {
                    String? selectedWord = await showDialog<String>(
                      context: context,
                      builder: (BuildContext context) {
                        return SimpleDialog(
                          title: const Text('Select View Next Word'),
                          children: viewNextWords.map((String word) {
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
                  }
                : null,
          ),

          // View Back Command
          SwitchListTile(
            title: const Text('Enable "View Back" Command'),
            value: settingsModel.viewBackCommandEnabled,
            onChanged: (value) => settingsModel.updateViewBackCommandEnabled(value),
          ),
          ListTile(
            title: const Text('View Back Word'),
            subtitle: Text('Current: ${settingsModel.viewBackWord}'),
            enabled: settingsModel.viewBackCommandEnabled,
            onTap: settingsModel.viewBackCommandEnabled
                ? () async {
                    String? selectedWord = await showDialog<String>(
                      context: context,
                      builder: (BuildContext context) {
                        return SimpleDialog(
                          title: const Text('Select View Back Word'),
                          children: viewBackWords.map((String word) {
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
                  }
                : null,
          ),

          // Mic On Command
          SwitchListTile(
            title: const Text('Enable "Mic On" Command'),
            value: settingsModel.micEnabledCommandEnabled,
            onChanged: (value) => settingsModel.updateMicEnabledCommandEnabled(value),
          ),
          ListTile(
            title: const Text('Enable Mic Word'),
            subtitle: Text('Current: ${settingsModel.micEnabledWord}'),
            enabled: settingsModel.micEnabledCommandEnabled,
            onTap: settingsModel.micEnabledCommandEnabled
                ? () async {
                    String? selectedWord = await showDialog<String>(
                      context: context,
                      builder: (BuildContext context) {
                        return SimpleDialog(
                          title: const Text('Select Enable Mic Word'),
                          children: micOnWords.map((String word) {
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
                  }
                : null,
          ),

          // Mic Off Command
          SwitchListTile(
            title: const Text('Enable "Mic Off" Command'),
            value: settingsModel.micDisableCommandEnabled,
            onChanged: (value) => settingsModel.updateMicDisableCommandEnabled(value),
          ),
          ListTile(
            title: const Text('Disable Mic Word'),
            subtitle: Text('Current: ${settingsModel.micDisableWord}'),
            enabled: settingsModel.micDisableCommandEnabled,
            onTap: settingsModel.micDisableCommandEnabled
                ? () async {
                    String? selectedWord = await showDialog<String>(
                      context: context,
                      builder: (BuildContext context) {
                        return SimpleDialog(
                          title: const Text('Select Disable Mic Word'),
                          children: micOffWords.map((String word) {
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
                  }
                : null,
          ),

          // Speaker On Command
          SwitchListTile(
            title: const Text('Enable "Speaker On" Command'),
            value: settingsModel.speakerEnabledCommandEnabled,
            onChanged: (value) => settingsModel.updateSpeakerEnabledCommandEnabled(value),
          ),
          ListTile(
            title: const Text('Enable Speaker Word'),
            subtitle: Text('Current: ${settingsModel.speakerEnabledWord}'),
            enabled: settingsModel.speakerEnabledCommandEnabled,
            onTap: settingsModel.speakerEnabledCommandEnabled
                ? () async {
                    String? selectedWord = await showDialog<String>(
                      context: context,
                      builder: (BuildContext context) {
                        return SimpleDialog(
                          title: const Text('Select Enable Speaker Word'),
                          children: speakerOnWords.map((String word) {
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
                  }
                : null,
          ),

          // Speaker Off Command
          SwitchListTile(
            title: const Text('Enable "Speaker Off" Command'),
            value: settingsModel.speakerDisableCommandEnabled,
            onChanged: (value) => settingsModel.updateSpeakerDisableCommandEnabled(value),
          ),
          ListTile(
            title: const Text('Disable Speaker Word'),
            subtitle: Text('Current: ${settingsModel.speakerDisableWord}'),
            enabled: settingsModel.speakerDisableCommandEnabled,
            onTap: settingsModel.speakerDisableCommandEnabled
                ? () async {
                    String? selectedWord = await showDialog<String>(
                      context: context,
                      builder: (BuildContext context) {
                        return SimpleDialog(
                          title: const Text('Select Disable Speaker Word'),
                          children: speakerOffWords.map((String word) {
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
                  }
                : null,
          ),

          // Full VR Mode Command
          SwitchListTile(
            title: const Text('Enable "Full VR Mode" Command'),
            value: settingsModel.fullVrModeCommandEnabled,
            onChanged: (value) => settingsModel.updateFullVrModeCommandEnabled(value),
          ),
          ListTile(
            title: const Text('Full VR Mode Word'),
            subtitle: Text('Current: ${settingsModel.fullVrModeWord}'),
            enabled: settingsModel.fullVrModeCommandEnabled,
            onTap: settingsModel.fullVrModeCommandEnabled
                ? () async {
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
                  }
                : null,
          ),

          // Full VR Mode2 Command
          SwitchListTile(
            title: const Text('Enable "Full VR Mode2" Command'),
            value: settingsModel.fullVrMode2CommandEnabled,
            onChanged: (value) => settingsModel.updateFullVrMode2CommandEnabled(value),
          ),
          ListTile(
            title: const Text('Full VR Mode2 Word'),
            subtitle: Text('Current: ${settingsModel.fullVrMode2Word}'),
            enabled: settingsModel.fullVrMode2CommandEnabled,
            onTap: settingsModel.fullVrMode2CommandEnabled
                ? () async {
                    String? selectedWord = await showDialog<String>(
                      context: context,
                      builder: (BuildContext context) {
                        return SimpleDialog(
                          title: const Text('Select Full VR Mode2 Word'),
                          children: fullVrMode2Words.map((String word) {
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
                      await settingsModel.updateFullVrMode2Word(selectedWord);
                    }
                  }
                : null,
          ),

          // 50/50 VR Mode Command
          SwitchListTile(
            title: const Text('Enable "50/50 VR Mode" Command'),
            value: settingsModel.vr50_50ModeCommandEnabled,
            onChanged: (value) => settingsModel.updateVr50_50ModeCommandEnabled(value),
          ),
          ListTile(
            title: const Text('50/50 VR Mode Word'),
            subtitle: Text('Current: ${settingsModel.vr50_50ModeWord}'),
            enabled: settingsModel.vr50_50ModeCommandEnabled,
            onTap: settingsModel.vr50_50ModeCommandEnabled
                ? () async {
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
                  }
                : null,
          ),

          // PiP VR Mode Command
          SwitchListTile(
            title: const Text('Enable "PiP VR Mode" Command'),
            value: settingsModel.pipVrModeCommandEnabled,
            onChanged: (value) => settingsModel.updatePipVrModeCommandEnabled(value),
          ),
          ListTile(
            title: const Text('PiP VR Mode Word'),
            subtitle: Text('Current: ${settingsModel.pipVrModeWord}'),
            enabled: settingsModel.pipVrModeCommandEnabled,
            onTap: settingsModel.pipVrModeCommandEnabled
                ? () async {
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
                  }
                : null,
          ),

          // PiP VR Mode2 Command
          SwitchListTile(
            title: const Text('Enable "PiP VR Mode2" Command'),
            value: settingsModel.pipVrMode2CommandEnabled,
            onChanged: (value) => settingsModel.updatePipVrMode2CommandEnabled(value),
          ),
          ListTile(
            title: const Text('PiP VR Mode2 Word'),
            subtitle: Text('Current: ${settingsModel.pipVrMode2Word}'),
            enabled: settingsModel.pipVrMode2CommandEnabled,
            onTap: settingsModel.pipVrMode2CommandEnabled
                ? () async {
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
                  }
                : null,
          ),

          const Divider(),
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
