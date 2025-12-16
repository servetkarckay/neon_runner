import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' hide Colors;
import 'package:flutter_neon_runner/config/game_config.dart';
import 'package:flutter_neon_runner/game/events/game_events.dart';
import 'package:flutter_neon_runner/game/systems/base_game_system.dart';
import 'package:flutter_neon_runner/game/systems/player_system.dart';
import 'package:flutter_neon_runner/models/game_state.dart';
import 'package:flutter_neon_runner/models/obstacle_data.dart';
import 'package:flutter_neon_runner/models/player_data.dart';
import 'package:flutter_neon_runner/utils/collision_utils.dart';
import 'package:flutter_neon_runner/utils/math_utils.dart';

/// System managing all collision detection and response
class CollisionSystem extends EventHandlerSystem implements PausableSystem {
  final PlayerSystem _playerSystem;
  bool _isPaused = false;

  // Obstacle tracking
  final List<ObstacleData> _obstacles = [];

  CollisionSystem(this._playerSystem);

  @override
  String get systemName => 'CollisionSystem';

  @override
  Future<void> initialize() async {
    // Subscribe to relevant events
    GameEventBus.instance.subscribe<ObstacleSpawnedEvent>(_handleObstacleSpawned);
    GameEventBus.instance.subscribe<ObstacleDestroyedEvent>(_handleObstacleDestroyed);
    GameEventBus.instance.subscribe<PlayerMoveEvent>(_handlePlayerMove);
  }

  @override
  void update(double dt) {
    if (_isPaused) return;

    _checkCollisions(dt);
    _checkGrazing();
  }

  @override
  void handleEvent(GameEvent event) {
    // Events are handled via subscriptions
  }

  @override
  List<Type> get handledEventTypes => [
    ObstacleSpawnedEvent,
    ObstacleDestroyedEvent,
    PlayerMoveEvent,
  ];

  @override
  void onPause() {
    _isPaused = true;
  }

  @override
  void onResume() {
    _isPaused = false;
  }

  @override
  bool get isPaused => _isPaused;

  // Public methods
  void addObstacle(ObstacleData obstacle) {
    _obstacles.add(obstacle);
  }

  void removeObstacle(ObstacleData obstacle) {
    _obstacles.remove(obstacle);
  }

  void clearAll() {
    _obstacles.clear();
  }

  // Private methods
  void _checkCollisions(double dt) {
    final playerData = _playerSystem.playerData;
    final playerRect = _playerSystem.playerRect;

    for (final obstacle in _obstacles) {
      // Predict obstacle movement
      final obstacleDisplacement = _predictObstacleMovement(obstacle, dt);

      // Use sweep collision for better accuracy
      final toi = sweepRectRectCollision(
        playerRect,
        playerData.currentVelocity - obstacleDisplacement,
        Rect.fromLTWH(obstacle.x, obstacle.y, obstacle.width, obstacle.height),
      );

      if (toi != null) {
        _handleCollision(obstacle, toi, dt);
      }
    }
  }

  Vector2 _predictObstacleMovement(ObstacleData obstacle, double dt) {
    double dx = 0.0;
    double dy = 0.0;

    if (obstacle is MovingPlatformObstacleData &&
        obstacle.oscillationAxis == OscillationAxis.horizontal) {
      dx = -cos(DateTime.now().millisecondsSinceEpoch * 0.05) * 4 * dt;
    } else if (obstacle is MovingAerialObstacleData) {
      // Predict next position for aerial obstacles
      final nextY = obstacle.initialY + sin((DateTime.now().millisecondsSinceEpoch + 16.67) * 0.1) * 40;
      dy = (nextY - obstacle.y) * dt;
    } else if (obstacle is HazardObstacleData) {
      final nextY = obstacle.initialY + sin((DateTime.now().millisecondsSinceEpoch + 16.67) * 0.05) * 25;
      dy = (nextY - obstacle.y) * dt;
    } else if (obstacle is FallingObstacleData) {
      dy = obstacle.velocityY * dt;
    }

    return Vector2(dx, dy);
  }

