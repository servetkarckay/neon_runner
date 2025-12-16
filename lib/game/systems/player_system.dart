import 'package:flutter/material.dart';
import 'package:flutter_neon_runner/config/game_config.dart';
import 'package:flutter_neon_runner/game/events/game_events.dart';
import 'package:flutter_neon_runner/game/systems/base_game_system.dart';
import 'package:flutter_neon_runner/models/player_data.dart';
import 'package:flutter_neon_runner/models/game_state.dart';

/// System managing player state, physics, and behavior
class PlayerSystem extends EventHandlerSystem implements PausableSystem, ResettableSystem {
  final PlayerData _playerData = PlayerData();
  bool _isPaused = false;

  // Input buffers for mobile touch responsiveness
  bool _jumpInputBuffer = false;
  bool _duckInputBuffer = false;
  int _jumpBufferTimer = 0;

  // Trail system
  final List<Rect> _trailHistory = [];

  @override
  String get systemName => 'PlayerSystem';

  // Getters
  PlayerData get playerData => _playerData;
  bool get isJumping => _playerData.isJumping;
  bool get isDucking => _playerData.isDucking;
  bool get hasShield => _playerData.hasShield;
  bool get hasMagnet => _playerData.hasMagnet;
  Rect get playerRect => Rect.fromLTWH(
    _playerData.x,
    _playerData.y,
    _playerData.width,
    _playerData.height,
  );

  List<Rect> get trailHistory => List.unmodifiable(_trailHistory);

  @override
  Future<void> initialize() async {
    // Subscribe to input events
    GameEventBus.instance.subscribe<InputEvent>(_handleInputEvent);
    GameEventBus.instance.subscribe<TouchInputEvent>(_handleTouchEvent);

    // Subscribe to game state events
    GameEventBus.instance.subscribe<GameStartedEvent>(_handleGameStarted);
    GameEventBus.instance.subscribe<GameOverEvent>(_handleGameOver);
  }

  @override
  void update(double dt) {
    if (_isPaused) return;

    // Update input buffers
    _updateInputBuffers();

    // Update power-up timers
    _updatePowerUpTimers(dt);

    // Apply physics
    _updatePhysics(dt);

    // Update trail
    _updateTrail();

    // Fire player move event
    GameEventBus.instance.fire(PlayerMoveEvent(
      _playerData.x,
      _playerData.y,
      _playerData.currentVelocity.x,
      _playerData.currentVelocity.y,
    ));
  }

  @override
  void handleEvent(GameEvent event) {
    // Events are handled via subscriptions
  }

  @override
  List<Type> get handledEventTypes => [
    InputEvent,
    TouchInputEvent,
    GameStartedEvent,
    GameOverEvent,
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
    _playerData.reset();
    _jumpInputBuffer = false;
    _duckInputBuffer = false;
    _jumpBufferTimer = 0;
    _trailHistory.clear();
  }

  // Public methods for other systems
  void activatePowerUp(PowerUpType type) {
    switch (type) {
      case PowerUpType.shield:
        _playerData.hasShield = true;
        GameEventBus.instance.fire(
          PlayerPowerUpActivatedEvent(type, 'FIREWALL ACTIVATED'),
        );
        break;
      case PowerUpType.multiplier:
        _playerData.scoreMultiplier = GameConfig.powerUpMultiplierValue;
        _playerData.multiplierTimer = GameConfig.powerUpMultiplierDuration;
        GameEventBus.instance.fire(
          PlayerPowerUpActivatedEvent(type, 'OVERCLOCK ACTIVATED'),
        );
        break;
      case PowerUpType.timeWarp:
        _playerData.timeWarpTimer = GameConfig.powerUpTimeWarpDuration;
        GameEventBus.instance.fire(
          PlayerPowerUpActivatedEvent(type, 'TIME WARP'),
        );
        break;
      case PowerUpType.magnet:
        _playerData.hasMagnet = true;
        _playerData.magnetTimer = GameConfig.powerUpMagnetDuration;
        GameEventBus.instance.fire(
          PlayerPowerUpActivatedEvent(type, 'MAGNETIZED'),
        );
        break;
    }

    // Play power-up sound
    GameEventBus.instance.fire(AudioPlayEvent('powerup'));

    // Create particle effect
    GameEventBus.instance.fire(ParticleCreateEvent(
      _playerData.x + _playerData.width / 2,
      _playerData.y + _playerData.height / 2,
      GameConfig.accentNeonColor,
      GameConfig.powerUpCollisionParticleCount,
      'powerup',
    ));
  }

  void breakShield() {
    if (_playerData.hasShield) {
      _playerData.hasShield = false;
      _playerData.invincibleTimer = GameConfig.playerInvincibleDuration;

      GameEventBus.instance.fire(AudioPlayEvent('shield_break'));

      GameEventBus.instance.fire(ParticleCreateEvent(
        _playerData.x + _playerData.width / 2,
        _playerData.y + _playerData.height / 2,
        GameConfig.accentNeonColor,
        30,
        'shield_break',
      ));
    }
  }

