import 'package:flutter/foundation.dart';
import 'package:flutter_neon_runner/models/game_state.dart';
import 'package:flutter_neon_runner/game/events/game_events.dart';
import 'package:flutter_neon_runner/game/systems/base_game_system.dart';

/// Strict finite state machine for game state management
/// Enforces explicit transitions and proper state behavior
class GameStateMachine extends EventHandlerSystem {
  GameState _currentState = GameState.menu;
  GameState _previousState = GameState.menu;
  int _stateTransitionCount = 0;
  DateTime? _lastTransitionTime;

  // State timers
  DateTime? _stateEnterTime;
  Duration _stateDuration = Duration.zero;

  // State-specific data
  Map<String, dynamic> _stateData = {};

  // Transition rules
  final Map<GameState, Set<GameState>> _allowedTransitions = {
    GameState.menu: {GameState.playing, GameState.settings},
    GameState.playing: {GameState.paused, GameState.gameOver},
    GameState.paused: {GameState.playing, GameState.menu, GameState.settings},
    GameState.gameOver: {GameState.reviving, GameState.playing, GameState.menu},
    GameState.reviving: {GameState.playing, GameState.gameOver},
  };

  @override
  String get systemName => 'GameStateMachine';

  // Getters
  GameState get currentState => _currentState;
  GameState get previousState => _previousState;
  int get stateTransitionCount => _stateTransitionCount;
  Duration get stateDuration => _stateDuration;
  DateTime? get stateEnterTime => _stateEnterTime;
  bool get canUpdate => _currentState == GameState.playing;
  bool get isFrozen => _currentState == GameState.reviving;

  @override
  Future<void> initialize() async {
    // Subscribe to state transition events
    GameEventBus.instance.subscribe<GameStartedEvent>(_handleGameStarted);
    GameEventBus.instance.subscribe<GamePausedEvent>(_handleGamePaused);
    GameEventBus.instance.subscribe<GameResumedEvent>(_handleGameResumed);
    GameEventBus.instance.subscribe<GameOverEvent>(_handleGameOver);
    GameEventBus.instance.subscribe<GameResetEvent>(_handleGameReset);
    GameEventBus.instance.subscribe<ReviveStartedEvent>(_handleReviveStarted);
    GameEventBus.instance.subscribe<ReviveCompletedEvent>(_handleReviveCompleted);
    GameEventBus.instance.subscribe<ReviveFailedEvent>(_handleReviveFailed);
  }

  @override
  void update(double dt) {
    if (_stateEnterTime != null) {
      _stateDuration = DateTime.now().difference(_stateEnterTime!);
    }
  }

  @override
  void handleEvent(GameEvent event) {
    // Events are handled via subscriptions
  }

  @override
  List<Type> get handledEventTypes => [
        GameStartedEvent,
        GamePausedEvent,
        GameResumedEvent,
        GameOverEvent,
        GameResetEvent,
        ReviveStartedEvent,
        ReviveCompletedEvent,
        ReviveFailedEvent,
      ];

  /// Explicit state transition with validation and logging
  bool transitionTo(GameState newState, {Map<String, dynamic>? data}) {
    // Validate transition
    if (!_canTransitionTo(newState)) {
      _logError('Invalid transition from $_currentState to $newState');
      return false;
    }

    // Log transition
    _logTransition(_currentState, newState, data);

    // Update state tracking
    _previousState = _currentState;
    _currentState = newState;
    _stateTransitionCount++;
    _lastTransitionTime = DateTime.now();
    _stateEnterTime = DateTime.now();
    _stateDuration = Duration.zero;

    // Store state data
    if (data != null) {
      _stateData.addAll(data);
    }

    // Fire state transition event
    GameEventBus.instance.fire(GameStateTransitionEvent(
      from: _previousState,
      to: _currentState,
      data: Map.from(_stateData),
    ));

    // Execute state enter logic
    _onStateEnter(_currentState);

    return true;
  }

  /// Check if transition is allowed
  bool _canTransitionTo(GameState newState) {
    if (_currentState == newState) return false; // No self-transitions

    final allowedStates = _allowedTransitions[_currentState];
    if (allowedStates == null) {
      _logError('No transitions defined for state $_currentState');
      return false;
    }

    return allowedStates.contains(newState);
  }

  /// State-specific enter logic
  void _onStateEnter(GameState state) {
    switch (state) {
      case GameState.menu:
        _onMenuEnter();
        break;
      case GameState.playing:
        _onPlayingEnter();
        break;
      case GameState.paused:
        _onPausedEnter();
        break;
      case GameState.gameOver:
        _onGameOverEnter();
        break;
      case GameState.reviving:
        _onRevivingEnter();
        break;
      case GameState.leaderboardView:
        _logDebug('Entering LeaderboardView state');
        break;
      case GameState.settings:
        _logDebug('Entering Settings state');
        break;
    }
  }

  void _onMenuEnter() {
    _logDebug('Entering Menu state');
    _stateData.clear();
    GameEventBus.instance.fire(MenuEnterEvent());
  }

