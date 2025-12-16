import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_neon_runner/config/game_config.dart';
import 'package:flutter_neon_runner/leaderboard/leaderboard_system.dart';

/// Redis-based validation system for atomic operations and enhanced security
/// Provides server-side validation, duplicate prevention, and integrity checks
class RedisValidator {
  static const String _keyPrefix = 'neon_runner:';
  static const String _scoreSubmissionsKey = '${_keyPrefix}score_submissions';
  static const String _validationKey = '${_keyPrefix}validation';
  static const String _leaderboardKey = '${_keyPrefix}leaderboard';
  static const String _playerDataKey = '${_keyPrefix}player_data';

  // Redis connection simulation
  bool _isConnected = false;
  final Map<String, String> _redisStore = {};
  final Map<String, DateTime> _expiryTimes = {};

  /// Check if Redis is connected
  bool get isConnected => _isConnected;

  // Atomic operation locks
  final Map<String, DateTime> _locks = {};
  static const Duration _lockTimeout = Duration(seconds: 10);

  // Validation cache
  final Map<String, ScoreValidationRecord> _validationCache = {};

  RedisValidator() {
    _simulateRedisConnection();
  }

  /// Validate and submit score with atomic operations
  Future<RedisValidationResult> validateAndSubmitScore({
    required ScoreValidationData validationData,
    required String leaderboardId,
  }) async {
    try {
      // Step 1: Check connection
      if (!_isConnected) {
        return RedisValidationResult.failure('Redis unavailable', canRetry: true);
      }

      // Step 2: Atomic lock for player submission
      final lockKey = _generateLockKey(validationData.userId);
      if (!await _acquireLock(lockKey)) {
        return RedisValidationResult.failure('Submission in progress', canRetry: true);
      }

      try {
        // Step 3: Check for duplicate submissions
        if (await _isDuplicateSubmission(validationData)) {
          return RedisValidationResult.failure('Duplicate submission', canRetry: false);
        }

        // Step 4: Validate score integrity
        final integrityCheck = await _validateScoreIntegrity(validationData);
        if (!integrityCheck.isValid) {
          return RedisValidationResult.failure(
            integrityCheck.reason ?? 'Integrity check failed',
            canRetry: false,
          );
        }

        // Step 5: Check rate limiting
        if (await _isRateLimited(validationData.userId)) {
          return RedisValidationResult.failure('Rate limited', canRetry: true);
        }

        // Step 6: Atomic leaderboard update
        final updateResult = await _atomicLeaderboardUpdate(
          validationData,
          leaderboardId,
        );

        if (!updateResult.success) {
          return RedisValidationResult.failure(
            updateResult.error ?? 'Update failed',
            canRetry: updateResult.canRetry,
          );
        }

        // Step 7: Record submission
        await _recordSubmission(validationData);

        // Step 8: Update player statistics
        await _updatePlayerStatistics(validationData);

        return RedisValidationResult.success(
          rank: updateResult.rank,
          leaderboardId: leaderboardId,
        );

      } finally {
        // Release lock
        await _releaseLock(lockKey);
      }

    } catch (e) {
      _logError('Redis validation error: $e');
      return RedisValidationResult.failure('Validation error: $e', canRetry: true);
    }
  }

  /// Get leaderboard with atomic read
  Future<RedisLeaderboardResult> getLeaderboard({
    required String leaderboardId,
    int limit = 100,
    int offset = 0,
    bool includePlayerRank = false,
    String? userId,
  }) async {
    try {
      if (!_isConnected) {
        return RedisLeaderboardResult.failure('Redis unavailable');
      }

      // Atomic read with consistency check
      final leaderboardKey = _generateLeaderboardKey(leaderboardId);
      final rawEntries = await _atomicZRevRangeWithScores(
        leaderboardKey,
        offset,
        offset + limit - 1,
      );

      final entries = rawEntries.map((entry) => LeaderboardEntry(
        rank: entry.rank,
        playerName: entry.playerName,
        score: entry.score,
        userId: entry.userId,
        timestamp: entry.timestamp,
        metadata: entry.metadata,
      )).toList();

      // Include player rank if requested
      int? playerRank;
      if (includePlayerRank && userId != null) {
        playerRank = await _getPlayerRank(leaderboardId, userId);
      }

      return RedisLeaderboardResult.success(
        entries: entries,
        playerRank: playerRank,
        totalPlayers: await _getLeaderboardSize(leaderboardId),
        fromCache: false,
      );

    } catch (e) {
      _logError('Error getting leaderboard: $e');
      return RedisLeaderboardResult.failure('Error: $e');
    }
  }

