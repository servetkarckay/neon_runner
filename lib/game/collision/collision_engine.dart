import 'dart:collection';
import 'dart:math';
import 'package:flutter/painting.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_neon_runner/game/collision/collision_types.dart';
import 'package:flutter_neon_runner/game/collision/spatial_hash.dart';
import 'package:flutter_neon_runner/game/collision/collision_helpers.dart';
import 'package:flutter_neon_runner/game/collision/collision_resolver.dart';
import 'package:flutter_neon_runner/utils/collision_utils.dart';
import 'package:flutter_neon_runner/utils/math_utils.dart';
import 'package:flutter_neon_runner/models/game_state.dart';

/// Core collision detection engine with spatial optimization
class CollisionEngine {
  final SpatialHash _spatialHash;
  final List<CollidableEntity> _entities;
  final Set<String> _collisionPairs;
  final CollisionResolver _resolver;

  CollisionEngine({
    double cellSize = 100.0,
  }) : _spatialHash = SpatialHash(cellSize: cellSize),
       _entities = [],
       _collisionPairs = HashSet<String>(),
       _resolver = CollisionResolver();

  /// Adds an entity to the collision system
  void addEntity(CollidableEntity entity) {
    _entities.add(entity);
    _spatialHash.insert(entity);
  }

  /// Removes an entity from the collision system
  void removeEntity(CollidableEntity entity) {
    _entities.remove(entity);
    _spatialHash.remove(entity);

    // Remove any collision pairs involving this entity
    _collisionPairs.removeWhere((pair) => pair.contains(entity.id));
  }

  /// Updates entity position in spatial hash
  void updateEntity(CollidableEntity entity, Rect newBounds) {
    _spatialHash.remove(entity);

    // Update bounds (this would require making bounds mutable in CollidableEntity)
    // For now, remove and re-add
    _spatialHash.insert(entity);
  }

  /// Detects all collisions in the current frame
  List<CollisionEvent> detectCollisions() {
    final collisions = <CollisionEvent>[];
    _collisionPairs.clear();

    // Use spatial hash for efficient broad-phase collision detection
    for (final entity in _entities) {
      final potentialCollisions = _spatialHash.query(entity.bounds);

      for (final other in potentialCollisions) {
        if (entity.id == other.id) continue;

        // Skip if we've already processed this pair
        final pairKey = _getPairKey(entity.id, other.id);
        if (_collisionPairs.contains(pairKey)) continue;

        if (entity.canCollideWith(other)) {
          final collision = _checkCollision(entity, other);
          if (collision != null) {
            final priority = _getCollisionPriority(entity, other, collision);
            collisions.add(CollisionEvent(
              collisionInfo: collision,
              priority: priority,
            ));
            _collisionPairs.add(pairKey);
          }
        }
      }
    }

    return collisions;
  }

  /// Detects and resolves all collisions in the current frame
  /// This is the main method that should be called to prevent overlapping
  List<CollisionEvent> detectAndResolveCollisions() {
    final collisions = <CollisionEvent>[];
    final collisionInfos = <CollisionInfo>[];
    _collisionPairs.clear();

    // First pass: detect all collisions
    for (final entity in _entities) {
      final potentialCollisions = _spatialHash.query(entity.bounds);

      for (final other in potentialCollisions) {
        if (entity.id == other.id) continue;

        // Skip if we've already processed this pair
        final pairKey = _getPairKey(entity.id, other.id);
        if (_collisionPairs.contains(pairKey)) continue;

        if (entity.canCollideWith(other)) {
          final collision = _checkCollision(entity, other);
          if (collision != null) {
            final priority = _getCollisionPriority(entity, other, collision);
            collisions.add(CollisionEvent(
              collisionInfo: collision,
              priority: priority,
            ));
            collisionInfos.add(collision);
            _collisionPairs.add(pairKey);
          }
        }
      }
    }

    // Second pass: resolve all detected collisions
    if (collisionInfos.isNotEmpty) {
      _resolver.resolveCollisions(collisionInfos);
    }

    return collisions;
  }

  /// Performs sweep collision detection for moving entities
  List<CollisionEvent> detectSweptCollisions(double dt) {
    final collisions = <CollisionEvent>[];
    _collisionPairs.clear();

    for (final entity in _entities) {
      if (entity.velocity.length == 0) continue;

      final potentialCollisions = _spatialHash.query(entity.bounds);

      for (final other in potentialCollisions) {
        if (entity.id == other.id) continue;

        final pairKey = _getPairKey(entity.id, other.id);
        if (_collisionPairs.contains(pairKey)) continue;

        if (entity.canCollideWith(other)) {
          final collision = _checkSweptCollision(entity, other, dt);
          if (collision != null) {
            final priority = _getCollisionPriority(entity, other, collision);
            collisions.add(CollisionEvent(
              collisionInfo: collision,
              priority: priority,
            ));
            _collisionPairs.add(pairKey);
          }
        }
      }
    }

    return collisions;
  }

