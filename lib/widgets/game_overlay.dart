import 'package:flutter/material.dart';
import 'package:flutter_neon_runner/game/neon_runner_game.dart';
import 'package:provider/provider.dart';
import 'package:flutter_neon_runner/game_state_provider.dart';
import 'package:flutter_neon_runner/models/game_state.dart';
import 'package:flutter_neon_runner/config/game_config.dart';

class GameOverlay extends StatefulWidget {
  final NeonRunnerGame game;

  const GameOverlay({super.key, required this.game});

  @override
  State<GameOverlay> createState() => _GameOverlayState();
}

class _GameOverlayState extends State<GameOverlay> {
  // _isMuted will now be managed by GameStateProvider, not locally
  // bool _isMuted = false;

  // @override
  // void initState() {
  //   super.initState();
  //   // Assuming game.audioController has a way to get initial mute state
  //   _isMuted = widget.game._audioController.isMuted;
  // }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameStateProvider>(
      builder: (context, gameStateProvider, child) {
        // Update _isMuted here if needed, or get it directly from gameStateProvider
        // _isMuted = gameStateProvider.gameInstance.audioController.isMuted; // Assuming a getter for audioController

        if (gameStateProvider.currentGameState != GameState.playing) {
          return const SizedBox.shrink(); // Hide HUD when not playing
        }

        return Stack( // Use a Stack to position multiple HUD elements
          children: [
            // Mute Button
            Positioned(
              top: GameConfig.defaultOverlayPadding,
              left: GameConfig.defaultOverlayPadding,
              child: GestureDetector(
                onTap: () {
                  gameStateProvider.gameInstance.toggleMute();
                  // No need for setState here, Provider will rebuild
                },
                child: Container(
                  padding: const EdgeInsets.all(GameConfig.mobileControlPauseButtonPadding), // Reusing constant
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha((255 * GameConfig.hudMuteButtonBgAlpha).round()),
                    borderRadius: BorderRadius.circular(GameConfig.mobileControlPauseButtonBorderRadius),
                    border: Border.all(color: GameConfig.accentNeonColor, width: GameConfig.hudMuteButtonBorderWidth),
                  ),
                  child: Icon(
                    gameStateProvider.gameInstance.audioController.isMuted ? Icons.volume_off : Icons.volume_up,
                    color: GameConfig.accentNeonColor,
                  ),
                ),
              ),
            ),

            // Score Display
            Positioned(
              top: GameConfig.defaultOverlayPadding,
              right: GameConfig.defaultOverlayPadding,
              child: _ScoreDisplay(
                score: gameStateProvider.score,
                scoreGlitch: gameStateProvider.scoreGlitch,
              ),
            ),

            // Speed Display
            Positioned(
              top: GameConfig.defaultOverlayPadding + GameConfig.defaultOverlaySpacing * 2.2, // Adjusted for spacing
              right: GameConfig.defaultOverlayPadding,
              child: _TextDisplay(
                label: 'SPEED',
                value: '${gameStateProvider.speed.toInt()}',
                color: GameConfig.primaryNeonColor,
              ),
            ),

            // Shield Status
            if (gameStateProvider.hasShield)
              Positioned(
                top: GameConfig.defaultOverlayPadding + GameConfig.defaultOverlaySpacing * 4.4, // Adjusted for spacing
                right: GameConfig.defaultOverlayPadding,
                child: _TextDisplay(
                  label: 'SHIELD',
                  value: 'ACTIVE',
                  color: GameConfig.accentNeonColor,
                ),
              ),
            
            // Multiplier Status
            if (gameStateProvider.multiplier > 1)
              Positioned(
                top: GameConfig.defaultOverlayPadding + GameConfig.defaultOverlaySpacing * 6.6, // Adjusted for spacing
                right: GameConfig.defaultOverlayPadding,
                child: _TextDisplay(
                  label: 'MULTIPLIER',
                  value: 'x${gameStateProvider.multiplier}',
                  color: GameConfig.yellowNeonColor,
                ),
              ),

            // Time Warp Status
            if (gameStateProvider.timeWarpActive)
              Positioned(
                top: GameConfig.defaultOverlayPadding + GameConfig.defaultOverlaySpacing * 8.8, // Adjusted for spacing
                right: GameConfig.defaultOverlayPadding,
                child: _TextDisplay(
                  label: 'TIME WARP',
                  value: '${(gameStateProvider.timeWarpTimer / GameConfig.framesPerSecond).ceil()}s', // Using constant
                  color: GameConfig.purpleNeonColor,
                ),
              ),

            // Magnet Status
            if (gameStateProvider.magnetActive)
              Positioned(
                top: GameConfig.defaultOverlayPadding + GameConfig.defaultOverlaySpacing * 11, // Adjusted for spacing
                right: GameConfig.defaultOverlayPadding,
                child: _TextDisplay(
                  label: 'MAGNET',
                  value: '${(gameStateProvider.magnetTimer / GameConfig.framesPerSecond).ceil()}s', // Using constant
                  color: GameConfig.pinkNeonColor,
                ),
              ),
          ],
        );
      },
    );
  }
}

// Helper widget for displaying animated score
class _ScoreDisplay extends StatelessWidget {
  final int score;
  final bool scoreGlitch;

  const _ScoreDisplay({required this.score, required this.scoreGlitch});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('score_$score'), // Key to trigger animation on score change
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: GameConfig.hudScoreAnimationDurationMs), // Quick animation for score update
      builder: (context, value, child) {
        return Transform.scale(
          scale: 1 + (value * GameConfig.hudScoreScaleAnimation), // Scale up slightly on change
          child: Text(
            'SCORE: $score',
            style: TextStyle(
              fontFamily: 'Share Tech Mono',
              fontSize: GameConfig.hudScoreFontSize,
              color: scoreGlitch ? GameConfig.errorNeonColor : GameConfig.primaryNeonColor,
              shadows: scoreGlitch
                  ? [
                      Shadow(
                        blurRadius: GameConfig.playerTrailBlurRadiusMultiplier, // Reusing blur radius for consistent neon glow
                        color: GameConfig.errorNeonColor.withAlpha((255 * GameConfig.hudScoreShadowAlpha).round()),
                        offset: Offset(0, 0),
                      ),
                    ]
                  : [
                      Shadow(
                        blurRadius: GameConfig.playerTrailBlurRadiusMultiplier, // Reusing blur radius for consistent neon glow
                        color: GameConfig.primaryNeonColor.withAlpha((255 * GameConfig.hudScoreShadowAlpha).round()),
                        offset: Offset(0, 0),
                      ),
                    ],
            ),
          ),
        );
      },
    );
  }
}

// Generic helper for displaying text labels and values
class _TextDisplay extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _TextDisplay({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Share Tech Mono',
            fontSize: GameConfig.hudLabelFontSize,
            color: color.withAlpha((255 * GameConfig.hudLabelAlpha).round()),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Share Tech Mono',
            fontSize: GameConfig.hudValueFontSize,
            color: color,
          ),
        ),
      ],
    );
  }
}