  void _onPlayingEnter() {
    _logDebug('Entering Playing state');

    if (_previousState == GameState.menu) {
      // Fresh start from menu
      GameEventBus.instance.fire(NewGameStartEvent());
    } else if (_previousState == GameState.reviving) {
      // Resuming from revive
      GameEventBus.instance.fire(ReviveResumeEvent());
    } else if (_previousState == GameState.gameOver) {
      // Retry from game over
      GameEventBus.instance.fire(RetryGameStartEvent());
    } else if (_previousState == GameState.paused) {
      // Resume from pause
      GameEventBus.instance.fire(GameResumeEvent());
    }
  }

  void _onPausedEnter() {
    _logDebug('Entering Paused state');
    GameEventBus.instance.fire(GamePausedEnterEvent());
  }

  void _onGameOverEnter() {
    _logDebug('Entering GameOver state');
    GameEventBus.instance.fire(GameOverEnterEvent(
      score: _stateData['score'] ?? 0,
      highscore: _stateData['highscore'] ?? 0,
    ));
  }

  void _onRevivingEnter() {
    _logDebug('Entering Reviving state');
    GameEventBus.instance.fire(RevivingEnterEvent());
  }

  /// State data management
  T? getStateData<T>(String key) {
    return _stateData[key] as T?;
  }

  void setStateData(String key, dynamic value) {
    _stateData[key] = value;
  }

  void clearStateData() {
    _stateData.clear();
  }

  /// Debug and logging
  void _logTransition(GameState from, GameState to, Map<String, dynamic>? data) {
    final dataStr = data?.isNotEmpty == true ? ' with data: $data' : '';
    _logDebug('State transition: $from → $to$dataStr');
  }

  void _logDebug(String message) {
    print('[GameStateMachine] $message');
  }

  void _logError(String message) {
    print('[GameStateMachine ERROR] $message');
  }

  /// State validation for debugging
  bool validateState() {
    // Check if current state is valid
    if (!GameState.values.contains(_currentState)) {
      _logError('Invalid current state: $_currentState');
      return false;
    }

    // Check transition count
    if (_stateTransitionCount < 0) {
      _logError('Invalid transition count: $_stateTransitionCount');
      return false;
    }

    // Check timing consistency
    if (_stateEnterTime != null && _lastTransitionTime != null) {
      if (_stateEnterTime!.isBefore(_lastTransitionTime!)) {
        _logError('State timing inconsistency');
        return false;
      }
    }

    return true;
  }

  /// Get state machine statistics
  Map<String, dynamic> getStatistics() {
    return {
      'currentState': _currentState.toString(),
      'previousState': _previousState.toString(),
      'stateTransitionCount': _stateTransitionCount,
      'stateDuration': _stateDuration.inMilliseconds,
      'stateEnterTime': _stateEnterTime?.toIso8601String(),
      'lastTransitionTime': _lastTransitionTime?.toIso8601String(),
      'stateData': _stateData,
    };
  }

  // Event handlers
  void _handleGameStarted(GameStartedEvent event) {
    transitionTo(GameState.playing);
  }

  void _handleGamePaused(GamePausedEvent event) {
    transitionTo(GameState.paused);
  }

  void _handleGameResumed(GameResumedEvent event) {
    transitionTo(GameState.playing);
  }

  void _handleGameOver(GameOverEvent event) {
    transitionTo(GameState.gameOver, data: {
      'score': event.score,
      'highscore': event.highscore,
    });
  }

  void _handleGameReset(GameResetEvent event) {
    transitionTo(GameState.menu);
  }

  void _handleReviveStarted(ReviveStartedEvent event) {
    transitionTo(GameState.reviving, data: {
      'adType': event.adType,
      'onSuccess': event.onSuccess,
      'onFailure': event.onFailure,
    });
  }

  void _handleReviveCompleted(ReviveCompletedEvent event) {
    transitionTo(GameState.playing, data: {
      'revived': true,
      'bonusScore': event.bonusScore,
    });
  }

  void _handleReviveFailed(ReviveFailedEvent event) {
    transitionTo(GameState.gameOver, data: {
      'reviveFailed': true,
      'reason': event.reason,
    });
  }

  @override
  void dispose() {
    // Unsubscribe from events
    GameEventBus.instance.unsubscribe<GameStartedEvent>(_handleGameStarted);
    GameEventBus.instance.unsubscribe<GamePausedEvent>(_handleGamePaused);
    GameEventBus.instance.unsubscribe<GameResumedEvent>(_handleGameResumed);
    GameEventBus.instance.unsubscribe<GameOverEvent>(_handleGameOver);
    GameEventBus.instance.unsubscribe<GameResetEvent>(_handleGameReset);
    GameEventBus.instance.unsubscribe<ReviveStartedEvent>(_handleReviveStarted);
    GameEventBus.instance.unsubscribe<ReviveCompletedEvent>(_handleReviveCompleted);
    GameEventBus.instance.unsubscribe<ReviveFailedEvent>(_handleReviveFailed);
  }
}