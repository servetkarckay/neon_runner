import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/painting.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'package:flutter_neon_runner/models/game_state.dart';
import 'package:flutter_neon_runner/game/components/player_component.dart';
import 'package:flutter_neon_runner/game/components/obstacle_component.dart';
import 'package:flutter_neon_runner/game/components/powerup_component.dart';
import 'package:flutter_neon_runner/game/components/enemy_component.dart';
import 'package:flutter_neon_runner/game/components/game_component.dart';

void main() {
  group('CollisionLogic Tests', () {
    late CollisionLogic collisionLogic;
    late PlayerComponent player;
    late GameComponent testObstacle;
    late GameComponent testPowerUp;
    late GameComponent testEnemy;

    setUp(() {
      collisionLogic = CollisionLogic();
      player = PlayerComponent();
      testObstacle = ObstacleComponent();
      testPowerUp = PowerUpComponent();
      testEnemy = EnemyComponent();
    });

    test('should detect player-obstacle collision when overlapping', () {
      // Arrange
      player.position = vm.Vector2(0, 0);
      player.size = vm.Vector2(50, 50);

      testObstacle.position = vm.Vector2(25, 25);
      testObstacle.size = vm.Vector2(50, 50);

      // Act
      final hasCollision = collisionLogic.checkCollision(player, testObstacle);

      // Assert
      expect(hasCollision, isTrue);
    });

    test('should not detect collision when objects are separate', () {
      // Arrange
      player.position = vm.Vector2(0, 0);
      player.size = vm.Vector2(50, 50);

      testObstacle.position = vm.Vector2(100, 100);
      testObstacle.size = vm.Vector2(50, 50);

      // Act
      final hasCollision = collisionLogic.checkCollision(player, testObstacle);

      // Assert
      expect(hasCollision, isFalse);
    });

    test('should detect player-powerup collision correctly', () {
      // Arrange
      player.position = vm.Vector2(10, 10);
      player.size = vm.Vector2(40, 40);

      testPowerUp.position = vm.Vector2(30, 30);
      testPowerUp.size = vm.Vector2(20, 20);

      // Act
      final hasCollision = collisionLogic.checkCollision(player, testPowerUp);

      // Assert
      expect(hasCollision, isTrue);
    });

    test('should detect player-enemy collision with hitboxes', () {
      // Arrange
      player.position = vm.Vector2(0, 0);
      player.size = vm.Vector2(50, 50);
      player.currentHitbox = Rect.fromLTWH(5, 5, 40, 40); // Smaller hitbox

      testEnemy.position = vm.Vector2(20, 20);
      testEnemy.size = vm.Vector2(50, 50);
      testEnemy.currentHitbox = Rect.fromLTWH(5, 5, 40, 40);

      // Act
      final hasCollision = collisionLogic.checkHitboxCollision(
        player.currentHitbox!,
        testEnemy.currentHitbox!,
      );

      // Assert
      expect(hasCollision, isTrue);
    });

    test('should calculate collision response correctly', () {
      // Arrange
      player.position = vm.Vector2(0, 0);
      player.velocity = vm.Vector2(5, 0);
      player.size = vm.Vector2(50, 50);

      testObstacle.position = vm.Vector2(40, 0);
      testObstacle.size = vm.Vector2(50, 50);
      testObstacle.velocity = vm.Vector2(-3, 0);

      // Act
      final response = collisionLogic.calculateCollisionResponse(player, testObstacle);

      // Assert
      expect(response.playerVelocity.x, lessThan(5)); // Should be reduced
      expect(response.obstacleVelocity.x, lessThan(-3)); // Should be affected
      expect(response.hasCollision, isTrue);
    });

    test('should handle edge case collision (touching edges)', () {
      // Arrange
      player.position = vm.Vector2(0, 0);
      player.size = vm.Vector2(50, 50);

      testObstacle.position = vm.Vector2(50, 0); // Exactly at the edge
      testObstacle.size = vm.Vector2(50, 50);

      // Act
      final hasCollision = collisionLogic.checkCollision(player, testObstacle);

      // Assert
      expect(hasCollision, isTrue);
    });

    test('should detect power-up collection radius', () {
      // Arrange
      player.position = vm.Vector2(0, 0);
      player.size = vm.Vector2(50, 50);

      testPowerUp.position = vm.Vector2(60, 60); // Outside collision but within collection radius
      testPowerUp.size = vm.Vector2(20, 20);

      // Act
      final canCollect = collisionLogic.checkPowerUpCollection(player, testPowerUp, radius: 80);

      // Assert
      expect(canCollect, isTrue);
    });

    test('should validate collision priorities correctly', () {
      // Arrange
      final collisions = [
        CollisionEvent(target: testObstacle, priority: CollisionPriority.high),
        CollisionEvent(target: testPowerUp, priority: CollisionPriority.low),
        CollisionEvent(target: testEnemy, priority: CollisionPriority.critical),
      ];

      // Act
      final sortedCollisions = collisionLogic.sortCollisionsByPriority(collisions);

      // Assert
      expect(sortedCollisions[0].target, equals(testEnemy));
      expect(sortedCollisions[0].priority, equals(CollisionPriority.critical));
      expect(sortedCollisions[1].target, equals(testObstacle));
      expect(sortedCollisions[1].priority, equals(CollisionPriority.high));
      expect(sortedCollisions[2].target, equals(testPowerUp));
      expect(sortedCollisions[2].priority, equals(CollisionPriority.low));
    });

    test('should handle multiple simultaneous collisions', () {
      // Arrange
      player.position = vm.Vector2(25, 25);
      player.size = vm.Vector2(50, 50);

      // Position multiple objects around the player
      testObstacle.position = vm.Vector2(30, 30);
      testObstacle.size = vm.Vector2(50, 50);

      testPowerUp.position = vm.Vector2(35, 35);
      testPowerUp.size = vm.Vector2(30, 30);

      testEnemy.position = vm.Vector2(40, 40);
      testEnemy.size = vm.Vector2(40, 40);

      // Act
      final collisions = collisionLogic.checkMultipleCollisions(
        player,
        [testObstacle, testPowerUp, testEnemy],
      );

      // Assert
      expect(collisions.length, equals(3));
      expect(collisions.any((c) => c.target == testObstacle), isTrue);
      expect(collisions.any((c) => c.target == testPowerUp), isTrue);
      expect(collisions.any((c) => c.target == testEnemy), isTrue);
    });
  });
}

