import 'dart:async';
import 'dart:math';
import 'package:flutter_neon_runner/config/game_config.dart';
import 'package:flutter_neon_runner/leaderboard/leaderboard_system.dart';
import 'package:flutter_neon_runner/leaderboard/redis_validator.dart';
import 'package:flutter_neon_runner/game_state_provider.dart';
import 'package:flutter_neon_runner/models/game_state.dart';

/// Integration system that coordinates leaderboard and Redis validation
/// Ensures seamless operation, proper error handling, and offline resilience
class LeaderboardIntegration {
  late LeaderboardSystem _leaderboardSystem;
  late RedisValidator _redisValidator;
  GameStateProvider? _gameStateProvider;

  // Integration state
  bool _isInitialized = false;
  bool _hasPendingSubmission = false;

  // Submission tracking
  final Map<String, SubmissionAttempt> _submissionAttempts = {};

  // Sync state
  bool _isSyncing = false;
  Timer? _syncTimer;
  static const Duration _syncInterval = Duration(minutes: 5);

  LeaderboardIntegration();

  /// Set the GameStateProvider to listen for game state changes
  void setGameStateProvider(GameStateProvider gameStateProvider) {
    // Remove old listener if exists
    if (_gameStateProvider != null) {
      _gameStateProvider!.removeListener(_onGameStateChanged);
    }

    _gameStateProvider = gameStateProvider;
    _gameStateProvider!.addListener(_onGameStateChanged);
  }

  // Getters
  bool get isInitialized => _isInitialized;
  bool get hasPendingSubmission => _hasPendingSubmission;
  bool get isSyncing => _isSyncing;
  LeaderboardSystem get leaderboardSystem => _leaderboardSystem;

  /// Initialize the integration system
  Future<void> initialize() async {
    if (_isInitialized) return;

    _logDebug('Initializing leaderboard integration...');

    // Initialize subsystems
    _leaderboardSystem = LeaderboardSystem();
    await _leaderboardSystem.initialize();

    _redisValidator = RedisValidator();

    // Subscribe to events
    _subscribeToEvents();

    // Start periodic sync
    _startPeriodicSync();

    _isInitialized = true;
    _logDebug('Leaderboard integration initialized');
  }

  /// Submit score with comprehensive validation and retry logic
  Future<LeaderboardSubmissionResult> submitScore({
    required int score,
    required String playerName,
    String? userId,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_isInitialized) {
      return LeaderboardSubmissionResult.failure(
        'Integration not initialized',
        canRetry: true,
      );
    }

    userId ??= _generateAnonymousUserId();
    final submissionId = _generateSubmissionId();

    try {
      // Step 1: Pre-submission validation
      final preValidation = await _validatePreSubmission(
        score: score,
        userId: userId,
        submissionId: submissionId,
      );

      if (!preValidation.isValid) {
        return LeaderboardSubmissionResult.failure(
          preValidation.reason ?? 'Pre-validation failed',
          canRetry: preValidation.canRetry,
        );
      }

      // Step 2: Create submission attempt
      _submissionAttempts[submissionId] = SubmissionAttempt(
        submissionId: submissionId,
        score: score,
        userId: userId,
        playerName: playerName,
        timestamp: DateTime.now(),
        retries: 0,
        status: SubmissionStatus.pending,
      );

      // Step 3: Submit to leaderboard system
      final submissionResult = await _leaderboardSystem.submitScore(
        score: score,
        playerName: playerName,
        userId: userId,
        metadata: metadata,
      );

      if (submissionResult.pending) {
        // Mark as pending for Redis validation
        _hasPendingSubmission = true;

        // Start background validation
        _startBackgroundValidation(submissionId);

        return LeaderboardSubmissionResult.pending();
      }

      return _convertSubmissionResult(submissionResult);

    } catch (e) {
      _logError('Score submission error: $e');
      return LeaderboardSubmissionResult.failure(
        'Submission error: $e',
        canRetry: true,
      );
    }
  }

