import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_neon_runner/game/neon_runner_game.dart';
import 'package:flutter_neon_runner/game_state_provider.dart';
import 'package:flutter_neon_runner/widgets/common/menu_button.dart';
import 'package:flutter_neon_runner/models/game_state.dart';

class PauseMenuOverlay extends StatefulWidget {
  final NeonRunnerGame game;

  const PauseMenuOverlay({super.key, required this.game});

  @override
  State<PauseMenuOverlay> createState() => _PauseMenuOverlayState();
}

class _PauseMenuOverlayState extends State<PauseMenuOverlay> {
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
  void didUpdateWidget(covariant PauseMenuOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final gameStateProvider = Provider.of<GameStateProvider>(context, listen: false);
      if (gameStateProvider.currentGameState != GameState.paused && _opacity == 1.0) {
        setState(() {
          _opacity = 0.0;
        });
      } else if (gameStateProvider.currentGameState == GameState.paused && _opacity == 0.0) {
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
              'SYSTEM PAUSED',
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontSize: GameConfig.pauseMenuTitleFontSize,
                fontWeight: FontWeight.bold,
                color: GameConfig.primaryNeonColor,
                shadows: [
                  Shadow(
                    color: GameConfig.primaryNeonColor.withAlpha((255 * GameConfig.overlayBackgroundAlpha).round()), // Using overlay background alpha for consistent shadow effect
                    blurRadius: GameConfig.pauseMenuTitleBlurRadius,
                  ),
                ],
              ),
            ),
            const SizedBox(height: GameConfig.mainMenuSectionSpacing), // Reusing section spacing
            _buildActionButton(
              text: 'RESUME',
              color: GameConfig.primaryNeonColor,
              onPressed: () {
                gameStateProvider.resumeGame();
              },
            ),
            const SizedBox(height: GameConfig.pauseMenuButtonSpacing),
            _buildActionButton(
              text: 'LEADERBOARD',
              color: Colors.white, // Consider making a constant
              onPressed: () {
                gameStateProvider.showLeaderboard();
              },
            ),
            const SizedBox(height: GameConfig.pauseMenuButtonSpacing),
            MenuButton(
              text: 'SETTINGS',
              onTap: () {
                gameStateProvider.updateGameState(GameState.settings);
              },
            ),
            const SizedBox(height: GameConfig.pauseMenuButtonSpacing),
            MenuButton(
              text: 'BACK TO MAIN MENU',
              onTap: () {
                gameStateProvider.updateGameState(GameState.menu);
              },
            ),
          ],
        ),
      ),
    ));
  }

  Widget _buildActionButton({
    required String text,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: color,
        backgroundColor: Colors.transparent,
        side: BorderSide(color: color, width: GameConfig.menuButtonBorderWidth), // Reusing border width
        padding: const EdgeInsets.symmetric(horizontal: GameConfig.pauseMenuActionButtonPaddingHorizontal, vertical: GameConfig.pauseMenuActionButtonPaddingVertical),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GameConfig.pauseMenuActionButtonBorderRadius),
        ),
        shadowColor: color.withAlpha((255 * GameConfig.pauseMenuActionButtonShadowAlpha).round()),
        elevation: GameConfig.pauseMenuActionButtonElevation,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Share Tech Mono',
          fontSize: GameConfig.pauseMenuActionButtonFontSize,
          letterSpacing: GameConfig.pauseMenuActionButtonLetterSpacing,
        ),
      ),
    );
  }
}