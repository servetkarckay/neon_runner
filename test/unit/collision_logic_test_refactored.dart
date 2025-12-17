import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_neon_runner/game/collision/collision_engine.dart';
import 'package:flutter_neon_runner/game/collision/collision_types.dart';
import 'package:flutter_neon_runner/game/collision/entity_factory.dart';
import 'package:flutter_neon_runner/models/game_state.dart';

void main() {
  group('Refactored Collision Logic Tests', () {
    late CollisionEngine collisionEngine;

    setUp(() {
      collisionEngine = CollisionEngine(cellSize: 100.0);
      CollisionEntityFactory.resetIdCounter();
    });

    test('should detect player-obstacle collision when overlapping', () {
      // Arrange
      final player = CollisionEntityFactory.createTestPlayerEntity(
        x: 0, y: 0, width: 50, height: 50,
      );
      final obstacle = CollisionEntityFactory.createTestObstacleEntity(
        x: 25, y: 25, // Overlapping with player
        obstacleType: ObstacleType.ground,
      );

      // Act
      collisionEngine.addEntity(player);
      collisionEngine.addEntity(obstacle);
      final collisions = collisionEngine.detectCollisions();

      // Assert
      expect(collisions.length, equals(1));
      expect(collisions.first.collisionInfo.entityA.type, equals(EntityType.player));
      expect(collisions.first.collisionInfo.entityB.type, equals(EntityType.obstacle));
    });

    test('should not detect collision when objects are separate', () {
      // Arrange
      final player = CollisionEntityFactory.createTestPlayerEntity(
        x: 0, y: 0, width: 50, height: 50,
      );
      final obstacle = CollisionEntityFactory.createTestObstacleEntity(
        x: 100, y: 100, // Far away from player
        obstacleType: ObstacleType.ground,
      );

      // Act
      collisionEngine.addEntity(player);
      collisionEngine.addEntity(obstacle);
      final collisions = collisionEngine.detectCollisions();

      // Assert
      expect(collisions.length, equals(0));
    });

    test('should detect player-powerup collision correctly', () {
      // Arrange
      final player = CollisionEntityFactory.createTestPlayerEntity(
        x: 10, y: 10, width: 40, height: 40,
      );
      final powerUp = CollisionEntityFactory.createPowerUpEntity(
        powerUpType: 'shield',
        x: 30, y: 30, width: 20, height: 20,
      );

      // Act
      collisionEngine.addEntity(player);
      collisionEngine.addEntity(powerUp);
      final collisions = collisionEngine.detectCollisions();

      // Assert
      expect(collisions.length, equals(1));
      expect(collisions.first.collisionInfo.entityA.type, equals(EntityType.player));
      expect(collisions.first.collisionInfo.entityB.type, equals(EntityType.powerUp));
    });

    test('should handle edge case collision (touching edges)', () {
      // Arrange
      final player = CollisionEntityFactory.createTestPlayerEntity(
        x: 0, y: 0, width: 50, height: 50,
      );
      final obstacle = CollisionEntityFactory.createTestObstacleEntity(
        x: 50, y: 0, // Exactly at the edge
        obstacleType: ObstacleType.ground,
      );

      // Act
      collisionEngine.addEntity(player);
      collisionEngine.addEntity(obstacle);
      final collisions = collisionEngine.detectCollisions();

      // Assert
      // Rect.overlaps() returns false for rectangles that only touch at edges
      // This is the correct behavior for overlapping collision detection
      expect(collisions.length, equals(0));
    });

    test('should detect power-up collection radius', () {
      // Arrange
      final player = CollisionEntityFactory.createTestPlayerEntity(
        x: 0, y: 0, width: 50, height: 50,
      );
      final powerUp = CollisionEntityFactory.createPowerUpEntity(
        powerUpType: 'shield',
        x: 60, y: 60, // Outside collision but within collection radius
        width: 20, height: 20,
        collectionRadius: 80.0,
      );

      // Act
      final canCollect = powerUp.canCollect(player);

      // Assert
      // Distance from (0,0) to (60,60) = sqrt(60^2 + 60^2) = sqrt(7200) ≈ 84.85
      // With radius 80, this should be false
      expect(canCollect, isFalse);
    });

    test('should validate collision priorities correctly', () {
      // Arrange
      final player = CollisionEntityFactory.createTestPlayerEntity(x: 100, y: 100);

      final obstacle1 = CollisionEntityFactory.createTestObstacleEntity(
          x: 150, y: 100, obstacleType: ObstacleType.spike,
        );
        final obstacle2 = CollisionEntityFactory.createPowerUpEntity(
          powerUpType: 'shield', x: 200, y: 100,
        );
        final obstacle3 = CollisionEntityFactory.createTestObstacleEntity(
          x: 250, y: 100, obstacleType: ObstacleType.hazardZone,
        );

        final collisions = [
          CollisionEvent(
            collisionInfo: CollisionInfo(
              entityA: player,
              entityB: obstacle1,
            ),
            priority: CollisionPriority.high,
          ),
          CollisionEvent(
            collisionInfo: CollisionInfo(
              entityA: player,
              entityB: obstacle2,
            ),
            priority: CollisionPriority.low,
          ),
          CollisionEvent(
            collisionInfo: CollisionInfo(
              entityA: player,
              entityB: obstacle3,
            ),
            priority: CollisionPriority.critical,
          ),
        ];

      // Act - Sort by priority
      final sortedCollisions = List<CollisionEvent>.from(collisions);
      sortedCollisions.sort((a, b) => b.priority.index.compareTo(a.priority.index));

      // Assert
      expect(sortedCollisions[0].priority, equals(CollisionPriority.critical));
      expect(sortedCollisions[1].priority, equals(CollisionPriority.high));
      expect(sortedCollisions[2].priority, equals(CollisionPriority.low));
    });

    test('should handle multiple simultaneous collisions', () {
      // Arrange
      final player = CollisionEntityFactory.createTestPlayerEntity(
        x: 25, y: 25, width: 50, height: 50,
      );

      // Position multiple objects around the player
      final obstacle = CollisionEntityFactory.createTestObstacleEntity(
        x: 30, y: 30, obstacleType: ObstacleType.ground,
      );
      final powerUp = CollisionEntityFactory.createPowerUpEntity(
        powerUpType: 'shield', x: 35, y: 35, width: 30, height: 30,
      );
      final aerialObstacle = CollisionEntityFactory.createTestObstacleEntity(
        x: 40, y: 40, obstacleType: ObstacleType.aerial,
      );

      // Act
      collisionEngine.addEntity(player);
      collisionEngine.addEntity(obstacle);
      collisionEngine.addEntity(powerUp);
      collisionEngine.addEntity(aerialObstacle);

      final detectedCollisions = collisionEngine.detectCollisions();

      // Assert
      expect(detectedCollisions.length, equals(5));

      // Verify all entities are involved in collisions
      final entityIds = detectedCollisions
          .map((c) => [c.collisionInfo.entityA.id, c.collisionInfo.entityB.id])
          .expand((ids) => ids)
          .toSet();

      expect(entityIds.contains(player.id), isTrue);
      expect(entityIds.contains(obstacle.id), isTrue);
      expect(entityIds.contains(powerUp.id), isTrue);
      expect(entityIds.contains(aerialObstacle.id), isTrue);
    });

    test('should handle grazing detection correctly', () {
      // Arrange
      final player = CollisionEntityFactory.createTestPlayerEntity(x: 100, y: 100);
      final obstacle = CollisionEntityFactory.createTestObstacleEntity(
        x: 160, y: 100, // Close enough for grazing but not collision
        obstacleType: ObstacleType.aerial,
      );

      // Act
      collisionEngine.addEntity(player);
      collisionEngine.addEntity(obstacle);

      final collisions = collisionEngine.detectCollisions();
      final grazingEvents = collisionEngine.detectGrazing(40.0); // 40 pixel graze distance

      // Assert
      expect(collisions.length, equals(0)); // No actual collision
      expect(grazingEvents.length, equals(1)); // But should detect grazing
    });

    test('should efficiently handle large number of entities', () {
      // Arrange - Create a grid of entities
      final player = CollisionEntityFactory.createTestPlayerEntity(x: 250, y: 250);
      collisionEngine.addEntity(player);

      // Add 50 obstacles in a grid pattern around the player
      for (var i = 0; i < 10; i++) {
        for (var j = 0; j < 5; j++) {
          final obstacle = CollisionEntityFactory.createTestObstacleEntity(
            x: i * 50.0,
            y: j * 50.0,
            obstacleType: ObstacleType.ground,
          );
          collisionEngine.addEntity(obstacle);
        }
      }

      // Act
      final collisions = collisionEngine.detectCollisions();

      // Assert
      // Player at (250, 250) should collide with obstacle at (250, 250)
      expect(collisions.length, equals(1));
      expect(collisionEngine.entityCount, equals(51)); // 1 player + 50 obstacles
    });

    tearDown(() {
      collisionEngine.clear();
      CollisionEntityFactory.resetIdCounter();
    });
  });
}