import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_neon_runner/game/neon_runner_game.dart';
import 'package:flutter_neon_runner/game_state_provider.dart';
import 'package:flutter_neon_runner/models/game_state.dart';
import 'package:flutter_neon_runner/config/game_config.dart';

class ReviveDialogOverlay extends StatefulWidget {
  final NeonRunnerGame game;

  const ReviveDialogOverlay({super.key, required this.game});

  @override
  State<ReviveDialogOverlay> createState() => _ReviveDialogOverlayState();
}

class _ReviveDialogOverlayState extends State<ReviveDialogOverlay>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _scaleController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameStateProvider = Provider.of<GameStateProvider>(context);
    final isReviving = gameStateProvider.currentGameState == GameState.reviving;

    return AnimatedOpacity(
      opacity: isReviving ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        body: Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black.withRed(10),
                    Colors.black.withBlue(10),
                    Colors.black,
                  ],
                ),
                border: Border.all(
                  color: GameConfig.primaryNeonColor.withValues(alpha: 0.6),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: GameConfig.primaryNeonColor.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildReviveIcon(),
                  const SizedBox(height: 24),
                  _buildReviveTitle(),
                  const SizedBox(height: 16),
                  _buildReviveMessage(),
                  const SizedBox(height: 32),
                  _buildReviveButton(gameStateProvider),
                  const SizedBox(height: 16),
                  _buildNoThanksButton(gameStateProvider),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviveIcon() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: GameConfig.primaryNeonColor.withValues(alpha: 0.1),
              border: Border.all(
                color: GameConfig.primaryNeonColor.withValues(alpha: 0.8),
                width: 3,
              ),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(
              Icons.favorite_rounded,
              size: 40,
              color: GameConfig.primaryNeonColor,
            ),
          ),
        );
      },
    );
  }

  Widget _buildReviveTitle() {
    return Text(
      'REVIVE',
      style: TextStyle(
        fontFamily: 'Orbitron',
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        shadows: [
          Shadow(
            color: GameConfig.primaryNeonColor.withValues(alpha: 0.8),
            blurRadius: 15,
          ),
        ],
        letterSpacing: 3,
      ),
    );
  }

  Widget _buildReviveMessage() {
    return Column(
      children: [
        Text(
          'Watch a short ad to',
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontSize: 18,
            color: Colors.white.withValues(alpha: 0.8),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'continue playing',
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontSize: 18,
            color: Colors.white.withValues(alpha: 0.8),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildReviveButton(GameStateProvider gameStateProvider) {
    return SizedBox(
      width: double.infinity,
      height: 70,
      child: ElevatedButton(
        onPressed: () {
          gameStateProvider.gameInstance.adsController.showRewardedAd(() {
            gameStateProvider.resumeGame();
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: GameConfig.primaryNeonColor,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
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
              Icons.play_circle_rounded,
              size: 28,
              color: Colors.black,
            ),
            const SizedBox(width: 12),
            Text(
              'WATCH AD',
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoThanksButton(GameStateProvider gameStateProvider) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: TextButton(
        onPressed: () {
          gameStateProvider.updateGameState(GameState.gameOver);
        },
        style: TextButton.styleFrom(
          foregroundColor: Colors.white.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.pressed)) {
                return Colors.white.withValues(alpha: 0.1);
              }
              return null;
            },
          ),
        ),
        child: Text(
          'NO THANKS',
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.6),
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}