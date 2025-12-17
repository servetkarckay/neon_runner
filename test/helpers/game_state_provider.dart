import '../helpers/mock_neon_runner_game.dart';
import 'game_state.dart';

class GameStateProvider {
  GameState _currentGameState = GameState.menu;
  late NeonRunnerGame _game;

  void initialize(NeonRunnerGame game) {
    _game = game;
  }

  NeonRunnerGame get game => _game;

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
    // Mock score submission
  }
}