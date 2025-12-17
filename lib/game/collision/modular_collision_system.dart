import 'package:flutter_neon_runner/game/collision/collision_engine.dart';
import 'package:flutter_neon_runner/game/collision/collision_types.dart';
import 'package:flutter_neon_runner/game/collision/collision_response.dart';
import 'package:flutter_neon_runner/game/collision/entity_factory.dart';
import 'package:flutter_neon_runner/game/systems/player_system.dart';
import 'package:flutter_neon_runner/game/events/game_events.dart';
import 'package:flutter_neon_runner/models/obstacle_data.dart';
import 'package:flutter_neon_runner/models/player_data.dart';
import 'package:flutter_neon_runner/config/game_config.dart';

// Define missing events if they don't exist in the existing event system
class PowerUpSpawnedEvent extends GameEvent {
  final String powerUpType;
  final double x;
  final double y;
  final double? width;
  final double? height;

  PowerUpSpawnedEvent({
    required this.powerUpType,
    required this.x,
    required this.y,
    this.width,
    this.height,
  });
}

class PowerUpCollectedEvent extends GameEvent {
  final String powerUpType;
  final double x;
  final double y;

  PowerUpCollectedEvent({
    required this.powerUpType,
    required this.x,
    required this.y,
  });
}

/// Main entry point for the new modular collision system
/// This class acts as an adapter between the existing game systems and the new collision architecture
class ModularCollisionSystem {
  final CollisionEngine _collisionEngine;
  final CollisionResponseSystem _responseSystem;
  final PlayerSystem _playerSystem;

  // Entity tracking for efficient updates
  final Map<String, CollidableEntity> _playerEntities = {};
  final Map<int, CollidableEntity> _obstacleEntities = {};
  final Map<String, CollidableEntity> _powerUpEntities = {};

  ModularCollisionSystem(this._playerSystem)
      : _collisionEngine = CollisionEngine(cellSize: 100.0),
        _responseSystem = CollisionResponseSystem();

  /// Initialize the collision system
  Future<void> initialize() async {
    // Subscribe to game events
    GameEventBus.instance.subscribe<ObstacleSpawnedEvent>(_handleObstacleSpawned);
    GameEventBus.instance.subscribe<ObstacleDestroyedEvent>(_handleObstacleDestroyed);
    GameEventBus.instance.subscribe<PlayerMoveEvent>(_handlePlayerMove);
    GameEventBus.instance.subscribe<PowerUpSpawnedEvent>(_handlePowerUpSpawned);
    GameEventBus.instance.subscribe<PowerUpCollectedEvent>(_handlePowerUpCollected);
  }

  /// Update collision detection for the current frame
  void update(double dt) {
    // Update player entity if it exists
    _updatePlayerEntity();

    // Update obstacle entities (for moving obstacles)
    _updateObstacleEntities(dt);

    // Detect collisions
    final collisions = _collisionEngine.detectCollisions();
    final grazingEvents = _collisionEngine.detectGrazing(GameConfig.grazeDistance);

    // Process collision responses
    if (collisions.isNotEmpty) {
      _responseSystem.processCollisions(collisions);
    }

    // Process grazing events
    if (grazingEvents.isNotEmpty) {
      _responseSystem.processGrazing(grazingEvents);
    }
  }

  /// Add an obstacle to the collision system
  void addObstacle(ObstacleData obstacleData) {
    final entity = CollisionEntityFactory.createObstacleEntity(obstacleData);
    _obstacleEntities[obstacleData.id] = entity;
    _collisionEngine.addEntity(entity);
  }

  /// Remove an obstacle from the collision system
  void removeObstacle(ObstacleData obstacleData) {
    final entity = _obstacleEntities.remove(obstacleData.id);
    if (entity != null) {
      _collisionEngine.removeEntity(entity);
    }
  }

  /// Add a power-up to the collision system
  void addPowerUp({
    required String powerUpType,
    required double x,
    required double y,
    double width = 30.0,
    double height = 30.0,
  }) {
    final entity = CollisionEntityFactory.createPowerUpEntity(
      powerUpType: powerUpType,
      x: x,
      y: y,
      width: width,
      height: height,
    );
    _powerUpEntities[entity.id] = entity;
    _collisionEngine.addEntity(entity);
  }

