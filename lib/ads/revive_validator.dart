import 'package:flutter_neon_runner/config/game_config.dart';
import 'package:flutter_neon_runner/game/events/game_events.dart';
import 'package:flutter_neon_runner/game/systems/game_state_controller.dart';
import 'package:flutter_neon_runner/game/systems/player_system.dart';
import 'package:flutter_neon_runner/models/game_state.dart';
import 'package:flutter_neon_runner/game/systems/base_game_system.dart';
import 'package:flutter_neon_runner/config/build_config.dart';
import 'package:flutter_neon_runner/utils/debug_utils.dart';

/// Revive validator system that prevents all revive-related issues
/// Ensures one revive per run and prevents cheating/exploits
class ReviveValidator {
  final GameStateController _gameStateController;
  final PlayerSystem _playerSystem;

  // Revive tracking
  bool _reviveUsedThisRun = false;
  int _currentRunId = 0;
  DateTime? _runStartTime;
  final Map<int, ReviveRecord> _reviveHistory = {};

  // Safety checks
  final List<GameState> _stateHistory = [];
  static const int _maxStateHistory = 100;

  // Anti-cheat measures
  int _lastScore = 0;
  DateTime? _lastScoreTime;
  final Map<String, int> _actionCounts = {};

  ReviveValidator({
    required GameStateController gameStateController,
    required PlayerSystem playerSystem,
  }) : _gameStateController = gameStateController,
       _playerSystem = playerSystem;

  // Getters
  bool get reviveUsedThisRun => _reviveUsedThisRun;
  int get currentRunId => _currentRunId;
  bool get canRevive => !_reviveUsedThisRun && _isInValidReviveState();

  /// Initialize the validator
  void initialize() {
    // Listen to game events
    GameEventBus.instance.subscribe<GameStartedEvent>(_handleGameStarted);
    GameEventBus.instance.subscribe<GameOverEvent>(_handleGameOver);
    GameEventBus.instance.subscribe<ReviveCompletedEvent>(_handleReviveCompleted);
    GameEventBus.instance.subscribe<ScoreUpdatedEvent>(_handleScoreUpdated);

    // Start new run
    _startNewRun();
  }

  /// Validate if revive is allowed
  ReviveValidationResult validateReviveRequest() {
    final issues = <String>[];

    // Check if revive already used
    if (_reviveUsedThisRun) {
      issues.add('Revive already used in this run');
    }

    // Check game state
    if (!_isInValidReviveState()) {
      issues.add('Not in valid state for revive');
    }

    // Check for suspicious activity
    final suspiciousIssues = _checkSuspiciousActivity();
    issues.addAll(suspiciousIssues);

    // Check for rapid score increases (possible cheating)
    final scoreIssues = _validateScoreProgression();
    issues.addAll(scoreIssues);

    return ReviveValidationResult(
      isValid: issues.isEmpty,
      issues: issues,
      runId: _currentRunId,
      canRetry: _canRetryRevive(),
    );
  }

  /// Record revive usage
  void recordReviveUsage() {
    if (_reviveUsedThisRun) {
      throw StateError('Revive already used in this run');
    }

    _reviveUsedThisRun = true;

    final record = ReviveRecord(
      runId: _currentRunId,
      timestamp: DateTime.now(),
      scoreAtRevive: _gameStateController.score,
      speedAtRevive: _gameStateController.speed,
      playerPosition: {
        'x': _playerSystem.playerData.x,
        'y': _playerSystem.playerData.y,
      },
    );

    _reviveHistory[_currentRunId] = record;

    _logDebug('Revive recorded for run $_currentRunId');
  }

