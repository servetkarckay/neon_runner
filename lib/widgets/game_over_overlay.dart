import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_neon_runner/game/neon_runner_game.dart';
import 'package:flutter_neon_runner/game_state_provider.dart';
import 'package:flutter_neon_runner/widgets/common/menu_button.dart';
import 'package:flutter_neon_runner/models/game_state.dart';
import 'package:flutter_neon_runner/config/game_config.dart';

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
      duration: const Duration(milliseconds: 500), // Consider making a constant
      child: Scaffold(
      backgroundColor: Colors.black.withAlpha((255 * GameConfig.overlayBackgroundAlpha).round()),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'SYSTEM FAILURE',
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontSize: GameConfig.gameOverTitleFontSize,
                fontWeight: FontWeight.bold,
                color: GameConfig.errorNeonColor,
                shadows: [
                  Shadow(
                    color: GameConfig.errorNeonColor.withAlpha((255 * GameConfig.overlayBackgroundAlpha).round()), // Consistent shadow alpha
                    blurRadius: GameConfig.gameOverTitleBlurRadius,
                  ),
                ],
              ),
            ),
            const SizedBox(height: GameConfig.defaultOverlaySpacing),
            Text(
              'FINAL SCORE: ${widget.game.score.toString().padLeft(6, '0')}',
              style: const TextStyle(
                fontFamily: 'Share Tech Mono',
                fontSize: GameConfig.gameOverScoreFontSize,
                color: GameConfig.primaryNeonColor,
              ),
            ),
            const SizedBox(height: GameConfig.defaultOverlayPadding),
            Text(
              'BEST SCORE: ${widget.game.highscore}',
              style: const TextStyle(
                fontFamily: 'Share Tech Mono',
                fontSize: GameConfig.gameOverHighscoreFontSize,
                color: Colors.white70, // Consider making a constant
              ),
            ),
            const SizedBox(height: GameConfig.mainMenuSectionSpacing), // Reusing section spacing
            MenuButton(
              text: 'REBOOT SYSTEM',
              onTap: () {
                gameStateProvider.gameInstance.adsController.showRewardedAd(() {
                   gameStateProvider.startGame();
                });
              },
            ),
            const SizedBox(height: GameConfig.gameOverButtonSpacing),
            MenuButton(
              text: 'LEADERBOARD',
              onTap: () {
                gameStateProvider.showLeaderboard();
              },
            ),
            const SizedBox(height: GameConfig.gameOverButtonSpacing),
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
