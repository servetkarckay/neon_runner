import 'package:flutter/material.dart'; // For Color

class ParticleData {
  double x;
  double y;
  double velocityX;
  double velocityY;
  double life;
  double maxLife;
  Color color;
  double size;

  ParticleData({
    required this.x,
    required this.y,
    required this.velocityX,
    required this.velocityY,
    required this.life,
    required this.maxLife,
    required this.color,
    required this.size,
  });

  void reset() {
    x = 0;
    y = 0;
    velocityX = 0;
    velocityY = 0;
    life = 0;
    maxLife = 0;
    color = Colors.transparent;
    size = 0;
  }
}