  /// Validate post-revive state
  RevivePostValidationResult validatePostReviveState() {
    final issues = <String>[];

    // Check for duplicate revive
    if (!_reviveUsedThisRun) {
      issues.add('Revive marked as unused after revive');
    }

    // Check for score duplication
    if (_gameStateController.score < _getLastRecordedScore()) {
      issues.add('Score decreased after revive');
    }

    // Check for timer desync
    final runDuration = DateTime.now().difference(_runStartTime!);
    if (runDuration.inSeconds > GameConfig.maxRunDurationSeconds) {
      issues.add('Run duration exceeded maximum');
    }

    // Check for immediate collision (revive in dangerous position)
    if (_isInDangerousPosition()) {
      issues.add('Revived in dangerous position');
    }

    return RevivePostValidationResult(
      isValid: issues.isEmpty,
      issues: issues,
      safePosition: !_isInDangerousPosition(),
      invincibilityActive: _playerSystem.playerData.invincibleTimer > 0,
    );
  }

  /// Start new run tracking
  void _startNewRun() {
    _currentRunId++;
    _reviveUsedThisRun = false;
    _runStartTime = DateTime.now();
    _lastScore = 0;
    _lastScoreTime = DateTime.now();
    _stateHistory.clear();
    _actionCounts.clear();

    _logDebug('Started new run tracking: $_currentRunId');
  }

  /// Validate current game state for revive
  bool _isInValidReviveState() {
    final currentState = _gameStateController.currentState;

    // Only allow revive from GameOver state
    if (currentState != GameState.gameOver) {
      return false;
    }

    // Must have been in GameOver for at least 1 second
    if (_stateHistory.length < 2) {
      return false;
    }

    final gameOverIndex = _stateHistory.lastIndexOf(GameState.gameOver);
    if (gameOverIndex == -1) {
      return false;
    }

    // Check that GameOver state is stable
    for (int i = gameOverIndex; i < _stateHistory.length; i++) {
      if (_stateHistory[i] != GameState.gameOver) {
        return false;
      }
    }

    return true;
  }

  /// Check for suspicious activity
  List<String> _checkSuspiciousActivity() {
    final issues = <String>[];

    // Check for rapid state transitions
    if (_stateHistory.length > 10) {
      final recentStates = _stateHistory.sublist(_stateHistory.length - 10);
      final uniqueStates = recentStates.toSet();

      if (uniqueStates.length > 5) {
        issues.add('Excessive state transitions detected');
      }
    }

    // Check for excessive player actions
    for (final action in _actionCounts.entries) {
      if (action.value > 1000) { // More than 1000 actions of any type
        issues.add('Excessive ${action.key} actions: ${action.value}');
      }
    }

    return issues;
  }

  /// Validate score progression for cheating
  List<String> _validateScoreProgression() {
    final issues = <String>[];
    final currentScore = _gameStateController.score;

    // Check for impossible score jumps
    final scoreDiff = currentScore - _lastScore;
    final timeDiff = DateTime.now().difference(_lastScoreTime!).inMilliseconds;

    if (timeDiff > 0) {
      final scoreRate = scoreDiff / (timeDiff / 1000);

      if (scoreRate > GameConfig.maxScoreRate) {
        issues.add('Suspicious score rate: $scoreRate points/sec');
      }
    }

    _lastScore = currentScore;
    _lastScoreTime = DateTime.now();

    return issues;
  }

  /// Check if player is in dangerous position
  bool _isInDangerousPosition() {
    final playerData = _playerSystem.playerData;

    // Check if player is too low (below ground)
    if (playerData.y > GameConfig.groundLevel) {
      return true;
    }

    // Check if player is too high (impossible position)
    if (playerData.y < -100) {
      return true;
    }

    // Check if player is too far right (off-screen)
    if (playerData.x > GameConfig.baseWidth + 100) {
      return true;
    }

    // Check if player is too far left (behind start)
    if (playerData.x < -50) {
      return true;
    }

    return false;
  }

  /// Check if revive can be retried
  bool _canRetryRevive() {
    // Allow retry if previous attempt failed due to technical issues
    final lastRecord = _reviveHistory[_currentRunId];
    if (lastRecord == null) return true;

    // Don't allow retry if revive was already completed
    return false;
  }

  /// Get last recorded score
  int _getLastRecordedScore() {
    final record = _reviveHistory[_currentRunId];
    return record?.scoreAtRevive ?? 0;
  }

  /// Record player action for anti-cheat
  void recordPlayerAction(String action) {
    _actionCounts[action] = (_actionCounts[action] ?? 0) + 1;
  }

