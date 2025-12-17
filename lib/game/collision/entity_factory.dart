import 'package:flutter/painting.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_neon_runner/game/collision/collision_types.dart';
import 'package:flutter_neon_runner/models/player_data.dart';
import 'package:flutter_neon_runner/models/obstacle_data.dart';
import 'package:flutter_neon_runner/models/game_state.dart';

/// Factory for creating collidable entities from game data
class CollisionEntityFactory {
  static int _nextId = 1;

  /// Creates a player entity from player data
  static PlayerEntity createPlayerEntity(PlayerData playerData, {Rect? hitbox}) {
    return PlayerEntity(
      id: 'player_${_nextId++}',
      playerData: playerData,
      currentHitbox: hitbox,
    );
  }

  /// Creates an obstacle entity from obstacle data
  static ObstacleEntity createObstacleEntity(ObstacleData obstacleData) {
    return ObstacleEntity(
      id: 'obstacle_${obstacleData.id}',
      obstacleData: obstacleData,
    );
  }

  /// Creates multiple obstacle entities from obstacle data list
  static List<ObstacleEntity> createObstacleEntities(List<ObstacleData> obstacles) {
    return obstacles.map((obstacle) => createObstacleEntity(obstacle)).toList();
  }

  /// Creates a power-up entity
  static PowerUpEntity createPowerUpEntity({
    required String powerUpType,
    required double x,
    required double y,
    double width = 30.0,
    double height = 30.0,
    double collectionRadius = 60.0,
  }) {
    final bounds = Rect.fromLTWH(x, y, width, height);
    return PowerUpEntity(
      id: 'powerup_${powerUpType}_${_nextId++}',
      powerUpType: powerUpType,
      bounds: bounds,
      collectionRadius: collectionRadius,
    );
  }

  /// Creates a test player entity at a specific position
  static PlayerEntity createTestPlayerEntity({
    required double x,
    required double y,
    double width = 50.0,
    double height = 50.0,
  }) {
    final playerData = PlayerData();
    playerData.x = x;
    playerData.y = y;
    playerData.width = width;
    playerData.height = height;
    playerData.currentVelocity = Vector2.zero();

    return PlayerEntity(
      id: 'test_player_${_nextId++}',
      playerData: playerData,
      currentHitbox: null,
    );
  }

  /// Creates a test obstacle entity at a specific position
  static ObstacleEntity createTestObstacleEntity({
    required double x,
    required double y,
    required ObstacleType obstacleType,
    double width = 50.0,
    double height = 50.0,
  }) {
    // Create a basic obstacle data for testing
    ObstacleData obstacleData;

    switch (obstacleType) {
      case ObstacleType.ground:
      case ObstacleType.platform:
        obstacleData = SimpleObstacleData(
          id: _nextId++,
          type: obstacleType,
          x: x,
          y: y,
          width: width,
          height: height,
        );
        break;

      case ObstacleType.fallingDrop:
        obstacleData = FallingObstacleData(
          id: _nextId++,
          x: x + width / 2,
          y: y + height / 2,
          width: 20,
          height: 20,
          velocityY: 100.0,
          initialY: y,
        );
        break;

      case ObstacleType.rotatingLaser:
        obstacleData = RotatingLaserObstacleData(
          id: _nextId++,
          x: x,
          y: y,
          width: width,
          height: height,
          initialY: y,
          angle: 0.0,
          rotationSpeed: 0.02,
          beamLength: 100.0,
        );
        break;

      case ObstacleType.hazardZone:
        obstacleData = HazardObstacleData(
          id: _nextId++,
          x: x,
          y: y,
          width: width,
          height: height,
          initialY: y,
        );
        break;

      case ObstacleType.spike:
        obstacleData = SpikeObstacleData(
          id: _nextId++,
          x: x,
          y: y,
          width: width,
          height: height,
        );
        break;

      case ObstacleType.aerial:
        obstacleData = AerialObstacleData(
          id: _nextId++,
          x: x,
          y: y,
          width: width,
          height: height,
        );
        break;

      default:
        obstacleData = SimpleObstacleData(
          id: _nextId++,
          type: obstacleType,
          x: x,
          y: y,
          width: width,
          height: height,
        );
        break;
    }

    return ObstacleEntity(
      id: 'test_obstacle_${obstacleData.id}',
      obstacleData: obstacleData,
    );
  }

