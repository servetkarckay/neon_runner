import 'dart:math';
import 'package:flutter_neon_runner/config/game_config.dart';
import 'package:flutter_neon_runner/game/events/game_events.dart';
import 'package:flutter_neon_runner/game/systems/base_game_system.dart';
import 'package:flutter_neon_runner/models/obstacle_data.dart';
import 'package:flutter_neon_runner/models/game_state.dart';
import 'package:flutter_neon_runner/game/systems/spawner_system.dart'; // New import
import 'package:flutter_neon_runner/game/powerup_manager.dart'; // Import PowerUpManager

/// System managing obstacle spawning, movement, and lifecycle
class ObstacleSystem extends EventHandlerSystem implements PausableSystem, ResettableSystem {
  bool _isPaused = false;
  int _frames = 0;
  int _nextSpawn = 0;
  double _currentSpeed = 0.0;
  bool _tutorialActive = false;

  // Obstacle pools for performance
  final Map<ObstacleType, List<ObstacleData>> _obstaclePools = {};
  final List<ObstacleData> _activeObstacles = [];

  // Spawner configuration
  late SpawnerSystem _spawnerSystem; // Changed from SpawnerUtils
  PowerUpManager? _powerUpManager; // Reference to PowerUpManager

  @override
  String get systemName => 'ObstacleSystem';

  List<ObstacleData> get activeObstacles => List.unmodifiable(_activeObstacles);
  int get frames => _frames;

  /// Set the PowerUpManager reference
  void setPowerUpManager(PowerUpManager powerUpManager) {
    _powerUpManager = powerUpManager;
  }

  /// Manually add an obstacle (used for tutorial system)
  void addObstacle(ObstacleData obstacle) {
    _activeObstacles.add(obstacle);
  }

  @override
  Future<void> initialize() async {
    _spawnerSystem = SpawnerSystem(); // Changed from SpawnerUtils()
    _initializeObstaclePools();

    // Subscribe to events
    GameEventBus.instance.subscribe<GameStartedEvent>(_handleGameStarted);
    GameEventBus.instance.subscribe<GameOverEvent>(_handleGameOver);
    GameEventBus.instance.subscribe<GameResetEvent>(_handleGameReset);
    GameEventBus.instance.subscribe<PlayerMoveEvent>(_handlePlayerMove);
  }

  @override
  void update(double dt) {
    if (_isPaused) return;

    // Clamp delta time at start of update loop to prevent physics breakdown
    const maxDt = 0.1;
    if (dt > maxDt) dt = maxDt;

    // Failsafe: if dt is invalid, use fixed fallback
    if (dt <= 0 || dt.isNaN || dt.isInfinite) {
      dt = 1.0 / 60.0; // Fixed fallback to 60fps
    }

    _frames++;

    // Failsafe: prevent frame counter overflow
    const maxFrames = 2147483647 - 1000; // Safe margin from int max
    if (_frames > maxFrames) {
      _frames = 0;
      _nextSpawn = _nextSpawn > maxFrames ? _nextSpawn - maxFrames : _frames + 60;
    }

    _updateObstacleMovement(dt);
    _updateSpawning();
    _removeOffscreenObstacles();
  }

  @override
  void handleEvent(GameEvent event) {
    // Events are handled via subscriptions
  }

  @override
  List<Type> get handledEventTypes => [
    GameStartedEvent,
    GameOverEvent,
    GameResetEvent,
    PlayerMoveEvent,
  ];

  @override
  void onPause() {
    _isPaused = true;
  }

  @override
  void onResume() {
    _isPaused = false;
  }

  @override
  bool get isPaused => _isPaused;

  @override
  void reset() {
    _frames = 0;
    _nextSpawn = 0;
    _currentSpeed = GameConfig.baseSpeed;
    _tutorialActive = false;
    _clearAllObstacles();
    _resetPools();
  }

  // Public methods
  void setTutorialMode(bool active) {
    _tutorialActive = active;
    if (active) {
      _nextSpawn = 100;
    }
  }

  void setCurrentSpeed(double speed) {
    // Enforce minimum world speed before movement calculations
    if (speed <= 0 || speed.isNaN || speed.isInfinite) {
      _currentSpeed = GameConfig.baseSpeed;
    } else {
      _currentSpeed = speed.clamp(GameConfig.baseSpeed, GameConfig.speedHardCap);
    }
  }

  // Private methods
  void _initializeObstaclePools() {
    for (final type in ObstacleType.values) {
      _obstaclePools[type] = [];
      // Pre-populate pools for performance
      for (int i = 0; i < 10; i++) {
        _obstaclePools[type]!.add(_spawnerSystem.createObstacle(type, 0));
      }
    }
  }

