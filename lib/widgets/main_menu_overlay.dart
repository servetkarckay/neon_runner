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
        backgroundColor: Colors.black.withAlpha((255 * 0.8).round()),
        body: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'NEON RUNNER',
                  style: TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00FF41),
                    shadows: const [
                      Shadow(
                        color: Color(0x8000FF41),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'CYBERPUNK PROTOCOL INITIATED',
                  style: TextStyle(
                    fontFamily: 'Share Tech Mono',
                    fontSize: 18,
                    color: Color(0xFF00FF41),
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 50),
                GestureDetector(
                  onTap: () {
                    Provider.of<GameStateProvider>(context, listen: false).startGame();
                  },
                  child: const Text(
                    'PRESS DUCK OR JUMP TO START',
                    style: TextStyle(
                      fontFamily: 'Share Tech Mono',
                      fontSize: 20,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 30), // Added spacing
                MenuButton(
                  text: 'LEADERBOARD',
                  onTap: () {
                    Provider.of<GameStateProvider>(context, listen: false).updateGameState(GameState.leaderboardView);
                  },
                ),
                const SizedBox(height: 20), // Added spacing
                MenuButton(
                  text: 'SETTINGS',
                  onTap: () {
                    Provider.of<GameStateProvider>(context, listen: false).updateGameState(GameState.settings);
                  },
                ),
                const SizedBox(height: 50),
                _buildDesktopControls(),
                const SizedBox(height: 30),
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
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        border: Border.all(color: Color.fromARGB((255 * 0.3).round(), 0, 255, 65), width: 1),
        color: Color.fromARGB((255 * 0.6).round(), 0, 20, 0),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Color.fromARGB((255 * 0.1).round(), 0, 255, 65),
            blurRadius: 15,
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
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        border: Border.all(color: Color.fromARGB((255 * 0.3).round(), 0, 255, 65), width: 1),
        color: Color.fromARGB((255 * 0.6).round(), 0, 20, 0),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Color.fromARGB((255 * 0.1).round(), 0, 255, 65),
            blurRadius: 15,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Color.fromARGB((255 * 0.3).round(), 0, 255, 65), width: 1)),
            ),
            padding: const EdgeInsets.only(bottom: 8.0),
            child: const Text(
              'SYSTEM UPGRADES',
              style: TextStyle(
                fontFamily: 'Share Tech Mono',
                fontWeight: FontWeight.bold,
                color: Color(0xFF00FF41),
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _PowerUpLegendRow(
            key: const Key('protection_powerup'),
            icon: '🛡',
            text: 'PROTECTION',
            color: Color(0xFF00FFFF),
          ),
          _PowerUpLegendRow(
            key: const Key('score_x2_powerup'),
            icon: '⚡',
            text: 'SCORE x2',
            color: Color(0xFFFFFF00),
          ),
          _PowerUpLegendRow(
            key: const Key('slow_time_powerup'),
            icon: '⏩',
            text: 'SLOW TIME',
            color: Color(0xFFAA00FF),
          ),
          _PowerUpLegendRow(
            key: const Key('magnet_powerup'),
            icon: '🧲',
            text: 'MAGNET',
            color: Color(0xFFFF00FF),
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
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: keys
                .map((key) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FF41),
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: Color.fromARGB((255 * 0.5).round(), 0, 255, 65),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: Text(
                          key,
                          style: const TextStyle(
                            fontFamily: 'Share Tech Mono',
                            color: Colors.black,
                            fontSize: 12,
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
              color: Color(0xFF00FF41),
              fontSize: 14,
              letterSpacing: 1,
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
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            icon,
            style: TextStyle(
              fontSize: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'Share Tech Mono',
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