  /// Creates multiple test entities for testing scenarios
  static TestEntitySet createTestScenario({
    String scenario = 'basic',
  }) {
    switch (scenario) {
      case 'basic_collision':
        return _createBasicCollisionScenario();
      case 'grazing_test':
        return _createGrazingTestScenario();
      case 'multiple_obstacles':
        return _createMultipleObstaclesScenario();
      case 'powerup_collection':
        return _createPowerUpCollectionScenario();
      default:
        return _createBasicCollisionScenario();
    }
  }

  /// Creates a basic collision test scenario
  static TestEntitySet _createBasicCollisionScenario() {
    final player = createTestPlayerEntity(x: 100, y: 100);
    final obstacle = createTestObstacleEntity(
      x: 150,
      y: 100,
      obstacleType: ObstacleType.ground,
    );

    return TestEntitySet(
      player: player,
      obstacles: [obstacle],
      powerUps: [],
      expectedCollisions: 1,
      expectedGrazing: 0,
    );
  }

  /// Creates a grazing test scenario
  static TestEntitySet _createGrazingTestScenario() {
    final player = createTestPlayerEntity(x: 100, y: 100);
    final obstacle = createTestObstacleEntity(
      x: 180, // Just outside collision range but within grazing range
      y: 100,
      obstacleType: ObstacleType.aerial,
    );

    return TestEntitySet(
      player: player,
      obstacles: [obstacle],
      powerUps: [],
      expectedCollisions: 0,
      expectedGrazing: 1,
    );
  }

  /// Creates a multiple obstacles test scenario
  static TestEntitySet _createMultipleObstaclesScenario() {
    final player = createTestPlayerEntity(x: 200, y: 200);
    final obstacles = [
      createTestObstacleEntity(
        x: 240, // Closer for definite collision (player right edge at 250)
        y: 200,
        obstacleType: ObstacleType.ground,
      ),
      createTestObstacleEntity(
        x: 200, // Closer for definite collision (player top edge at 200)
        y: 160,
        obstacleType: ObstacleType.aerial,
      ),
      createTestObstacleEntity(
        x: 300, // This one should not collide
        y: 250,
        obstacleType: ObstacleType.spike,
      ),
    ];

    return TestEntitySet(
      player: player,
      obstacles: obstacles,
      powerUps: [],
      expectedCollisions: 2, // Two obstacles are close enough
      expectedGrazing: 0, // No obstacles within grazing range
    );
  }

  /// Creates a power-up collection test scenario
  static TestEntitySet _createPowerUpCollectionScenario() {
    final player = createTestPlayerEntity(x: 100, y: 100);
    final powerUp = createPowerUpEntity(
      powerUpType: 'shield',
      x: 140,
      y: 100,
      collectionRadius: 80.0, // Large enough for easy collection
    );
    final obstacle = createTestObstacleEntity(
      x: 300,
      y: 100,
      obstacleType: ObstacleType.ground,
    );

    return TestEntitySet(
      player: player,
      obstacles: [obstacle],
      powerUps: [powerUp],
      expectedCollisions: 0,
      expectedGrazing: 0,
    );
  }

  /// Resets the ID counter (useful for tests)
  static void resetIdCounter() {
    _nextId = 1;
  }
}

/// Test entity set for creating test scenarios
class TestEntitySet {
  final PlayerEntity player;
  final List<ObstacleEntity> obstacles;
  final List<PowerUpEntity> powerUps;
  final int expectedCollisions;
  final int expectedGrazing;

  TestEntitySet({
    required this.player,
    required this.obstacles,
    required this.powerUps,
    required this.expectedCollisions,
    required this.expectedGrazing,
  });

  /// Gets all entities in the test set
  List<CollidableEntity> getAllEntities() {
    final entities = <CollidableEntity>[];
    entities.add(player);
    entities.addAll(obstacles);
    entities.addAll(powerUps);
    return entities;
  }
}