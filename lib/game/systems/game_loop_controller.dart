import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter_neon_runner/config/game_config.dart';
import 'package:flutter_neon_runner/game/events/game_events.dart';
import 'package:flutter_neon_runner/game/systems/base_game_system.dart';
import 'package:flutter_neon_runner/game/systems/game_state_controller.dart';
import 'package:flutter_neon_runner/game/systems/player_system.dart';
import 'package:flutter_neon_runner/game/systems/obstacle_system.dart';
import 'package:flutter_neon_runner/game/systems/collision_system.dart';
import 'package:flutter_neon_runner/game/systems/audio_system.dart';
import 'package:flutter_neon_runner/models/game_state.dart';

/// Central game loop controller coordinating all systems
class GameLoopController extends EventHandlerSystem {
  // Core systems
  late GameStateController _gameStateController;
  late PlayerSystem _playerSystem;
  late ObstacleSystem _obstacleSystem;
  late CollisionSystem _collisionSystem;
  late AudioSystem _audioSystem;

  // Game loop state
  int _frames = 0;
  double _speed = 0.0;
  int _score = 0;
  int _hudUpdateCounter = 0;
  bool _scoreGlitch = false;

  // Performance monitoring
  final List<double> _frameTimes = [];
  static const int _maxFrameTimeSamples = 60;
  double _averageFrameTime = 0.0;

  @override
  String get systemName => 'GameLoopController';

  // Getters
  GameStateController get gameStateController => _gameStateController;
  PlayerSystem get playerSystem => _playerSystem;
  ObstacleSystem get obstacleSystem => _obstacleSystem;
  CollisionSystem get collisionSystem => _collisionSystem;
  AudioSystem get audioSystem => _audioSystem;
  int get frames => _frames;
  double get speed => _speed;
  int get score => _score;
  bool get scoreGlitch => _scoreGlitch;
  double get averageFrameTime => _averageFrameTime;

  @override
  Future<void> initialize() async {
    // Initialize systems in dependency order
    _gameStateController = GameStateController();
    await _gameStateController.initialize();

    _playerSystem = PlayerSystem();
    await _playerSystem.initialize();

    _obstacleSystem = ObstacleSystem();
    await _obstacleSystem.initialize();

    _collisionSystem = CollisionSystem(_playerSystem);
    await _collisionSystem.initialize();

    _audioSystem = AudioSystem();
    await _audioSystem.initialize();

    // Subscribe to events
    _setupEventSubscriptions();

    // Initialize game state
    reset();
  }

  @override
  void update(double dt) {
    // Skip update if dt is 0 to prevent potential issues
    if (dt == 0) return;

    // Strict state-based update rules
    if (!_gameStateController.canUpdate) return;

    // Freeze game world during revive state
    if (_gameStateController.isFrozen) {
      // Only update UI and animations, not game logic
      _updateSystems(dt, skipGameLogic: true);
      return;
    }

    // Performance monitoring
    _recordFrameTime(dt);

    _frames++;
    _updateGameSpeed();
    _updateScore();
    _updateSystems(dt, skipGameLogic: false);
    _updateHUD();

    // Random score glitch effect
    _checkRandomScoreGlitch();
  }

  @override
  void handleEvent(GameEvent event) {
    // Events are handled via subscriptions
  }

  @override
  List<Type> get handledEventTypes => [
    GameStartedEvent,
    GameOverEvent,
    ScoreUpdatedEvent,
    GrazingDetectedEvent,
    ObstacleHitEvent,
  ];

  // Public methods
  void startGame() {
    _gameStateController.startGame(playerData: _playerSystem.playerData);
  }

  void pauseGame() {
    _gameStateController.pauseGame();
  }

  void resumeGame() {
    _gameStateController.resumeGame();
  }

  void gameOver({int? finalScore}) {
    _gameStateController.gameOver(finalScore: finalScore);
  }

  void reset() {
    _frames = 0;
    _speed = GameConfig.baseSpeed;
    _score = 0;
    _scoreGlitch = false;
    _hudUpdateCounter = 0;
    _frameTimes.clear();
    _averageFrameTime = 0.0;

    // Reset all systems
    _playerSystem.reset();
    _obstacleSystem.reset();
    _collisionSystem.clearAll();
  }

  void handleInput(InputAction action, bool isPressed) {
    switch (action) {
      case InputAction.jump:
        GameEventBus.instance.fire(InputEvent(InputAction.jump, isPressed));
        break;
      case InputAction.duck:
        GameEventBus.instance.fire(InputEvent(InputAction.duck, isPressed));
        break;
      case InputAction.pause:
        if (_gameStateController.isPlaying) {
          pauseGame();
        } else if (_gameStateController.isPaused) {
          resumeGame();
        }
        break;
      case InputAction.start:
        if (_gameStateController.isInMenu) {
          startGame();
        }
        break;
    }
  }

  void handleTouchInput(Offset position, InputAction action) {
    GameEventBus.instance.fire(TouchInputEvent(position, action));
  }

