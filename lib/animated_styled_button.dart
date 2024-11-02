// lib/animated_styled_button.dart

import 'package:flutter/material.dart';

class AnimatedStyledButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isEnabled;

  const AnimatedStyledButton({
    Key? key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isEnabled = true,
  }) : super(key: key);

  @override
  _AnimatedStyledButtonState createState() => _AnimatedStyledButtonState();
}

class _AnimatedStyledButtonState extends State<AnimatedStyledButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.1,
    );

    _scaleAnimation =
        Tween<double>(begin: 1.0, end: 0.9).animate(_controller);
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.isEnabled) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.isEnabled) {
      _controller.reverse();
      widget.onPressed?.call();
    }
  }

  void _onTapCancel() {
    if (widget.isEnabled) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isEnabled ? _onTapDown : null,
      onTapUp: widget.isEnabled ? _onTapUp : null,
      onTapCancel: widget.isEnabled ? _onTapCancel : null,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.isEnabled ? Colors.black : Colors.grey, // Updated parameter
            foregroundColor: Colors.white, // Updated parameter
            padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 4.0),
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            elevation: widget.isEnabled ? 5 : 0,
          ),
          onPressed: widget.isEnabled ? widget.onPressed : null,
          icon: Icon(widget.icon),
          label: Text(widget.label),
        ),
      ),
    );
  }
}