  void _handleCollision(ObstacleData obstacle, double toi, double dt) {
    final playerData = _playerSystem.playerData;
    final playerRect = _playerSystem.playerRect;

    // Calculate positions at time of impact
    final playerRectAtTOI = Rect.fromLTWH(
      playerRect.left + playerData.currentVelocity.x * toi,
      playerRect.top + playerData.currentVelocity.y * toi,
      playerRect.width,
      playerRect.height,
    );

    final obstacleRectAtTOI = Rect.fromLTWH(
      obstacle.x,
      obstacle.y,
      obstacle.width,
      obstacle.height,
    );

    // Check detailed collision
    if (_checkDetailedCollision(playerRectAtTOI, obstacleRectAtTOI, obstacle)) {
      bool safe = false;

      // Check for platform landing
      if ((obstacle.type == ObstacleType.platform ||
              obstacle.type == ObstacleType.movingPlatform) &&
          playerData.velocityY >= 0) {
        if (playerRect.top <= obstacle.y &&
            playerRectAtTOI.bottom > obstacle.y) {
          // Player landed on platform
          playerData.y = obstacle.y - playerData.height;
          playerData.velocityY = 0;
          playerData.isJumping = false;
          safe = true;

          // Create landing particle
          GameEventBus.instance.fire(ParticleCreateEvent(
            playerData.x + playerData.width / 2,
            playerData.y + playerData.height,
            Colors.cyan,
            1,
            'platform_land',
          ));
        }
      } else if (obstacle.type == ObstacleType.hazardZone) {
        // Check if player is in safe zone of hazard
        if (playerData.y + playerData.height >
            obstacle.y + obstacle.height - GameConfig.hazardZoneSafeTolerance) {
          safe = true;
          playerData.isGrazing = true;
        }
      }

      if (!safe) {
        if (playerData.invincibleTimer > 0) {
          safe = true;
        } else if (playerData.hasShield) {
          // Break shield
          _playerSystem.breakShield();
          safe = true;
        } else {
          // Game over
          GameEventBus.instance.fire(ObstacleHitEvent(
            obstacle,
            playerData.x + playerData.width / 2,
            playerData.y + playerData.height / 2,
          ));

          GameEventBus.instance.fire(GameOverEvent(0, 0)); // Score will be set by GameStateController
        }
      }
    }
  }

  bool _checkDetailedCollision(Rect playerRect, Rect obstacleRect, ObstacleData obstacle) {
    // Apply collision padding for player
    const padding = GameConfig.playerCollisionPadding;
    final paddedPlayerRect = Rect.fromLTWH(
      playerRect.left + padding,
      playerRect.top + padding,
      playerRect.width - padding * 2,
      playerRect.height - padding * 2,
    );

    switch (obstacle.type) {
      case ObstacleType.rotatingLaser:
        return _checkRotatingLaserCollision(paddedPlayerRect, obstacleRect, obstacle as RotatingLaserObstacleData);

      case ObstacleType.laserGrid:
        return _checkLaserGridCollision(paddedPlayerRect, obstacleRect, obstacle as LaserGridObstacleData);

      case ObstacleType.fallingDrop:
        return _checkFallingDropCollision(paddedPlayerRect, obstacleRect, obstacle as FallingObstacleData);

      case ObstacleType.spike:
        return _checkSpikeCollision(paddedPlayerRect, obstacleRect, obstacle as SpikeObstacleData);

      case ObstacleType.aerial:
      case ObstacleType.movingAerial:
        return _checkAerialCollision(paddedPlayerRect, obstacleRect, obstacle as AerialObstacleData);

      case ObstacleType.slantedSurface:
        return _checkSlantedSurfaceCollision(paddedPlayerRect, obstacleRect, obstacle as SlantedObstacleData);

      default:
        return rectRectCollision(paddedPlayerRect, obstacleRect);
    }
  }

  bool _checkRotatingLaserCollision(Rect playerRect, Rect obstacleRect, RotatingLaserObstacleData obstacle) {
    if (rectRectCollision(playerRect, obstacleRect)) return true;

    // Check laser beam collision
    final centerX = obstacleRect.left + obstacleRect.width / 2;
    final centerY = obstacleRect.top + obstacleRect.height / 2;
    final endX = centerX + cos(obstacle.angle) * obstacle.beamLength;
    final endY = centerY + sin(obstacle.angle) * obstacle.beamLength;

    return lineRect(centerX, centerY, endX, endY, playerRect);
  }

  bool _checkLaserGridCollision(Rect playerRect, Rect obstacleRect, LaserGridObstacleData obstacle) {
    if (playerRect.left + playerRect.width > obstacleRect.left + 5 &&
        playerRect.left < obstacleRect.left + obstacleRect.width - 5) {
      final safeTop = obstacle.gapY - obstacle.gapHeight / 2 + GameConfig.laserGridSafePadding;
      final safeBottom = obstacle.gapY + obstacle.gapHeight / 2 - GameConfig.laserGridSafePadding;

      return playerRect.top < safeTop || (playerRect.top + playerRect.height) > safeBottom;
    }
    return false;
  }

  bool _checkFallingDropCollision(Rect playerRect, Rect obstacleRect, FallingObstacleData obstacle) {
    final centerX = obstacleRect.left + obstacleRect.width / 2;
    final centerY = obstacleRect.top + obstacleRect.height / 2;
    final radius = obstacleRect.width / 2 - 6;

    final testX = max(playerRect.left, min(centerX, playerRect.left + playerRect.width));
    final testY = max(playerRect.top, min(centerY, playerRect.top + playerRect.height));

    final dx = centerX - testX;
    final dy = centerY - testY;

    return (dx * dx + dy * dy) < (radius * radius);
  }

