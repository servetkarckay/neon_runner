import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_neon_runner/config/build_config.dart';
import 'package:flutter_neon_runner/game/events/game_events.dart';
import 'package:flutter_neon_runner/game/systems/base_game_system.dart';
import 'package:flutter_neon_runner/game/state/game_state_machine.dart';
import 'package:flutter_neon_runner/models/game_state.dart';
import 'package:flutter_neon_runner/models/player_data.dart';
import 'package:flutter_neon_runner/utils/debug_utils.dart';

/// Central controller for managing game state and coordinating systems
/// Now uses strict finite state machine for state management
class GameStateController extends EventHandlerSystem implements ResettableSystem {
  late GameStateMachine _stateMachine;
  int _score = 0;
  int _highscore = 0;
  double _speed = 0.0;
  bool _tutorialActive = false;

  @override
  String get systemName => 'GameStateController';

  // Getters (delegate to state machine)
  GameState get currentState => _stateMachine.currentState;
  GameState get previousState => _stateMachine.previousState;
  int get score => _score;
  int get highscore => _highscore;
  double get speed => _speed;
  bool get tutorialActive => _tutorialActive;
  bool get isPlaying => _stateMachine.currentState == GameState.playing;
  bool get isPaused => _stateMachine.currentState == GameState.paused;
  bool get isGameOver => _stateMachine.currentState == GameState.gameOver;
  bool get isInMenu => _stateMachine.currentState == GameState.menu;
  bool get isReviving => _stateMachine.currentState == GameState.reviving;
  bool get canUpdate => _stateMachine.canUpdate;
  bool get isFrozen => _stateMachine.isFrozen;
  Duration get stateDuration => _stateMachine.stateDuration;

  @override
  Future<void> initialize() async {
    // Initialize state machine
    _stateMachine = GameStateMachine();
    await _stateMachine.initialize();

    // Subscribe to relevant events
    GameEventBus.instance.subscribe<ScoreUpdatedEvent>(_handleScoreUpdated);
    GameEventBus.instance.subscribe<HighscoreUpdatedEvent>(_handleHighscoreUpdated);
  }

  @override
  void update(double dt) {
    // Update state machine
    _stateMachine.update(dt);

    // Update state data
    _stateMachine.setStateData('score', _score);
    _stateMachine.setStateData('highscore', _highscore);
    _stateMachine.setStateData('speed', _speed);
  }

  @override
  void handleEvent(GameEvent event) {
    // Events are handled via subscriptions
  }

  @override
  List<Type> get handledEventTypes => [
        ScoreUpdatedEvent,
        HighscoreUpdatedEvent,
      ];

  @override
  void reset() {
    _score = 0;
    _speed = 0.0;
    _tutorialActive = false;
    _stateMachine.transitionTo(GameState.menu);
  }

  // State change methods (use state machine)
  void startGame({PlayerData? playerData}) {
    _speed = 5.0; // Initial speed from GameConfig
    _stateMachine.transitionTo(GameState.playing, data: {
      'freshStart': true,
      'playerData': playerData,
    });
  }

  void pauseGame() {
    _stateMachine.transitionTo(GameState.paused);
  }

  void resumeGame() {
    _stateMachine.transitionTo(GameState.playing);
  }

  void gameOver({int? finalScore}) {
    if (finalScore != null) {
      _score = finalScore;
    }

    _stateMachine.transitionTo(GameState.gameOver, data: {
      'score': _score,
      'highscore': _highscore,
    });
  }

  void returnToMenu() {
    _stateMachine.transitionTo(GameState.menu);
  }

  // Revive flow for rewarded ads
  void startReviving({
    required VoidCallback onSuccess,
    required void Function(String) onFailure,
    String adType = 'rewarded',
  }) {
    _stateMachine.transitionTo(GameState.reviving, data: {
      'adType': adType,
      'onSuccess': onSuccess,
      'onFailure': onFailure,
    });

    // Fire revive started event
    GameEventBus.instance.fire(ReviveStartedEvent(
      adType: adType,
      onSuccess: onSuccess,
      onFailure: onFailure,
    ));
  }

  void completeReviving({int bonusScore = 0}) {
    _stateMachine.transitionTo(GameState.playing, data: {
      'revived': true,
      'bonusScore': bonusScore,
    });

    // Fire revive completed event
    GameEventBus.instance.fire(ReviveCompletedEvent(bonusScore: bonusScore));
  }

  void failReviving(String reason) {
    _stateMachine.transitionTo(GameState.gameOver, data: {
      'reviveFailed': true,
      'reason': reason,
    });

    // Fire revive failed event
    GameEventBus.instance.fire(ReviveFailedEvent(reason));
  }

  // Game state updates
  void updateScore(int newScore, {int multiplier = 1}) {
    if (newScore != _score) {
      _score = newScore;
      GameEventBus.instance.fire(ScoreUpdatedEvent(_score, multiplier));
    }
  }

  void updateHighscore(int newHighscore) {
    if (newHighscore > _highscore) {
      _highscore = newHighscore;
      GameEventBus.instance.fire(HighscoreUpdatedEvent(_highscore));
    }
  }

  void updateSpeed(double newSpeed) {
    _speed = newSpeed;
  }

  void setTutorialState(bool active) {
    _tutorialActive = active;
  }

  // State machine methods
  Map<String, dynamic> getStatistics() {
    return _stateMachine.getStatistics();
  }

  bool validateState() {
    return _stateMachine.validateState();
  }

  void setDebugMode(bool debugMode) {
    // This method is not implemented in GameStateMachine
  }

  List<Map<String, dynamic>> getStateHistory() {
    // This method is not implemented in GameStateMachine
    return [];
  }

  // Event handlers
  void _handleGameStarted(GameStartedEvent event) {
    if (!BuildConfig.enableLogs) return;
    DebugUtils.log('Game started');
  }

  void _handleGamePaused(GamePausedEvent event) {
    if (!BuildConfig.enableLogs) return;
    DebugUtils.log('Game paused');
  }

  void _handleGameResumed(GameResumedEvent event) {
    if (!BuildConfig.enableLogs) return;
    DebugUtils.log('Game resumed');
  }

  void _handleGameOver(GameOverEvent event) {
    if (!BuildConfig.enableLogs) return;
    DebugUtils.log('Game over - Score: ${event.score}, Highscore: ${event.highscore}');

    if (event.score > _highscore) {
      updateHighscore(event.score);
    }
  }

  void _handleGameReset(GameResetEvent event) {
    if (!BuildConfig.enableLogs) return;
    DebugUtils.log('Game reset');
  }

  void _handleScoreUpdated(ScoreUpdatedEvent event) {
    // Score already updated in updateScore
  }

  void _handleHighscoreUpdated(HighscoreUpdatedEvent event) {
    // Highscore already updated in updateHighscore
  }

  @override
  void dispose() {
    // Unsubscribe from events
    GameEventBus.instance.unsubscribe<GameStartedEvent>(_handleGameStarted);
    GameEventBus.instance.unsubscribe<GamePausedEvent>(_handleGamePaused);
    GameEventBus.instance.unsubscribe<GameResumedEvent>(_handleGameResumed);
    GameEventBus.instance.unsubscribe<GameOverEvent>(_handleGameOver);
    GameEventBus.instance.unsubscribe<GameResetEvent>(_handleGameReset);
    GameEventBus.instance.unsubscribe<ScoreUpdatedEvent>(_handleScoreUpdated);
    GameEventBus.instance.unsubscribe<HighscoreUpdatedEvent>(_handleHighscoreUpdated);
  }
}