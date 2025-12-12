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
      duration: const Duration(milliseconds: 500),
      child: Scaffold(
      backgroundColor: Colors.black.withAlpha((255 * 0.8).round()),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'SYSTEM PAUSED',
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00FF41),
                shadows: [
                  Shadow(
                    color: Color(0x8000FF41), // Direct ARGB value
                    blurRadius: 20,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            _buildActionButton(
              text: 'RESUME',
              color: const Color(0xFF00FF41),
              onPressed: () {
                gameStateProvider.resumeGame();
              },
            ),
            const SizedBox(height: 20),
            _buildActionButton(
              text: 'LEADERBOARD',
              color: Colors.white,
              onPressed: () {
                gameStateProvider.showLeaderboard();
              },
            ),
            const SizedBox(height: 20),
            MenuButton(
              text: 'SETTINGS',
              onTap: () {
                gameStateProvider.updateGameState(GameState.settings);
              },
            ),
            const SizedBox(height: 20),
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
        side: BorderSide(color: color, width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        shadowColor: color.withAlpha((255 * 0.5).round()),
        elevation: 10,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Share Tech Mono',
          fontSize: 20,
          letterSpacing: 2,
        ),
      ),
    );
  }
}