  /// Checks for grazing (near-miss collisions)
  List<CollisionEvent> detectGrazing(double grazeDistance) {
    final grazingEvents = <CollisionEvent>[];

    // First detect actual collisions to exclude them from grazing
    final actualCollisions = detectCollisions();
    final collidingEntityPairs = <String>{};

    for (final event in actualCollisions) {
      final pairKey = _getPairKey(event.collisionInfo.entityA.id, event.collisionInfo.entityB.id);
      collidingEntityPairs.add(pairKey);
    }

    for (final entity in _entities) {
      if (entity.type != EntityType.player) continue;

      final player = entity as PlayerEntity;
      final potentialCollisions = _spatialHash.query(player.bounds);

      for (final other in potentialCollisions) {
        if (other.type != EntityType.obstacle) continue;
        if (other.id == player.id) continue;

        // Skip if this pair is already colliding
        final pairKey = _getPairKey(player.id, other.id);
        if (collidingEntityPairs.contains(pairKey)) continue;

        final obstacle = other as ObstacleEntity;
        if (obstacle.obstacleData.grazed) continue;

        final distance = CollisionHelpers.vectorDistance(player.center, obstacle.center);
        final grazeThreshold = max(obstacle.bounds.width, obstacle.bounds.height) / 2 + grazeDistance;

        if (distance < grazeThreshold) {
          // This counts as a graze
          final collisionInfo = CollisionInfo(
            entityA: player,
            entityB: obstacle,
            penetrationDepth: grazeThreshold - distance,
          );

          grazingEvents.add(CollisionEvent(
            collisionInfo: collisionInfo,
            priority: CollisionPriority.low, // Grazing is low priority
          ));
        }
      }
    }

    return grazingEvents;
  }

  /// Line-of-sight check between two points
  bool hasLineOfSight(Vector2 from, Vector2 to, {Set<EntityType>? ignoreTypes}) {
    ignoreTypes ??= {EntityType.particle};

    // Create a line segment
    final lineBounds = Rect.fromPoints(
      Offset(from.x, from.y),
      Offset(to.x, to.y),
    );

    final potentialCollisions = _spatialHash.query(lineBounds);

    for (final entity in potentialCollisions) {
      if (ignoreTypes.contains(entity.type)) continue;

      // Check if line intersects with entity
      if (_lineIntersectsEntity(from, to, entity)) {
        return false;
      }
    }

    return true;
  }

  /// Raycast to find first entity hit by a ray
  CollidableEntity? raycast(Vector2 origin, Vector2 direction, double maxDistance, {EntityType? targetType}) {
    final end = origin + direction.normalized() * maxDistance;
    final rayBounds = Rect.fromPoints(
      Offset(origin.x, origin.y),
      Offset(end.x, end.y),
    );

    CollidableEntity? closestHit;
    double closestDistance = maxDistance;

    final potentialCollisions = _spatialHash.query(rayBounds);

    for (final entity in potentialCollisions) {
      if (targetType != null && entity.type != targetType) continue;

      final intersection = _rayIntersectsEntity(origin, direction, entity);
      if (intersection != null) {
        final distance = (origin - intersection).length;
        if (distance < closestDistance) {
          closestDistance = distance;
          closestHit = entity;
        }
      }
    }

    return closestHit;
  }

  /// Clears all entities from the system
  void clear() {
    _entities.clear();
    _spatialHash.clear();
    _collisionPairs.clear();
  }

  /// Gets current entity count
  int get entityCount => _entities.length;

  /// Gets all entities of a specific type
  List<CollidableEntity> getEntitiesByType(EntityType type) {
    return _entities.where((e) => e.type == type).toList();
  }

  /// Gets debug information about the spatial hash
  dynamic get debugInfo => _spatialHash.debugInfo;

  // Private methods

  String _getPairKey(String idA, String idB) {
    return idA.compareTo(idB) < 0 ? '$idA-$idB' : '$idB-$idA';
  }

