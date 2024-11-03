// lib/about_page.dart
// Copyright © 2024 Sami Hekkanen. All rights reserved.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Import the url_launcher package
import 'generated/dependencies.dart'; // Import the generated dependencies

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Sort the dependencies alphabetically
    final sortedDependencies = dependencies.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'About VisuYou',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black, // Match your app's theme
        iconTheme: const IconThemeData(
            color: Colors.grey), // Set the back icon color to gray
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'VisuYou - True P2P VR Experience',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const SelectableText(
              'This application provides a peer-to-peer VR streaming experience using WebRTC and Flutter. It is designed to be simple, reliable, and efficient, providing high-quality VR experiences across various devices.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            const Text(
              '© 2024 Sami Hekkanen. All rights reserved.',
              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () async {
                final Uri url =
                    Uri.parse('https://buymeacoffee.com/samihekkanen');
                if (!await launchUrl(url)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open the link.')),
                  );
                }
              },
              child: const Text(
                'Buy Me a Coffee (External Link)',
                style: TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Dependencies:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: sortedDependencies.length,
                itemBuilder: (context, index) {
                  final packageName = sortedDependencies[index];
                  final version = dependencies[packageName];
                  return ListTile(
                    title: Text(packageName),
                    subtitle: Text('Version: $version'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
