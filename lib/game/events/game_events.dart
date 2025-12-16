import 'dart:ui';
import 'package:flutter_neon_runner/models/game_state.dart';
import 'package:flutter_neon_runner/models/player_data.dart';

/// Game events for decoupled communication between systems
abstract class GameEvent {
  final GameState? gameState;
  const GameEvent({this.gameState});
}

// Core Game Events
class GameStartedEvent extends GameEvent {
  const GameStartedEvent() : super(gameState: GameState.playing);
}

class GamePausedEvent extends GameEvent {
  const GamePausedEvent() : super(gameState: GameState.paused);
}

class GameResumedEvent extends GameEvent {
  const GameResumedEvent() : super(gameState: GameState.playing);
}

class GameOverEvent extends GameEvent {
  final int score;
  final int highscore;

  GameOverEvent(this.score, this.highscore) : super(gameState: GameState.gameOver);
}

class GameResetEvent extends GameEvent {}

// Player Events
class PlayerJumpEvent extends GameEvent {
  final double x;
  final double y;

  PlayerJumpEvent(this.x, this.y);
}

class PlayerDuckEvent extends GameEvent {
  final bool isDucking;

  PlayerDuckEvent(this.isDucking);
}

class PlayerMoveEvent extends GameEvent {
  final double x;
  final double y;
  final double velocityX;
  final double velocityY;

  PlayerMoveEvent(this.x, this.y, this.velocityX, this.velocityY);
}

class PlayerPowerUpActivatedEvent extends GameEvent {
  final PowerUpType powerUpType;
  final String message;

  PlayerPowerUpActivatedEvent(this.powerUpType, this.message);
}

// Obstacle Events
class ObstacleSpawnedEvent extends GameEvent {
  final dynamic obstacle;

  ObstacleSpawnedEvent(this.obstacle);
}

class ObstacleDestroyedEvent extends GameEvent {
  final dynamic obstacle;

  ObstacleDestroyedEvent(this.obstacle);
}

class ObstacleHitEvent extends GameEvent {
  final dynamic obstacle;
  final double x;
  final double y;

  ObstacleHitEvent(this.obstacle, this.x, this.y);
}

// Collision Events
class CollisionDetectedEvent extends GameEvent {
  final Rect playerRect;
  final Rect obstacleRect;
  final dynamic obstacle;

  CollisionDetectedEvent(this.playerRect, this.obstacleRect, this.obstacle);
}

class GrazingDetectedEvent extends GameEvent {
  final int points;
  final double x;
  final double y;

  GrazingDetectedEvent(this.points, this.x, this.y);
}

// Score Events
class ScoreUpdatedEvent extends GameEvent {
  final int newScore;
  final int scoreMultiplier;

  ScoreUpdatedEvent(this.newScore, this.scoreMultiplier);
}

class HighscoreUpdatedEvent extends GameEvent {
  final int newHighscore;

  HighscoreUpdatedEvent(this.newHighscore);
}

// Audio Events
class AudioPlayEvent extends GameEvent {
  final String soundType;

  AudioPlayEvent(this.soundType);
}

class AudioMusicControlEvent extends GameEvent {
  final bool play;

  AudioMusicControlEvent(this.play);
}

// UI Events
class ShowMessageEvent extends GameEvent {
  final String message;
  final Duration duration;

  ShowMessageEvent(this.message, this.duration);
}

class HudUpdateEvent extends GameEvent {
  final int score;
  final double speed;
  final int highscore;
  final PlayerData? playerData;

  HudUpdateEvent(this.score, this.speed, this.highscore, this.playerData);
}

// Particle Events
class ParticleCreateEvent extends GameEvent {
  final double x;
  final double y;
  final Color color;
  final int count;
  final String type;

  ParticleCreateEvent(this.x, this.y, this.color, this.count, this.type);
}

// Input Events
class InputEvent extends GameEvent {
  final InputAction action;
  final bool isPressed;

  InputEvent(this.action, this.isPressed);
}

class TouchInputEvent extends GameEvent {
  final Offset position;
  final InputAction action;

  TouchInputEvent(this.position, this.action);
}

// Ad Events
class ShowAdEvent extends GameEvent {
  final String adType;
  final VoidCallback? onComplete;

  ShowAdEvent(this.adType, {this.onComplete});
}

class ReviveCompletedEvent extends GameEvent {
  final int bonusScore;

  ReviveCompletedEvent({this.bonusScore = 0});
}

class RevivingEnterEvent extends GameEvent {
  const RevivingEnterEvent() : super(gameState: GameState.reviving);
}

class ReviveStartedEvent extends GameEvent {
  final String adType;
  final VoidCallback? onSuccess;
  final void Function(String)? onFailure;

  ReviveStartedEvent({
    required this.adType,
    this.onSuccess,
    this.onFailure,
  });
}

class ReviveFailedEvent extends GameEvent {
  final String reason;

  ReviveFailedEvent(this.reason);
}

// Leaderboard Events
class LeaderboardUpdateEvent extends GameEvent {
  final int score;
  final String? userId;

  LeaderboardUpdateEvent(this.score, {this.userId});
}

// Performance Events
class PerformanceWarningEvent extends GameEvent {
  final String warning;
  final double metric;

  PerformanceWarningEvent(this.warning, this.metric);
}

class PerformanceLevelChangedEvent extends GameEvent {
  final String level;
  final double fps;
  final int droppedFrames;

  PerformanceLevelChangedEvent({
    required this.level,
    required this.fps,
    required this.droppedFrames,
  });
}

/// Additional events for state machine communication
class GameStateTransitionEvent extends GameEvent {
  final GameState from;
  final GameState to;
  final Map<String, dynamic> data;

  GameStateTransitionEvent({
    required this.from,
    required this.to,
    required this.data,
  });
}

class MenuEnterEvent extends GameEvent {}

class NewGameStartEvent extends GameEvent {}

class RetryGameStartEvent extends GameEvent {}

class ReviveResumeEvent extends GameEvent {}

class GameResumeEvent extends GameEvent {}

class GamePausedEnterEvent extends GameEvent {}

class GameOverEnterEvent extends GameEvent {
  final int score;
  final int highscore;

  GameOverEnterEvent({
    required this.score,
    required this.highscore,
  });
}