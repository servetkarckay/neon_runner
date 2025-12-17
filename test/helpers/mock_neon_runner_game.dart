import 'package:flutter_neon_runner/models/game_state.dart';
import 'package:vector_math/vector_math_64.dart';
import 'mock_ad_system.dart';
import 'mock_leaderboard_system.dart';

class MockPlayer {
  bool isDead = false;
  bool canRevive = true;
  bool isInvincible = false;
  int revivesUsed = 0;
  double invincibilityTimer = 0;
  int score = 0;

  Vector2 position = Vector2(0.0, 0.0);
  Vector2 velocity = Vector2(0.0, 0.0);

  void setInvincible(double duration) {
    isInvincible = true;
    invincibilityTimer = duration;
  }

  void resetVelocity() {
    velocity = Vector2.zero();
  }
}

class NeonRunnerGame {
  MockPlayer player = MockPlayer();
  int score = 0;
  int highscore = 0;
  GameState gameState = GameState.menu;
  bool paused = false;
  String? userId;
  bool scoreGlitch = false;
  double speed = 0.0;
  MockPlayerData playerData = MockPlayerData();
  MockRewardedAdSystem? adSystem;
  MockLeaderboardSystem? leaderboardSystem;

  NeonRunnerGame({this.adSystem, this.leaderboardSystem});

  void update(double dt) {
    // Mock update logic
  }

  void initGame() {
    score = 0;
    player.isDead = false;
    player.canRevive = true;
    player.isInvincible = false;
    player.score = 0;
    player.position.setValues(0, 0);
    player.velocity.setValues(0, 0);
    gameState = GameState.playing;
    paused = false;
  }
}

class MockPlayerData {
  int scoreMultiplier = 1;
  bool hasShield = false;
  bool isGrazing = false;
  int multiplierTimer = 0;
  int timeWarpTimer = 0;
  int magnetTimer = 0;
}