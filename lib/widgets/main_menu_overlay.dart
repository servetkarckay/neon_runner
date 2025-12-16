import 'package:flutter/material.dart';
import 'package:flutter_neon_runner/game/neon_runner_game.dart';
import 'package:provider/provider.dart';
import 'package:flutter_neon_runner/game_state_provider.dart';
import 'package:flutter_neon_runner/widgets/common/menu_button.dart';
import 'package:flutter_neon_runner/models/game_state.dart';
import 'package:flutter_neon_runner/config/game_config.dart';

class MainMenuOverlay extends StatefulWidget {
  final NeonRunnerGame game;

  const MainMenuOverlay({super.key, required this.game});

  @override
  State<MainMenuOverlay> createState() => _MainMenuOverlayState();
}

class _MainMenuOverlayState extends State<MainMenuOverlay>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _glowAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));
    _glowController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameStateProvider = Provider.of<GameStateProvider>(context);
    final isMenu = gameStateProvider.currentGameState == GameState.menu;

    return AnimatedOpacity(
      opacity: isMenu ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black,
                Colors.black.withRed(10),
                Colors.black.withBlue(10),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  _buildTitle(),
                  const SizedBox(height: 40),
                  _buildStartButton(),
                  const SizedBox(height: 32),
                  _buildMenuButtons(),
                  const Spacer(flex: 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Column(
          children: [
            Text(
              'NEON RUNNER',
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: GameConfig.primaryNeonColor.withValues(alpha: _glowAnimation.value),
                    blurRadius: 20,
                  ),
                  Shadow(
                    color: GameConfig.primaryNeonColor.withValues(alpha: _glowAnimation.value * 0.5),
                    blurRadius: 40,
                  ),
                ],
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: GameConfig.primaryNeonColor.withValues(alpha: 0.5),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'TOUCH TO PLAY',
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 14,
                  color: GameConfig.primaryNeonColor,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStartButton() {
    return Container(
      width: double.infinity,
      height: 80,
      child: ElevatedButton(
        onPressed: () {
          Provider.of<GameStateProvider>(context, listen: false).startGame();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: GameConfig.primaryNeonColor,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          shadowColor: GameConfig.primaryNeonColor,
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.pressed)) {
                return Colors.white.withValues(alpha: 0.2);
              }
              return null;
            },
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_arrow_rounded,
              size: 32,
              color: Colors.black,
            ),
            const SizedBox(width: 12),
            Text(
              'START',
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButtons() {
    return Column(
      children: [
        _buildMenuButton(
          text: 'LEADERBOARD',
          icon: Icons.leaderboard_rounded,
          onTap: () {
            Provider.of<GameStateProvider>(context, listen: false)
                .updateGameState(GameState.leaderboardView);
          },
        ),
        const SizedBox(height: 16),
        _buildMenuButton(
          text: 'SOUND',
          icon: Icons.volume_up_rounded,
          onTap: () {
            // Toggle sound
          },
        ),
      ],
    );
  }

  Widget _buildMenuButton({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: GameConfig.primaryNeonColor,
          side: BorderSide(
            color: GameConfig.primaryNeonColor.withValues(alpha: 0.6),
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.pressed)) {
                return GameConfig.primaryNeonColor.withValues(alpha: 0.1);
              }
              return null;
            },
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: GameConfig.primaryNeonColor,
            ),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: GameConfig.primaryNeonColor,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
