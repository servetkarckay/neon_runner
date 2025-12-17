import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/painting.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_neon_runner/game/collision/collision_resolver.dart';
import 'package:flutter_neon_runner/game/collision/collision_types.dart';

void main() {
  group('CollisionResolver Basic Tests', () {
    late CollisionResolver resolver;

    setUp(() {
      resolver = CollisionResolver();
    });

    test('should calculate correct separation vector', () {
      // Create a mock collision info with known penetration
      final collision = CollisionInfo(
        entityA: TestCollidableEntity(
          id: 'entity1',
          type: EntityType.player,
          shape: CollisionShape.rectangle,
        ),
        entityB: TestCollidableEntity(
          id: 'entity2',
          type: EntityType.obstacle,
          shape: CollisionShape.rectangle,
        ),
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
        entityA: TestCollidableEntity(
          id: 'entity1',
          type: EntityType.player,
          shape: CollisionShape.rectangle,
        ),
        entityB: TestCollidableEntity(
          id: 'entity2',
          type: EntityType.obstacle,
          shape: CollisionShape.rectangle,
        ),
        contactPoint: Vector2.zero(),
        normal: Vector2(1, 0),
        penetrationDepth: 5.0,
      );

      final deepCollision = CollisionInfo(
        entityA: TestCollidableEntity(
          id: 'entity3',
          type: EntityType.player,
          shape: CollisionShape.rectangle,
        ),
        entityB: TestCollidableEntity(
          id: 'entity4',
          type: EntityType.obstacle,
          shape: CollisionShape.rectangle,
        ),
        contactPoint: Vector2.zero(),
        normal: Vector2(0, 1),
        penetrationDepth: 20.0,
      );

      final collisions = [shallowCollision, deepCollision];

      // Resolve collisions
      final resolvedCount = resolver.resolveCollisions(collisions);

      // Should resolve both collisions
      expect(resolvedCount, equals(2));
    });

    test('should separate along minimum overlap axis', () {
      // Test horizontal overlap (smaller)
      final horizontalCollision = CollisionInfo(
        entityA: TestCollidableEntity(
          id: 'entity1',
          type: EntityType.player,
          shape: CollisionShape.rectangle,
        ),
        entityB: TestCollidableEntity(
          id: 'entity2',
          type: EntityType.obstacle,
          shape: CollisionShape.rectangle,
        ),
        contactPoint: Vector2.zero(),
        normal: Vector2(1, 0),
        penetrationDepth: 5.0,
      );

      final hSeparation = resolver.calculateSeparation(horizontalCollision);

      // Should separate horizontally
      expect(hSeparation.x.abs(), greaterThan(0));
      expect(hSeparation.y, equals(0));

      // Test vertical overlap (smaller)
      final verticalCollision = CollisionInfo(
        entityA: TestCollidableEntity(
          id: 'entity3',
          type: EntityType.player,
          shape: CollisionShape.rectangle,
        ),
        entityB: TestCollidableEntity(
          id: 'entity4',
          type: EntityType.obstacle,
          shape: CollisionShape.rectangle,
        ),
        contactPoint: Vector2.zero(),
        normal: Vector2(0, 1),
        penetrationDepth: 3.0,
      );

      final vSeparation = resolver.calculateSeparation(verticalCollision);

      // Should separate vertically
      expect(vSeparation.x, equals(0));
      expect(vSeparation.y.abs(), greaterThan(0));
    });
  });
}

// Simple test entity for testing collision resolution
class TestCollidableEntity extends CollidableEntity {
  TestCollidableEntity({
    required super.id,
    required super.type,
    required super.shape,
  }) : super(
         bounds: Rect.zero,
         velocity: Vector2.zero(),
       );

  @override
  bool canCollideWith(CollidableEntity other) => true;

  @override
  CollisionShapeData createShapeData() => TestShapeData(Rect.zero);
}

class TestShapeData extends CollisionShapeData {
  TestShapeData(super.bounds);

  @override
  bool collidesWith(CollisionShapeData other) => true;
}