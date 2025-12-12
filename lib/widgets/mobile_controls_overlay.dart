import 'package:flutter/material.dart';
import 'package:flutter_neon_runner/game/neon_runner_game.dart';
import 'package:flutter_neon_runner/models/game_state.dart';
import 'package:provider/provider.dart';
import 'package:flutter_neon_runner/game_state_provider.dart';

class MobileControlsOverlay extends StatefulWidget {
  final NeonRunnerGame game;

  const MobileControlsOverlay({super.key, required this.game});

  @override
  State<MobileControlsOverlay> createState() => _MobileControlsOverlayState();
}

class _MobileControlsOverlayState extends State<MobileControlsOverlay> {
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
  void didUpdateWidget(covariant MobileControlsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final gameStateProvider = Provider.of<GameStateProvider>(context, listen: false);
      if (gameStateProvider.currentGameState != GameState.playing && _opacity == 1.0) {
        setState(() {
          _opacity = 0.0;
        });
      } else if (gameStateProvider.currentGameState == GameState.playing && _opacity == 0.0) {
        setState(() {
          _opacity = 1.0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final gameStateProvider = Provider.of<GameStateProvider>(context);

    // Only show mobile controls when the game is playing
    if (gameStateProvider.currentGameState != GameState.playing) {
      return const SizedBox.shrink();
    }

    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 500),
      child: Positioned.fill(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Adjust button size based on screen width
            final buttonSize = constraints.maxWidth * 0.15; // 15% of screen width

            return Stack(
              children: [
                Positioned(
                  left: constraints.maxWidth * 0.05, // 5% from left
                  bottom: constraints.maxHeight * 0.1, // 10% from bottom
                  child: _MobileButton(
                    size: buttonSize,
                    label: 'DUCK',
                    onTapDown: () {
                      if (!widget.game.inputLock) {
                        widget.game.playerData.isDucking = true;
                        if (!widget.game.playerData.isJumping) widget.game.audioController.playDuck();
                      }
                    },
                    onTapUp: () {
                      widget.game.playerData.isDucking = false;
                    },
                  ),
                ),
                Positioned(
                  right: constraints.maxWidth * 0.05, // 5% from right
                  bottom: constraints.maxHeight * 0.1, // 10% from bottom
                  child: _MobileButton(
                    size: buttonSize,
                    label: 'JUMP',
                    onTapDown: () {
                      if (widget.game.gameState == GameState.menu || widget.game.gameState == GameState.gameOver) {
                        gameStateProvider.startGame();
                        return;
                      }
                      if (widget.game.gameState == GameState.playing) {
                        if (!widget.game.inputLock) {
                          widget.game.playerData.isHoldingJump = true;
                          widget.game.playerData.jumpBufferTimer = 8;
                          if (!widget.game.playerData.isJumping) {
                            widget.game.performJump();
                          }
                        }
                      }
                    },
                    onTapUp: () {
                      widget.game.playerData.isHoldingJump = false;
                    },
                  ),
                ),
                // Pause button
                Positioned(
                  top: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: () {
                      gameStateProvider.pauseGame();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha((255 * 0.6).round()),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: const Color(0xFF00FF41), width: 1),
                      ),
                      child: const Icon(
                        Icons.pause,
                        color: Color(0xFF00FF41),
                      ),
                    ),
                  ),
                )
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MobileButton extends StatelessWidget {
  final double size;
  final String label;
  final VoidCallback onTapDown;
  final VoidCallback onTapUp;

  const _MobileButton({
    required this.size,
    required this.label,
    required this.onTapDown,
    required this.onTapUp,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onTapDown(),
      onTapUp: (_) => onTapUp(),
      onTapCancel: () => onTapUp(), // Handle tap cancel as tap up
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.black.withAlpha((255 * 0.5).round()),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF00FF41), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Color.fromARGB((255 * 0.2).round(), 0, 255, 65), // Not const
                          blurRadius: 15,
                        ),
                      ],        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Share Tech Mono',
              color: Color(0xFF00FF41),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}