  /// Get leaderboard with fallback logic
  Future<LeaderboardGetResult> getLeaderboard({
    required String leaderboardId,
    int limit = 50,
    int offset = 0,
    bool includePlayerRank = false,
    String? userId,
  }) async {
    if (!_isInitialized) {
      return LeaderboardGetResult.failure('Integration not initialized');
    }

    try {
      // Try to get from leaderboard system (includes cache and fallback)
      final systemResult = await _leaderboardSystem.getLeaderboard(
        leaderboardId: leaderboardId,
        limit: limit,
        offset: offset,
      );

      if (systemResult.success) {
        // If player rank requested, get it separately
        int? playerRank;
        if (includePlayerRank && userId != null) {
          final rankResult = await _leaderboardSystem.getPlayerRank(
            userId: userId,
            leaderboardId: leaderboardId,
          );
          playerRank = rankResult.found ? rankResult.rank : null;
        }

        return LeaderboardGetResult.success(
          entries: systemResult.entries,
          fromCache: systemResult.fromCache,
          isStale: systemResult.isStale,
          isOffline: systemResult.isOffline,
          playerRank: playerRank,
        );
      }

      // Fallback to Redis direct if system failed
      if (_redisValidator.isConnected) {
        final redisResult = await _redisValidator.getLeaderboard(
          leaderboardId: leaderboardId,
          limit: limit,
          offset: offset,
          includePlayerRank: includePlayerRank,
          userId: userId,
        );

        if (redisResult.success) {
          return LeaderboardGetResult.success(
            entries: redisResult.entries,
            fromCache: false,
            isStale: false,
            isOffline: false,
            playerRank: redisResult.playerRank,
          );
        }
      }

      return LeaderboardGetResult.failure('All sources failed');

    } catch (e) {
      _logError('Error getting leaderboard: $e');
      return LeaderboardGetResult.failure('Error: $e');
    }
  }

  /// Force immediate sync of pending submissions
  Future<void> forceSync() async {
    if (_isSyncing) return;

    _isSyncing = true;
    _logDebug('Force syncing pending submissions...');

    try {
      // Sync Redis validator pending scores
      await _redisValidator.syncPendingScores();

      // Sync leaderboard system queue
      await _leaderboardSystem.syncPendingScores();

      _logDebug('Force sync completed');
    } catch (e) {
      _logError('Force sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Get comprehensive statistics
  LeaderboardIntegrationStats getStatistics() {
    final totalSubmissions = _submissionAttempts.length;
    final successfulSubmissions = _submissionAttempts.values
        .where((attempt) => attempt.status == SubmissionStatus.success)
        .length;

    return LeaderboardIntegrationStats(
      isInitialized: _isInitialized,
      hasPendingSubmission: _hasPendingSubmission,
      isSyncing: _isSyncing,
      totalSubmissions: totalSubmissions,
      successfulSubmissions: successfulSubmissions,
      successRate: totalSubmissions > 0 ? successfulSubmissions / totalSubmissions : 0.0,
      pendingSubmissions: _submissionAttempts.values
          .where((attempt) => attempt.status == SubmissionStatus.pending)
          .length,
      redisConnected: _redisValidator.isConnected,
    );
  }

  // Private methods

  void _subscribeToEvents() {
    // State change listening is handled by setGameStateProvider method
    // This method is kept for compatibility
  }

  /// Handle game state changes
  void _onGameStateChanged() {
    if (_gameStateProvider == null) return;

    final currentGameState = _gameStateProvider!.currentGameState;

    // Handle game over state - trigger score submission
    if (currentGameState == GameState.gameOver) {
      _handleGameOver();
    }
    // Handle game restart - clear pending submissions
    else if (currentGameState == GameState.menu) {
      _clearPendingSubmissions();
    }
  }

  /// Handle game over event
  void _handleGameOver() {
    if (_gameStateProvider == null) return;

    final finalScore = _gameStateProvider!.score.value;
    _logDebug('Game over detected with score: $finalScore');

    // Trigger score submission if score is meaningful
    if (finalScore > 0) {
      // The actual submission will be handled by the LeaderboardService
      // This method just logs the event for now
    }
  }

  /// Clear pending submissions when game restarts
  void _clearPendingSubmissions() {
    final pendingCount = _submissionAttempts.length;
    if (pendingCount > 0) {
      _logDebug('Clearing $pendingCount pending submissions');
      _submissionAttempts.clear();
    }
  }


  Future<PreValidationResult> _validatePreSubmission({
    required int score,
    required String userId,
    required String submissionId,
  }) async {
    // Check submission rate
    final now = DateTime.now();
    final recentSubmissions = _submissionAttempts.values
        .where((attempt) =>
            attempt.userId == userId &&
            now.difference(attempt.timestamp).inMinutes < 1)
        .length;

    if (recentSubmissions >= 5) {
      return PreValidationResult.failure('Too many submissions');
    }

    // Validate score range
    if (score < 0 || score > GameConfig.maxPossibleScore) {
      return PreValidationResult.failure('Invalid score range');
    }

    // Check for duplicate submission
    if (_submissionAttempts.containsKey(submissionId)) {
      return PreValidationResult.failure('Duplicate submission');
    }

    return PreValidationResult.success();
  }

  void _startBackgroundValidation(String submissionId) {
    // Start background task to validate with Redis
    Timer(Duration(seconds: 1), () async {
      final attempt = _submissionAttempts[submissionId];
      if (attempt == null || attempt.status != SubmissionStatus.pending) return;

      try {
        final validationData = ScoreValidationData(
          submissionId: submissionId,
          userId: attempt.userId,
          score: attempt.score,
          playerName: attempt.playerName,
          timestamp: attempt.timestamp,
          metadata: {},
          hash: _generateScoreHash(attempt.score, attempt.userId, submissionId),
        );

        final result = await _redisValidator.validateAndSubmitScore(
          validationData: validationData,
          leaderboardId: 'alltime',
        );

        if (result.success) {
          attempt.status = SubmissionStatus.success;
          _logDebug('Background validation successful: ${result.rank}');
        } else {
          attempt.status = SubmissionStatus.failed;
          _logDebug('Background validation failed: ${result.errorMessage}');
        }

      } catch (e) {
        attempt.status = SubmissionStatus.failed;
        _logError('Background validation error: $e');
      }

      // Check if all pending submissions are processed
      _checkPendingSubmissions();
    });
  }

  void _checkPendingSubmissions() {
    final pendingCount = _submissionAttempts.values
        .where((attempt) => attempt.status == SubmissionStatus.pending)
        .length;

    if (pendingCount == 0) {
      _hasPendingSubmission = false;
    }
  }

  LeaderboardSubmissionResult _convertSubmissionResult(ScoreSubmissionResult result) {
    if (result.success) {
      return LeaderboardSubmissionResult.success();
    } else if (result.pending) {
      return LeaderboardSubmissionResult.pending();
    } else {
      return LeaderboardSubmissionResult.failure(
        result.errorMessage ?? 'Unknown error',
        canRetry: result.shouldRetry,
      );
    }
  }

  String _generateAnonymousUserId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    final data = 'anonymous_$timestamp$random';
    return data.substring(0, 16);
  }

  String _generateSubmissionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    final data = 'sub_$timestamp$random';
    return data.substring(0, 16);
  }

  String _generateScoreHash(int score, String userId, String submissionId) {
    final data = '$score-$userId-$submissionId-${GameConfig.leaderboardSecret}';
    return data.hashCode.toString(); // Simplified hash
  }

  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (timer) {
      forceSync();
    });
  }

  void _logDebug(String message) {
    // Debug logging disabled for production
  }

  void _logError(String message) {
    // Error logging disabled for production
  }

  void dispose() {
    _syncTimer?.cancel();
    _submissionAttempts.clear();

    // Remove GameStateProvider listener if it was added
    if (_gameStateProvider != null) {
      _gameStateProvider!.removeListener(_onGameStateChanged);
      _gameStateProvider = null;
    }

    _leaderboardSystem.dispose();
    _redisValidator.dispose();
  }
}

