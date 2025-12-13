import 'package:flutter/material.dart';
import 'package:flutter_neon_runner/game/neon_runner_game.dart';
import 'package:flutter_neon_runner/models/game_state.dart';
import 'package:provider/provider.dart';
import 'package:flutter_neon_runner/game_state_provider.dart';
import 'package:flutter_neon_runner/config/game_config.dart';

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
      duration: const Duration(milliseconds: 500), // Consider making a constant
      child: Positioned.fill(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Adjust button size based on screen width
            final buttonSize = constraints.maxWidth * GameConfig.mobileControlDuckJumpButtonSizeRatio;

            return Stack(
              children: [
                Positioned(
                  left: constraints.maxWidth * GameConfig.mobileControlButtonHorizontalMarginRatio,
                  bottom: constraints.maxHeight * GameConfig.mobileControlButtonBottomMarginRatio,
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
                  right: constraints.maxWidth * GameConfig.mobileControlButtonHorizontalMarginRatio,
                  bottom: constraints.maxHeight * GameConfig.mobileControlButtonBottomMarginRatio,
                  child: _MobileButton(
                    size: buttonSize,
                    label: 'JUMP',
                    onTapDown: () {
                      if (gameStateProvider.currentGameState == GameState.menu || gameStateProvider.currentGameState == GameState.gameOver) {
                        gameStateProvider.startGame();
                        return;
                      }
                      if (gameStateProvider.currentGameState == GameState.playing) {
                        if (!widget.game.inputLock) {
                          widget.game.playerData.isHoldingJump = true;
                          widget.game.playerData.jumpBufferTimer = GameConfig.jumpBufferDuration;
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
                  top: GameConfig.defaultOverlayPadding,
                  right: GameConfig.defaultOverlayPadding,
                  child: GestureDetector(
                    onTap: () {
                      gameStateProvider.pauseGame();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(GameConfig.mobileControlPauseButtonPadding),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha((255 * GameConfig.mobileControlPauseButtonBgAlpha).round()),
                        borderRadius: BorderRadius.circular(GameConfig.mobileControlPauseButtonBorderRadius),
                        border: Border.all(color: GameConfig.primaryNeonColor, width: GameConfig.mobileControlPauseButtonBorderWidth),
                      ),
                      child: const Icon(
                        Icons.pause,
                        color: GameConfig.primaryNeonColor,
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
          color: Colors.black.withAlpha((255 * GameConfig.mobileControlButtonBgAlpha).round()),
          shape: BoxShape.circle,
          border: Border.all(color: GameConfig.primaryNeonColor, width: GameConfig.mobileControlButtonBorderWidth),
                      boxShadow: [
                        BoxShadow(
                          color: GameConfig.primaryNeonColor.withAlpha((255 * GameConfig.mobileControlButtonShadowAlpha).round()),
                          blurRadius: GameConfig.mobileControlButtonShadowBlurRadius,
                        ),
                      ],        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Share Tech Mono',
              color: GameConfig.primaryNeonColor,
              fontSize: GameConfig.mobileControlButtonFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}