  /// Remove a power-up from the collision system
  void removePowerUp(String entityId) {
    final entity = _powerUpEntities.remove(entityId);
    if (entity != null) {
      _collisionEngine.removeEntity(entity);
    }
  }

  /// Clear all entities from the collision system
  void clearAll() {
    _playerEntities.clear();
    _obstacleEntities.clear();
    _powerUpEntities.clear();
    _collisionEngine.clear();
  }

  /// Get debug information about the collision system
  ModularCollisionDebugInfo get debugInfo {
    return ModularCollisionDebugInfo(
      totalEntities: _collisionEngine.entityCount,
      playerEntities: _playerEntities.length,
      obstacleEntities: _obstacleEntities.length,
      powerUpEntities: _powerUpEntities.length,
      spatialHashInfo: _collisionEngine.debugInfo,
    );
  }

  // Private methods

  /// Update the player entity based on current player data
  void _updatePlayerEntity() {
    final playerData = _playerSystem.playerData;
    final playerEntity = _playerEntities['player'];

    if (playerEntity == null) {
      // Create player entity if it doesn't exist
      final newPlayerEntity = CollisionEntityFactory.createPlayerEntity(
        playerData,
        hitbox: _playerSystem.playerRect,
      );
      _playerEntities['player'] = newPlayerEntity;
      _collisionEngine.addEntity(newPlayerEntity);
    } else {
      // Update existing player entity position
      // Note: In a full implementation, we'd make bounds mutable or recreate the entity
      // For now, we remove and re-add
      _collisionEngine.removeEntity(playerEntity);
      final updatedPlayerEntity = CollisionEntityFactory.createPlayerEntity(
        playerData,
        hitbox: _playerSystem.playerRect,
      );
      _playerEntities['player'] = updatedPlayerEntity;
      _collisionEngine.addEntity(updatedPlayerEntity);
    }
  }

  /// Update moving obstacle entities
  void _updateObstacleEntities(double dt) {
    // This would handle animated/moving obstacles
    // For now, static obstacles don't need updates
    // In a full implementation, we'd update obstacle positions based on their movement patterns
  }

  // Event handlers

  void _handleObstacleSpawned(ObstacleSpawnedEvent event) {
    addObstacle(event.obstacle);
  }

  void _handleObstacleDestroyed(ObstacleDestroyedEvent event) {
    removeObstacle(event.obstacle);
  }

  void _handlePlayerMove(PlayerMoveEvent event) {
    // Player movement is handled in _updatePlayerEntity()
  }

  void _handlePowerUpSpawned(PowerUpSpawnedEvent event) {
    addPowerUp(
      powerUpType: event.powerUpType,
      x: event.x,
      y: event.y,
      width: event.width ?? 30.0,
      height: event.height ?? 30.0,
    );
  }

  void _handlePowerUpCollected(PowerUpCollectedEvent event) {
    // Remove the collected power-up
    // Note: We'd need to know which power-up entity was collected
    // This would require additional event data or tracking
  }

  /// Dispose of the collision system
  void dispose() {
    clearAll();
    GameEventBus.instance.unsubscribe<ObstacleSpawnedEvent>(_handleObstacleSpawned);
    GameEventBus.instance.unsubscribe<ObstacleDestroyedEvent>(_handleObstacleDestroyed);
    GameEventBus.instance.unsubscribe<PlayerMoveEvent>(_handlePlayerMove);
    GameEventBus.instance.unsubscribe<PowerUpSpawnedEvent>(_handlePowerUpSpawned);
    GameEventBus.instance.unsubscribe<PowerUpCollectedEvent>(_handlePowerUpCollected);
  }
}

/// Debug information for the modular collision system
class ModularCollisionDebugInfo {
  final int totalEntities;
  final int playerEntities;
  final int obstacleEntities;
  final int powerUpEntities;
  final dynamic spatialHashInfo; // Would use SpatialHashDebugInfo if available

  ModularCollisionDebugInfo({
    required this.totalEntities,
    required this.playerEntities,
    required this.obstacleEntities,
    required this.powerUpEntities,
    required this.spatialHashInfo,
  });

  @override
  String toString() {
    return 'ModularCollisionDebugInfo('
        'totalEntities: $totalEntities, '
        'playerEntities: $playerEntities, '
        'obstacleEntities: $obstacleEntities, '
        'powerUpEntities: $powerUpEntities, '
        'spatialHashInfo: $spatialHashInfo'
        ')';
  }
}