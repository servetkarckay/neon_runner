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
              Colors.black.withAlpha((255 * GameConfig.overlayBackgroundAlpha).round()), // Using overlay background alpha for consistency
            ],
            stops: const [GameConfig.vignetteStop1, GameConfig.vignetteStop2, GameConfig.vignetteStop3],
          ),
        ),
      ),
    );
  }
}