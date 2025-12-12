import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flutter_neon_runner/game/neon_runner_game.dart';
import 'package:provider/provider.dart';
import 'package:flutter_neon_runner/game_state_provider.dart';
import 'package:flutter_neon_runner/models/game_state.dart';
import 'package:flutter_neon_runner/widgets/game_overlay.dart';
import 'package:flutter_neon_runner/widgets/main_menu_overlay.dart';
import 'package:flutter_neon_runner/widgets/pause_menu_overlay.dart';
import 'package:flutter_neon_runner/widgets/game_over_overlay.dart';
import 'package:flutter_neon_runner/widgets/leaderboard_overlay.dart';
import 'package:flutter_neon_runner/widgets/mobile_controls_overlay.dart'; // Import MobileControlsOverlay
import 'package:flutter_neon_runner/widgets/vignette_effect.dart'; // Import VignetteEffect
import 'package:flutter_neon_runner/widgets/settings_overlay.dart'; // Import SettingsOverlay


void main() {
  runApp(const MyGameApp());
}

class MyGameApp extends StatefulWidget {
  const MyGameApp({super.key});

  @override
  State<MyGameApp> createState() => _MyGameAppState();
}

class _MyGameAppState extends State<MyGameApp> {
  late final NeonRunnerGame _game;
  late final GameStateProvider _gameStateProvider;

  @override
  void initState() {
    super.initState();
    _gameStateProvider = GameStateProvider(); // Initialize provider first
    _game = NeonRunnerGame(_gameStateProvider); // Pass provider to game
    _gameStateProvider.setGame(_game); // Set game in provider
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GameStateProvider>.value(
      value: _gameStateProvider,
      child: MaterialApp(
        title: 'Neon Runner',
        theme: ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.cyan,
          fontFamily: 'Share Tech Mono',
          scaffoldBackgroundColor: Colors.black,
          textTheme: Theme.of(context).textTheme.apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
          ),
        ),
        home: Consumer<GameStateProvider>(
          builder: (context, gameStateProvider, child) {
            final game = gameStateProvider.gameInstance; // Access game from provider
            return Scaffold(
              body: Stack(
                children: [
                  GameWidget(game: game),
                  if (gameStateProvider.currentGameState == GameState.menu)
                    MainMenuOverlay(game: game),
                  if (gameStateProvider.currentGameState == GameState.paused)
                    PauseMenuOverlay(game: game),
                  if (gameStateProvider.currentGameState == GameState.gameOver)
                    GameOverOverlay(game: game),
                  if (gameStateProvider.currentGameState == GameState.leaderboardView)
                    LeaderboardOverlay(game: game),
                  if (gameStateProvider.currentGameState == GameState.settings)
                    SettingsOverlay(game: game),
                  GameOverlay(game: game), // For HUD and other always-on elements
                  const VignetteEffect(), // Add Vignette Effect
                  MobileControlsOverlay(game: game), // Add Mobile Controls Overlay
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}