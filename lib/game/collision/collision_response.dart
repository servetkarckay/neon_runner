import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' hide Colors;
import 'package:flutter_neon_runner/game/collision/collision_types.dart';
import 'package:flutter_neon_runner/game/events/game_events.dart';
import 'package:flutter_neon_runner/config/game_config.dart';
import 'package:flutter_neon_runner/models/game_state.dart';
import 'package:flutter_neon_runner/game/systems/base_game_system.dart';

/// Handles collision responses and game logic separately from collision detection
class CollisionResponseSystem {
  /// Processes a single collision event
  void processCollision(CollisionEvent event) {
    final collision = event.collisionInfo;

    // Determine what type of collision this is
    if (_isPlayerObstacleCollision(collision)) {
      _handlePlayerObstacleCollision(collision);
    } else if (_isPlayerPowerUpCollision(collision)) {
      _handlePlayerPowerUpCollision(collision);
    }
  }

  /// Processes multiple collision events in priority order
  void processCollisions(List<CollisionEvent> collisions) {
    // Sort by priority (critical first)
    final sortedCollisions = List<CollisionEvent>.from(collisions);
    sortedCollisions.sort((a, b) => b.priority.index.compareTo(a.priority.index));

    for (final event in sortedCollisions) {
      processCollision(event);
    }
  }

  /// Processes grazing events
  void processGrazing(List<CollisionEvent> grazingEvents) {
    for (final event in grazingEvents) {
      final collision = event.collisionInfo;
      _handleGrazingEvent(collision);
    }
  }

  /// Checks if collision involves player and obstacle
  bool _isPlayerObstacleCollision(CollisionInfo collision) {
    return (collision.entityA.type == EntityType.player && collision.entityB.type == EntityType.obstacle) ||
           (collision.entityA.type == EntityType.obstacle && collision.entityB.type == EntityType.player);
  }

  /// Checks if collision involves player and power-up
  bool _isPlayerPowerUpCollision(CollisionInfo collision) {
    return (collision.entityA.type == EntityType.player && collision.entityB.type == EntityType.powerUp) ||
           (collision.entityA.type == EntityType.powerUp && collision.entityB.type == EntityType.player);
  }

  /// Handles player-obstacle collision
  void _handlePlayerObstacleCollision(CollisionInfo collision) {
    final playerEntity = collision.entityA.type == EntityType.player ?
                         collision.entityA as PlayerEntity :
                         collision.entityB as PlayerEntity;

    final obstacleEntity = collision.entityA.type == EntityType.obstacle ?
                          collision.entityA as ObstacleEntity :
                          collision.entityB as ObstacleEntity;

    final obstacleType = obstacleEntity.obstacleData.type;
    final playerData = playerEntity.playerData;

    // Check for special collision types
    switch (obstacleType) {
      case ObstacleType.platform:
      case ObstacleType.movingPlatform:
        _handlePlatformCollision(playerEntity, obstacleEntity, collision);
        break;

      case ObstacleType.hazardZone:
        _handleHazardZoneCollision(playerEntity, obstacleEntity, collision);
        break;

      case ObstacleType.rotatingLaser:
      case ObstacleType.spike:
      case ObstacleType.fallingDrop:
        _handleHazardCollision(playerEntity, obstacleEntity, collision);
        break;

      default:
        _handleStandardObstacleCollision(playerEntity, obstacleEntity, collision);
        break;
    }
  }

  /// Handles platform collision (player can land on top)
  void _handlePlatformCollision(PlayerEntity player, ObstacleEntity obstacle, CollisionInfo collision) {
    final playerData = player.playerData;
    final obstacleData = obstacle.obstacleData;

    // Check if player is landing on top of platform
    if (playerData.velocityY >= 0 &&
        player.bounds.top <= obstacle.bounds.top + 10) { // Add some tolerance

      // Player landed on platform
      playerData.y = obstacleData.y - playerData.height;
      playerData.velocityY = 0;
      playerData.isJumping = false;

      // Fire landing particle event
      GameEventBus.instance.fire(ParticleCreateEvent(
        playerData.x + playerData.width / 2,
        playerData.y + playerData.height,
        Colors.white,
        1,
        'platform_land',
      ));

      GameEventBus.instance.fire(PlatformLandedEvent(
        playerData.x + playerData.width / 2,
        playerData.y + playerData.height,
      ));
    } else {
      // Player hit platform from the side or bottom - treat as normal obstacle
      _handleStandardObstacleCollision(player, obstacle, collision);
    }
  }

  /// Handles hazard zone collision (safe area in the middle)
  void _handleHazardZoneCollision(PlayerEntity player, ObstacleEntity obstacle, CollisionInfo collision) {
    final playerData = player.playerData;
    final obstacleData = obstacle.obstacleData;

    // Check if player is in the safe zone
    final safeZoneTop = obstacleData.y + obstacleData.height - GameConfig.hazardZoneSafeTolerance;

    if (playerData.y + playerData.height > safeZoneTop) {
      // Player is in safe zone
      playerData.isGrazing = true;
      // Don't fire game over - this is safe
    } else {
      // Player hit the dangerous part
      _handleHazardCollision(player, obstacle, collision);
    }
  }

