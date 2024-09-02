import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _enableAudio = false;
  late SharedPreferences prefs;
  bool _enableNotifications = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {
      _enableAudio = prefs.getBool('enableAudio') ?? false;
    });
  }

  Future<void> _updateAudioSetting(bool value) async {
    setState(() {
      _enableAudio = value;
    });
    await prefs.setBool('enableAudio', value);
    // Consider using an event or callback to inform the app of the setting change
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Enable Audio'),
            value: _enableAudio,
            onChanged: _updateAudioSetting,
          ),
          SwitchListTile(
            title: const Text('Enable Notifications'),
            value: _enableNotifications,
            onChanged: (bool value) {
              setState(() {
                _enableNotifications = value;
              });
            },
          ),
          ListTile(
            title: const Text('Privacy Policy'),
            onTap: () {
              // Handle Privacy Policy Logic
            },
          ),
          ListTile(
            title: const Text('Terms of Service'),
            onTap: () {
              // Handle Terms of Service Logic
            },
          ),
        ],
      ),
    );
  }
}
