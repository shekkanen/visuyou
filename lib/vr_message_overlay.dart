// vr_message_overlay.dart

import 'package:flutter/material.dart';

class VRMessageOverlay extends StatelessWidget {
  final String message;

  const VRMessageOverlay({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        color: Colors.black54, // Semi-transparent background
        padding: const EdgeInsets.all(16.0),
        child: Text(
          message,
          style: const TextStyle(
            fontSize: 24.0,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
