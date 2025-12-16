import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_neon_runner/game/neon_runner_game.dart';
import 'package:flutter_neon_runner/models/game_state.dart';
import 'package:flutter_neon_runner/models/powerup_data.dart';
import 'package:flutter_neon_runner/game/systems/spawner_system.dart'; // NEW import
import 'dart:ui' as ui; // Import for ui.Rect

class PowerUpManager extends Component {
  late final NeonRunnerGame _game;
  late final SpawnerSystem _spawnerSystem; // NEW instance

  final List<PowerUpData> _activePowerUps = [];
  final List<PowerUpData> _powerUpPool = [];

  PowerUpManager(this._game) {
    _spawnerSystem = SpawnerSystem(); // Initialize SpawnerSystem
  }

  void spawnPowerUp(double xOffset, {double? fixedY}) {
    final roll = Random().nextDouble();
    PowerUpType type = PowerUpType.shield;

    if (roll > 0.75) {
      type = PowerUpType.multiplier;
    } else if (roll > 0.55) {
      type = PowerUpType.timeWarp;
    } else if (roll > 0.40) {
      type = PowerUpType.magnet;
    }

    final y = fixedY ?? (_game.size.y - (Random().nextDouble() > 0.5 ? 90 : 40));
    final pu = _spawnerSystem.getPowerUpFromPool(_powerUpPool, type, _game.size.x + xOffset, y); // UPDATED call
    _activePowerUps.add(pu);
  }

  @override
  void update(double dt) {
    if (dt == 0) return;
    super.update(dt);
    
    final playerData = _game.playerData;
    final timeScale = playerData.timeWarpTimer > 0 ? 0.5 : 1.0;

    for (int i = _activePowerUps.length - 1; i >= 0; i--) {
      final pu = _activePowerUps[i];
      if (playerData.hasMagnet) {
        final dx = (playerData.x + playerData.width / 2) - (pu.x + pu.width / 2);
        final dy = (playerData.y + playerData.height / 2) - (pu.y + pu.height / 2);
        final dist = sqrt(dx * dx + dy * dy);
        if (dist < 400) {
          pu.x = pu.x + (dx / dist) * 15 * timeScale;
          pu.y = pu.y + (dy / dist) * 15 * timeScale;
        } else {
          pu.x = pu.x - _game.speed * timeScale;
          pu.y = pu.y + sin((_game.frames + pu.floatOffset) * 0.1) * 0.5 * timeScale;
        }
      } else {
        pu.x = pu.x - _game.speed * timeScale;
        pu.y = pu.y + sin((_game.frames + pu.floatOffset) * 0.1) * 0.5 * timeScale;
      }
      if (pu.x + pu.width < -50) {
        _powerUpPool.add(_activePowerUps.removeAt(i));
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    for (final pu in _activePowerUps) {
      final paint = Paint()
        ..style = PaintingStyle.fill;

      // Apply shadowBlur equivalent
      canvas.drawShadow(
        Path()..addRect(ui.Rect.fromLTWH(pu.x, pu.y, pu.width, pu.height)),
        Colors.white.withAlpha((255 * 0.5).round()), // Base shadow color
        15, // blurRadius
        false, // transparentOccluder
      );

      final textPainter = TextPainter(
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling, // Ensure no scaling issues
      );
      final textStyle = const TextStyle(
        fontSize: 16.0,
        fontFamily: 'Orbitron', // Using Orbitron for power-up text
        fontWeight: FontWeight.bold,
        color: Colors.black, // Text color for contrast
      );

      switch (pu.type) {
        case PowerUpType.shield:
          paint.color = const Color(0xFF00FFFF);
          canvas.drawCircle(Offset(pu.x + pu.width / 2, pu.y + pu.height / 2), 12, paint);
          textPainter.text = TextSpan(text: 'S', style: textStyle);
          textPainter.layout();
          textPainter.paint(canvas, Offset(pu.x + pu.width / 2 - textPainter.width / 2, pu.y + pu.height / 2 - textPainter.height / 2));
          break;
        case PowerUpType.multiplier:
          paint.color = const Color(0xFFFFFF00);
          final path = Path()
            ..moveTo(pu.x + pu.width / 2, pu.y)
            ..lineTo(pu.x + pu.width, pu.y + pu.height / 2)
            ..lineTo(pu.x + pu.width / 2, pu.y + pu.height)
            ..lineTo(pu.x, pu.y + pu.height / 2)
            ..close();
          canvas.drawPath(path, paint);
          textPainter.text = TextSpan(text: 'x2', style: textStyle);
          textPainter.layout();
          textPainter.paint(canvas, Offset(pu.x + pu.width / 2 - textPainter.width / 2, pu.y + pu.height / 2 - textPainter.height / 2));
          break;
        case PowerUpType.timeWarp:
          paint.color = const Color(0xFFAA00FF);
          final path = Path()
            ..moveTo(pu.x, pu.y)
            ..lineTo(pu.x + pu.width, pu.y + pu.height / 2)
            ..lineTo(pu.x, pu.y + pu.height)
            ..close();
          canvas.drawPath(path, paint);
          textPainter.text = TextSpan(text: '>>', style: textStyle);
          textPainter.layout();
          textPainter.paint(canvas, Offset(pu.x + pu.width / 2 - textPainter.width / 2, pu.y + pu.height / 2 - textPainter.height / 2));
          break;
        case PowerUpType.magnet:
          paint.color = const Color(0xFFFF00FF);
          final center = Offset(pu.x + pu.width / 2, pu.y + pu.height / 2);
          final magnetRadius = pu.width / 2;
          final magnetThickness = pu.width * 0.3;

          final magnetPath = Path()
            ..arcTo(
              ui.Rect.fromCircle(center: center, radius: magnetRadius),
              pi, // Start angle (180 degrees)
              -pi, // Sweep angle (180 degrees counter-clockwise)
              false,
            ) // Top arc
            ..lineTo(center.dx + magnetRadius, center.dy + magnetThickness)
            ..arcTo(
              ui.Rect.fromCircle(center: center, radius: magnetRadius - magnetThickness),
              0, // Start angle (0 degrees)
              pi, // Sweep angle (180 degrees clockwise)
              false,
            ) // Inner arc
            ..lineTo(center.dx - magnetRadius, center.dy)
            ..close();
          canvas.drawPath(magnetPath, paint);
          break;
      }
    }
  }

  void reset() {
    _activePowerUps.forEach(_powerUpPool.add);
    _activePowerUps.clear();
  }

  List<PowerUpData> get activePowerUps => _activePowerUps;
}
