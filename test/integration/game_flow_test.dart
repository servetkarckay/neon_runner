import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_neon_runner/game/neon_runner_game.dart';
import 'package:flutter_neon_runner/game_state_provider.dart';
import 'package:flutter_neon_runner/models/game_state.dart';
import 'package:flutter_neon_runner/ads/rewarded_ad_system.dart';
import 'package:flutter_neon_runner/leaderboard/leaderboard_system.dart';

void main() {
  group('Game Flow Integration Tests', () {
    late NeonRunnerGame game;
    late GameStateProvider gameStateProvider;
    late MockRewardedAdSystem mockAdSystem;
    late MockLeaderboardSystem mockLeaderboardSystem;

    setUp(() {
      mockAdSystem = MockRewardedAdSystem();
      mockLeaderboardSystem = MockLeaderboardSystem();

      game = NeonRunnerGame(
        adSystem: mockAdSystem,
        leaderboardSystem: mockLeaderboardSystem,
      );

      gameStateProvider = GameStateProvider();
      gameStateProvider.initialize(game);
    });

    group('Play → Die → Ad → Revive → Continue Flow', () {
      testWidgets('complete revive flow works correctly', (WidgetTester tester) async {
        // Arrange - Start game
        gameStateProvider.startGame();
        expect(gameStateProvider.currentGameState, equals(GameState.playing));

        // Simulate player death
        game.player.isDead = true;
        game.player.canRevive = true;
        await tester.pump(Duration(milliseconds: 100));

        // Should transition to gameOver
        expect(gameStateProvider.currentGameState, equals(GameState.gameOver));

        // Arrange - Ad is available
        mockAdSystem.isAdAvailable = true;
        mockAdSystem.shouldAdSucceed = true;

        // Act - User chooses to revive
        await tester.tap(find.text('RETRY'));
        await tester.pump(Duration(milliseconds: 100));

        // Should show revive dialog
        expect(find.text('WATCH AD'), findsOneWidget);

        // Act - User watches ad
        await tester.tap(find.text('WATCH AD'));
        await tester.pump(Duration(seconds: 1)); // Wait for ad

        // Assert - Player should be revived
        expect(game.player.isDead, isFalse);
        expect(game.player.canRevive, isFalse);
        expect(game.player.isInvincible, isTrue);
        expect(gameStateProvider.currentGameState, equals(GameState.playing));

        // Verify score is preserved
        expect(game.score, greaterThan(0));
      });

      testWidgets('revive flow handles ad failure gracefully', (WidgetTester tester) async {
        // Arrange - Start and die
        gameStateProvider.startGame();
        game.player.isDead = true;
        game.player.canRevive = true;
        await tester.pump(Duration(milliseconds: 100));

        // Arrange - Ad fails
        mockAdSystem.isAdAvailable = true;
        mockAdSystem.shouldAdSucceed = false;

        // Act - User tries to revive
        await tester.tap(find.text('RETRY'));
        await tester.pump(Duration(milliseconds: 100));
        await tester.tap(find.text('WATCH AD'));
        await tester.pump(Duration(seconds: 1));

        // Assert - Should go to game over
        expect(gameStateProvider.currentGameState, equals(GameState.gameOver));
        expect(find.text('MAIN MENU'), findsOneWidget);
      });
    });

    group('Play → Die → No Ad → Game Over Flow', () {
      testWidgets('game over flow works without revive', (WidgetTester tester) async {
        // Arrange - Start game
        gameStateProvider.startGame();
        expect(gameStateProvider.currentGameState, equals(GameState.playing));

        // Simulate player death with no revive available
        game.player.isDead = true;
        game.player.canRevive = false;
        await tester.pump(Duration(milliseconds: 100));

        // Assert - Should show game over
        expect(gameStateProvider.currentGameState, equals(GameState.gameOver));
        expect(find.text('GAME OVER'), findsOneWidget);

        // Should show score
        expect(find.text('SCORE'), findsOneWidget);

        // Should not show revive option
        expect(find.text('WATCH AD'), findsNothing);
      });

      testWidgets('can return to main menu from game over', (WidgetTester tester) async {
        // Arrange - Game over state
        gameStateProvider.startGame();
        game.player.isDead = true;
        await tester.pump(Duration(milliseconds: 100));

        // Act - Return to main menu
        await tester.tap(find.text('MAIN MENU'));
        await tester.pump(Duration(milliseconds: 100));

        // Assert - Should be back at main menu
        expect(gameStateProvider.currentGameState, equals(GameState.menu));
        expect(find.text('START'), findsOneWidget);
      });
    });

    group('Leaderboard Submission Flow', () {
      testWidgets('submits score on game over', (WidgetTester tester) async {
        // Arrange - Play and get score
        gameStateProvider.startGame();
        game.player.score = 5000;
        game.player.isDead = true;
        await tester.pump(Duration(milliseconds: 100));

        // Act - Game over occurs
        expect(gameStateProvider.currentGameState, equals(GameState.gameOver));

        // Assert - Score should be submitted
        expect(mockLeaderboardSystem.submittedScores.length, equals(1));
        expect(mockLeaderboardSystem.submittedScores.last, equals(5000));
      });

      testWidgets('prevents duplicate submissions', (WidgetTester tester) async {
        // Arrange - Play and get score
        gameStateProvider.startGame();
        game.player.score = 3000;
        game.player.isDead = true;
        await tester.pump(Duration(milliseconds: 100));

        // Act - Try to submit again
        gameStateProvider.submitScore(3000);
        await tester.pump(Duration(milliseconds: 100));

        // Assert - Only one submission
        expect(mockLeaderboardSystem.submittedScores.length, equals(1));
      });
    });

    group('Pause and Resume Flow', () {
      testWidgets('pausing and resuming works correctly', (WidgetTester tester) async {
        // Arrange - Start game
        gameStateProvider.startGame();
        expect(gameStateProvider.currentGameState, equals(GameState.playing));

        // Act - Pause game
        await tester.tap(find.byIcon(Icons.pause_rounded));
        await tester.pump(Duration(milliseconds: 100));

        // Assert - Game should be paused
        expect(gameStateProvider.currentGameState, equals(GameState.paused));
        expect(find.text('RESUME'), findsOneWidget);

        // Act - Resume game
        await tester.tap(find.text('RESUME'));
        await tester.pump(Duration(milliseconds: 100));

        // Assert - Game should be playing
        expect(gameStateProvider.currentGameState, equals(GameState.playing));
      });

      testWidgets('pause maintains game state', (WidgetTester tester) async {
        // Arrange - Play and get some score
        gameStateProvider.startGame();
        game.player.score = 2000;
        game.player.position.setValues(100, 200);
        await tester.pump(Duration(milliseconds: 100));

        // Act - Pause
        await tester.tap(find.byIcon(Icons.pause_rounded));
        await tester.pump(Duration(milliseconds: 100));

        // Assert - Score and position should be preserved
        expect(game.player.score, equals(2000));
        expect(game.player.position.x, equals(100));
        expect(game.player.position.y, equals(200));

        // Resume and verify still preserved
        await tester.tap(find.text('RESUME'));
        await tester.pump(Duration(milliseconds: 100));

        expect(gameStateProvider.currentGameState, equals(GameState.playing));
        expect(game.player.score, equals(2000));
      });
    });

    group('Main Menu Navigation', () {
      testWidgets('navigate to leaderboard from main menu', (WidgetTester tester) async {
        // Arrange - At main menu
        expect(gameStateProvider.currentGameState, equals(GameState.menu));

        // Act - Tap leaderboard button
        await tester.tap(find.text('LEADERBOARD'));
        await tester.pump(Duration(milliseconds: 100));

        // Assert - Should show leaderboard
        expect(gameStateProvider.currentGameState, equals(GameState.leaderboardView));
      });

      testWidgets('can start new game from main menu', (WidgetTester tester) async {
        // Arrange - At main menu
        expect(gameStateProvider.currentGameState, equals(GameState.menu));

        // Act - Tap start button
        await tester.tap(find.text('START'));
        await tester.pump(Duration(milliseconds: 100));

        // Assert - Should start playing
        expect(gameStateProvider.currentGameState, equals(GameState.playing));
        expect(game.player.isDead, isFalse);
        expect(game.score, equals(0));
      });
    });

    group('Performance and Stability', () {
      testWidgets('game remains responsive during extended play', (WidgetTester tester) async {
        // Arrange
        gameStateProvider.startGame();

        // Act - Simulate extended play
        for (int i = 0; i < 100; i++) {
          // Simulate frame updates
          game.update(0.016); // 60 FPS
          await tester.pump(Duration(milliseconds: 16));

          // Occasional pauses
          if (i % 30 == 0) {
            gameStateProvider.pauseGame();
            await tester.pump(Duration(milliseconds: 100));
            gameStateProvider.resumeGame();
            await tester.pump(Duration(milliseconds: 100));
          }
        }

        // Assert - Game should still be responsive
        expect(gameStateProvider.currentGameState, equals(GameState.playing));
        expect(find.byType(Container), findsWidgets);
      });

      testWidgets('handles rapid state changes', (WidgetTester tester) async {
        // Arrange
        gameStateProvider.startGame();

        // Act - Rapid state changes
        for (int i = 0; i < 20; i++) {
          if (i % 2 == 0) {
            gameStateProvider.pauseGame();
          } else {
            gameStateProvider.resumeGame();
          }
          await tester.pump(Duration(milliseconds: 10));
        }

        // Assert - Should be in a valid state
        expect(
          gameStateProvider.currentGameState,
          anyOf([equals(GameState.playing), equals(GameState.paused)])
        );
      });
    });
  });
}

