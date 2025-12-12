import 'package:flutter/material.dart';
import 'package:flutter_neon_runner/game/neon_runner_game.dart';
import 'package:provider/provider.dart';
import 'package:flutter_neon_runner/game_state_provider.dart';
import 'package:flutter_neon_runner/models/game_state.dart';

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
              top: 16,
              left: 16,
              child: GestureDetector(
                onTap: () {
                  gameStateProvider.gameInstance.toggleMute();
                  // No need for setState here, Provider will rebuild
                },
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha((255 * 0.6).round()),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: Colors.cyan, width: 1),
                  ),
                  child: Icon(
                    gameStateProvider.gameInstance.audioController.isMuted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.cyan,
                  ),
                ),
              ),
            ),

            // Score Display
            Positioned(
              top: 16,
              right: 16,
              child: _ScoreDisplay(
                score: gameStateProvider.score,
                scoreGlitch: gameStateProvider.scoreGlitch,
              ),
            ),

            // Speed Display
            Positioned(
              top: 60,
              right: 16,
              child: _TextDisplay(
                label: 'SPEED',
                value: '${gameStateProvider.speed.toInt()}',
                color: Color(0xFF00FF41),
              ),
            ),

            // Shield Status
            if (gameStateProvider.hasShield)
              Positioned(
                top: 104,
                right: 16,
                child: _TextDisplay(
                  label: 'SHIELD',
                  value: 'ACTIVE',
                  color: Color(0xFF00FFFF),
                ),
              ),
            
            // Multiplier Status
            if (gameStateProvider.multiplier > 1)
              Positioned(
                top: 148,
                right: 16,
                child: _TextDisplay(
                  label: 'MULTIPLIER',
                  value: 'x${gameStateProvider.multiplier}',
                  color: Color(0xFFFFFF00),
                ),
              ),

            // Time Warp Status
            if (gameStateProvider.timeWarpActive)
              Positioned(
                top: 192,
                right: 16,
                child: _TextDisplay(
                  label: 'TIME WARP',
                  value: '${(gameStateProvider.timeWarpTimer / 60).ceil()}s',
                  color: Color(0xFFAA00FF),
                ),
              ),

            // Magnet Status
            if (gameStateProvider.magnetActive)
              Positioned(
                top: 236,
                right: 16,
                child: _TextDisplay(
                  label: 'MAGNET',
                  value: '${(gameStateProvider.magnetTimer / 60).ceil()}s',
                  color: Color(0xFFFF00FF),
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
      duration: const Duration(milliseconds: 200), // Quick animation for score update
      builder: (context, value, child) {
        return Transform.scale(
          scale: 1 + (value * 0.1), // Scale up slightly on change
          child: Text(
            'SCORE: $score',
            style: TextStyle(
              fontFamily: 'Share Tech Mono',
              fontSize: 24,
              color: scoreGlitch ? Colors.red : Color(0xFF00FF41),
              shadows: scoreGlitch
                  ? [
                      Shadow(
                        blurRadius: 5.0,
                        color: Colors.red.withAlpha((255 * 0.8).round()),
                        offset: Offset(0, 0),
                      ),
                    ]
                  : [
                      Shadow(
                        blurRadius: 5.0,
                        color: const Color(0xFF00FF41).withAlpha((255 * 0.8).round()),
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
            fontSize: 12,
            color: color.withAlpha((255 * 0.7).round()),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Share Tech Mono',
            fontSize: 18,
            color: color,
          ),
        ),
      ],
    );
  }
}