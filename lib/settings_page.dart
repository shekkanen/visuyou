import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _enableNotifications = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
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