  // Private methods
  void _updateInputBuffers() {
    if (_jumpBufferTimer > 0) {
      _jumpBufferTimer--;
    }

    // Process buffered jump input
    if (_jumpInputBuffer && !_playerData.isJumping) {
      _performJump();
      _jumpInputBuffer = false;
    }

    // Apply duck input
    if (_duckInputBuffer) {
      _playerData.height = GameConfig.playerDuckingHeight;
      if (!_playerData.isJumping) {
        GameEventBus.instance.fire(AudioPlayEvent('duck'));
      }
    } else {
      _playerData.height = GameConfig.playerDefaultHeight;
    }
  }

  void _updatePhysics(double dt) {
    final timeScale = _playerData.timeWarpTimer > 0 ? 0.5 : 1.0;

    // Jump sustain
    if (_playerData.isJumping &&
        _playerData.isHoldingJump &&
        _playerData.jumpTimer > 0) {
      _playerData.velocityY -= GameConfig.jumpSustain * timeScale;
      _playerData.jumpTimer--;
    }

    // Apply gravity
    _playerData.velocityY += GameConfig.gravity * timeScale;

    // Update position
    _playerData.y += _playerData.velocityY * timeScale;

    // Ground collision
    final groundY = GameConfig.groundLevel - _playerData.height;
    if (_playerData.y > groundY) {
      _playerData.y = groundY;
      _playerData.velocityY = 0;
      _playerData.isJumping = false;

      // Check for buffered jump
      if (_jumpBufferTimer > 0) {
        _performJump();
      } else {
        // Create dust particle
        GameEventBus.instance.fire(ParticleCreateEvent(
          _playerData.x,
          _playerData.y + _playerData.height,
          Colors.white,
          1,
          'dust',
        ));
      }
    }
  }

  void _updateTrail() {
    _trailHistory.add(Rect.fromLTWH(
      _playerData.x,
      _playerData.y,
      _playerData.width,
      _playerData.height,
    ));

    // Maintain trail length based on speed
    final maxTrail = (10 + 100 * 0.8).floor(); // Using current speed
    if (_trailHistory.length > maxTrail) {
      _trailHistory.removeAt(0);
    }
  }

  void _updatePowerUpTimers(double dt) {
    if (_playerData.timeWarpTimer > 0) {
      _playerData.timeWarpTimer--;
    }

    if (_playerData.multiplierTimer > 0) {
      _playerData.multiplierTimer--;
      if (_playerData.multiplierTimer <= 0) {
        _playerData.scoreMultiplier = 1;
      }
    }

    if (_playerData.magnetTimer > 0) {
      _playerData.magnetTimer--;
      if (_playerData.magnetTimer <= 0) {
        _playerData.hasMagnet = false;
      }
    }

    if (_playerData.invincibleTimer > 0) {
      _playerData.invincibleTimer--;
    }
  }

  void _performJump() {
    _playerData.isJumping = true;
    _playerData.isHoldingJump = true;
    _playerData.velocityY = -GameConfig.jumpForce;
    _playerData.jumpTimer = GameConfig.jumpTimerMax;
    _jumpBufferTimer = 0;

    GameEventBus.instance.fire(PlayerJumpEvent(
      _playerData.x,
      _playerData.y,
    ));

    GameEventBus.instance.fire(AudioPlayEvent('jump'));
  }

  // Event handlers
  void _handleInputEvent(InputEvent event) {
    switch (event.action) {
      case InputAction.jump:
        if (event.isPressed) {
          _jumpInputBuffer = true;
          _playerData.isHoldingJump = true;
          _jumpBufferTimer = GameConfig.jumpBufferDuration;
        } else {
          _playerData.isHoldingJump = false;
        }
        break;
      case InputAction.duck:
        _duckInputBuffer = event.isPressed;
        break;
      case InputAction.pause:
        // Pause is handled by GameStateProvider
        break;
      case InputAction.start:
        // Start is handled by GameStateProvider
        break;
    }
  }

  void _handleTouchEvent(TouchInputEvent event) {
    // Convert touch position to input action
    final screenHeight = 800.0; // Use actual screen height
    final isUpperHalf = event.position.dy < screenHeight / 2;

    switch (event.action) {
      case InputAction.jump:
        _handleInputEvent(InputEvent(InputAction.jump, isUpperHalf));
        break;
      case InputAction.duck:
        _handleInputEvent(InputEvent(InputAction.duck, !isUpperHalf));
        break;
      case InputAction.pause:
      case InputAction.start:
        // Pause and start are handled elsewhere
        break;
    }
  }

  void _handleGameStarted(GameStartedEvent event) {
    reset();
    _playerData.y = GameConfig.groundLevel - _playerData.height;
  }

  void _handleGameOver(GameOverEvent event) {
    // Player system responds to game over
    _isPaused = true;
  }

  @override
  void dispose() {
    GameEventBus.instance.unsubscribe<InputEvent>(_handleInputEvent);
    GameEventBus.instance.unsubscribe<TouchInputEvent>(_handleTouchEvent);
    GameEventBus.instance.unsubscribe<GameStartedEvent>(_handleGameStarted);
    GameEventBus.instance.unsubscribe<GameOverEvent>(_handleGameOver);
  }
}