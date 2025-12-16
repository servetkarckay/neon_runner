import 'package:flutter/material.dart';
import 'package:flutter_neon_runner/game/neon_runner_game.dart';
import 'package:flutter_neon_runner/models/game_state.dart';
import 'package:flutter_neon_runner/services/leaderboard_service.dart';
import 'package:uuid/uuid.dart';

class GameStateProvider extends ChangeNotifier {
  late NeonRunnerGame _game;
  late final LeaderboardService leaderboardService;

  GameStateProvider() : leaderboardService = LeaderboardService();

  // Game instance management
  void setGame(NeonRunnerGame game) {
    _game = game;
  }

  NeonRunnerGame get gameInstance => _game;

  // --- State Management ---

  // Main game state (e.g., menu, playing, gameOver)
  GameState _currentGameState = GameState.menu;
  GameState get currentGameState => _currentGameState;

  // For UI that needs to know if the game is paused by the engine
  bool _isEnginePaused = false;
  bool get isEnginePaused => _isEnginePaused;

  // --- ValueNotifiers for reactive HUD updates ---
  // These allow widgets to listen to specific data changes without
  // rebuilding the entire widget tree via notifyListeners().

  final ValueNotifier<int> score = ValueNotifier(0);
  final ValueNotifier<int> highscore = ValueNotifier(0);
  final ValueNotifier<double> speed = ValueNotifier(0.0);
  final ValueNotifier<int> multiplier = ValueNotifier(1);
  final ValueNotifier<bool> hasShield = ValueNotifier(false);
  final ValueNotifier<bool> isGrazing = ValueNotifier(false);
  final ValueNotifier<bool> scoreGlitch = ValueNotifier(false);
  
  // Power-up timers
  final ValueNotifier<int> multiplierTimer = ValueNotifier(0);
  final ValueNotifier<int> timeWarpTimer = ValueNotifier(0);
  final ValueNotifier<int> magnetTimer = ValueNotifier(0);
  

  // --- Methods to update state from the game ---

  /// Updates all HUD data from the game instance.
  /// Called periodically from the game loop, but less frequently than every frame.
  void updateHudData() {
    score.value = _game.score;
    highscore.value = _game.highscore;
    speed.value = _game.speed;
    multiplier.value = _game.playerData.scoreMultiplier.toInt();
    hasShield.value = _game.playerData.hasShield;
    isGrazing.value = _game.playerData.isGrazing;
    scoreGlitch.value = _game.scoreGlitch;
    multiplierTimer.value = _game.playerData.multiplierTimer;
    timeWarpTimer.value = _game.playerData.timeWarpTimer;
    magnetTimer.value = _game.playerData.magnetTimer;
  }

  // --- Game Flow Control Methods (called by UI) ---

  void updateGameState(GameState newState) {
    if (_currentGameState == newState) return;
    _currentGameState = newState;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void startGame() {
    debugPrint('GameStateProvider: startGame() called.');
    _game.initGame();
    updateGameState(GameState.playing);
    // The game is now responsible for its own running state.
    // We just tell the UI what overlay to show.
    if (_game.paused) {
      _game.paused = false;
    }
  }

  void pauseGame() {
    if (_currentGameState != GameState.playing) return;
    debugPrint('GameStateProvider: Pausing game.');
    _game.paused = true;
    _isEnginePaused = true;
    updateGameState(GameState.paused);
  }

  void resumeGame() {
    if (_currentGameState != GameState.paused) return;
    debugPrint('GameStateProvider: Resuming game.');
    _game.paused = false;
    _isEnginePaused = false;
    updateGameState(GameState.playing);
  }

  void gameOver() {
    updateGameState(GameState.gameOver);

    String playerId = _game.userId ?? const Uuid().v4();
    _game.userId ??= playerId;
    String playerName = 'ANONYMOUS'; // Placeholder

    // Submit score to leaderboard
    if (_game.score > 0) { // Can be adjusted based on logic
      leaderboardService.submitScore(playerId, playerName, _game.score);
    }
  }

  void showLeaderboard() {
    updateGameState(GameState.leaderboardView);
  }

  void backToPauseMenu() {
    updateGameState(GameState.paused);
  }

  @override
  void dispose() {
    score.dispose();
    highscore.dispose();
    speed.dispose();
    multiplier.dispose();
    hasShield.dispose();
    isGrazing.dispose();
    scoreGlitch.dispose();
    multiplierTimer.dispose();
    timeWarpTimer.dispose();
    magnetTimer.dispose();
    super.dispose();
  }
}