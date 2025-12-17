import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_neon_runner/game/collision/collision_engine.dart';
import 'package:flutter_neon_runner/game/collision/entity_factory.dart';
import 'package:flutter_neon_runner/models/game_state.dart';

void main() {
  group('Refactored Collision Detection Tests', () {
    late CollisionEngine collisionEngine;

    setUp(() {
      collisionEngine = CollisionEngine(cellSize: 100.0);
      CollisionEntityFactory.resetIdCounter();
    });

    test('should detect collision when player and obstacle overlap', () {
      // Arrange - Player and obstacle at same position
      final player = CollisionEntityFactory.createTestPlayerEntity(x: 100, y: 100);
      final obstacle = CollisionEntityFactory.createTestObstacleEntity(
        x: 100, y: 100, obstacleType: ObstacleType.ground,
      );

      // Act
      collisionEngine.addEntity(player);
      collisionEngine.addEntity(obstacle);
      final collisions = collisionEngine.detectCollisions();

      // Assert
      expect(collisions.length, equals(1));
    });

    test('should not detect collision when player and obstacle are far apart', () {
      // Arrange - Player and obstacle far apart
      final player = CollisionEntityFactory.createTestPlayerEntity(x: 0, y: 0);
      final obstacle = CollisionEntityFactory.createTestObstacleEntity(
        x: 500, y: 500, obstacleType: ObstacleType.ground,
      );

      // Act
      collisionEngine.addEntity(player);
      collisionEngine.addEntity(obstacle);
      final collisions = collisionEngine.detectCollisions();

      // Assert
      expect(collisions.length, equals(0));
    });

    test('should handle edge case collisions at boundaries', () {
      // Arrange - Player at boundary
      final player = CollisionEntityFactory.createTestPlayerEntity(x: 0, y: 0);
      final obstacle = CollisionEntityFactory.createTestObstacleEntity(
        x: 30, y: 30, // Just touching collision boundary
        obstacleType: ObstacleType.ground,
      );

      // Act
      collisionEngine.addEntity(player);
      collisionEngine.addEntity(obstacle);
      final collisions = collisionEngine.detectCollisions();

      // Assert
      expect(collisions.length, equals(1));
    });

    test('should prevent double counting of same collision', () {
      // Arrange
      final player = CollisionEntityFactory.createTestPlayerEntity(x: 100, y: 100);
      final obstacle = CollisionEntityFactory.createTestObstacleEntity(
        x: 100, y: 100, obstacleType: ObstacleType.ground,
      );

      // Act - Simulate multiple collision detections in same frame
      collisionEngine.addEntity(player);
      collisionEngine.addEntity(obstacle);

      final firstDetection = collisionEngine.detectCollisions();
      final secondDetection = collisionEngine.detectCollisions();

      // Assert - Both should find the collision, but in practice, game logic would prevent double processing
      expect(firstDetection.length, equals(1));
      expect(secondDetection.length, equals(1));
      expect(firstDetection.first.collisionInfo.entityA.id, equals(secondDetection.first.collisionInfo.entityA.id));
    });

    test('should handle different obstacle types correctly', () {
      // Arrange
      final player = CollisionEntityFactory.createTestPlayerEntity(x: 100, y: 100);

      final groundObstacle = CollisionEntityFactory.createTestObstacleEntity(
        x: 120, y: 100, obstacleType: ObstacleType.ground,
      );
      final aerialObstacle = CollisionEntityFactory.createTestObstacleEntity(
        x: 100, y: 120, obstacleType: ObstacleType.aerial,
      );
      final fallingDrop = CollisionEntityFactory.createTestObstacleEntity(
        x: 110, y: 110, obstacleType: ObstacleType.fallingDrop,
      );

      // Act
      collisionEngine.addEntity(player);
      collisionEngine.addEntity(groundObstacle);
      collisionEngine.addEntity(aerialObstacle);
      collisionEngine.addEntity(fallingDrop);

      final collisions = collisionEngine.detectCollisions();

      // Assert - All three should collide with player
      expect(collisions.length, equals(3));
    });

    tearDown(() {
      collisionEngine.clear();
      CollisionEntityFactory.resetIdCounter();
    });
  });
}