import 'package:flutter/material.dart';

class VignetteEffect extends StatelessWidget {
  const VignetteEffect({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              Colors.transparent,
              Colors.transparent,
              Colors.black.withAlpha((255 * 0.8).round()),
            ],
            stops: const [0.6, 0.8, 1.0], // Adjust stops for desired effect
          ),
        ),
      ),
    );
  }
}