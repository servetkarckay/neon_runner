import 'package:flutter/material.dart';
import 'game_state_provider.dart';
import 'mock_neon_runner_game.dart';

class TestApp extends StatelessWidget {
  final Widget child;
  final GameStateProvider? gameStateProvider;
  final NeonRunnerGame? game;

  const TestApp({
    super.key,
    required this.child,
    this.gameStateProvider,
    this.game,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(800, 600)),
        child: child,
      ),
    );
  }
}

// Mock widgets for testing UI elements
class MainMenuOverlay extends StatelessWidget {
  final VoidCallback? onStartGame;
  final VoidCallback? onShowLeaderboard;

  const MainMenuOverlay({
    super.key,
    this.onStartGame,
    this.onShowLeaderboard,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: onStartGame,
              child: Text('START'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: onShowLeaderboard,
              child: Text('LEADERBOARD'),
            ),
          ],
        ),
      ),
    );
  }
}

class GameOverOverlay extends StatelessWidget {
  final VoidCallback? onRetry;
  final VoidCallback? onMainMenu;
  final bool canRevive;

  const GameOverOverlay({
    super.key,
    this.onRetry,
    this.onMainMenu,
    this.canRevive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('GAME OVER'),
            Text('SCORE'),
            if (canRevive) ...[
              ElevatedButton(
                onPressed: onRetry,
                child: Text('WATCH AD'),
              ),
            ],
            ElevatedButton(
              onPressed: onMainMenu,
              child: Text('MAIN MENU'),
            ),
          ],
        ),
      ),
    );
  }
}

class GameOverlay extends StatelessWidget {
  final int score;
  final double time;

  const GameOverlay({
    super.key,
    required this.score,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('SCORE: $score'),
          Text('TIME: ${time.toStringAsFixed(1)}'),
        ],
      ),
    );
  }
}

class ReviveDialogOverlay extends StatelessWidget {
  final VoidCallback? onWatchAd;

  const ReviveDialogOverlay({
    super.key,
    this.onWatchAd,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: onWatchAd,
          child: Text('WATCH AD'),
        ),
      ),
    );
  }
}

class PauseMenuOverlay extends StatelessWidget {
  final VoidCallback? onResume;

  const PauseMenuOverlay({
    super.key,
    this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: onResume,
          child: Text('RESUME'),
        ),
      ),
    );
  }
}