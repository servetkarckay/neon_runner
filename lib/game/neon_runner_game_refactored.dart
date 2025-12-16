import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_neon_runner/config/game_config.dart';
import 'package:flutter_neon_runner/game/events/game_events.dart';
import 'package:flutter_neon_runner/game/systems/game_loop_controller.dart';
import 'package:flutter_neon_runner/game/systems/ui_system.dart';
import 'package:flutter_neon_runner/game_state_provider.dart';
import 'package:flutter_neon_runner/models/game_state.dart';
import 'package:flutter_neon_runner/ads_controller.dart';
import 'package:flutter_neon_runner/local_storage_service.dart';
import 'package:flutter_neon_runner/game/systems/game_state_controller.dart';
import 'package:flutter_neon_runner/game/systems/base_game_system.dart';
import 'package:flutter_neon_runner/config/build_config.dart';

/// Refactored Neon Runner Game using modular system architecture
/// Optimized for mobile touch-first gameplay with high performance
class NeonRunnerGameRefactored extends FlameGame with KeyboardEvents {
  late final GameStateProvider _gameStateProvider;
  late final GameLoopController _gameLoopController;
  late final UISystem _uiSystem;

  // Legacy services (to be refactored into systems)
  late final AdsController _adsController;
  late final LocalStorageService _localStorageService;

  // Game state
  bool _initialized = false;

  NeonRunnerGameRefactored(this._gameStateProvider);

  // Getters for external access
  GameLoopController get gameLoop => _gameLoopController;
  UISystem get uiSystem => _uiSystem;
  GameStateController get gameState => _gameLoopController.gameStateController;

  @override
  Color backgroundColor() => const Color(0xFF000000); // Black background

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Start in paused state
    paused = true;

    // Initialize services
    _adsController = AdsController();
    _localStorageService = LocalStorageService();
    await _adsController.init();
    await _localStorageService.init();

    // Initialize game systems
    await _initializeGameSystems();

    // Setup mobile touch controls
    // _setupTouchControls();

    _initialized = true;
  }

  @override
  void update(double dt) {
    if (!_initialized || paused) {
      super.update(dt);
      return;
    }

    // Update game loop controller which coordinates all systems
    _gameLoopController.update(dt);

    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (!_initialized) return;

    // Render UI system overlay
    _uiSystem.render(canvas, size.toSize());

    // Handle FPS display for debugging
    if (BuildConfig.enableFPSCounter) {
      _renderDebugFPS(canvas);
    }
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    // Desktop input handling (kept for development/testing)
    final isKeyDown = event is KeyDownEvent;
    final gameState = _gameStateProvider.currentGameState;

    if (gameState == GameState.menu || gameState == GameState.gameOver) {
      if (isKeyDown &&
          (keysPressed.contains(LogicalKeyboardKey.space) ||
              keysPressed.contains(LogicalKeyboardKey.enter))) {
        startGame();
        return KeyEventResult.handled;
      }
    }

    if (isKeyDown && keysPressed.contains(LogicalKeyboardKey.keyP)) {
      togglePause();
      return KeyEventResult.handled;
    }

    if (gameState == GameState.playing) {
      // Convert keyboard to game actions
      if (keysPressed.contains(LogicalKeyboardKey.arrowUp) ||
          keysPressed.contains(LogicalKeyboardKey.space)) {
        _gameLoopController.handleInput(InputAction.jump, isKeyDown);
        return KeyEventResult.handled;
      }

      if (keysPressed.contains(LogicalKeyboardKey.arrowDown)) {
        _gameLoopController.handleInput(InputAction.duck, isKeyDown);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  // Mobile-first game control methods
  void startGame() {
    _gameStateProvider.startGame();
    _gameLoopController.startGame();
    paused = false;
  }

  void pauseGame() {
    _gameStateProvider.pauseGame();
    _gameLoopController.pauseGame();
    paused = true;
  }

  void resumeGame() {
    _gameStateProvider.resumeGame();
    _gameLoopController.resumeGame();
    paused = false;
  }

  void togglePause() {
    if (_gameStateProvider.currentGameState == GameState.playing) {
      pauseGame();
    } else if (_gameStateProvider.currentGameState == GameState.paused) {
      resumeGame();
    }
  }

  void gameOver() {
    final score = _gameLoopController.score;
    final highscore = _localStorageService.getHighscore();

    if (score > highscore) {
      _localStorageService.setHighscore(score);
    }

    _gameStateProvider.gameOver();
    _gameLoopController.gameOver(finalScore: score);
    paused = true;

    // Auto-show revive option after delay
    Future.delayed(const Duration(seconds: 1), () {
      if (gameState.isGameOver) {
        _showReviveOption();
      }
    });
  }

  void _showReviveOption() {
    // Show rewarded ad for revive (mobile optimization)
    _adsController.showRewardedAd(() {
      gameState.completeReviving(bonusScore: 500);
      paused = false;
    });
  }

  void returnToMenu() {
    _gameStateProvider.updateGameState(GameState.menu);
    _gameLoopController.reset();
    paused = true;
  }

  // Touch input handling for mobile
  void handleTouchInput(Offset position) {
    if (_gameStateProvider.currentGameState == GameState.menu ||
        _gameStateProvider.currentGameState == GameState.gameOver) {
      startGame();
      return;
    }

    if (_gameStateProvider.currentGameState == GameState.playing) {
      // Determine action based on touch position
      final screenHeight = size.y;
      final isUpperHalf = position.dy < screenHeight / 2;

      if (isUpperHalf) {
        _gameLoopController.handleTouchInput(position, InputAction.jump);
      } else {
        _gameLoopController.handleTouchInput(position, InputAction.duck);
      }
    }
  }

  void handleTouchEnd() {
    // Release any held actions
    _gameLoopController.handleInput(InputAction.jump, false);
    _gameLoopController.handleInput(InputAction.duck, false);
  }

  // System initialization
  Future<void> _initializeGameSystems() async {
    // Initialize game loop controller which sets up all other systems
    _gameLoopController = GameLoopController();
    await _gameLoopController.initialize();

    // Initialize UI system
    _uiSystem = UISystem(_gameLoopController.playerSystem);
    await _uiSystem.initialize();

    // Connect with game state provider
    _connectGameStateProvider();
  }

  void _connectGameStateProvider() {
    // Listen to game state changes from provider
    _gameStateProvider.addListener(_onGameStateChanged);
  }

  void _onGameStateChanged() {
    final currentState = _gameStateProvider.currentGameState;

    switch (currentState) {
      case GameState.playing:
        if (paused) {
          resumeGame();
        }
        break;
      case GameState.paused:
        pauseGame();
        break;
      case GameState.gameOver:
        gameOver();
        break;
      case GameState.menu:
        returnToMenu();
        break;
      default:
        break;
    }
  }

  void _renderDebugFPS(Canvas canvas) {
    // Simple FPS counter for debugging
    final fpsText = 'FPS: ${(1000 / _gameLoopController.averageFrameTime).toStringAsFixed(1)}';
    final textPainter = TextPainter(
      text: TextSpan(
        text: fpsText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(10, 10));
  }
}