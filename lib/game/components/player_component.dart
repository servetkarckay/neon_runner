import 'package:vector_math/vector_math_64.dart' as vm;
import 'game_component.dart';

/// Player component representing the main character
class PlayerComponent extends GameComponent {
  /// Player health
  int health = 100;

  /// Player score
  int score = 0;

  /// Whether player is invincible
  bool isInvincible = false;

  /// Invincibility timer
  double invincibilityTimer = 0.0;

  /// Whether player can revive
  bool canRevive = true;

  /// Whether player is dead
  bool isDead = false;

  /// Current power-ups
  final List<PowerUpType> activePowerUps = [];

  PlayerComponent() {
    size = vm.Vector2(50, 50);
    health = 100;
    score = 0;
    isDead = false;
    canRevive = true;
    isInvincible = false;
    invincibilityTimer = 0.0;
  }

  @override
  String get componentType => 'player';

  @override
  void update(double dt) {
    super.update(dt);

    // Update invincibility timer
    if (isInvincible && invincibilityTimer > 0) {
      invincibilityTimer -= dt;
      if (invincibilityTimer <= 0) {
        isInvincible = false;
        invincibilityTimer = 0.0;
      }
    }
  }

  /// Apply damage to player
  void takeDamage(int damage) {
    if (!isInvincible && !isDead) {
      health -= damage;
      if (health <= 0) {
        health = 0;
        isDead = true;
      }
    }
  }

  /// Heal player
  void heal(int amount) {
    if (!isDead) {
      health = (health + amount).clamp(0, 100);
    }
  }

  /// Add score
  void addScore(int points) {
    if (!isDead) {
      score += points;
    }
  }

  /// Activate invincibility
  void activateInvincibility(double duration) {
    isInvincible = true;
    invincibilityTimer = duration;
  }

  /// Add power-up
  void addPowerUp(PowerUpType powerUp) {
    if (!activePowerUps.contains(powerUp)) {
      activePowerUps.add(powerUp);
    }
  }

  /// Remove power-up
  void removePowerUp(PowerUpType powerUp) {
    activePowerUps.remove(powerUp);
  }

  /// Check if player has specific power-up
  bool hasPowerUp(PowerUpType powerUp) {
    return activePowerUps.contains(powerUp);
  }

  /// Revive player
  void revive() {
    if (canRevive && isDead) {
      isDead = false;
      canRevive = false;
      health = 100;
      activateInvincibility(3.0); // 3 seconds of invincibility after revive
    }
  }

  /// Reset player to initial state
  @override
  void reset() {
    super.reset();
    health = 100;
    score = 0;
    isDead = false;
    canRevive = true;
    isInvincible = false;
    invincibilityTimer = 0.0;
    activePowerUps.clear();
  }
}

/// Power-up types for the player
enum PowerUpType {
  shield,
  multiplier,
  speed,
  magnet,
  invincibility,
}