  ObstacleData _getObstacleFromPool(ObstacleType type) {
    final pool = _obstaclePools[type]!;
    if (pool.isNotEmpty) {
      final obstacle = pool.removeLast();
      obstacle.grazed = false; // Reset grazed state
      return obstacle;
    }
    // Create new if pool is empty using SpawnerSystem
    return _spawnerSystem.createObstacle(type, _frames + Random().nextInt(1000));
  }

  void _returnToPool(ObstacleData obstacle) {
    obstacle.x = GameConfig.obstacleRemoveX; // Reset position
    _obstaclePools[obstacle.type]!.add(obstacle);
  }

  void _updateSpawning() {
    if (_tutorialActive) {
      _updateTutorialSpawning();
      return;
    }

    if (_frames >= _nextSpawn) {
      _spawnObstacle();
      _calculateNextSpawn();
    }
  }

  void _updateTutorialSpawning() {
    // Tutorial-specific spawning logic
    if (_activeObstacles.isEmpty) {
      final obstacle = _spawnerSystem.createObstacle(
        ObstacleType.ground,
        _frames + Random().nextInt(1000), // Generate a unique ID
      );
      obstacle.x = GameConfig.baseWidth + GameConfig.tutorialObstacleTutorialX;
      obstacle.y = GameConfig.groundLevel - GameConfig.tutorialObstacleJumpYOffset;
      _activeObstacles.add(obstacle);
      GameEventBus.instance.fire(ObstacleSpawnedEvent(obstacle));
    }
  }

  void _spawnObstacle() {
    // Use spawner utilities to get obstacle configuration
    final spawnConfig = _spawnerSystem.getRandomSpawnConfig(_currentSpeed);

    final obstacle = _getObstacleFromPool(spawnConfig.type);
    obstacle.x = GameConfig.baseWidth;
    obstacle.y = spawnConfig.y;
    obstacle.width = spawnConfig.width;
    obstacle.height = spawnConfig.height;

    // Update special properties based on type
    _updateObstacleProperties(obstacle, spawnConfig);

    _activeObstacles.add(obstacle);
    GameEventBus.instance.fire(ObstacleSpawnedEvent(obstacle));

    // Spawn power-ups based on obstacle type (moved from NeonRunnerGame)
    _spawnPowerUpForObstacle(obstacle);
  }

  void _spawnPowerUpForObstacle(ObstacleData obstacle) {
    if (_powerUpManager == null) return;

    bool powerUpSpawned = false;
    if (obstacle.type == ObstacleType.hazardZone &&
        Random().nextDouble() < 0.35) {
      final puY = obstacle.y - 70;
      final absoluteX = obstacle.x + obstacle.width / 2;
      final relativeOffset = absoluteX - GameConfig.baseWidth;
      _powerUpManager!.spawnPowerUp(relativeOffset, fixedY: puY);
      powerUpSpawned = true;
    } else if ((obstacle.type == ObstacleType.platform ||
            obstacle.type == ObstacleType.movingPlatform) &&
        Random().nextDouble() < 0.4) {
      final puY = obstacle.y - 40;
      final absoluteX = obstacle.x + obstacle.width / 2;
      final relativeOffset = absoluteX - GameConfig.baseWidth;
      _powerUpManager!.spawnPowerUp(relativeOffset, fixedY: puY);
      powerUpSpawned = true;
    } else if (obstacle.type == ObstacleType.laserGrid &&
        Random().nextDouble() < 0.4) {
      final lg = obstacle as LaserGridObstacleData;
      final puY = lg.gapY;
      final absoluteX = obstacle.x + obstacle.width / 2;
      final relativeOffset = absoluteX - GameConfig.baseWidth;
      _powerUpManager!.spawnPowerUp(relativeOffset, fixedY: puY);
      powerUpSpawned = true;
    }

    if (!powerUpSpawned &&
        Random().nextDouble() < GameConfig.powerUpSpawnChance) {
      final gapUntilNextSpawn = _nextSpawn - _frames;
      _powerUpManager!.spawnPowerUp((gapUntilNextSpawn * _currentSpeed * 0.4).floorToDouble());
    }
  }

  void _updateObstacleProperties(ObstacleData obstacle, dynamic spawnConfig) {
    if (obstacle is MovingAerialObstacleData) {
      obstacle.initialY = spawnConfig.y;
    } else if (obstacle is MovingPlatformObstacleData) {
      obstacle.initialY = spawnConfig.y;
      obstacle.oscillationAxis = spawnConfig.oscillationAxis;
    } else if (obstacle is HazardObstacleData) {
      obstacle.initialY = spawnConfig.y;
    } else if (obstacle is FallingObstacleData) {
      obstacle.velocityY = 0;
    } else if (obstacle is RotatingLaserObstacleData) {
      obstacle.angle = Random().nextDouble() * 2 * pi;
    } else if (obstacle is LaserGridObstacleData) {
      obstacle.gapY = spawnConfig.gapY ?? GameConfig.groundLevel - 100;
      obstacle.gapHeight = spawnConfig.gapHeight ?? 80;
    }
  }

