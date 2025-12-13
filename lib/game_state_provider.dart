import 'package:flutter/material.dart';
import 'package:flutter_neon_runner/game/neon_runner_game.dart';
import 'package:flutter_neon_runner/models/game_state.dart';
import 'package:flutter_neon_runner/services/leaderboard_service.dart'; // Import LeaderboardService
import 'package:uuid/uuid.dart'; // Import uuid for generating unique IDs

class GameStateProvider extends ChangeNotifier {
  late NeonRunnerGame _game;
  late final LeaderboardService leaderboardService; // Declare LeaderboardService

  GameStateProvider() : leaderboardService = LeaderboardService();

  // Method to set the game instance after provider is created
  void setGame(NeonRunnerGame game) {
    _game = game;
  }

  // Getter to expose the game instance
  NeonRunnerGame get gameInstance => _game;

  // HUD-related getters
  int get score => _game.score;
  double get speed => _game.speed;
  bool get hasShield => _game.playerData.hasShield;
  int get multiplier => _game.playerData.scoreMultiplier.toInt();
  int get multiplierTimer => _game.playerData.multiplierTimer;
  bool get timeWarpActive => _game.playerData.timeWarpTimer > 0;
  int get timeWarpTimer => _game.playerData.timeWarpTimer;
  bool get magnetActive => _game.playerData.hasMagnet;
  int get magnetTimer => _game.playerData.magnetTimer;
  bool get scoreGlitch => _game.scoreGlitch;
  bool get isGrazing => _game.playerData.isGrazing;

  GameState _currentGameState = GameState.menu;

  // Getter to expose the current game state
  GameState get currentGameState => _currentGameState;
  
  // Method to update the game state
  void updateGameState(GameState newState) {
    _currentGameState = newState;
    notifyListeners();
  }

  void startGame() {
    // Ensure the game is initialized before starting
    if (!_game.isMounted) { // Check if the game is already mounted before adding
       // This might not be the right place to add the game, it's usually added in main.dart GameWidget
    }
    _game.initGame();
    _currentGameState = GameState.playing; // Directly set state
    notifyListeners();
  }

  void pauseGame() {
    _game.togglePause();
    _currentGameState = GameState.paused; // Directly set state
    notifyListeners();
  }

  void resumeGame() {
    _game.togglePause();
    _currentGameState = GameState.playing; // Directly set state
    notifyListeners();
  }

  void gameOver() {
    _game.gameOver();
    // Assuming _game.userId is already set from LocalStorageService
    String playerId = _game.userId ?? const Uuid().v4();
    _game.userId ??= playerId;

    String playerName = 'ANONYMOUS'; // Placeholder, could be customizable later

    if (_game.score > _game.highscore) { // Only submit if it's a new high score
      leaderboardService.submitScore(playerId, playerName, _game.score);
    }
    _currentGameState = GameState.gameOver; // Directly set state
    notifyListeners();
  }

  void showLeaderboard() {
    updateGameState(GameState.leaderboardView);
  }

  void backToPauseMenu() {
    updateGameState(GameState.paused);
  }

  void updateHudData() {
    notifyListeners();
  }
}