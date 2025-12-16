import 'dart:math';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'game_component.dart';
import 'player_component.dart';

/// Power-up component that grants abilities to the player
class PowerUpComponent extends GameComponent {
  /// Type of power-up
  PowerUpType powerUpType = PowerUpType.shield;

  /// Value or strength of the power-up
  double value = 1.0;

  /// Collection radius (how close player needs to be)
  double collectionRadius = 60.0;

  /// Magnetic attraction radius
  double magnetRadius = 80.0;

  /// Animation timer for visual effects
  double animationTimer = 0.0;

  /// Whether power-up has been collected
  bool isCollected = false;

  /// Duration of power-up effect
  double effectDuration = 5.0;

  PowerUpComponent() {
    size = vm.Vector2(30, 30);
    collectionRadius = 60.0;
    magnetRadius = 80.0;
    isCollected = false;
    animationTimer = 0.0;
    effectDuration = 5.0;
  }

  @override
  String get componentType => 'powerup';

  @override
  void update(double dt) {
    super.update(dt);

    animationTimer += dt;

    // Apply floating animation
    position.y += sin(animationTimer * 2) * 20 * dt;
  }

  /// Set power-up type with appropriate properties
  void setPowerUpType(PowerUpType type) {
    powerUpType = type;

    switch (type) {
      case PowerUpType.shield:
        value = 1.0;
        effectDuration = 10.0;
        break;
      case PowerUpType.multiplier:
        value = 2.0;
        effectDuration = 15.0;
        break;
      case PowerUpType.speed:
        value = 1.5;
        effectDuration = 8.0;
        break;
      case PowerUpType.magnet:
        value = 100.0;
        effectDuration = 12.0;
        break;
      case PowerUpType.invincibility:
        value = 3.0;
        effectDuration = 5.0;
        break;
    }
  }

  /// Check if power-up can be collected by player
  bool canCollect(PlayerComponent player) {
    if (isCollected || !player.isActive || player.isDead) {
      return false;
    }

    final distance = (player.position - position).length;

    // Check if player has magnet power-up
    if (player.hasPowerUp(PowerUpType.magnet)) {
      return distance <= magnetRadius;
    }

    return distance <= collectionRadius;
  }

  /// Apply power-up effect to player
  void applyToPlayer(PlayerComponent player) {
    if (isCollected) return;

    isCollected = true;
    isActive = false;

    switch (powerUpType) {
      case PowerUpType.shield:
        player.addPowerUp(PowerUpType.shield);
        break;
      case PowerUpType.multiplier:
        player.addPowerUp(PowerUpType.multiplier);
        break;
      case PowerUpType.speed:
        player.addPowerUp(PowerUpType.speed);
        break;
      case PowerUpType.magnet:
        player.addPowerUp(PowerUpType.magnet);
        break;
      case PowerUpType.invincibility:
        player.activateInvincibility(effectDuration);
        break;
    }
  }

  /// Magnetic attraction to player
  void attractToPlayer(PlayerComponent player, double dt) {
    if (!player.hasPowerUp(PowerUpType.magnet) || isCollected) {
      return;
    }

    final distance = (player.position - position).length;
    if (distance <= magnetRadius && distance > collectionRadius) {
      final direction = (player.position - position).normalized();
      final attractionSpeed = 200.0 * dt;
      position.add(direction * attractionSpeed);
    }
  }

  /// Reset power-up to initial state
  @override
  void reset() {
    super.reset();
    isCollected = false;
    animationTimer = 0.0;
    collectionRadius = 60.0;
    magnetRadius = 80.0;
    effectDuration = 5.0;
  }
}