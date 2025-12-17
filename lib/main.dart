import 'package:flutter/foundation.dart';
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
import 'package:flutter/services.dart'; // Added this import
import 'package:logging/logging.dart';

void main() {
  // Configure logging
  Logger.root.level = kDebugMode ? Level.ALL : Level.WARNING;
  Logger.root.onRecord.listen((record) {
    if (kDebugMode) {
      // In debug mode, print with more detailed formatting
      // ignore: avoid_print - This is the logging framework output handler
      print('${record.level.name}: ${record.time}: ${record.loggerName}: ${record.message}');
      if (record.error != null) {
        // ignore: avoid_print - This is the logging framework output handler
        print('  Error: ${record.error}');
      }
      if (record.stackTrace != null) {
        // ignore: avoid_print - This is the logging framework output handler
        print('  Stack trace: ${record.stackTrace}');
      }
    } else {
      // In release mode, only log warnings and errors
      if (record.level.value >= Level.WARNING.value) {
        // ignore: avoid_print - This is the logging framework output handler
        print('${record.level.name}: ${record.loggerName}: ${record.message}');
      }
    }
  });

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
  late final FocusNode _gameFocusNode; // Declare FocusNode

  @override
  void initState() {
    super.initState();
    _gameFocusNode = FocusNode(); // Initialize FocusNode
    _gameStateProvider = GameStateProvider(); // Initialize provider first
    _game = NeonRunnerGame(_gameStateProvider); // Pass provider to game
    _gameStateProvider.setGame(_game); // Set game in provider

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_gameFocusNode.canRequestFocus) {
        FocusScope.of(context).requestFocus(_gameFocusNode);
      }
    });
  }

  @override
  void dispose() {
    _gameFocusNode.dispose(); // Dispose of FocusNode
    super.dispose();
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
            final game =
                gameStateProvider.gameInstance; // Access game from provider
            return Scaffold(
              body: Focus(
                // Wrap with Focus widget
                focusNode: _gameFocusNode, // Assign the new FocusNode
                autofocus: false, // Set autofocus to false as per instructions
                onKeyEvent: (FocusNode node, KeyEvent event) {
                  // Use onKeyEvent and KeyEvent
                  if (event is KeyDownEvent) {
                    // Only handle KeyDown events for game logic
                    return game.onKeyEvent(event, {
                      event.logicalKey,
                    }); // Pass key events to the game, creating a Set
                  }
                  return KeyEventResult.ignored; // Ignore other key events
                },
                child: Builder(
                  builder: (BuildContext focusContext) {
                    return Stack(
                      children: [
                        GameWidget(
                          game: game,
                          autofocus: true,
                        ), // Add autofocus to GameWidget
                        if (gameStateProvider.currentGameState ==
                            GameState.menu)
                          MainMenuOverlay(game: game),
                        if (gameStateProvider.currentGameState ==
                            GameState.paused)
                          PauseMenuOverlay(game: game),
                        if (gameStateProvider.currentGameState ==
                            GameState.gameOver)
                          GameOverOverlay(game: game),
                        if (gameStateProvider.currentGameState ==
                            GameState.leaderboardView)
                          LeaderboardOverlay(game: game),
                        if (gameStateProvider.currentGameState ==
                            GameState.settings)
                          SettingsOverlay(game: game),
                        GameOverlay(
                          game: game,
                        ), // For HUD and other always-on elements
                        const VignetteEffect(), // Add Vignette Effect
                        MobileControlsOverlay(
                          game: game,
                        ), // Add Mobile Controls Overlay
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
