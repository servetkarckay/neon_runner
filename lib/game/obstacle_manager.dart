import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_neon_runner/config/game_config.dart';
import 'package:flutter_neon_runner/models/game_state.dart';
import 'package:flutter_neon_runner/models/obstacle_data.dart';
import 'package:flutter_neon_runner/game/systems/obstacle_system.dart'; // NEW import for ObstacleSystem
import 'dart:ui' as ui; // Import for ui.Rect

class ObstacleManager extends Component {
  late final ObstacleSystem _obstacleSystem; // Dependency on ObstacleSystem
  int _obstacleIdCounter = 0;

  ObstacleManager(this._obstacleSystem); // Inject ObstacleSystem

  // Delegate getters to ObstacleSystem
  List<ObstacleData> get activeObstacles => _obstacleSystem.activeObstacles;
  int get obstacleIdCounter => _obstacleIdCounter;

  void spawnObstacle(ObstacleData obstacle) {
    obstacle.id = ++_obstacleIdCounter;
    // Delegate to ObstacleSystem
    _obstacleSystem.addObstacle(obstacle);
  }

  void reset() {
    _obstacleIdCounter = 0;
    // Reset the obstacle system as well
    _obstacleSystem.reset();
  }

  @override
  void update(double dt) {
    if (dt == 0) return;
    super.update(dt);

    // Update the obstacle system
    _obstacleSystem.update(dt);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    for (final obs in _obstacleSystem.activeObstacles) { // Use _obstacleSystem.activeObstacles
      final paint = Paint();
      paint.color = Colors.red; // Default color for obstacles

      if (obs.type == ObstacleType.hazardZone) {
        paint.color = const Color.fromRGBO(255, 0, 0, 0.4);
        canvas.drawRect(obs.toRect(), paint);

        final strokePaint = Paint()
          ..color = Colors.red
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawRect(obs.toRect(), strokePaint);
      } else if (obs.type == ObstacleType.fallingDrop) {
        paint.color = Colors.orange;
        canvas.drawCircle(
          ui.Offset(obs.x + obs.width / 2, obs.y + obs.height / 2),
          obs.width / 2,
          paint,
        );
      } else if (obs.type == ObstacleType.aerial ||
          obs.type == ObstacleType.movingAerial) {
        paint.color = const Color(0xFFFF0055);
        final path = Path()
          ..moveTo(obs.x + obs.width / 2, obs.y)
          ..lineTo(obs.x + obs.width, obs.y + obs.height / 2)
          ..lineTo(obs.x + obs.width / 2, obs.y + obs.height)
          ..lineTo(obs.x, obs.y + obs.height / 2)
          ..close();
        canvas.drawPath(path, paint);
      } else if (obs.type == ObstacleType.platform ||
          obs.type == ObstacleType.movingPlatform) {
        paint.color = const Color(0xFF0088FF);
        canvas.drawRect(obs.toRect(), paint);
      } else if (obs.type == ObstacleType.rotatingLaser) {
        paint.color = const Color(0xFF333333);
        canvas.drawRect(obs.toRect(), paint);
        final laserPaint = Paint()
          ..color = Colors.red
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke;
        final laserCenter = ui.Offset(
          obs.x + obs.width / 2,
          obs.y + obs.height / 2,
        );
        final rotatingObs = obs as RotatingLaserObstacleData;
        final laserEndX =
            laserCenter.dx + cos(rotatingObs.angle) * rotatingObs.beamLength;
        final laserEndY =
            laserCenter.dy + sin(rotatingObs.angle) * rotatingObs.beamLength;
        canvas.drawLine(
          laserCenter,
          ui.Offset(laserEndX, laserEndY),
          laserPaint,
        );
      } else if (obs.type == ObstacleType.laserGrid) {
        paint.color = Colors.red.withAlpha((255 * 0.2).round());
        final laserGridObs = obs as LaserGridObstacleData;
        final topHeight = laserGridObs.gapY - laserGridObs.gapHeight / 2;
        final bottomY = laserGridObs.gapY + laserGridObs.gapHeight / 2;
        canvas.drawRect(
          ui.Rect.fromLTWH(obs.x, 0, obs.width, topHeight),
          paint,
        );
        canvas.drawRect(
          ui.Rect.fromLTWH(
            obs.x,
            bottomY,
            obs.width,
            GameConfig.groundLevel - bottomY,
          ),
          paint,
        );
      } else if (obs.type == ObstacleType.spike) {
        paint.color = Colors.red;
        final path = Path()
          ..moveTo(obs.x, obs.y + obs.height)
          ..lineTo(obs.x + obs.width / 2, obs.y)
          ..lineTo(obs.x + obs.width, obs.y + obs.height)
          ..close();
        canvas.drawPath(path, paint);
      } else {
        canvas.drawRect(obs.toRect(), paint);
      }

      // Debug: Draw obstacle hitbox
      if (GameConfig.debugShowHitboxes) {
        final hitboxPaint = Paint()
          ..color = const Color.fromARGB(128, 33, 150, 243)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawRect(obs.toRect(), hitboxPaint);
      }
    }
  }
}