  /// Batch validate multiple scores (for admin tools)
  Future<BatchValidationResult> batchValidateScores(
    List<ScoreValidationData> scores,
  ) async {
    final results = <String, RedisValidationResult>{};

    try {
      if (!_isConnected) {
        return BatchValidationResult.failure('Redis unavailable');
      }

      // Process in batches to avoid overwhelming Redis
      const batchSize = 10;
      for (int i = 0; i < scores.length; i += batchSize) {
        final batch = scores.skip(i).take(batchSize).toList();

        for (final score in batch) {
          final result = await validateAndSubmitScore(
            validationData: score,
            leaderboardId: _allTimeLeaderboardId,
          );
          results[score.submissionId] = result;
        }
      }

      return BatchValidationResult.success(results);

    } catch (e) {
      _logError('Batch validation error: $e');
      return BatchValidationResult.failure('Batch error: $e');
    }
  }

  // Private atomic operations

  Future<bool> _acquireLock(String lockKey) async {
    final expiry = DateTime.now().add(_lockTimeout);

    // Simulate Redis SETNX operation
    if (!_locks.containsKey(lockKey)) {
      _locks[lockKey] = expiry;
      return true;
    }

    // Check if lock has expired
    final existingExpiry = _locks[lockKey]!;
    if (DateTime.now().isAfter(existingExpiry)) {
      _locks[lockKey] = expiry;
      return true;
    }

    return false;
  }

  Future<void> _releaseLock(String lockKey) async {
    _locks.remove(lockKey);
  }

  Future<bool> _isDuplicateSubmission(ScoreValidationData validationData) async {
    final submissionKey = '${_scoreSubmissionsKey}:${validationData.submissionId}';

    // Simulate Redis EXISTS operation
    return _redisStore.containsKey(submissionKey);
  }

  Future<ScoreIntegrityResult> _validateScoreIntegrity(
    ScoreValidationData validationData,
  ) async {
    // Verify hash integrity
    final computedHash = _generateScoreHash(
      validationData.score,
      validationData.userId,
      validationData.submissionId,
    );

    if (computedHash != validationData.hash) {
      return ScoreIntegrityResult.failure('Invalid hash');
    }

    // Check timestamp freshness
    final now = DateTime.now();
    final scoreAge = now.difference(validationData.timestamp);

    if (scoreAge.inMinutes > 5) {
      return ScoreIntegrityResult.failure('Timestamp too old');
    }

    // Validate score bounds
    if (validationData.score < 0 || validationData.score > GameConfig.maxPossibleScore) {
      return ScoreIntegrityResult.failure('Score out of bounds');
    }

    // Check for suspicious patterns
    if (await _isSuspiciousScore(validationData)) {
      return ScoreIntegrityResult.failure('Suspicious score pattern');
    }

    return ScoreIntegrityResult.success();
  }

  Future<bool> _isSuspiciousScore(ScoreValidationData validationData) async {
    // Check validation cache for previous submissions
    final userKey = '${_validationKey}:${validationData.userId}';
    final cachedRecord = _validationCache[userKey];

    if (cachedRecord != null) {
      // Check score progression
      final scoreIncrease = validationData.score - cachedRecord.lastScore;
      final timeDiff = validationData.timestamp.difference(cachedRecord.lastTimestamp);

      // Suspicious if score increased too rapidly
      if (scoreIncrease > 10000 && timeDiff.inMinutes < 1) {
        return true;
      }

      // Suspicious if exact same score as recent submission
      if (scoreIncrease == 0 && timeDiff.inSeconds < 10) {
        return true;
      }
    }

    return false;
  }

  Future<bool> _isRateLimited(String userId) async {
    final rateLimitKey = '${_validationKey}:rate_limit:$userId';

    // Simulate Redis INCR and EXPIRE
    final currentCount = (_redisStore[rateLimitKey] ?? '0').hashCode;
    _redisStore[rateLimitKey] = (currentCount + 1).toString();

    // Check rate limit (max 5 submissions per minute)
    if (currentCount >= 5) {
      return true;
    }

    return false;
  }

