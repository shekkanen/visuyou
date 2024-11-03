// Copyright © 2024 Sami Hekkanen. All rights reserved.
import 'package:flutter/material.dart';

class PolicyPage extends StatelessWidget {
  final String title;
  final String content;

  const PolicyPage({Key? key, required this.title, required this.content})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black, // Match your app's theme
        iconTheme: const IconThemeData(
            color: Colors.grey), // Set back icon color to gray
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: SelectableText(
          content,
          style: const TextStyle(fontSize: 16.0),
        ),
        // Implement text selection
      ),
    );
  }
}