  CollisionInfo? _checkCollision(CollidableEntity entityA, CollidableEntity entityB) {
    final shapeA = entityA.createShapeData();
    final shapeB = entityB.createShapeData();

    if (shapeA.collidesWith(shapeB)) {
      // Calculate collision normal and penetration depth
      final normal = _calculateCollisionNormal(entityA, entityB);
      final penetration = _calculatePenetrationDepth(entityA, entityB);

      return CollisionInfo(
        entityA: entityA,
        entityB: entityB,
        contactPoint: _calculateContactPoint(entityA, entityB),
        normal: normal,
        penetrationDepth: penetration,
      );
    }

    return null;
  }

  CollisionInfo? _checkSweptCollision(CollidableEntity entityA, CollidableEntity entityB, double dt) {
    // Use sweep collision detection for moving entities
    final relativeVelocity = entityA.velocity - entityB.velocity;

    if (relativeVelocity.length == 0) {
      return _checkCollision(entityA, entityB);
    }

    // For simplicity, use sweepRectRectCollision for rectangles
    // In a full implementation, we'd have specialized sweep tests for each shape combination
    final toi = sweepRectRectCollision(
      entityA.bounds,
      relativeVelocity,
      entityB.bounds,
    );

    if (toi != null && toi <= dt) {
      final contactPoint = _calculateContactPoint(entityA, entityB, toi: toi);
      final normal = _calculateCollisionNormal(entityA, entityB);

      return CollisionInfo(
        entityA: entityA,
        entityB: entityB,
        timeOfImpact: toi,
        contactPoint: contactPoint,
        normal: normal,
        penetrationDepth: 0.0, // Sweep collisions typically don't have penetration
      );
    }

    return null;
  }

  Vector2 _calculateCollisionNormal(CollidableEntity entityA, CollidableEntity entityB) {
    final direction = entityB.center - entityA.center;
    return direction.normalized();
  }

  double _calculatePenetrationDepth(CollidableEntity entityA, CollidableEntity entityB) {
    final distance = (entityA.center - entityB.center).length;
    final combinedRadius = entityA.radius + entityB.radius;
    return max(0.0, combinedRadius - distance);
  }

  Vector2 _calculateContactPoint(CollidableEntity entityA, CollidableEntity entityB, {double? toi}) {
    // Simple approximation: use the midpoint between centers
    // In a full implementation, this would be more accurate based on the shapes
    return (entityA.center + entityB.center) / 2;
  }

  CollisionPriority _getCollisionPriority(CollidableEntity entityA, CollidableEntity entityB, CollisionInfo collision) {
    // Player-hazard collisions are critical
    if ((entityA.type == EntityType.player && entityB.type == EntityType.obstacle) ||
        (entityB.type == EntityType.player && entityA.type == EntityType.obstacle)) {

      final obstacle = entityA.type == EntityType.obstacle ? entityA : entityB;
      final obstacleType = obstacle.properties['obstacleType'];

      if (obstacleType == ObstacleType.hazardZone ||
          obstacleType == ObstacleType.rotatingLaser ||
          obstacleType == ObstacleType.spike) {
        return CollisionPriority.critical;
      }

      return CollisionPriority.high;
    }

    // Power-ups are medium priority
    if (entityA.type == EntityType.powerUp || entityB.type == EntityType.powerUp) {
      return CollisionPriority.medium;
    }

    return CollisionPriority.low;
  }

  bool _lineIntersectsEntity(Vector2 from, Vector2 to, CollidableEntity entity) {
    return lineRect(from.x, from.y, to.x, to.y, entity.bounds);
  }

  Vector2? _rayIntersectsEntity(Vector2 origin, Vector2 direction, CollidableEntity entity) {
    // Simple ray-rectangle intersection
    final rayBounds = Rect.fromCircle(
      center: Offset(origin.x + direction.x * 1000, origin.y + direction.y * 1000),
      radius: 1.0,
    );

    if (!entity.bounds.overlaps(rayBounds)) return null;

    // For more accurate intersection, we'd need proper ray-shape intersection tests
    // This is a simplified version
    final t = _rayIntersectsRect(origin, direction, entity.bounds);
    return t != null ? origin + direction * t : null;
  }

  double? _rayIntersectsRect(Vector2 origin, Vector2 direction, Rect rect) {
    final invDir = Vector2(1.0 / direction.x, 1.0 / direction.y);

    final t1 = (rect.left - origin.x) * invDir.x;
    final t2 = (rect.right - origin.x) * invDir.x;
    final t3 = (rect.top - origin.y) * invDir.y;
    final t4 = (rect.bottom - origin.y) * invDir.y;

    final tMin = max(min(t1, t2), min(t3, t4));
    final tMax = min(max(t1, t2), max(t3, t4));

    if (tMin <= tMax && tMax >= 0) {
      return tMin >= 0 ? tMin : tMax;
    }

    return null;
  }
}