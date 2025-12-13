import 'package:flutter/material.dart';
import 'package:flutter_neon_runner/game/neon_runner_game.dart';
import 'package:provider/provider.dart';
import 'package:flutter_neon_runner/game_state_provider.dart';
import 'package:flutter_neon_runner/models/game_state.dart';
import 'package:flutter_neon_runner/widgets/common/menu_button.dart';

class SettingsOverlay extends StatefulWidget {
  final NeonRunnerGame game;

  const SettingsOverlay({super.key, required this.game});

  @override
  State<SettingsOverlay> createState() => _SettingsOverlayState();
}

class _SettingsOverlayState extends State<SettingsOverlay> {
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
  void didUpdateWidget(covariant SettingsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final gameStateProvider = Provider.of<GameStateProvider>(context, listen: false);
      if (gameStateProvider.currentGameState != GameState.settings && _opacity == 1.0) {
        setState(() {
          _opacity = 0.0;
        });
      } else if (gameStateProvider.currentGameState == GameState.settings && _opacity == 0.0) {
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
                'SETTINGS',
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: GameConfig.mainMenuTitleFontSize, // Reusing main menu title size
                  fontWeight: FontWeight.bold,
                  color: GameConfig.primaryNeonColor,
                  shadows: [
                    Shadow(
                      color: GameConfig.primaryNeonColor.withAlpha((255 * GameConfig.overlayBackgroundAlpha).round()),
                      blurRadius: GameConfig.mainMenuTitleBlurRadius, // Reusing main menu title blur
                    ),
                  ],
                ),
              ),
              const SizedBox(height: GameConfig.mainMenuSectionSpacing), // Reusing section spacing
              _SettingItem(
                label: 'SOUND',
                valueWidget: Switch(
                  value: !gameStateProvider.gameInstance.audioController.isMuted,
                  onChanged: (bool value) {
                    gameStateProvider.gameInstance.toggleMute();
                  },
                  activeThumbColor: GameConfig.primaryNeonColor,
                  inactiveThumbColor: Colors.grey, // Consider making a constant
                  inactiveTrackColor: Colors.grey.withAlpha(128), // Consider making a constant
                ),
              ),
              const SizedBox(height: GameConfig.defaultOverlaySpacing), // Reusing default spacing
              MenuButton(
                text: 'BACK TO MAIN MENU',
                onTap: () {
                  gameStateProvider.updateGameState(GameState.menu);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingItem extends StatelessWidget {
  final String label;
  final Widget valueWidget;

  const _SettingItem({
    required this.label,
    required this.valueWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: GameConfig.pauseMenuActionButtonPaddingHorizontal, vertical: GameConfig.defaultOverlayPadding), // Reusing padding constants
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Share Tech Mono',
              fontSize: GameConfig.pauseMenuActionButtonFontSize, // Reusing font size
              color: Colors.white, // Consider making a constant
            ),
          ),
          valueWidget,
        ],
      ),
    );
  }
}

// Reusing _MenuButton from main_menu_overlay.dart (or create a common widgets file)

