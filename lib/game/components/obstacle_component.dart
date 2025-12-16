import 'dart:math';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'game_component.dart';

/// Obstacle component representing hazards in the game
class ObstacleComponent extends GameComponent {
  /// Type of obstacle
  ObstacleType obstacleType = ObstacleType.static;

  /// Damage dealt by this obstacle
  int damage = 10;

  /// Whether obstacle is destroyable
  bool isDestroyable = false;

  /// Obstacle health (if destroyable)
  int obstacleHealth = 1;

  /// Animation timer for moving obstacles
  double animationTimer = 0.0;

  /// Movement pattern for dynamic obstacles
  MovementPattern? movementPattern;

  ObstacleComponent() {
    size = vm.Vector2(50, 50);
    damage = 10;
    isDestroyable = false;
    obstacleHealth = 1;
    obstacleType = ObstacleType.static;
  }

  @override
  String get componentType => 'obstacle';

  @override
  void update(double dt) {
    super.update(dt);

    // Update animation
    animationTimer += dt;

    // Apply movement pattern if exists
    if (movementPattern != null) {
      _applyMovementPattern(dt);
    }
  }

  /// Apply movement pattern to obstacle
  void _applyMovementPattern(double dt) {
    switch (movementPattern) {
      case MovementPattern.horizontal:
        velocity.x = (sin(animationTimer).abs() * 100);
        break;
      case MovementPattern.vertical:
        velocity.y = (sin(animationTimer).abs() * 100);
        break;
      case MovementPattern.circular:
        final radius = 50.0;
        position.x = position.x + cos(animationTimer) * radius * dt;
        position.y = position.y + sin(animationTimer) * radius * dt;
        break;
      case MovementPattern.diagonal:
        velocity.x = 50;
        velocity.y = 50;
        break;
      case null:
        break;
    }
  }

  /// Take damage (if destroyable)
  void takeDamage(int damage) {
    if (isDestroyable) {
      obstacleHealth -= damage;
      if (obstacleHealth <= 0) {
        isActive = false;
      }
    }
  }

  /// Set obstacle type with appropriate properties
  void setObstacleType(ObstacleType type) {
    obstacleType = type;

    switch (type) {
      case ObstacleType.static:
        velocity.setZero();
        isDestroyable = false;
        damage = 10;
        break;
      case ObstacleType.moving:
        movementPattern = MovementPattern.horizontal;
        isDestroyable = false;
        damage = 15;
        break;
      case ObstacleType.rotating:
        movementPattern = MovementPattern.circular;
        isDestroyable = false;
        damage = 20;
        break;
      case ObstacleType.destroyable:
        isDestroyable = true;
        obstacleHealth = 2;
        damage = 5;
        break;
    }
  }

  /// Reset obstacle to initial state
  @override
  void reset() {
    super.reset();
    damage = 10;
    isDestroyable = false;
    obstacleHealth = 1;
    animationTimer = 0.0;
    movementPattern = null;
    obstacleType = ObstacleType.static;
  }
}

/// Types of obstacles
enum ObstacleType {
  static,
  moving,
  rotating,
  destroyable,
}

/// Movement patterns for dynamic obstacles
enum MovementPattern {
  horizontal,
  vertical,
  circular,
  diagonal,
}