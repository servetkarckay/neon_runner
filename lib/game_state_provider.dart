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


  GameState get currentGameState => _game.gameState;
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

  void updateGameState(GameState newState) {
    _game.gameState = newState;
    notifyListeners();
  }

  void startGame() {
    _game.initGame();
    updateGameState(GameState.playing);
  }

  void pauseGame() {
    _game.togglePause();
    updateGameState(GameState.paused);
  }

  void resumeGame() {
    _game.togglePause();
    updateGameState(GameState.playing);
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
    updateGameState(GameState.gameOver);
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