// Data models

class SubmissionAttempt {
  final String submissionId;
  final int score;
  final String userId;
  final String playerName;
  final DateTime timestamp;
  int retries;
  SubmissionStatus status;

  SubmissionAttempt({
    required this.submissionId,
    required this.score,
    required this.userId,
    required this.playerName,
    required this.timestamp,
    required this.retries,
    required this.status,
  });
}

class PreValidationResult {
  final bool isValid;
  final String? reason;
  final bool canRetry;

  PreValidationResult.success()
      : isValid = true,
        reason = null,
        canRetry = false;

  PreValidationResult.failure(this.reason, {this.canRetry = false})
      : isValid = false;
}

class LeaderboardSubmissionResult {
  final bool success;
  final bool pending;
  final String? errorMessage;
  final bool canRetry;

  LeaderboardSubmissionResult.success()
      : success = true,
        pending = false,
        errorMessage = null,
        canRetry = false;

  LeaderboardSubmissionResult.pending()
      : success = false,
        pending = true,
        errorMessage = null,
        canRetry = false;

  LeaderboardSubmissionResult.failure(this.errorMessage, {this.canRetry = false})
      : success = false,
        pending = false;
}

class LeaderboardGetResult {
  final bool success;
  final List<LeaderboardEntry> entries;
  final bool fromCache;
  final bool isStale;
  final bool isOffline;
  final int? playerRank;
  final String? errorMessage;

  LeaderboardGetResult.success({
    required this.entries,
    this.fromCache = false,
    this.isStale = false,
    this.isOffline = false,
    this.playerRank,
  }) : success = true,
        errorMessage = null;

  LeaderboardGetResult.failure(this.errorMessage)
      : success = false,
        entries = [],
        fromCache = false,
        isStale = false,
        isOffline = false,
        playerRank = null;
}

class LeaderboardIntegrationStats {
  final bool isInitialized;
  final bool hasPendingSubmission;
  final bool isSyncing;
  final int totalSubmissions;
  final int successfulSubmissions;
  final double successRate;
  final int pendingSubmissions;
  final bool redisConnected;

  LeaderboardIntegrationStats({
    required this.isInitialized,
    required this.hasPendingSubmission,
    required this.isSyncing,
    required this.totalSubmissions,
    required this.successfulSubmissions,
    required this.successRate,
    required this.pendingSubmissions,
    required this.redisConnected,
  });
}