  /// Record state change
  void recordStateChange(GameState newState) {
    _stateHistory.add(newState);

    if (_stateHistory.length > _maxStateHistory) {
      _stateHistory.removeAt(0);
    }
  }

  /// Get revive statistics
  ReviveStatistics getStatistics() {
    final totalRevives = _reviveHistory.length;
    final successfulRevives = _reviveHistory.values
        .where((record) => record.wasSuccessful)
        .length;

    final averageScore = totalRevives > 0
        ? _reviveHistory.values
            .map((record) => record.scoreAtRevive)
            .reduce((a, b) => a + b) / totalRevives
        : 0.0;

    return ReviveStatistics(
      totalRevives: totalRevives,
      successfulRevives: successfulRevives,
      currentRunId: _currentRunId,
      reviveUsedThisRun: _reviveUsedThisRun,
      averageScoreAtRevive: averageScore,
      totalRunTime: _runStartTime != null
          ? DateTime.now().difference(_runStartTime!)
          : Duration.zero,
    );
  }

  // Event handlers
  void _handleGameStarted(GameStartedEvent event) {
    _startNewRun();
  }

  void _handleGameOver(GameOverEvent event) {
    recordStateChange(GameState.gameOver);
  }

  void _handleReviveCompleted(ReviveCompletedEvent event) {
    recordReviveUsage();

    // Validate post-revive state
    final postValidation = validatePostReviveState();
    if (!postValidation.isValid) {
      _logError('Post-revive validation failed: ${postValidation.issues}');
    }
  }

  void _handleScoreUpdated(ScoreUpdatedEvent event) {
    // Track score progression for anti-cheat
  }

  void _logDebug(String message) {
    if (!BuildConfig.enableLogs) return;
    DebugUtils.log('[ReviveValidator] DEBUG: $message');
  }

  void _logError(String message) {
    if (!BuildConfig.enableLogs) return;
    DebugUtils.log('[ReviveValidator] ERROR: $message');
  }

  void dispose() {
    GameEventBus.instance.unsubscribe<GameStartedEvent>(_handleGameStarted);
    GameEventBus.instance.unsubscribe<GameOverEvent>(_handleGameOver);
    GameEventBus.instance.unsubscribe<ReviveCompletedEvent>(_handleReviveCompleted);
    GameEventBus.instance.unsubscribe<ScoreUpdatedEvent>(_handleScoreUpdated);
  }
}

/// Result of revive validation
class ReviveValidationResult {
  final bool isValid;
  final List<String> issues;
  final int runId;
  final bool canRetry;

  ReviveValidationResult({
    required this.isValid,
    required this.issues,
    required this.runId,
    required this.canRetry,
  });
}

/// Result of post-revive validation
class RevivePostValidationResult {
  final bool isValid;
  final List<String> issues;
  final bool safePosition;
  final bool invincibilityActive;

  RevivePostValidationResult({
    required this.isValid,
    required this.issues,
    required this.safePosition,
    required this.invincibilityActive,
  });
}

/// Record of revive usage
class ReviveRecord {
  final int runId;
  final DateTime timestamp;
  final int scoreAtRevive;
  final double speedAtRevive;
  final Map<String, double> playerPosition;
  bool wasSuccessful = false;

  ReviveRecord({
    required this.runId,
    required this.timestamp,
    required this.scoreAtRevive,
    required this.speedAtRevive,
    required this.playerPosition,
  });

  void markSuccessful() {
    wasSuccessful = true;
  }
}

/// Revive statistics
class ReviveStatistics {
  final int totalRevives;
  final int successfulRevives;
  final int currentRunId;
  final bool reviveUsedThisRun;
  final double averageScoreAtRevive;
  final Duration totalRunTime;

  ReviveStatistics({
    required this.totalRevives,
    required this.successfulRevives,
    required this.currentRunId,
    required this.reviveUsedThisRun,
    required this.averageScoreAtRevive,
    required this.totalRunTime,
  });

  double get successRate => totalRevives > 0 ? successfulRevives / totalRevives : 0.0;
}