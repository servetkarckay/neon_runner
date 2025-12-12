import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_neon_runner/models/particle_data.dart';
import 'package:flutter_neon_runner/utils/spawner_utils.dart';
import 'dart:math'; // Import for Random
import 'dart:ui' as ui; // Import for ui.Rect

class ParticleManager extends Component {
  final List<ParticleData> _activeParticles = [];
  final List<ParticleData> _particlePool = [];

  @override
  void update(double dt) {
    super.update(dt);
    double timeScale = 1.0;

    for (int i = _activeParticles.length - 1; i >= 0; i--) {
      final p = _activeParticles[i];
      p.x += p.velocityX * timeScale;
      p.y += p.velocityY * timeScale;
      p.life -= 0.05;
      if (p.life <= 0) {
        _particlePool.add(_activeParticles.removeAt(i));
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    for (final p in _activeParticles) {
      final paint = Paint()
        ..color = p.color.withAlpha((255 * (p.life / p.maxLife)).round());
      canvas.drawRect(ui.Rect.fromLTWH(p.x, p.y, p.size, p.size), paint);
    }
  }

  void createExplosion(double x, double y, Color color, {int count = 20}) {
    for (int i = 0; i < count; i++) {
      _activeParticles.add(getParticleFromPool(
        _particlePool,
        x, y, (Random().nextDouble() - 0.5) * 10, (Random().nextDouble() - 0.5) * 10, color, Random().nextDouble() * 4 + 1, 1.0,
      ));
    }
  }

  void createDust(double x, double y) {
    if (Random().nextDouble() > 0.5) return;
    _activeParticles.add(getParticleFromPool(
      _particlePool,
      x + Random().nextDouble() * 20, y, -2 - Random().nextDouble() * 2, -0.5 - Random().nextDouble() * 1, const Color(0xFF004400), 2, 0.5,
    ));
  }

  void reset() {
    _activeParticles.forEach(_particlePool.add);
    _activeParticles.clear();
  }
}
