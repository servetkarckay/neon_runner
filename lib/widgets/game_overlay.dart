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
  @override
  Widget build(BuildContext context) {
    return Consumer<GameStateProvider>(
      builder: (context, gameStateProvider, child) {
        if (gameStateProvider.currentGameState != GameState.playing) {
          return const SizedBox.shrink(); // Hide HUD when not playing
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Stack(
              children: [
                // Pause Button (Top Left)
                Positioned(
                  top: 0,
                  left: 0,
                  child: _buildPauseButton(gameStateProvider),
                ),

                // Score Display (Top Right)
                Positioned(
                  top: 0,
                  right: 0,
                  child: _buildScoreDisplay(gameStateProvider),
                ),

                // Power-ups Display (Bottom Left)
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: _buildPowerUpsDisplay(gameStateProvider),
                ),

                // Mobile Controls (Bottom Right - only visible on touch devices)
                if (GameConfig.isMobile)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: _buildMobileControls(gameStateProvider),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPauseButton(GameStateProvider gameStateProvider) {
    return GestureDetector(
      onTap: () {
        gameStateProvider.pauseGame();
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          border: Border.all(
            color: GameConfig.primaryNeonColor.withValues(alpha: 0.5),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Icon(
          Icons.pause_rounded,
          size: 28,
          color: GameConfig.primaryNeonColor,
        ),
      ),
    );
  }

  Widget _buildScoreDisplay(GameStateProvider gameStateProvider) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('score_${gameStateProvider.score.value}'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 1 + (value * 0.1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              border: Border.all(
                color: GameConfig.primaryNeonColor.withValues(alpha: 0.5),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              gameStateProvider.score.value.toString(),
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: GameConfig.primaryNeonColor.withValues(alpha: 0.8),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPowerUpsDisplay(GameStateProvider gameStateProvider) {
    final powerUps = <Widget>[];

    // Shield
    if (gameStateProvider.hasShield.value) {
      powerUps.add(_buildPowerUpIcon(
        icon: Icons.shield_rounded,
        color: GameConfig.accentNeonColor,
      ));
    }

    // Multiplier
    if (gameStateProvider.multiplier.value > 1) {
      powerUps.add(_buildPowerUpIcon(
        icon: Icons.star_rounded,
        color: GameConfig.yellowNeonColor,
        label: 'x${gameStateProvider.multiplier.value}',
      ));
    }

    // Time Warp
    if (gameStateProvider.timeWarpTimer.value > 0) {
      final seconds = (gameStateProvider.timeWarpTimer.value / 60).ceil();
      powerUps.add(_buildPowerUpIcon(
        icon: Icons.speed_rounded,
        color: GameConfig.purpleNeonColor,
        label: '${seconds}s',
      ));
    }

    // Magnet
    if (gameStateProvider.magnetTimer.value > 0) {
      final seconds = (gameStateProvider.magnetTimer.value / 60).ceil();
      powerUps.add(_buildPowerUpIcon(
        icon: Icons.flash_on,
        color: GameConfig.pinkNeonColor,
        label: '${seconds}s',
      ));
    }

    if (powerUps.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        border: Border.all(
          color: GameConfig.primaryNeonColor.withValues(alpha: 0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: powerUps,
      ),
    );
  }

  Widget _buildPowerUpIcon({
    required IconData icon,
    required Color color,
    String? label,
  }) {
    return Container(
      width: 48,
      height: 48,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        border: Border.all(
          color: color.withValues(alpha: 0.6),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(
              icon,
              size: 24,
              color: color,
            ),
          ),
          if (label != null)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileControls(GameStateProvider gameStateProvider) {
    return Container(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sound Toggle
          GestureDetector(
            onTap: () {
              gameStateProvider.gameInstance.toggleMute();
            },
            child: Container(
              width: 50,
              height: 50,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                border: Border.all(
                  color: GameConfig.accentNeonColor.withValues(alpha: 0.5),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(
                gameStateProvider.gameInstance.audioController.isMuted
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                size: 24,
                color: GameConfig.accentNeonColor,
              ),
            ),
          ),
        ],
      ),
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