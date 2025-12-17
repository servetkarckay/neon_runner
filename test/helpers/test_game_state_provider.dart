import 'package:flutter_neon_runner/models/game_state.dart';
import 'mock_leaderboard_system.dart';

class TestGameStateProvider {
  MockLeaderboardSystem? mockLeaderboardSystem;
  List<int> submittedScores = [];
  GameState _currentGameState = GameState.menu;

  TestGameStateProvider({this.mockLeaderboardSystem});

  void initialize(dynamic game) {
    // Mock initialization
  }

  GameState get currentGameState => _currentGameState;

  void startGame() {
    _currentGameState = GameState.playing;
  }

  void pauseGame() {
    _currentGameState = GameState.paused;
  }

  void resumeGame() {
    _currentGameState = GameState.playing;
  }

  void gameOver() {
    _currentGameState = GameState.gameOver;
  }

  void returnToMenu() {
    _currentGameState = GameState.menu;
  }

  void showLeaderboard() {
    _currentGameState = GameState.leaderboardView;
  }

  void submitScore(int score) {
    if (mockLeaderboardSystem != null && !submittedScores.contains(score)) {
      mockLeaderboardSystem!.submitScore('ANONYMOUS', score);
      submittedScores.add(score);
    }
  }
}