// Mock classes for integration testing
class MockRewardedAdSystem extends RewardedAdSystem {
  bool isAdAvailable = true;
  bool shouldAdSucceed = true;

  @override
  Future<bool> isRewardedAdLoaded() async {
    return isAdAvailable;
  }

  @override
  Future<bool> showRewardedAd(VoidCallback? onUserEarnedReward) async {
    await Future.delayed(Duration(milliseconds: 500)); // Simulate ad loading

    if (shouldAdSucceed && onUserEarnedReward != null) {
      onUserEarnedReward();
    }

    return shouldAdSucceed;
  }
}

class MockLeaderboardSystem extends LeaderboardSystem {
  final List<int> submittedScores = [];

  @override
  Future<void> submitScore(int score) async {
    submittedScores.add(score);
    await Future.delayed(Duration(milliseconds: 100)); // Simulate network
  }

  @override
  Future<bool> isScoreDuplicate(int score) async {
    return submittedScores.contains(score);
  }
}

// Simplified NeonRunnerGame for testing
class NeonRunnerGame {
  final MockPlayerComponent player = MockPlayerComponent();
  int score = 0;
  final MockRewardedAdSystem adSystem;
  final MockLeaderboardSystem leaderboardSystem;

  NeonRunnerGame({
    required this.adSystem,
    required this.leaderboardSystem,
  });

