import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_neon_runner/game/neon_runner_game.dart';
import 'package:flutter_neon_runner/game_state_provider.dart';
import 'package:flutter_neon_runner/widgets/common/menu_button.dart';
import 'package:flutter_neon_runner/models/game_state.dart';

class GameOverOverlay extends StatefulWidget {
  final NeonRunnerGame game;

  const GameOverOverlay({super.key, required this.game});

  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay> {
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _opacity = 1.0;
      });
    });
  }

  @override
  void didUpdateWidget(covariant GameOverOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final gameStateProvider = Provider.of<GameStateProvider>(context, listen: false);
      if (gameStateProvider.currentGameState != GameState.gameOver && _opacity == 1.0) {
        setState(() {
          _opacity = 0.0;
        });
      } else if (gameStateProvider.currentGameState == GameState.gameOver && _opacity == 0.0) {
        setState(() {
          _opacity = 1.0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final gameStateProvider = Provider.of<GameStateProvider>(context);

    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 500),
      child: Scaffold(
      backgroundColor: Colors.black.withAlpha((255 * 0.8).round()),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'SYSTEM FAILURE',
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.red,
                shadows: [
                  Shadow(
                    color: const Color(0x80FF0000),
                    blurRadius: 20,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'FINAL SCORE: ${widget.game.score.toString().padLeft(6, '0')}',
              style: const TextStyle(
                fontFamily: 'Share Tech Mono',
                fontSize: 24,
                color: Color(0xFF00FF41),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'BEST SCORE: ${widget.game.highscore}',
              style: const TextStyle(
                fontFamily: 'Share Tech Mono',
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 40),
            MenuButton(
              text: 'REBOOT SYSTEM',
              onTap: () {
                gameStateProvider.gameInstance.adsController.showRewardedAd(() {
                   gameStateProvider.startGame();
                });
              },
            ),
            const SizedBox(height: 20),
            MenuButton(
              text: 'LEADERBOARD',
              onTap: () {
                gameStateProvider.showLeaderboard();
              },
            ),
            const SizedBox(height: 20),
            MenuButton(
              text: 'MAIN MENU',
              onTap: () {
                gameStateProvider.updateGameState(GameState.menu);
              },
            ),
          ],
        ),
      ),
    ));
  }
}
