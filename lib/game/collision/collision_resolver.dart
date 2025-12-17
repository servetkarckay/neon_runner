import 'package:vector_math/vector_math.dart';
import 'package:flutter_neon_runner/game/collision/collision_types.dart';
import 'package:flutter_neon_runner/models/game_state.dart';

/// Handles physics-based collision resolution to prevent overlapping entities
class CollisionResolver {
  /// Resolves all detected collisions by applying position corrections
  /// Returns the number of resolved collisions
  int resolveCollisions(List<CollisionInfo> collisions) {
    int resolvedCount = 0;

    // Process collisions in order of deepest penetration first
    final sortedCollisions = List<CollisionInfo>.from(collisions);
    sortedCollisions.sort((a, b) => b.penetrationDepth.compareTo(a.penetrationDepth));

    for (final collision in sortedCollisions) {
      if (resolveCollision(collision)) {
        resolvedCount++;
      }
    }

    return resolvedCount;
  }

  /// Resolves a single collision by separating the entities
  /// Returns true if the collision was resolved
  bool resolveCollision(CollisionInfo collision) {
    final entityA = collision.entityA;
    final entityB = collision.entityB;

    // Skip if either entity cannot be moved (static obstacles)
    if (!_canMove(entityA) && !_canMove(entityB)) {
      return false;
    }

    // Calculate separation vector
    final separation = calculateSeparation(collision);

    // Apply position correction based on mass/movability
    if (_canMove(entityA) && _canMove(entityB)) {
      // Both can move - split the separation
      final halfSeparation = separation / 2;
      _applyPositionCorrection(entityA, -halfSeparation);
      _applyPositionCorrection(entityB, halfSeparation);
    } else if (_canMove(entityA)) {
      // Only A can move - apply full separation
      _applyPositionCorrection(entityA, -separation);
    } else {
      // Only B can move - apply full separation
      _applyPositionCorrection(entityB, separation);
    }

    // Zero out relative velocity along collision normal to prevent bouncing
    _resolveVelocity(collision);

    return true;
  }

  /// Calculates the separation vector needed to resolve the collision
  Vector2 calculateSeparation(CollisionInfo collision) {
    final normal = collision.normal;
    final penetration = collision.penetrationDepth;

    // Use the calculated penetration depth and normal
    // Add a small epsilon to ensure complete separation
    const epsilon = 0.01;
    return normal! * (penetration + epsilon);
  }

  /// Applies position correction to an entity
  void _applyPositionCorrection(CollidableEntity entity, Vector2 correction) {
    // For obstacles, we need to update their position data
    if (entity is ObstacleEntity) {
      entity.obstacleData.x += correction.x;
      entity.obstacleData.y += correction.y;
    }
    // For player entity
    else if (entity is PlayerEntity) {
      entity.playerData.x += correction.x;
      entity.playerData.y += correction.y;
    }
    // For other entities, apply generic position update if they have a position property
    else if (entity.properties.containsKey('x') && entity.properties.containsKey('y')) {
      entity.properties['x'] = (entity.properties['x'] as num) + correction.x;
      entity.properties['y'] = (entity.properties['y'] as num) + correction.y;
    }
  }

  /// Resolves velocities to prevent objects from moving into each other again
  void _resolveVelocity(CollisionInfo collision) {
    // Since velocity is final in CollidableEntity, we can't directly modify it
    // The velocity resolution will be handled by the individual systems that own the entities
    // This is a limitation of the current architecture
    // For now, we only apply position correction
  }

  
  /// Checks if an entity can be moved during resolution
  bool _canMove(CollidableEntity entity) {
    // Player can always be moved
    if (entity.type == EntityType.player) return true;

    // Moving obstacles can be moved
    if (entity is ObstacleEntity) {
      final obstacleType = entity.obstacleData.type;
      return obstacleType == ObstacleType.movingPlatform ||
             obstacleType == ObstacleType.movingAerial ||
             obstacleType == ObstacleType.hazardZone ||
             obstacleType == ObstacleType.fallingDrop;
    }

    // Power-ups and projectiles can move
    if (entity.type == EntityType.powerUp || entity.type == EntityType.projectile) return true;

    return false;
  }
}