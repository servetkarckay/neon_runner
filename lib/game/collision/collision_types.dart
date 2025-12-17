import 'dart:math';
import 'package:flutter/painting.dart';
import 'package:vector_math/vector_math.dart' hide Colors;
import 'package:flutter_neon_runner/models/obstacle_data.dart';
import 'package:flutter_neon_runner/models/player_data.dart';
import 'package:flutter_neon_runner/models/game_state.dart';
import 'package:flutter_neon_runner/utils/collision_utils.dart';
import 'package:flutter_neon_runner/game/collision/collision_helpers.dart';

/// Represents the shape of a collidable entity
enum CollisionShape {
  rectangle,
  circle,
  polygon,
  line,
}

/// Represents the type of a collidable entity
enum EntityType {
  player,
  obstacle,
  powerUp,
  particle,
  projectile,
}

/// Base class for all collidable entities
abstract class CollidableEntity {
  final String id;
  final EntityType type;
  final CollisionShape shape;
  final Rect bounds;
  final Vector2 velocity;
  final Map<String, dynamic> properties;

  CollidableEntity({
    required this.id,
    required this.type,
    required this.shape,
    required this.bounds,
    required this.velocity,
    Map<String, dynamic>? properties,
  }) : properties = properties ?? {};

  /// Gets the center position of the entity
  Vector2 get center => Vector2(
    bounds.left + bounds.width / 2,
    bounds.top + bounds.height / 2,
  );

  /// Gets the radius for circular collision detection
  double get radius => min(bounds.width, bounds.height) / 2;

  /// Checks if this entity can collide with another entity
  bool canCollideWith(CollidableEntity other) {
    // Same type entities usually don't collide with each other
    if (type == other.type) return false;

    // Particles typically don't collide with anything
    if (type == EntityType.particle || other.type == EntityType.particle) return false;

    return true;
  }

  /// Creates a collision shape specific to this entity
  CollisionShapeData createShapeData();
}

/// Shape-specific collision data
abstract class CollisionShapeData {
  final Rect bounds;

  CollisionShapeData(this.bounds);

  bool collidesWith(CollisionShapeData other);
}

/// Rectangle collision shape
class RectangleShapeData extends CollisionShapeData {
  RectangleShapeData(super.bounds);

  @override
  bool collidesWith(CollisionShapeData other) {
    if (other is RectangleShapeData) {
      return bounds.overlaps(other.bounds);
    } else if (other is CircleShapeData) {
      return _rectCircleCollision(bounds, other.center, other.radius);
    } else if (other is LineShapeData) {
      return _lineRect(
        other.start.x, other.start.y,
        other.end.x, other.end.y,
        bounds,
      );
    }
    return false;
  }

  bool _rectCircleCollision(Rect rect, Vector2 circleCenter, double circleRadius) {
    final testX = max(rect.left, min(circleCenter.x, rect.right));
    final testY = max(rect.top, min(circleCenter.y, rect.bottom));

    final dx = circleCenter.x - testX;
    final dy = circleCenter.y - testY;

    return (dx * dx + dy * dy) < (circleRadius * circleRadius);
  }

  bool _lineRect(double x1, double y1, double x2, double y2, Rect rect) {
    // Check if line endpoints are inside rectangle
    if (rect.contains(Offset(x1, y1)) || rect.contains(Offset(x2, y2))) {
      return true;
    }

    // Check if line intersects any of the rectangle's sides
    return _lineLine(x1, y1, x2, y2, rect.left, rect.top, rect.right, rect.top) || // Top
           _lineLine(x1, y1, x2, y2, rect.right, rect.top, rect.right, rect.bottom) || // Right
           _lineLine(x1, y1, x2, y2, rect.right, rect.bottom, rect.left, rect.bottom) || // Bottom
           _lineLine(x1, y1, x2, y2, rect.left, rect.bottom, rect.left, rect.top); // Left
  }

  bool _lineLine(double x1, double y1, double x2, double y2, double x3, double y3, double x4, double y4) {
    final denominator = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4);
    if (denominator == 0) return false;

    final t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denominator;
    final u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / denominator;

    return t >= 0 && t <= 1 && u >= 0 && u <= 1;
  }
}

/// Circle collision shape
class CircleShapeData extends CollisionShapeData {
  final Vector2 center;
  final double radius;

  CircleShapeData(super.bounds, this.center, this.radius);

  @override
  bool collidesWith(CollisionShapeData other) {
    if (other is CircleShapeData) {
      return CollisionHelpers.circleCircleCollision(center, radius, other.center, other.radius);
    } else if (other is RectangleShapeData) {
      return CollisionHelpers.rectCircleCollision(other.bounds, center, radius);
    } else if (other is LineShapeData) {
      return CollisionHelpers.lineCircle(
        other.start.x, other.start.y,
        other.end.x, other.end.y,
        center.x, center.y,
        radius,
      );
    }
    return false;
  }
}

/// Line collision shape
class LineShapeData extends CollisionShapeData {
  final Vector2 start;
  final Vector2 end;

  LineShapeData(super.bounds, this.start, this.end);

  @override
  bool collidesWith(CollisionShapeData other) {
    if (other is LineShapeData) {
      return CollisionHelpers.lineLine(
        start.x, start.y,
        end.x, end.y,
        other.start.x, other.start.y,
        other.end.x, other.end.y,
      );
    } else if (other is RectangleShapeData) {
      return CollisionHelpers.lineRect(
        start.x, start.y,
        end.x, end.y,
        other.bounds,
      );
    } else if (other is CircleShapeData) {
      return CollisionHelpers.lineCircle(
        start.x, start.y,
        end.x, end.y,
        other.center.x, other.center.y,
        other.radius,
      );
    }
    return false;
  }
}

