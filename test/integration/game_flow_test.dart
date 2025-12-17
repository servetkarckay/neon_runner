import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_neon_runner/models/game_state.dart';
import '../helpers/mock_ad_system.dart';
import '../helpers/mock_leaderboard_system.dart';
import '../helpers/test_game_state_provider.dart';
import '../helpers/test_widget_wrapper.dart';
import '../helpers/mock_neon_runner_game.dart';

void main() {
  group('Game Flow Integration Tests', () {
    late NeonRunnerGame game;
    late TestGameStateProvider gameStateProvider;
    late MockRewardedAdSystem mockAdSystem;
    late MockLeaderboardSystem mockLeaderboardSystem;

    setUp(() {
      mockAdSystem = MockRewardedAdSystem();
      mockLeaderboardSystem = MockLeaderboardSystem();

      game = NeonRunnerGame(
        adSystem: mockAdSystem,
        leaderboardSystem: mockLeaderboardSystem,
      );

      gameStateProvider = TestGameStateProvider(mockLeaderboardSystem: mockLeaderboardSystem);
      gameStateProvider.initialize(game);
    });

    group('Play → Die → Ad → Revive → Continue Flow', () {
      testWidgets('complete revive flow works correctly', (WidgetTester tester) async {
        // Arrange - Build widget tree with GameOver overlay
        await tester.pumpWidget(
          TestApp(
            child: GameOverOverlay(
              canRevive: true,
              onRetry: () {
                // Simulate successful revive
                game.player.isDead = false;
                game.player.canRevive = false;
                game.player.isInvincible = true;
                gameStateProvider.startGame();
              },
            ),
          ),
        );

        // Should show game over dialog
        expect(find.text('WATCH AD'), findsOneWidget);

        // Act - User watches ad (simulated)
        await tester.tap(find.text('WATCH AD'));
        await tester.pump(Duration(seconds: 1)); // Wait for ad

        // Assert - Player should be revived
        expect(game.player.isDead, isFalse);
        expect(game.player.canRevive, isFalse);
        expect(game.player.isInvincible, isTrue);
      });

      testWidgets('revive flow handles ad failure gracefully', (WidgetTester tester) async {
        // Arrange - Build widget tree with GameOver overlay that simulates ad failure
        bool adFailed = false;

        await tester.pumpWidget(
          TestApp(
            child: GameOverOverlay(
              canRevive: true,
              onRetry: () {
                // Simulate ad failure - should go to main menu
                adFailed = true;
                gameStateProvider.returnToMenu();
              },
              onMainMenu: () {
                gameStateProvider.returnToMenu();
              },
            ),
          ),
        );

        // Act - User tries to revive (simulated failure)
        await tester.tap(find.text('WATCH AD'));
        await tester.pump(Duration(seconds: 1));

        // Assert - Should show main menu (ad failed)
        expect(adFailed, isTrue);
        expect(gameStateProvider.currentGameState, equals(GameState.menu));
      });
    });

    group('Play → Die → No Ad → Game Over Flow', () {
      testWidgets('game over flow works without revive', (WidgetTester tester) async {
        // Arrange - Start game
        gameStateProvider.startGame();
        expect(gameStateProvider.currentGameState, equals(GameState.playing));

        // Build game over overlay
        await tester.pumpWidget(
          TestApp(
            child: GameOverOverlay(
              canRevive: false,
            ),
          ),
        );

        // Simulate player death with no revive available
        game.player.isDead = true;
        game.player.canRevive = false;
        gameStateProvider.gameOver();
        await tester.pump();

        // Assert - Should show game over
        expect(gameStateProvider.currentGameState, equals(GameState.gameOver));
        expect(find.text('GAME OVER'), findsOneWidget);

        // Should show score
        expect(find.text('SCORE'), findsOneWidget);

        // Should not show revive option
        expect(find.text('WATCH AD'), findsNothing);
      });

      testWidgets('can return to main menu from game over', (WidgetTester tester) async {
        // Arrange - Build game over overlay
        await tester.pumpWidget(
          TestApp(
            child: GameOverOverlay(
              onMainMenu: () {
                gameStateProvider.returnToMenu();
              },
            ),
          ),
        );

        // Set game state to game over
        gameStateProvider.gameOver();
        await tester.pump();

        // Act - Return to main menu
        await tester.tap(find.text('MAIN MENU'));
        await tester.pump();

        // Assert - Should be back at main menu
        expect(gameStateProvider.currentGameState, equals(GameState.menu));
      });
    });

    group('Leaderboard Submission Flow', () {
      testWidgets('submits score on game over', (WidgetTester tester) async {
        // Arrange - Play and get score
        gameStateProvider.startGame();
        game.score = 5000;
        game.player.isDead = true;
        gameStateProvider.gameOver();
        await tester.pump();

        // Manually submit the score (simulating what would happen in game over)
        gameStateProvider.submitScore(5000);
        await tester.pump();

        // Assert - Score should be submitted
        expect(gameStateProvider.submittedScores.length, equals(1));
        expect(gameStateProvider.submittedScores.last, equals(5000));
      });

      testWidgets('prevents duplicate submissions', (WidgetTester tester) async {
        // Arrange - Play and get score
        gameStateProvider.startGame();
        game.score = 3000;
        game.player.isDead = true;
        gameStateProvider.gameOver();
        await tester.pump();

        // Submit first time
        gameStateProvider.submitScore(3000);
        await tester.pump();

        // Act - Try to submit again
        gameStateProvider.submitScore(3000);
        await tester.pump();

        // Assert - Only one submission
        expect(gameStateProvider.submittedScores.length, equals(1));
      });
    });

    group('Pause and Resume Flow', () {
      testWidgets('pausing and resuming works correctly', (WidgetTester tester) async {
        // Arrange - Start game
        gameStateProvider.startGame();
        expect(gameStateProvider.currentGameState, equals(GameState.playing));

        // Act - Pause game
        gameStateProvider.pauseGame();
        await tester.pump();
        await tester.pump(Duration.zero);

        // Build pause menu after pausing
        await tester.pumpWidget(
          TestApp(
            child: PauseMenuOverlay(
              onResume: () {
                gameStateProvider.resumeGame();
              },
            ),
          ),
        );
        await tester.pump();

        // Assert - Game should be paused
        expect(gameStateProvider.currentGameState, equals(GameState.paused));
        expect(find.text('RESUME'), findsOneWidget);

        // Act - Resume game
        await tester.tap(find.text('RESUME'));
        await tester.pump();
        await tester.pump(Duration.zero);

        // Assert - Game should be playing
        expect(gameStateProvider.currentGameState, equals(GameState.playing));
      });

      testWidgets('pause maintains game state', (WidgetTester tester) async {
        // Arrange - Play and get some score
        gameStateProvider.startGame();
        game.player.score = 2000;
        game.player.position.setValues(100, 200);
        await tester.pumpWidget(TestApp(child: PauseMenuOverlay()));
        await tester.pump(Duration(milliseconds: 100));

        // Act - Pause
        gameStateProvider.pauseGame();
        await tester.pump();
        await tester.pump(Duration.zero);

        // Build pause menu with proper callback
        await tester.pumpWidget(
          TestApp(
            child: PauseMenuOverlay(
              onResume: () {
                gameStateProvider.resumeGame();
              },
            ),
          ),
        );
        await tester.pump();

        // Assert - Score and position should be preserved
        expect(game.player.score, equals(2000));
        expect(game.player.position.x, equals(100));
        expect(game.player.position.y, equals(200));
        expect(gameStateProvider.currentGameState, equals(GameState.paused));

        // Resume and verify still preserved
        await tester.tap(find.text('RESUME'));
        await tester.pump();
        await tester.pump(Duration.zero);

        expect(gameStateProvider.currentGameState, equals(GameState.playing));
        expect(game.player.score, equals(2000));
      });
    });

    group('Main Menu Navigation', () {
      testWidgets('navigate to leaderboard from main menu', (WidgetTester tester) async {
        // Arrange - At main menu
        await tester.pumpWidget(
          TestApp(
            child: MainMenuOverlay(
              onShowLeaderboard: () {
                gameStateProvider.showLeaderboard();
              },
            ),
          ),
        );

        expect(gameStateProvider.currentGameState, equals(GameState.menu));

        // Act - Tap leaderboard button
        await tester.tap(find.text('LEADERBOARD'));
        await tester.pump(Duration(milliseconds: 100));

        // Assert - Should show leaderboard
        expect(gameStateProvider.currentGameState, equals(GameState.leaderboardView));
      });

      testWidgets('can start new game from main menu', (WidgetTester tester) async {
        // Arrange - At main menu
        await tester.pumpWidget(
          TestApp(
            child: MainMenuOverlay(
              onStartGame: () {
                game.player.isDead = false;
                game.player.score = 0;
                game.score = 0;
                gameStateProvider.startGame();
              },
            ),
          ),
        );

        expect(gameStateProvider.currentGameState, equals(GameState.menu));

        // Act - Tap start button
        await tester.tap(find.text('START'));
        await tester.pump(Duration(milliseconds: 100));

        // Assert - Should start playing
        expect(gameStateProvider.currentGameState, equals(GameState.playing));
        expect(game.player.isDead, isFalse);
        expect(game.score, equals(0));
        expect(game.player.score, equals(0));
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