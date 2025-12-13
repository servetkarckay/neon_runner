import 'package:flutter/material.dart';
import 'package:flutter_neon_runner/game/neon_runner_game.dart';
import 'package:provider/provider.dart';
import 'package:flutter_neon_runner/game_state_provider.dart';
import 'package:flutter_neon_runner/widgets/common/menu_button.dart';
import 'package:flutter_neon_runner/models/game_state.dart';

class MainMenuOverlay extends StatefulWidget {
  final NeonRunnerGame game;

  const MainMenuOverlay({super.key, required this.game});

  @override
  State<MainMenuOverlay> createState() => _MainMenuOverlayState();
}

class _MainMenuOverlayState extends State<MainMenuOverlay> {
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
  void didUpdateWidget(covariant MainMenuOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final gameStateProvider = Provider.of<GameStateProvider>(context, listen: false);
      if (gameStateProvider.currentGameState != GameState.menu && _opacity == 1.0) {
        setState(() {
          _opacity = 0.0;
        });
      } else if (gameStateProvider.currentGameState == GameState.menu && _opacity == 0.0) {
        setState(() {
          _opacity = 1.0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 500),
      onEnd: () {
        if (_opacity == 0.0 &&
            Provider.of<GameStateProvider>(context, listen: false).currentGameState != GameState.menu) {
          // No need to actively remove from tree here, conditional rendering in main.dart handles it
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black.withAlpha((255 * GameConfig.overlayBackgroundAlpha).round()),
        body: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'NEON RUNNER',
                  style: TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: GameConfig.mainMenuTitleFontSize,
                    fontWeight: FontWeight.bold,
                    color: GameConfig.primaryNeonColor,
                    shadows: [
                      Shadow(
                        color: GameConfig.primaryNeonColor.withAlpha((255 * GameConfig.overlayBackgroundAlpha).round()), // Using overlay background alpha for consistent shadow effect
                        blurRadius: GameConfig.mainMenuTitleBlurRadius,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: GameConfig.defaultOverlayPadding), // Using default spacing
                Text(
                  'CYBERPUNK PROTOCOL INITIATED',
                  style: TextStyle(
                    fontFamily: 'Share Tech Mono',
                    fontSize: GameConfig.mainMenuSubtitleFontSize,
                    color: GameConfig.primaryNeonColor,
                    letterSpacing: GameConfig.mainMenuSubtitleLetterSpacing,
                  ),
                ),
                const SizedBox(height: GameConfig.mainMenuSectionSpacing),
                GestureDetector(
                  onTap: () {
                    Provider.of<GameStateProvider>(context, listen: false).startGame();
                  },
                  child: const Text(
                    'PRESS DUCK OR JUMP TO START',
                    style: TextStyle(
                      fontFamily: 'Share Tech Mono',
                      fontSize: GameConfig.mainMenuStartPromptFontSize,
                      color: Colors.white,
                      letterSpacing: GameConfig.mainMenuStartPromptLetterSpacing,
                    ),
                  ),
                ),
                const SizedBox(height: GameConfig.mainMenuButtonSpacing), // Added spacing
                MenuButton(
                  text: 'LEADERBOARD',
                  onTap: () {
                    Provider.of<GameStateProvider>(context, listen: false).updateGameState(GameState.leaderboardView);
                  },
                ),
                const SizedBox(height: GameConfig.mainMenuButtonSpacing), // Added spacing
                MenuButton(
                  text: 'SETTINGS',
                  onTap: () {
                    Provider.of<GameStateProvider>(context, listen: false).updateGameState(GameState.settings);
                  },
                ),
                const SizedBox(height: GameConfig.mainMenuSectionSpacing),
                _buildDesktopControls(),
                const SizedBox(height: GameConfig.mainMenuButtonSpacing),
                _buildSystemUpgradesLegend(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopControls() {
    return Container(
      padding: const EdgeInsets.all(GameConfig.controlRowContainerPadding),
      margin: const EdgeInsets.symmetric(horizontal: GameConfig.controlRowContainerMarginHorizontal),
      decoration: BoxDecoration(
        border: Border.all(color: GameConfig.primaryNeonColor.withAlpha((255 * GameConfig.controlRowContainerBorderWidth).round()), width: GameConfig.controlRowContainerBorderWidth),
        color: GameConfig.darkGreenOverlayColor.withAlpha((255 * GameConfig.controlRowContainerBgAlpha).round()), // Manual ARGB for black-greenish hue
        borderRadius: BorderRadius.circular(GameConfig.controlRowContainerBorderRadius),
        boxShadow: [
          BoxShadow(
            color: GameConfig.primaryNeonColor.withAlpha((255 * GameConfig.controlRowContainerShadowAlpha).round()),
            blurRadius: GameConfig.controlRowContainerShadowBlurRadius,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ControlRow(
            key: const Key('jump_control_row'),
            keys: ['SPACE', '↑'],
            action: 'JUMP',
          ),
          _ControlRow(
            key: const Key('duck_control_row'),
            keys: ['↓'],
            action: 'DUCK / DIVE',
          ),
          _ControlRow(
            key: const Key('pause_control_row'),
            keys: ['P'],
            action: 'PAUSE',
          ),
        ],
      ),
    );
  }

  Widget _buildSystemUpgradesLegend() {
    return Container(
      padding: const EdgeInsets.all(GameConfig.powerUpLegendContainerPadding),
      margin: const EdgeInsets.symmetric(horizontal: GameConfig.powerUpLegendContainerMarginHorizontal),
      decoration: BoxDecoration(
        border: Border.all(color: GameConfig.primaryNeonColor.withAlpha((255 * GameConfig.powerUpLegendContainerBorderWidth).round()), width: GameConfig.powerUpLegendContainerBorderWidth),
        color: GameConfig.darkGreenOverlayColor.withAlpha((255 * GameConfig.powerUpLegendContainerBgAlpha).round()), // Manual ARGB for black-greenish hue
        borderRadius: BorderRadius.circular(GameConfig.powerUpLegendContainerBorderRadius),
        boxShadow: [
          BoxShadow(
            color: GameConfig.primaryNeonColor.withAlpha((255 * GameConfig.powerUpLegendContainerShadowAlpha).round()),
            blurRadius: GameConfig.powerUpLegendContainerShadowBlurRadius,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: GameConfig.primaryNeonColor.withAlpha((255 * GameConfig.powerUpLegendTitleBorderWidth).round()), width: GameConfig.powerUpLegendTitleBorderWidth)),
            ),
            padding: const EdgeInsets.only(bottom: GameConfig.powerUpLegendTitlePaddingBottom),
            child: const Text(
              'SYSTEM UPGRADES',
              style: TextStyle(
                fontFamily: 'Share Tech Mono',
                fontWeight: FontWeight.bold,
                color: GameConfig.primaryNeonColor,
                fontSize: GameConfig.powerUpLegendTitleFontSize,
              ),
            ),
          ),
          const SizedBox(height: GameConfig.defaultOverlayPadding),
          _PowerUpLegendRow(
            key: const Key('protection_powerup'),
            icon: '🛡',
            text: 'PROTECTION',
            color: GameConfig.accentNeonColor,
          ),
          _PowerUpLegendRow(
            key: const Key('score_x2_powerup'),
            icon: '⚡',
            text: 'SCORE x2',
            color: GameConfig.yellowNeonColor,
          ),
          _PowerUpLegendRow(
            key: const Key('slow_time_powerup'),
            icon: '⏩',
            text: 'SLOW TIME',
            color: GameConfig.purpleNeonColor,
          ),
          _PowerUpLegendRow(
            key: const Key('magnet_powerup'),
            icon: '🧲',
            text: 'MAGNET',
            color: GameConfig.pinkNeonColor,
          ),
        ],
      ),
    );
  }
}

class _ControlRow extends StatelessWidget {
  final List<String> keys;
  final String action;

  const _ControlRow({super.key, required this.keys, required this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: GameConfig.controlRowVerticalPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: keys
                .map((key) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: GameConfig.controlRowKeyPaddingHorizontal / 3), // Reduced padding
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: GameConfig.controlRowKeyPaddingHorizontal, vertical: GameConfig.controlRowKeyPaddingVertical),
                        decoration: BoxDecoration(
                          color: GameConfig.primaryNeonColor,
                          borderRadius: BorderRadius.circular(GameConfig.controlRowKeyBorderRadius),
                          boxShadow: [
                            BoxShadow(
                              color: GameConfig.primaryNeonColor.withAlpha((255 * GameConfig.controlRowKeyShadowAlpha).round()),
                              blurRadius: GameConfig.controlRowKeyShadowBlurRadius,
                            ),
                          ],
                        ),
                        child: Text(
                          key,
                          style: const TextStyle(
                            fontFamily: 'Share Tech Mono',
                            color: Colors.black,
                            fontSize: GameConfig.controlRowKeyFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          Text(
            action,
            style: const TextStyle(
              fontFamily: 'Share Tech Mono',
              color: GameConfig.primaryNeonColor,
              fontSize: GameConfig.controlRowActionFontSize,
              letterSpacing: GameConfig.controlRowActionLetterSpacing,
            ),
          ),
        ],
      ),
    );
  }
}

class _PowerUpLegendRow extends StatelessWidget {
  final String icon;
  final String text;
  final Color color;

  const _PowerUpLegendRow({super.key, 
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: GameConfig.controlRowVerticalPadding), // Reusing vertical padding
      child: Row(
        children: [
          Text(
            icon,
            style: TextStyle(
              fontSize: GameConfig.powerUpLegendIconFontSize,
              color: color,
            ),
          ),
          const SizedBox(width: GameConfig.powerUpLegendTextSpacing),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'Share Tech Mono',
              color: Colors.white, // Consider making a constant for general text color
              fontSize: GameConfig.powerUpLegendTextFontSize,
            ),
          ),
        ],
      ),
    );
  }
}