  bool _checkSpikeCollision(Rect playerRect, Rect obstacleRect, SpikeObstacleData obstacle) {
    if (!rectRectCollision(playerRect, obstacleRect)) return false;

    final tipX = obstacleRect.left + obstacleRect.width / 2;
    final tipY = obstacleRect.top;

    // Check collision with triangle shape
    if (lineRect(obstacleRect.left, obstacleRect.top + obstacleRect.height, tipX, tipY, playerRect)) {
      return true;
    } else if (lineRect(tipX, tipY, obstacleRect.left + obstacleRect.width, obstacleRect.top + obstacleRect.height, playerRect)) {
      return true;
    } else {
      final centerX = playerRect.left + playerRect.width / 2;
      final bottomY = playerRect.top + playerRect.height;
      return centerX > obstacleRect.left &&
          centerX < obstacleRect.left + obstacleRect.width &&
          bottomY > obstacleRect.top + obstacleRect.height / 2;
    }
  }

  bool _checkAerialCollision(Rect playerRect, Rect obstacleRect, AerialObstacleData obstacle) {
    if (!rectRectCollision(playerRect, obstacleRect)) return false;

    final centerX = obstacleRect.left + obstacleRect.width / 2;
    final centerY = obstacleRect.top + obstacleRect.height / 2;

    // Check collision with diamond shape
    return lineRect(obstacleRect.left, centerY, centerX, obstacleRect.top, playerRect) ||
        lineRect(centerX, obstacleRect.top, obstacleRect.left + obstacleRect.width, centerY, playerRect) ||
        lineRect(obstacleRect.left + obstacleRect.width, centerY, centerX, obstacleRect.top + obstacleRect.height, playerRect) ||
        lineRect(centerX, obstacleRect.top + obstacleRect.height, obstacleRect.left, centerY, playerRect);
  }

  bool _checkSlantedSurfaceCollision(Rect playerRect, Rect obstacleRect, SlantedObstacleData obstacle) {
    final x1 = obstacleRect.left + obstacle.lineX1;
    final y1 = obstacleRect.top + obstacle.lineY1;
    final x2 = obstacleRect.left + obstacle.lineX2;
    final y2 = obstacleRect.top + obstacle.lineY2;

    return lineRect(x1, y1, x2, y2, playerRect);
  }

  void _checkGrazing() {
    final playerData = _playerSystem.playerData;
    final playerCenter = Offset(
      playerData.x + playerData.width / 2,
      playerData.y + playerData.height / 2,
    );

    for (final obstacle in _obstacles) {
      if (obstacle.grazed) continue;

      final obstacleCenter = Offset(obstacle.x + obstacle.width / 2, obstacle.y + obstacle.height / 2);
      final distance = (playerCenter - obstacleCenter).distance;
      const grazeDist = GameConfig.grazeDistance;

      if (distance < max(obstacle.width, obstacle.height) / 2 + grazeDist) {
        if (_isValidGraze(obstacle, playerData)) {
          obstacle.grazed = true;
          playerData.isGrazing = true;

          // Award graze points
          final grazeScore = (GameConfig.grazeScoreAmount * playerData.scoreMultiplier).toInt();
          GameEventBus.instance.fire(GrazingDetectedEvent(
            grazeScore,
            playerData.x + playerData.width / 2,
            playerData.y + playerData.height / 2,
          ));

          // Create graze particle
          GameEventBus.instance.fire(ParticleCreateEvent(
            playerData.x + playerData.width / 2,
            playerData.y + playerData.height / 2,
            Colors.white,
            1,
            'graze',
          ));
        }
      }
    }
  }

  bool _isValidGraze(ObstacleData obstacle, PlayerData playerData) {
    switch (obstacle.type) {
      case ObstacleType.laserGrid:
        final lg = obstacle as LaserGridObstacleData;
        final safeTop = lg.gapY - lg.gapHeight / 2 + GameConfig.laserGridSafePadding;
        final safeBottom = lg.gapY + lg.gapHeight / 2 - GameConfig.laserGridSafePadding;
        return !(playerData.y > safeTop && (playerData.y + playerData.height) < safeBottom);

      case ObstacleType.platform:
      case ObstacleType.movingPlatform:
        return !(playerData.y > obstacle.y + obstacle.height);

      default:
        return true;
    }
  }

  
  // Event handlers
  void _handleObstacleSpawned(ObstacleSpawnedEvent event) {
    addObstacle(event.obstacle);
  }

  void _handleObstacleDestroyed(ObstacleDestroyedEvent event) {
    removeObstacle(event.obstacle);
  }

  void _handlePlayerMove(PlayerMoveEvent event) {
    // Update player velocity for collision prediction
    _playerSystem.playerData.currentVelocity = Vector2(event.velocityX, event.velocityY);
  }

  @override
  void dispose() {
    clearAll();
    GameEventBus.instance.unsubscribe<ObstacleSpawnedEvent>(_handleObstacleSpawned);
    GameEventBus.instance.unsubscribe<ObstacleDestroyedEvent>(_handleObstacleDestroyed);
    GameEventBus.instance.unsubscribe<PlayerMoveEvent>(_handlePlayerMove);
  }
}