// Helper classes for testing
class MockPlayerComponent extends PlayerComponent {
  MockPlayerComponent() {
    position.setValues(0, 0);
    size.setValues(50, 50);
    velocity.setValues(0, 0);
  }
}

class MockObstacleComponent extends ObstacleComponent {
  MockObstacleComponent() {
    position.setValues(0, 0);
    size.setValues(50, 50);
    velocity.setValues(0, 0);
  }
}

class MockPowerUpComponent extends PowerUpComponent {
  MockPowerUpComponent() {
    position.setValues(0, 0);
    size.setValues(30, 30);
  }
}

class MockEnemyComponent extends EnemyComponent {
  MockEnemyComponent() {
    position.setValues(0, 0);
    size.setValues(40, 40);
    velocity.setValues(0, 0);
  }
}

// Mock enums and data classes
enum PowerUpType { shield, multiplier, speed, magnet }

enum CollisionPriority { low, medium, high, critical }

class CollisionEvent {
  final GameComponent target;
  final CollisionPriority priority;
  final vm.Vector2? contactPoint;
  final vm.Vector2? normal;

  CollisionEvent({
    required this.target,
    required this.priority,
    this.contactPoint,
    this.normal,
  });
}

class CollisionResponse {
  final vm.Vector2 playerVelocity;
  final vm.Vector2 obstacleVelocity;
  final bool hasCollision;
  final vm.Vector2? separation;

  CollisionResponse({
    required this.playerVelocity,
    required this.obstacleVelocity,
    required this.hasCollision,
    this.separation,
  });
}

// Simplified collision logic for testing
class CollisionLogic {
  bool checkCollision(PlayerComponent a, GameComponent b) {
    final aRect = Rect.fromLTWH(
      a.position.x,
      a.position.y,
      a.size.x,
      a.size.y,
    );

    final bRect = Rect.fromLTWH(
      b.position.x,
      b.position.y,
      b.size.x,
      b.size.y,
    );

    return aRect.overlaps(bRect);
  }

  bool checkHitboxCollision(Rect hitboxA, Rect hitboxB) {
    return hitboxA.overlaps(hitboxB);
  }

  CollisionResponse calculateCollisionResponse(PlayerComponent player, GameComponent obstacle) {
    final hasCollision = checkCollision(player, obstacle);

    if (!hasCollision) {
      return CollisionResponse(
        playerVelocity: player.velocity,
        obstacleVelocity: obstacle.velocity,
        hasCollision: false,
      );
    }

    // Simple elastic collision response
    final combinedMass = 1.0 + 1.0; // Assuming unit mass
    final newPlayerVelocity = (player.velocity - obstacle.velocity) / combinedMass;
    final newObstacleVelocity = (obstacle.velocity - player.velocity) / combinedMass;

    return CollisionResponse(
      playerVelocity: newPlayerVelocity,
      obstacleVelocity: newObstacleVelocity,
      hasCollision: true,
      separation: vm.Vector2(1, 0), // Simple separation
    );
  }

  bool checkPowerUpCollection(PlayerComponent player, GameComponent powerUp, {double radius = 60}) {
    final distance = (player.position - powerUp.position).length;
    return distance <= radius;
  }

  List<CollisionEvent> sortCollisionsByPriority(List<CollisionEvent> collisions) {
    final sorted = List<CollisionEvent>.from(collisions);
    sorted.sort((a, b) => b.priority.index.compareTo(a.priority.index));
    return sorted;
  }

  List<CollisionEvent> checkMultipleCollisions(
    PlayerComponent player,
    List<GameComponent> objects,
  ) {
    final collisions = <CollisionEvent>[];

    for (final obj in objects) {
      if (checkCollision(player, obj)) {
        final priority = _getCollisionPriority(obj);
        collisions.add(CollisionEvent(target: obj, priority: priority));
      }
    }

    return collisions;
  }

  CollisionPriority _getCollisionPriority(GameComponent obj) {
    if (obj is EnemyComponent) return CollisionPriority.critical;
    if (obj is ObstacleComponent) return CollisionPriority.high;
    if (obj is PowerUpComponent) return CollisionPriority.low;
    return CollisionPriority.medium;
  }
}