  void update(double dt) {
    if (!player.isDead) {
      // Simulate score increase
      score += (10 * dt).round();
    }
  }
}

class MockPlayerComponent {
  bool isDead = false;
  bool canRevive = true;
  bool isInvincible = false;
  int score = 0;
  final position = Vector2.zero();
}

// Simplified GameStateProvider for testing
class GameStateProvider {
  GameState _currentState = GameState.menu;
  NeonRunnerGame? _game;

  void initialize(NeonRunnerGame game) {
    _game = game;
  }

  GameState get currentGameState => _currentState;

  void startGame() {
    _currentState = GameState.playing;
    _game?.player.isDead = false;
    _game?.player.canRevive = true;
    _game?.score = 0;
  }

  void pauseGame() {
    if (_currentState == GameState.playing) {
      _currentState = GameState.paused;
    }
  }

  void resumeGame() {
    if (_currentState == GameState.paused) {
      _currentState = GameState.playing;
    }
  }

  void gameOver() {
    _currentState = GameState.gameOver;
    _game?.player.isDead = true;
  }

  void submitScore(int score) {
    // Submit would be handled by leaderboard system
  }
}

// Simplified base classes
class RewardedAdSystem {
  Future<bool> isRewardedAdLoaded() async => false;
  Future<bool> showRewardedAd(VoidCallback? onUserEarnedReward) async => false;
}

class LeaderboardSystem {
  Future<void> submitScore(int score) async {}
  Future<bool> isScoreDuplicate(int score) async => false;
}

// Simplified Vector2
class Vector2 {
  double x = 0.0;
  double y = 0.0;

  Vector2.zero();

  void setValues(double x, double y) {
    this.x = x;
    this.y = y;
  }
}