/// Player entity
class PlayerEntity extends CollidableEntity {
  final PlayerData playerData;
  final Rect? currentHitbox;

  PlayerEntity({
    required String id,
    required this.playerData,
    required this.currentHitbox,
  }) : super(
    id: id,
    type: EntityType.player,
    shape: CollisionShape.rectangle,
    bounds: Rect.fromLTWH(playerData.x, playerData.y, playerData.width, playerData.height),
    velocity: Vector2(playerData.currentVelocity.x, playerData.currentVelocity.y),
    properties: {
      'isJumping': playerData.isJumping,
      'hasShield': playerData.hasShield,
      'invincibleTimer': playerData.invincibleTimer,
      'isGrazing': playerData.isGrazing,
    },
  );

  @override
  CollisionShapeData createShapeData() {
    // Use current hitbox if available, otherwise use bounds with padding
    final effectiveBounds = currentHitbox ?? bounds;
    return RectangleShapeData(effectiveBounds);
  }
}

/// Obstacle entity
class ObstacleEntity extends CollidableEntity {
  final ObstacleData obstacleData;

  ObstacleEntity({
    required String id,
    required this.obstacleData,
  }) : super(
    id: id,
    type: EntityType.obstacle,
    shape: _getShapeForObstacle(obstacleData),
    bounds: Rect.fromLTWH(obstacleData.x, obstacleData.y, obstacleData.width, obstacleData.height),
    velocity: Vector2.zero(),
    properties: {
      'obstacleType': obstacleData.type,
      'grazed': obstacleData.grazed,
      'damage': 1, // Default damage since ObstacleData doesn't have this property
    },
  );

  static CollisionShape _getShapeForObstacle(ObstacleData obstacle) {
    switch (obstacle.type) {
      case ObstacleType.fallingDrop:
        return CollisionShape.circle;
      case ObstacleType.rotatingLaser:
      case ObstacleType.slantedSurface:
        return CollisionShape.line;
      case ObstacleType.spike:
      case ObstacleType.aerial:
      case ObstacleType.movingAerial:
        return CollisionShape.polygon;
      default:
        return CollisionShape.rectangle;
    }
  }

  @override
  CollisionShapeData createShapeData() {
    switch (shape) {
      case CollisionShape.circle:
        final center = Vector2(
          bounds.left + bounds.width / 2,
          bounds.top + bounds.height / 2,
        );
        final radius = bounds.width / 2 - 6; // Account for visual padding
        return CircleShapeData(bounds, center, radius);

      case CollisionShape.line:
        if (obstacleData is RotatingLaserObstacleData) {
          final centerX = bounds.left + bounds.width / 2;
          final centerY = bounds.top + bounds.height / 2;
          final angle = (obstacleData as RotatingLaserObstacleData).angle;
          final beamLength = (obstacleData as RotatingLaserObstacleData).beamLength;

          final end = Vector2(
            centerX + cos(angle) * beamLength,
            centerY + sin(angle) * beamLength,
          );

          return LineShapeData(bounds, Vector2(centerX, centerY), end);
        } else if (obstacleData is SlantedObstacleData) {
          final slantedData = obstacleData as SlantedObstacleData;
          final x1 = bounds.left + slantedData.lineX1;
          final y1 = bounds.top + slantedData.lineY1;
          final x2 = bounds.left + slantedData.lineX2;
          final y2 = bounds.top + slantedData.lineY2;

          return LineShapeData(bounds, Vector2(x1, y1), Vector2(x2, y2));
        }
        break;

      case CollisionShape.rectangle:
        return RectangleShapeData(bounds);

      case CollisionShape.polygon:
        // For complex shapes, fall back to rectangle with specialized collision logic
        return RectangleShapeData(bounds);
    }

    return RectangleShapeData(bounds);
  }
}

/// Power-up entity
class PowerUpEntity extends CollidableEntity {
  final String powerUpType;
  final double collectionRadius;

  PowerUpEntity({
    required String id,
    required this.powerUpType,
    required Rect bounds,
    this.collectionRadius = 60.0,
  }) : super(
    id: id,
    type: EntityType.powerUp,
    shape: CollisionShape.circle,
    bounds: bounds,
    velocity: Vector2.zero(),
    properties: {
      'powerUpType': powerUpType,
      'collectionRadius': collectionRadius,
    },
  );

  @override
  CollisionShapeData createShapeData() {
    final center = Vector2(
      bounds.left + bounds.width / 2,
      bounds.top + bounds.height / 2,
    );
    return CircleShapeData(bounds, center, radius);
  }

  /// Checks if player is within collection radius
  bool canCollect(PlayerEntity player) {
    final distance = (center - player.center).length;
    return distance <= collectionRadius;
  }
}

/// Collision information between two entities
class CollisionInfo {
  final CollidableEntity entityA;
  final CollidableEntity entityB;
  final Vector2? contactPoint;
  final Vector2? normal;
  final double? timeOfImpact;
  final double penetrationDepth;

  CollisionInfo({
    required this.entityA,
    required this.entityB,
    this.contactPoint,
    this.normal,
    this.timeOfImpact,
    this.penetrationDepth = 0.0,
  });

  /// Gets the other entity in the collision
  CollidableEntity getOther(CollidableEntity entity) {
    return entity.id == entityA.id ? entityB : entityA;
  }
}

/// Priority levels for collision resolution
enum CollisionPriority {
  critical, // Hazards that kill player
  high,     // Obstacles that block movement
  medium,   // Power-ups and collectibles
  low,      // Environmental effects
}

/// Collision event with priority
class CollisionEvent {
  final CollisionInfo collisionInfo;
  final CollisionPriority priority;
  final DateTime timestamp;

  CollisionEvent({
    required this.collisionInfo,
    required this.priority,
  }) : timestamp = DateTime.now();
}