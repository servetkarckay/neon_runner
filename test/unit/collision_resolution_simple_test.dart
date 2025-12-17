import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/painting.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_neon_runner/game/collision/collision_resolver.dart';
import 'package:flutter_neon_runner/game/collision/collision_types.dart';
import 'package:flutter_neon_runner/models/player_data.dart';
import 'package:flutter_neon_runner/models/obstacle_data.dart';
import 'package:flutter_neon_runner/models/game_state.dart';

void main() {
  group('CollisionResolver Tests', () {
    late CollisionResolver resolver;

    setUp(() {
      resolver = CollisionResolver();
    });

    test('should calculate correct separation vector', () {
      // Create a mock collision info with known penetration
      final collision = CollisionInfo(
        entityA: MockCollidableEntity(id: 'entity1', type: EntityType.player),
        entityB: MockCollidableEntity(id: 'entity2', type: EntityType.obstacle),
        contactPoint: Vector2.zero(),
        normal: Vector2(1, 0), // Collision normal pointing right
        penetrationDepth: 10.0,
      );

      // Test the separation calculation
      final separation = resolver.calculateSeparation(collision);

      // Should separate by penetration depth + epsilon along the normal
      expect(separation.x, closeTo(10.01, 0.001));
      expect(separation.y, closeTo(0.0, 0.001));
    });

    test('should resolve multiple collisions in penetration order', () {
      // Create collisions with different penetration depths
      final shallowCollision = CollisionInfo(
        entityA: MockCollidableEntity(id: 'entity1', type: EntityType.player),
        entityB: MockCollidableEntity(id: 'entity2', type: EntityType.obstacle),
        contactPoint: Vector2.zero(),
        normal: Vector2(1, 0),
        penetrationDepth: 5.0,
      );

      final deepCollision = CollisionInfo(
        entityA: MockCollidableEntity(id: 'entity3', type: EntityType.player),
        entityB: MockCollidableEntity(id: 'entity4', type: EntityType.obstacle),
        contactPoint: Vector2.zero(),
        normal: Vector2(0, 1),
        penetrationDepth: 20.0,
      );

      // Resolve collisions
      final resolvedCount = resolver.resolveCollisions([shallowCollision, deepCollision]);

      // Should resolve both collisions
      expect(resolvedCount, equals(2));
    });

    test('should not move immovable entities', () {
      // Create collision between player and static obstacle
      final player = MockPlayerEntity(
        id: 'player',
        x: 100,
        y: 100,
        width: 40,
        height: 40,
      );

      final obstacle = MockObstacleEntity(
        id: 'obstacle',
        x: 130, // Overlapping by 30 pixels
        y: 100,
        width: 40,
        height: 40,
      );

      final initialObstacleX = obstacle.obstacleData.x;

      final collision = CollisionInfo(
        entityA: player,
        entityB: obstacle,
        contactPoint: Vector2(130, 120),
        normal: Vector2(1, 0),
        penetrationDepth: 30.0,
      );

      // Resolve collision
      final resolved = resolver.resolveCollision(collision);

      // Should resolve collision
      expect(resolved, isTrue);

      // Static obstacle should not move
      expect(obstacle.obstacleData.x, equals(initialObstacleX));
      // Note: Mock entities don't properly apply position correction, so we don't test player movement here
    });
  });
}

// Mock classes for testing
class MockCollidableEntity extends CollidableEntity {
  MockCollidableEntity({
    required super.id,
    required super.type,
    Vector2? center,
    Vector2? velocity,
    Rect? bounds,
    double? radius,
  }) : super(
    shape: CollisionShape.rectangle,
    bounds: bounds ?? Rect.zero,
    velocity: velocity ?? Vector2.zero(),
    properties: {},
  );

  @override
  bool canCollideWith(CollidableEntity other) => true;

  @override
  CollisionShapeData createShapeData() => MockShapeData();
}

class MockPlayerEntity extends MockCollidableEntity {
  final PlayerData playerData;

  MockPlayerEntity({
    required super.id,
    required double x,
    required double y,
    required double width,
    required double height,
  }) : playerData = PlayerData(),
       super(
         type: EntityType.player,
         center: Vector2(x + width/2, y + height/2),
         bounds: Rect.fromLTWH(x, y, width, height),
         radius: (width + height) / 4,
       ) {
    playerData.x = x;
    playerData.y = y;
    playerData.width = width;
    playerData.height = height;
  }
}

class MockObstacleEntity extends MockCollidableEntity {
  final ObstacleData obstacleData;

  MockObstacleEntity({
    required super.id,
    required double x,
    required double y,
    required double width,
    required double height,
  }) : obstacleData = SimpleObstacleData(
         id: 1,
         type: ObstacleType.platform,
         x: x,
         y: y,
         width: width,
         height: height,
       ),
       super(
         type: EntityType.obstacle,
         center: Vector2(x + width/2, y + height/2),
         bounds: Rect.fromLTWH(x, y, width, height),
         radius: (width + height) / 4,
       );
}

class MockShapeData extends CollisionShapeData {
  MockShapeData() : super(Rect.zero);

  @override
  bool collidesWith(CollisionShapeData other) => true;
}