  // Mobile performance optimization
  void optimizePerformance() {
    // Remove old frame time samples
    if (_frameTimes.length > _maxFrameTimeSamples) {
      _frameTimes.removeAt(0);
    }

    // Calculate average frame time
    if (_frameTimes.isNotEmpty) {
      _averageFrameTime = _frameTimes.reduce((a, b) => a + b) / _frameTimes.length;
    }

    // Performance warnings
    if (_averageFrameTime > 0.016) { // Below 60 FPS
      GameEventBus.instance.fire(PerformanceWarningEvent(
        'Low FPS detected',
        _averageFrameTime,
      ));
    }
  }

  // Private methods
  void _setupEventSubscriptions() {
    GameEventBus.instance.subscribe<GameStartedEvent>(_handleGameStarted);
    GameEventBus.instance.subscribe<GameOverEvent>(_handleGameOver);
    GameEventBus.instance.subscribe<ScoreUpdatedEvent>(_handleScoreUpdated);
    GameEventBus.instance.subscribe<GrazingDetectedEvent>(_handleGrazingDetected);
    GameEventBus.instance.subscribe<ObstacleHitEvent>(_handleObstacleHit);
  }

  void _updateGameSpeed() {
    // Gradually increase speed
    if (_speed < GameConfig.maxSpeed) {
      _speed += GameConfig.speedIncrement;
    }

    // Update systems with current speed
    _obstacleSystem.setCurrentSpeed(_speed);
    _gameStateController.updateSpeed(_speed);
  }

  void _updateScore() {
    // Update score based on frames and speed
    if (_frames % GameConfig.scoreUpdateFrequency == 0) {
      final playerData = _playerSystem.playerData;
      final scoreIncrease = (1 * playerData.scoreMultiplier).toInt();
      _score += scoreIncrease;

      // Check for score milestone effects
      if (_score > 0 && _score % GameConfig.scoreGlitchTrigger == 0) {
        _triggerScoreGlitch(isMilestone: true);
      }

      // Update score in game state
      _gameStateController.updateScore(_score, multiplier: playerData.scoreMultiplier.toInt());
    }
  }

  void _updateSystems(double dt, {bool skipGameLogic = false}) {
    if (skipGameLogic) {
      // Only update UI and audio during frozen states
      _audioSystem.update(dt);
      _gameStateController.update(dt);
    } else {
      // Update all systems in order
      _playerSystem.update(dt);
      _obstacleSystem.update(dt);
      _collisionSystem.update(dt);
      _audioSystem.update(dt);
      _gameStateController.update(dt);
    }
  }

  void _updateHUD() {
    // Update HUD data periodically, not every frame
    _hudUpdateCounter++;
    if (_hudUpdateCounter >= 5) {
      _hudUpdateCounter = 0;

      GameEventBus.instance.fire(HudUpdateEvent(
        _score,
        _speed,
        _gameStateController.highscore,
        _playerSystem.playerData,
      ));
    }
  }

  void _checkRandomScoreGlitch() {
    if (Random().nextDouble() < GameConfig.randomScoreGlitchChance && !_scoreGlitch) {
      _triggerScoreGlitch(isMilestone: false);
    }
  }

  void _triggerScoreGlitch({required bool isMilestone}) {
    _scoreGlitch = true;
    if (isMilestone) {
      GameEventBus.instance.fire(AudioPlayEvent('score'));
    }

    Future.delayed(Duration(
      milliseconds: isMilestone
          ? GameConfig.scoreGlitchDurationLong
          : GameConfig.scoreGlitchDurationShort,
    ), () {
      _scoreGlitch = false;
    });
  }

  void _recordFrameTime(double dt) {
    _frameTimes.add(dt);
    optimizePerformance();
  }

  // Event handlers
  void _handleGameStarted(GameStartedEvent event) {
    reset();
    _frames = 0;
    _speed = GameConfig.baseSpeed;
  }

  void _handleGameOver(GameOverEvent event) {
    _score = event.score;
    _gameStateController.updateHighscore(event.highscore);
  }

  void _handleScoreUpdated(ScoreUpdatedEvent event) {
    _score = event.newScore;
  }

  void _handleGrazingDetected(GrazingDetectedEvent event) {
    _score += event.points;
    GameEventBus.instance.fire(ScoreUpdatedEvent(_score, 1));
  }

  void _handleObstacleHit(ObstacleHitEvent event) {
    gameOver(finalScore: _score);
  }

  @override
  void dispose() {
    // Unsubscribe from events
    GameEventBus.instance.unsubscribe<GameStartedEvent>(_handleGameStarted);
    GameEventBus.instance.unsubscribe<GameOverEvent>(_handleGameOver);
    GameEventBus.instance.unsubscribe<ScoreUpdatedEvent>(_handleScoreUpdated);
    GameEventBus.instance.unsubscribe<GrazingDetectedEvent>(_handleGrazingDetected);
    GameEventBus.instance.unsubscribe<ObstacleHitEvent>(_handleObstacleHit);

    // Dispose systems
    _playerSystem.dispose();
    _obstacleSystem.dispose();
    _collisionSystem.dispose();
    _audioSystem.dispose();
    _gameStateController.dispose();
  }
}