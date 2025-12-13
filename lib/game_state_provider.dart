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
  bool _isHudUpdateLoopActive = false; // New flag to control continuous HUD updates

  // Getter to expose the current game state
  GameState get currentGameState => _currentGameState;
  
  // Method to update the game state
  void updateGameState(GameState newState) {
    if (_currentGameState == newState) return; // Only update if state actually changes

    _currentGameState = newState;

    if (_currentGameState == GameState.playing && !_isHudUpdateLoopActive) {
      _isHudUpdateLoopActive = true;
      _scheduleHudFrameCallback(); // Start the HUD update loop
    } else if (_currentGameState != GameState.playing && _isHudUpdateLoopActive) {
      _isHudUpdateLoopActive = false; // Stop the HUD update loop (by not rescheduling)
    }

    notifyListeners(); // Notify for general state changes (e.g., menu to playing)
  }

  // New method to schedule HUD updates
  void _scheduleHudFrameCallback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isHudUpdateLoopActive) return; // If loop is deactivated, stop
      notifyListeners(); // Notify listeners for HUD data

      // If still playing, reschedule for the next frame
      if (_currentGameState == GameState.playing) {
        _scheduleHudFrameCallback();
      } else {
        _isHudUpdateLoopActive = false; // Ensure flag is false if state changed unexpectedly
      }
    });
  }
}