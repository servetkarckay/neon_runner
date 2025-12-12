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
      duration: const Duration(milliseconds: 500),
      child: Scaffold(
      backgroundColor: Colors.black.withAlpha((255 * 0.8).round()),
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF00FF41), width: 2),
            color: Color.fromARGB(229, 0, 20, 0), // Not const
            boxShadow: [
              BoxShadow(
                color: Color.fromARGB((255 * 0.3).round(), 0, 255, 65),
                blurRadius: 30,
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
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00FF41),
                  shadows: [
                  Shadow(
                    color: Color(0x8000FF41),
                    blurRadius: 10,
                  ),
                ],
              ),
            ), // Missing closing parenthesis for the Text widget.
              const SizedBox(height: 20),
              _isLoading
                  ? CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00FF41)),
                    )
                  : Column(
                      children: [
                        for (var entry in _leaderboardEntries)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${entry['rank']}.',
                                  style: TextStyle(
                                    fontFamily: 'Share Tech Mono',
                                    fontSize: 18,
                                    color: entry['isUser'] == true
                                        ? Colors.yellow
                                        : Colors.white,
                                  ),
                                ),
                                Text(
                                  entry['name'].toString(),
                                  style: TextStyle(
                                    fontFamily: 'Share Tech Mono',
                                    fontSize: 18,
                                    color: entry['isUser'] == true
                                        ? Colors.yellow
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
                                    fontSize: 18,
                                    color: entry['isUser'] == true
                                        ? Colors.yellow
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
              const SizedBox(height: 30),
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
