import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_neon_runner/config/game_config.dart';
import 'package:flutter_neon_runner/models/game_state.dart';
import 'package:flutter_neon_runner/models/obstacle_data.dart';
import 'package:flutter_neon_runner/utils/spawner_utils.dart';
import 'dart:ui' as ui; // Import for ui.Rect

class ObstacleManager extends Component {
  final List<ObstacleData> _activeObstacles = [];
  final List<ObstacleData> _obstaclePool = [];
  int _obstacleIdCounter = 0;
  ObstacleType? _lastObstacleType;

  int get obstacleIdCounter => _obstacleIdCounter; // Public getter

  final double _baseWidth;
  final double _groundLevel;
  double _currentSpeed;
  int _frames;

  ObstacleManager({
    required double baseWidth,
    required double groundLevel,
    required double currentSpeed,
    required int frames,
  })  : _baseWidth = baseWidth,
        _groundLevel = groundLevel,
        _currentSpeed = currentSpeed,
        _frames = frames;

  void updateSpeedAndFrames(double newSpeed, int newFrames) {
    _currentSpeed = newSpeed;
    _frames = newFrames;
  }

  void spawnObstacle(int nextSpawn) {
    if (_frames < nextSpawn) return;

    final ObstacleData obstacle = getObstacleFromPool(_obstaclePool, _obstacleIdCounter++);
    configureObstacle(obstacle, _currentSpeed, GameConfig(), _baseWidth);

    if (_lastObstacleType != null) {
      // Apply type-specific adjustments
      if ((_lastObstacleType == ObstacleType.spike || _lastObstacleType == ObstacleType.ground) &&
          (obstacle.type == ObstacleType.aerial || obstacle.type == ObstacleType.movingAerial)) {
        obstacle.x += 120;
      }
      if (_lastObstacleType == ObstacleType.hazardZone && obstacle.type == ObstacleType.hazardZone) {
        obstacle.x += 100;
      }
      if (_lastObstacleType == ObstacleType.laserGrid) {
        obstacle.x += 150;
      }
    }



    _activeObstacles.add(obstacle);
    _lastObstacleType = obstacle.type;

  }

  @override
  void update(double dt) {
    super.update(dt);
    double timeScale = 1.0;

    for (int i = _activeObstacles.length - 1; i >= 0; i--) {
      final obs = _activeObstacles[i];
      double moveX = _currentSpeed * timeScale;

      final frame = _frames;
      final sin0_05 = sin(frame * 0.05);
      final sin0_1 = sin(frame * 0.1);
      final cos0_05 = cos(frame * 0.05);

      if (obs is MovingPlatformObstacleData && obs.oscillationAxis == OscillationAxis.horizontal) {
        moveX -= cos0_05 * 4 * timeScale;
      }

      obs.x = obs.x - moveX; // Use setter
      // obs.updatePosition(obs.x - moveX, obs.y); // Alternative using updatePosition

      if (obs is MovingAerialObstacleData) {
        obs.y = obs.initialY + sin0_1 * 40; // Use setter
      } else if (obs is HazardObstacleData) {
        obs.y = obs.initialY + sin0_05 * 25; // Use setter
      } else if (obs is MovingPlatformObstacleData && obs.oscillationAxis != OscillationAxis.horizontal) {
        obs.y = obs.initialY + sin0_05 * 50; // Use setter
      } else if (obs is FallingObstacleData) {
        obs.velocityY += (0.4 * timeScale);
        obs.y = obs.y + obs.velocityY * timeScale; // Use setter
        if (obs.y + obs.height > _groundLevel) {

          _obstaclePool.add(_activeObstacles.removeAt(i));
          continue;
        }
      } else if (obs is RotatingLaserObstacleData) {
        obs.angle = (obs.angle) + (obs.rotationSpeed) * timeScale;
      }

      if (obs.x + obs.width < -150) {
        _obstaclePool.add(_activeObstacles.removeAt(i));
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    for (final obs in _activeObstacles) {
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
        canvas.drawCircle(ui.Offset(obs.x + obs.width / 2, obs.y + obs.height / 2), obs.width / 2, paint);
      } else if (obs.type == ObstacleType.aerial || obs.type == ObstacleType.movingAerial) {
        paint.color = const Color(0xFFFF0055);
        final path = Path()
          ..moveTo(obs.x + obs.width / 2, obs.y)
          ..lineTo(obs.x + obs.width, obs.y + obs.height / 2)
          ..lineTo(obs.x + obs.width / 2, obs.y + obs.height)
          ..lineTo(obs.x, obs.y + obs.height / 2)
          ..close();
        canvas.drawPath(path, paint);
      } else if (obs.type == ObstacleType.platform || obs.type == ObstacleType.movingPlatform) {
        paint.color = const Color(0xFF0088FF);
        canvas.drawRect(obs.toRect(), paint);
      } else if (obs.type == ObstacleType.rotatingLaser) {
        paint.color = const Color(0xFF333333);
        canvas.drawRect(obs.toRect(), paint);
        final laserPaint = Paint()
          ..color = Colors.red
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke;
        final laserCenter = ui.Offset(obs.x + obs.width / 2, obs.y + obs.height / 2);
        final rotatingObs = obs as RotatingLaserObstacleData;
        final laserEndX = laserCenter.dx + cos(rotatingObs.angle) * rotatingObs.beamLength;
        final laserEndY = laserCenter.dy + sin(rotatingObs.angle) * rotatingObs.beamLength;
        canvas.drawLine(laserCenter, ui.Offset(laserEndX, laserEndY), laserPaint);
      } else if (obs.type == ObstacleType.laserGrid) {
        paint.color = Colors.red.withAlpha((255 * 0.2).round());
        final laserGridObs = obs as LaserGridObstacleData;
        final topHeight = laserGridObs.gapY - laserGridObs.gapHeight / 2;
        final bottomY = laserGridObs.gapY + laserGridObs.gapHeight / 2;
        canvas.drawRect(ui.Rect.fromLTWH(obs.x, 0, obs.width, topHeight), paint);
        canvas.drawRect(ui.Rect.fromLTWH(obs.x, bottomY, obs.width, _groundLevel - bottomY), paint);
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
    }
  }

  void reset() {
    _activeObstacles.forEach(_obstaclePool.add);
    _activeObstacles.clear();
    _obstacleIdCounter = 0;
    _lastObstacleType = null;
  }
  
  List<ObstacleData> get activeObstacles => _activeObstacles;
}
