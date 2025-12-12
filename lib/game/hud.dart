import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class Hud extends PositionComponent {
  int score = 0;
  double speedPercent = 0;
  bool hasShield = false;
  int multiplier = 1;
  int multiplierTimer = 0;
  bool timeWarpActive = false;
  int timeWarpTimer = 0;
  bool magnetActive = false;
  int magnetTimer = 0;
  bool scoreGlitch = false;
  bool isGrazing = false;

  final TextPaint _scoreTextPaint = TextPaint(
    style: const TextStyle(
      fontSize: 24.0,
      color: Color(0xFF00FF41),
      fontFamily: 'Share Tech Mono',
    ),
  );
  final TextPaint _subTextPaint = TextPaint(
    style: const TextStyle(
      fontSize: 16.0,
      color: Color(0xFF00FF41),
      fontFamily: 'Share Tech Mono',
    ),
  );

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Score
    _scoreTextPaint.render(
      canvas,
      'SCORE: ${score.toString().padLeft(6, '0')}',
      Vector2(size.x - 200, 20),
    );

    // Speed
    _subTextPaint.render(
      canvas,
      'SPEED: ${speedPercent.round()}%',
      Vector2(size.x - 200, 50),
    );

  }
}