  void _calculateNextSpawn() {
    final minGap = (GameConfig.spawnRateMin - min((_currentSpeed - GameConfig.baseSpeed) * 2, 30)).toInt();
    final maxGap = GameConfig.spawnRateMax;

    // Failsafe: ensure minimum gap to prevent negative values
    final safeMinGap = minGap.clamp(10, maxGap);
    int gap = Random().nextInt(maxGap - safeMinGap + 1) + safeMinGap;

    // Adjust gap based on obstacle difficulty
    if (_activeObstacles.isNotEmpty) {
      final lastObstacle = _activeObstacles.last;
      switch (lastObstacle.type) {
        case ObstacleType.hazardZone:
          gap += 20;
          break;
        case ObstacleType.movingPlatform:
          gap += 15;
          break;
        case ObstacleType.laserGrid:
          gap += 30;
          break;
        default:
          break;
      }
    }

    // Emergency failsafe: prevent infinite spawn delays
    gap = gap.clamp(10, 300);
    _nextSpawn = _frames + gap;

    // Additional failsafe: ensure spawn timer doesn't overflow
    if (_nextSpawn < _frames) {
      _nextSpawn = _frames + 30; // Emergency reset
    }
  }

  void _updateObstacleMovement(double dt) {
    // DEBUG: Log obstacle movement every 60 frames
    if (_frames % 60 == 0 && _activeObstacles.isNotEmpty) {
      final firstObs = _activeObstacles.first;
      print('[OBSTACLE_DEBUG] frames=$_frames currentSpeed=$_currentSpeed dt=$dt firstObstacleX=${firstObs.x}');
    }

    for (final obstacle in _activeObstacles) {
      obstacle.x -= _currentSpeed * dt;

      // Update movement for dynamic obstacles
      if (obstacle is MovingAerialObstacleData) {
        obstacle.y = obstacle.initialY + sin(_frames * 0.1) * 40;
      } else if (obstacle is HazardObstacleData) {
        obstacle.y = obstacle.initialY + sin(_frames * 0.05) * 25;
      } else if (obstacle is MovingPlatformObstacleData) {
        if (obstacle.oscillationAxis == OscillationAxis.horizontal) {
          // Handled in collision system
        } else {
          obstacle.y = obstacle.initialY + sin(_frames * 0.05) * 50;
        }
      } else if (obstacle is FallingObstacleData) {
        obstacle.velocityY += GameConfig.gravity * dt;
        obstacle.y += obstacle.velocityY * dt;
      } else if (obstacle is RotatingLaserObstacleData) {
        obstacle.angle += obstacle.rotationSpeed * dt;
      }
    }
  }

  void _removeOffscreenObstacles() {
    for (int i = _activeObstacles.length - 1; i >= 0; i--) {
      final obstacle = _activeObstacles[i];
      if (obstacle.x < GameConfig.obstacleRemoveX) {
        _activeObstacles.removeAt(i);
        _returnToPool(obstacle);
        GameEventBus.instance.fire(ObstacleDestroyedEvent(obstacle));
      }
    }
  }

  void _clearAllObstacles() {
    for (final obstacle in _activeObstacles) {
      _returnToPool(obstacle);
    }
    _activeObstacles.clear();
  }

  void _resetPools() {
    for (final pool in _obstaclePools.values) {
      for (final obstacle in pool) {
        obstacle.grazed = false;
      }
    }
  }

  // Event handlers
  void _handleGameStarted(GameStartedEvent event) {
    reset();
    _currentSpeed = GameConfig.baseSpeed;
    _nextSpawn = 100;
  }

  void _handleGameOver(GameOverEvent event) {
    // Game over handling
  }

  void _handleGameReset(GameResetEvent event) {
    reset();
  }

  void _handlePlayerMove(PlayerMoveEvent event) {
    // Could be used for dynamic difficulty adjustment
  }

  @override
  void dispose() {
    _clearAllObstacles();
    _obstaclePools.clear();

    GameEventBus.instance.unsubscribe<GameStartedEvent>(_handleGameStarted);
    GameEventBus.instance.unsubscribe<GameOverEvent>(_handleGameOver);
    GameEventBus.instance.unsubscribe<GameResetEvent>(_handleGameReset);
    GameEventBus.instance.unsubscribe<PlayerMoveEvent>(_handlePlayerMove);
  }
}