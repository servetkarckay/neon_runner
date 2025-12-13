import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_neon_runner/game/neon_runner_game.dart';
import 'package:flutter_neon_runner/game_state_provider.dart';
import 'package:flutter_neon_runner/widgets/common/menu_button.dart';
import 'package:flutter_neon_runner/models/game_state.dart';

class LeaderboardOverlay extends StatefulWidget {
  final NeonRunnerGame game;

  const LeaderboardOverlay({super.key, required this.game});

  @override
  State<LeaderboardOverlay> createState() => _LeaderboardOverlayState();
}

class _LeaderboardOverlayState extends State<LeaderboardOverlay> {
  List<Map<String, dynamic>> _leaderboardEntries = [];
  bool _isLoading = true;
  double _opacity = 0.0; // For fade transition

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _opacity = 1.0; // Start fade-in
      });
    });
    _loadLeaderboard();
  }

  @override
  void didUpdateWidget(covariant LeaderboardOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final gameStateProvider = Provider.of<GameStateProvider>(context, listen: false);
      if (gameStateProvider.currentGameState != GameState.leaderboardView && _opacity == 1.0) {
        setState(() {
          _opacity = 0.0; // Start fade-out
        });
      } else if (gameStateProvider.currentGameState == GameState.leaderboardView && _opacity == 0.0) {
        setState(() {
          _opacity = 1.0; // Start fade-in
        });
      }
    });
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _isLoading = true;
    });

    final gameStateProvider = Provider.of<GameStateProvider>(context, listen: false);
    final leaderboardService = gameStateProvider.leaderboardService;
    final String playerId = gameStateProvider.gameInstance.userId ?? ''; // Get current player ID. If null, a new one will be generated on game over.

    List<Map<String, dynamic>> fetchedScores = await leaderboardService.loadTopScores(5); // Load top 5 scores

    // Prepare leaderboard entries
    List<Map<String, dynamic>> newLeaderboardEntries = [];
    int rankCounter = 1;
    for (var entry in fetchedScores) {
      newLeaderboardEntries.add({
        'rank': rankCounter++,
        'name': entry['name'],
        'score': entry['score'],
        'isUser': entry['playerId'] == playerId,
      });
    }

    // Check if the current player is in the fetched top scores
    bool playerInTopScores = newLeaderboardEntries.any((entry) => entry['isUser'] == true);

    if (!playerInTopScores && playerId.isNotEmpty) {
      // If player is not in top scores, try to get their specific rank
      final int? playerRank = await leaderboardService.getRank(playerId, 'ANONYMOUS'); // 'ANONYMOUS' is placeholder name
      if (playerRank != null) {
        // Add player's own score as a separate entry if not in top 5
        newLeaderboardEntries.add({
          'rank': playerRank,
          'name': 'YOU', // Or actual name if stored
          'score': gameStateProvider.gameInstance.highscore, // Current highscore for "YOU"
          'isUser': true,
        });
        // Sort to ensure correct rank ordering after adding player's entry
        newLeaderboardEntries.sort((a, b) => (a['rank'] as int).compareTo(b['rank'] as int));
      }
    }

    setState(() {
      _leaderboardEntries = newLeaderboardEntries;
      _isLoading = false;
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
        child: Container(
          width: GameConfig.leaderboardContainerWidth,
          padding: const EdgeInsets.all(GameConfig.leaderboardContainerPadding),
          decoration: BoxDecoration(
            border: Border.all(color: GameConfig.primaryNeonColor, width: GameConfig.leaderboardContainerBorderWidth),
            color: GameConfig.darkGreenOverlayColor.withAlpha((255 * 0.9).round()), // Manual ARGB for black-greenish hue, slightly less transparent
            boxShadow: [
              BoxShadow(
                color: GameConfig.primaryNeonColor.withAlpha((255 * GameConfig.leaderboardContainerShadowAlpha).round()),
                blurRadius: GameConfig.leaderboardContainerShadowBlurRadius,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                          Text(
                            'LEADERBOARD',
                            style: TextStyle(
                              fontFamily: 'Orbitron',
                              fontSize: GameConfig.leaderboardTitleFontSize,
                              fontWeight: FontWeight.bold,
                              color: GameConfig.primaryNeonColor,
                              shadows: [
                                Shadow(
                                  color: GameConfig.primaryNeonColor.withAlpha((255 * GameConfig.overlayBackgroundAlpha).round()), // Consistent shadow alpha
                                  blurRadius: GameConfig.leaderboardTitleBlurRadius,
                                ),
                              ],
                            ),
                          ),              const SizedBox(height: GameConfig.defaultOverlaySpacing),
              _isLoading
                  ? CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(GameConfig.primaryNeonColor),
                    )
                  : Column(
                      children: [
                        for (var entry in _leaderboardEntries)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: GameConfig.leaderboardEntryVerticalPadding),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${entry['rank']}.',
                                  style: TextStyle(
                                    fontFamily: 'Share Tech Mono',
                                    fontSize: GameConfig.leaderboardEntryFontSize,
                                    color: entry['isUser'] == true
                                        ? GameConfig.yellowNeonColor
                                        : Colors.white,
                                  ),
                                ),
                                Text(
                                  entry['name'].toString(),
                                  style: TextStyle(
                                    fontFamily: 'Share Tech Mono',
                                    fontSize: GameConfig.leaderboardEntryFontSize,
                                    color: entry['isUser'] == true
                                        ? GameConfig.yellowNeonColor
                                        : Colors.white,
                                    fontWeight: entry['isUser'] == true
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                Text(
                                  entry['score'].toString(),
                                  style: TextStyle(
                                    fontFamily: 'Share Tech Mono',
                                    fontSize: GameConfig.leaderboardEntryFontSize,
                                    color: entry['isUser'] == true
                                        ? GameConfig.yellowNeonColor
                                        : Colors.white,
                                    fontWeight: entry['isUser'] == true
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
              const SizedBox(height: GameConfig.leaderboardButtonSpacing),
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
    ));
  }
}