  Future<LeaderboardUpdateResult> _atomicLeaderboardUpdate(
    ScoreValidationData validationData,
    String leaderboardId,
  ) async {
    try {
      final leaderboardKey = _generateLeaderboardKey(leaderboardId);

      // Simulate Redis ZADD operation (atomic)
      final member = '${validationData.userId}:${validationData.submissionId}';
      final score = validationData.score;

      // Get current rank before update
      final entries = await _atomicZRevRangeWithScores(leaderboardKey, 0, -1);
      final currentRank = _findPlayerRank(entries, validationData.userId);

      // Add score to sorted set
      _redisStore['${leaderboardKey}:$member'] = score.toString();

      // Update player data
      final playerDataKey = _generatePlayerDataKey(validationData.userId);
      final playerData = {
        'playerName': validationData.playerName,
        'lastScore': validationData.score.toString(),
        'lastTimestamp': validationData.timestamp.millisecondsSinceEpoch.toString(),
        'submissions': '1',
      };
      _redisStore[playerDataKey] = jsonEncode(playerData);

      // Get new rank
      final updatedEntries = await _atomicZRevRangeWithScores(leaderboardKey, 0, -1);
      final newRank = _findPlayerRank(updatedEntries, validationData.userId);

      return LeaderboardUpdateResult.success(
        rank: newRank,
        previousRank: currentRank,
      );

    } catch (e) {
      _logError('Leaderboard update error: $e');
      return LeaderboardUpdateResult.failure('Update error: $e');
    }
  }

  Future<void> _recordSubmission(ScoreValidationData validationData) async {
    final submissionKey = '${_scoreSubmissionsKey}:${validationData.submissionId}';

    // Simulate Redis SET with expiry
    _redisStore[submissionKey] = jsonEncode({
      'userId': validationData.userId,
      'score': validationData.score,
      'playerName': validationData.playerName,
      'timestamp': validationData.timestamp.millisecondsSinceEpoch,
      'hash': validationData.hash,
    });

    // Update validation cache
    final userKey = '${_validationKey}:${validationData.userId}';
    _validationCache[userKey] = ScoreValidationRecord(
      userId: validationData.userId,
      lastScore: validationData.score,
      lastTimestamp: validationData.timestamp,
      submissionCount: 1,
    );
  }

  Future<void> _updatePlayerStatistics(ScoreValidationData validationData) async {
    final statsKey = '${_playerDataKey}:stats:${validationData.userId}';

    // Simulate Redis HINCRBY operations
    final currentStats = _redisStore[statsKey] ?? jsonEncode({
      'totalSubmissions': 0,
      'totalScore': 0,
      'bestScore': 0,
      'firstSubmission': DateTime.now().millisecondsSinceEpoch,
      'lastSubmission': DateTime.now().millisecondsSinceEpoch,
    });

    final stats = jsonDecode(currentStats);
    stats['totalSubmissions']++;
    stats['totalScore'] += validationData.score;
    stats['bestScore'] = max(stats['bestScore'], validationData.score);
    stats['lastSubmission'] = validationData.timestamp.millisecondsSinceEpoch;

    _redisStore[statsKey] = jsonEncode(stats);
  }

  // Redis simulation methods

  void _simulateRedisConnection() {
    // Simulate Redis connection with random availability
    Timer.periodic(Duration(seconds: 30), (timer) {
      _isConnected = Random().nextDouble() < 0.95; // 95% uptime
    });

    // Start as connected
    _isConnected = true;
  }

  Future<List<LeaderboardEntryData>> _atomicZRevRangeWithScores(
    String key,
    int start,
    int end,
  ) async {
    // Simulate Redis ZREVRANGE with scores
    final entries = <LeaderboardEntryData>[];
    final prefix = '$key:';

    // Find all entries for this leaderboard
    final matchingKeys = _redisStore.keys.where((k) => k.startsWith(prefix)).toList();

    // Sort by score (descending)
    matchingKeys.sort((a, b) {
      final scoreA = double.tryParse(_redisStore[a] ?? '0') ?? 0;
      final scoreB = double.tryParse(_redisStore[b] ?? '0') ?? 0;
      return scoreB.compareTo(scoreA);
    });

    // Return requested range
    for (int i = start; i <= end && i < matchingKeys.length; i++) {
      final key = matchingKeys[i];
      final score = double.tryParse(_redisStore[key] ?? '0') ?? 0;
      final parts = key.split(':');

      if (parts.length >= 3) {
        final userId = parts[1];
        final submissionId = parts[2];

        entries.add(LeaderboardEntryData(
          rank: i + 1,
          userId: userId,
          submissionId: submissionId,
          score: score.toInt(),
          playerName: 'Player$userId',
          timestamp: DateTime.now(),
          metadata: {},
        ));
      }
    }

    return entries;
  }

