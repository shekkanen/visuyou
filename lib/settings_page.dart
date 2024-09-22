import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'policy_page.dart'; // Import the PolicyPage widget

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

  // Privacy Policy Text
  final String _privacyPolicyText = '''
**Privacy Policy**

_Last updated: October 1, 2023_

**1. Introduction**

Welcome to **VisuYou** ("we", "us", or "our"). We are committed to respecting your privacy. This Privacy Policy outlines how we handle any information collected when you use our mobile application ("the App").

**2. Information We Do Not Collect**

- **Personal Data**: We do not collect, store, or process any personal information.
- **Usage Data**: We do not track or record your usage patterns within the App.
- **Cookies and Tracking Technologies**: We do not use cookies or similar tracking technologies.

**3. Data Transmission**

The App establishes a direct peer-to-peer (P2P) connection between devices for streaming purposes. No data is routed through our servers.

**4. Third-Party Services**

Our App may use third-party libraries or services that have their own privacy policies. Please refer to their respective privacy policies for more information.

**5. Children's Privacy**

Our App does not target anyone under the age of 13. We do not knowingly collect personal information from children under 13.

**6. Changes to This Privacy Policy**

We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy within the App.

**7. Contact Us**

If you have any questions about this Privacy Policy, please contact us at:

[Your Contact Information]
''';

  // Terms of Service Text
  final String _termsOfServiceText = '''
**Terms of Service**

_Last updated: October 1, 2023_

**1. Acceptance of Terms**

By downloading or using **VisuYou** ("the App"), you agree to be bound by these Terms of Service ("Terms"). If you do not agree to these Terms, please do not use the App.

**2. Description of the App**

VisuYou allows users to engage in a peer-to-peer virtual reality experience using WebRTC technology. The App facilitates direct connections between devices without the use of a central server.

**3. Use of the App**

- **Compliance with Laws**: You agree to use the App in compliance with all applicable laws and regulations.
- **Age Requirement**: You must be at least 13 years old to use the App.
- **Prohibited Conduct**: You agree not to misuse the App, including but not limited to transmitting harmful content or interfering with other users' enjoyment of the App.

**4. Health and Safety Warning**

**WARNING:**

- **Risk of Injury**: Using virtual reality headsets may cause motion sickness, disorientation, dizziness, nausea, or other discomfort. If you experience any adverse symptoms, stop using the App immediately.
- **Physical Hazards**: Be aware of your surroundings. Using the App with a VR headset may impair your ability to perceive real-world environments, leading to potential accidents or injuries.
- **Supervision of Minors**: If minors use the App, they should do so under adult supervision.

**5. Disclaimer of Warranties**

The App is provided on an "AS IS" and "AS AVAILABLE" basis. We make no warranties, express or implied, regarding the App's operation or your use of it.

**6. Limitation of Liability**

To the fullest extent permitted by law, we shall not be liable for any indirect, incidental, special, consequential, or punitive damages, including but not limited to physical injury, loss of data, or other intangible losses resulting from:

- Your access to or use of the App.
- Any conduct or content of any third party within the App.
- Unauthorized access, use, or alteration of your transmissions or content.

**7. Indemnification**

You agree to indemnify and hold harmless VisuYou and its affiliates from any claims, liabilities, damages, losses, and expenses arising out of your use of the App.

**8. Changes to the Terms**

We reserve the right to modify these Terms at any time. We will notify you of any changes by posting the new Terms within the App. Your continued use of the App after changes signifies your acceptance of the new Terms.

**9. Governing Law**

These Terms shall be governed by and construed in accordance with the laws of [Your Country/State], without regard to its conflict of law provisions.

**10. Contact Us**

If you have any questions about these Terms, please contact us at:

[Your Contact Information]
''';

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
              _navigateToPolicyPage('Privacy Policy', _privacyPolicyText);
            },
          ),
          ListTile(
            title: const Text('Terms of Service'),
            onTap: () {
              _navigateToPolicyPage('Terms of Service', _termsOfServiceText);
            },
          ),
        ],
      ),
    );
  }
}