  /// Handles hazards that damage the player
  void _handleHazardCollision(PlayerEntity player, ObstacleEntity obstacle, CollisionInfo collision) {
    final playerData = player.playerData;

    if (playerData.invincibleTimer > 0) {
      // Player is invincible - safe collision
      return;
    }

    if (playerData.hasShield) {
      // Break shield
      GameEventBus.instance.fire(ShieldBreakEvent(
        playerData.x + playerData.width / 2,
        playerData.y + playerData.height / 2,
      ));
      playerData.hasShield = false;
      return;
    }

    // Game over
    GameEventBus.instance.fire(ObstacleHitEvent(
      obstacle.obstacleData,
      playerData.x + playerData.width / 2,
      playerData.y + playerData.height / 2,
    ));

    GameEventBus.instance.fire(GameOverEvent(0, 0)); // Score will be set by game state
  }

  /// Handles standard obstacle collision
  void _handleStandardObstacleCollision(PlayerEntity player, ObstacleEntity obstacle, CollisionInfo collision) {
    final playerData = player.playerData;

    if (playerData.invincibleTimer > 0) {
      // Player is invincible - safe collision
      return;
    }

    if (playerData.hasShield) {
      // Break shield
      GameEventBus.instance.fire(ShieldBreakEvent(
        playerData.x + playerData.width / 2,
        playerData.y + playerData.height / 2,
      ));
      playerData.hasShield = false;
      return;
    }

    // Game over
    GameEventBus.instance.fire(ObstacleHitEvent(
      obstacle.obstacleData,
      playerData.x + playerData.width / 2,
      playerData.y + playerData.height / 2,
    ));

    GameEventBus.instance.fire(GameOverEvent(0, 0));
  }

  /// Handles player-powerup collision
  void _handlePlayerPowerUpCollision(CollisionInfo collision) {
    final playerEntity = collision.entityA.type == EntityType.player ?
                         collision.entityA as PlayerEntity :
                         collision.entityB as PlayerEntity;

    final powerUpEntity = collision.entityA.type == EntityType.powerUp ?
                          collision.entityA as PowerUpEntity :
                          collision.entityB as PowerUpEntity;

    final powerUpType = powerUpEntity.powerUpType;
    final playerData = playerEntity.playerData;

    switch (powerUpType) {
      case 'shield':
        playerData.hasShield = true;
        break;
      case 'multiplier':
        playerData.scoreMultiplier = 2;
        playerData.multiplierTimer = 600; // 10 seconds at 60 FPS
        break;
      case 'timeWarp':
        playerData.timeWarpTimer = 300; // 5 seconds
        break;
      case 'magnet':
        playerData.magnetTimer = 600; // 10 seconds
        break;
    }

    // Fire power-up collected event
    GameEventBus.instance.fire(PowerUpCollectedEvent(
      powerUpType,
      playerData.x + playerData.width / 2,
      playerData.y + playerData.height / 2,
    ));

    // Create collection particle
    GameEventBus.instance.fire(ParticleCreateEvent(
      playerData.x + playerData.width / 2,
      playerData.y + playerData.height / 2,
      Colors.yellow,
      1,
      'powerup_collect',
    ));
  }

  /// Handles grazing events (near-misses with obstacles)
  void _handleGrazingEvent(CollisionInfo collision) {
    final playerEntity = collision.entityA.type == EntityType.player ?
                         collision.entityA as PlayerEntity :
                         collision.entityB as PlayerEntity;

    final obstacleEntity = collision.entityA.type == EntityType.obstacle ?
                          collision.entityA as ObstacleEntity :
                          collision.entityB as ObstacleEntity;

    final playerData = playerEntity.playerData;
    final obstacleData = obstacleEntity.obstacleData;

    // Mark obstacle as grazed to prevent duplicate grazing
    obstacleData.grazed = true;
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
      Colors.cyan,
      1,
      'graze',
    ));
  }

  /// Separates two entities to resolve overlap
  Vector2 resolveSeparation(CollidableEntity entityA, CollidableEntity entityB) {
    // Simple separation based on collision normal
    if (entityA.type == EntityType.player && entityB.type == EntityType.obstacle) {
      // Push player away from obstacle
      final direction = (entityA.center - entityB.center).normalized();
      return direction * 2.0; // Small separation distance
    }

    return Vector2.zero();
  }

  /// Validates if a collision response should be applied
  bool shouldProcessCollision(CollisionInfo collision) {
    // Check if entities can still collide
    if (!collision.entityA.canCollideWith(collision.entityB)) {
      return false;
    }

    // Check if player is already in a state that prevents this collision
    if (collision.entityA.type == EntityType.player) {
      final player = collision.entityA as PlayerEntity;
      if (player.playerData.invincibleTimer > 0) {
        return false;
      }
    }

    if (collision.entityB.type == EntityType.player) {
      final player = collision.entityB as PlayerEntity;
      if (player.playerData.invincibleTimer > 0) {
        return false;
      }
    }

    return true;
  }
}