  int? _findPlayerRank(List<LeaderboardEntryData> entries, String userId) {
    for (int i = 0; i < entries.length; i++) {
      if (entries[i].userId == userId) {
        return i + 1;
      }
    }
    return null;
  }

  Future<int> _getPlayerRank(String leaderboardId, String userId) async {
    final entries = await _atomicZRevRangeWithScores(
      _generateLeaderboardKey(leaderboardId),
      0,
      -1,
    );
    return _findPlayerRank(entries, userId) ?? 0;
  }

  Future<int> _getLeaderboardSize(String leaderboardId) async {
    final key = _generateLeaderboardKey(leaderboardId);
    final prefix = '$key:';
    return _redisStore.keys.where((k) => k.startsWith(prefix)).length;
  }

  // Utility methods

  String _generateLockKey(String userId) {
    return '${_validationKey}:lock:$userId';
  }

  String _generateLeaderboardKey(String leaderboardId) {
    return '${_leaderboardKey}:$leaderboardId';
  }

  String _generatePlayerDataKey(String userId) {
    return '${_playerDataKey}:$userId';
  }

  String _generateScoreHash(int score, String userId, String submissionId) {
    final data = '$score-$userId-$submissionId-${GameConfig.leaderboardSecret}';
    return sha256.convert(utf8.encode(data)).toString();
  }

  void _logError(String message) {
    print('[RedisValidator] ERROR: $message');
  }

  void dispose() {
    _locks.clear();
    _validationCache.clear();
    _redisStore.clear();
    _expiryTimes.clear();
  }
}

// Data structures for Redis operations

class LeaderboardEntryData {
  final int rank;
  final String userId;
  final String submissionId;
  final int score;
  final String playerName;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  LeaderboardEntryData({
    required this.rank,
    required this.userId,
    required this.submissionId,
    required this.score,
    required this.playerName,
    required this.timestamp,
    required this.metadata,
  });
}

class ScoreValidationRecord {
  final String userId;
  final int lastScore;
  final DateTime lastTimestamp;
  final int submissionCount;

  ScoreValidationRecord({
    required this.userId,
    required this.lastScore,
    required this.lastTimestamp,
    required this.submissionCount,
  });
}

// Result classes

class RedisValidationResult {
  final bool success;
  final int? rank;
  final String? leaderboardId;
  final String? errorMessage;
  final bool canRetry;

  RedisValidationResult.success({
    this.rank,
    this.leaderboardId,
  }) : success = true,
        errorMessage = null,
        canRetry = false;

  RedisValidationResult.failure(this.errorMessage, {this.canRetry = false})
      : success = false,
        rank = null,
        leaderboardId = null;
}

class RedisLeaderboardResult {
  final bool success;
  final List<LeaderboardEntry> entries;
  final int? playerRank;
  final int? totalPlayers;
  final bool fromCache;
  final String? errorMessage;

  RedisLeaderboardResult.success({
    required this.entries,
    this.playerRank,
    this.totalPlayers,
    this.fromCache = false,
  }) : success = true,
        errorMessage = null;

  RedisLeaderboardResult.failure(this.errorMessage)
      : success = false,
        entries = [],
        playerRank = null,
        totalPlayers = null,
        fromCache = false;
}

class LeaderboardUpdateResult {
  final bool success;
  final int? rank;
  final int? previousRank;
  final String? error;
  final bool canRetry;

  LeaderboardUpdateResult.success({
    required this.rank,
    this.previousRank,
  }) : success = true,
        error = null,
        canRetry = false;

  LeaderboardUpdateResult.failure(this.error, {this.canRetry = false})
      : success = false,
        rank = null,
        previousRank = null;
}

class ScoreIntegrityResult {
  final bool isValid;
  final String? reason;

  ScoreIntegrityResult.success()
      : isValid = true,
        reason = null;

  ScoreIntegrityResult.failure(this.reason)
      : isValid = false;
}

class BatchValidationResult {
  final bool success;
  final Map<String, RedisValidationResult>? results;
  final String? errorMessage;

  BatchValidationResult.success(this.results)
      : success = true,
        errorMessage = null;

  BatchValidationResult.failure(this.errorMessage)
      : success = false,
        results = null;
}

const String _allTimeLeaderboardId = 'alltime';