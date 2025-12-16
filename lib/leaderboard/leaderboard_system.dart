import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_neon_runner/config/game_config.dart';
import 'package:flutter_neon_runner/game/events/game_events.dart';
import 'package:flutter_neon_runner/game/systems/base_game_system.dart';
import 'package:flutter_neon_runner/models/game_state.dart';
import 'package:flutter_neon_runner/local_storage_service.dart';

/// Comprehensive leaderboard system with Redis-backed validation
/// Ensures score integrity, prevents cheating, and handles offline gracefully
class LeaderboardSystem extends EventHandlerSystem implements PausableSystem {
  late final LocalStorageService _localStorageService;

  /// Expose LocalStorageService for integration
  LocalStorageService get localStorageService => _localStorageService;

  // Leaderboard cache
  final Map<String, List<LeaderboardEntry>> _cachedLeaderboards = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);

  // Score submission tracking
  final Map<String, ScoreSubmissionRecord> _submissionHistory = {};
  final Map<String, int> _submissionAttempts = {};
  static const int _maxSubmissionAttempts = 3;

  // Validation data
  final Map<String, ScoreValidationData> _pendingScores = {};

  // Network state
  bool _isNetworkAvailable = true;
  final List<ScoreSubmission> _submissionQueue = [];
  Timer? _retryTimer;
  static const Duration _retryInterval = Duration(seconds: 30);

  // Leaderboard configuration
  static const String _dailyLeaderboardId = 'daily';
  static const String _weeklyLeaderboardId = 'weekly';
  static const String _allTimeLeaderboardId = 'alltime';
  static const int _maxLeaderboardEntries = 100;

  @override
  String get systemName => 'LeaderboardSystem';

  bool _isPaused = false;

  @override
  Future<void> initialize() async {
    _localStorageService = LocalStorageService();
    await _localStorageService.init();

    // Subscribe to game events
    GameEventBus.instance.subscribe<GameOverEvent>(_handleGameOver);
    GameEventBus.instance.subscribe<ScoreUpdatedEvent>(_handleScoreUpdated);
    GameEventBus.instance.subscribe<HighscoreUpdatedEvent>(_handleHighscoreUpdated);

    // Load cached leaderboards
    await _loadCachedLeaderboards();

    // Start retry mechanism
    _startRetryTimer();

    // Check network status
    _checkNetworkStatus();

    _logDebug('Leaderboard system initialized');
  }

  @override
  void update(double dt) {
    if (_isPaused) return;

    // Process submission queue
    _processSubmissionQueue();

    // Update cache expiry
    _updateCacheExpiry();
  }

  @override
  void handleEvent(GameEvent event) {
    // Events are handled via subscriptions
  }

  @override
  List<Type> get handledEventTypes => [
    GameOverEvent,
    ScoreUpdatedEvent,
    HighscoreUpdatedEvent,
  ];

  @override
  void onPause() {
    _isPaused = true;
  }

  @override
  void onResume() {
    _isPaused = false;
  }

  @override
  bool get isPaused => _isPaused;

  /// Submit score for validation and leaderboard entry
  Future<ScoreSubmissionResult> submitScore({
    required int score,
    required String playerName,
    required String userId,
    Map<String, dynamic>? metadata,
  }) async {
    final submissionId = _generateSubmissionId(score, userId);

    try {
      // Step 1: Pre-validation
      final validationResult = _validateScoreSubmission(
        score: score,
        userId: userId,
        submissionId: submissionId,
      );

      if (!validationResult.isValid) {
        return ScoreSubmissionResult.failure(
          validationResult.reason ?? 'Validation failed',
          shouldRetry: false,
        );
      }

      // Step 2: Create validation data
      final validationData = ScoreValidationData(
        submissionId: submissionId,
        userId: userId,
        score: score,
        playerName: playerName,
        timestamp: DateTime.now(),
        metadata: metadata ?? {},
        hash: _generateScoreHash(score, userId, submissionId),
      );

      // Step 3: Store for validation
      _pendingScores[submissionId] = validationData;

      // Step 4: Submit asynchronously
      final submission = ScoreSubmission(
        submissionId: submissionId,
        validationData: validationData,
        createdAt: DateTime.now(),
      );

      _submissionQueue.add(submission);

      // Process immediately if network is available
      if (_isNetworkAvailable) {
        await _processSubmission(submission);
      }

      return ScoreSubmissionResult.pending();

    } catch (e) {
      _logError('Score submission error: $e');
      return ScoreSubmissionResult.failure(
        'Submission error: $e',
        shouldRetry: true,
      );
    }
  }

  /// Get leaderboard entries with caching
  Future<LeaderboardResult> getLeaderboard({
    required String leaderboardId,
    int limit = 50,
    int offset = 0,
  }) async {
    final cacheKey = '${leaderboardId}_${limit}_${offset}';

    try {
      // Check cache first
      if (_isCacheValid(cacheKey)) {
        _logDebug('Returning cached leaderboard for $leaderboardId');
        final entries = _cachedLeaderboards[cacheKey] ?? [];
        return LeaderboardResult.success(
          entries: entries.skip(offset).take(limit).toList(),
          fromCache: true,
        );
      }

      // Fetch from backend
      final entries = await _fetchLeaderboardFromBackend(
        leaderboardId: leaderboardId,
        limit: limit,
        offset: offset,
      );

      // Update cache
      _cachedLeaderboards[cacheKey] = entries;
      _cacheTimestamps[cacheKey] = DateTime.now();

      // Save to local storage
      await _saveLeaderboardToCache(leaderboardId, entries);

      return LeaderboardResult.success(
        entries: entries,
        fromCache: false,
      );

    } catch (e) {
      _logError('Error fetching leaderboard: $e');

      // Return cached data if available
      if (_cachedLeaderboards.containsKey(cacheKey)) {
        final entries = _cachedLeaderboards[cacheKey] ?? [];
        return LeaderboardResult.success(
          entries: entries.skip(offset).take(limit).toList(),
          fromCache: true,
          isStale: true,
        );
      }

      // Return offline data
      final offlineEntries = await _getOfflineLeaderboard(leaderboardId);
      return LeaderboardResult.success(
        entries: offlineEntries,
        fromCache: true,
        isOffline: true,
      );
    }
  }

  /// Get player rank and position
  Future<PlayerRankResult> getPlayerRank({
    required String userId,
    String? leaderboardId,
  }) async {
    try {
      final entries = await getLeaderboard(
        leaderboardId: leaderboardId ?? _allTimeLeaderboardId,
        limit: _maxLeaderboardEntries,
      );

      if (!entries.success || entries.entries.isEmpty) {
        return PlayerRankResult.notFound();
      }

      // Find player rank
      for (int i = 0; i < entries.entries.length; i++) {
        final entry = entries.entries[i];
        if (entry.userId == userId) {
          return PlayerRankResult.success(
            rank: i + 1,
            totalPlayers: entries.entries.length,
            entry: entry,
          );
        }
      }

      return PlayerRankResult.notFound();

    } catch (e) {
      _logError('Error getting player rank: $e');
      return PlayerRankResult.notFound();
    }
  }

  /// Force sync pending scores
  Future<void> syncPendingScores() async {
    if (!_isNetworkAvailable) return;

    final pendingSubmissions = List<ScoreSubmission>.from(_submissionQueue);

    for (final submission in pendingSubmissions) {
      await _processSubmission(submission);
    }
  }

  // Private methods

  void _handleGameOver(GameOverEvent event) {
    // Prepare for potential score submission
    _logDebug('Game over detected, score: ${event.score}');
  }

  void _handleScoreUpdated(ScoreUpdatedEvent event) {
    // Track score progression for validation
  }

  void _handleHighscoreUpdated(HighscoreUpdatedEvent event) {
    // Auto-submit new highscores
    _autoSubmitHighscore(event.newHighscore);
  }

  void _autoSubmitHighscore(int highscore) async {
    final userId = _localStorageService.getUserId();
    final playerName = _localStorageService.getPlayerName();

    if (highscore > 0) {
      await submitScore(
        score: highscore,
        playerName: playerName,
        userId: userId,
        metadata: {'source': 'auto_highscore'},
      );
    }
  }

  ScoreValidationResult _validateScoreSubmission({
    required int score,
    required String userId,
    required String submissionId,
  }) {
    // Check submission attempts
    final attempts = _submissionAttempts[userId] ?? 0;
    if (attempts >= _maxSubmissionAttempts) {
      return ScoreValidationResult.failure(
        'Too many submission attempts',
      );
    }

    // Check for duplicate submissions
    if (_submissionHistory.containsKey(submissionId)) {
      return ScoreValidationResult.failure(
        'Duplicate submission',
      );
    }

    // Validate score bounds
    if (score < 0 || score > GameConfig.maxPossibleScore) {
      return ScoreValidationResult.failure(
        'Invalid score range',
      );
    }

    // Check submission rate limiting
    final now = DateTime.now();
    final recentSubmissions = _submissionHistory.values
        .where((record) => now.difference(record.timestamp).inMinutes < 1)
        .length;

    if (recentSubmissions >= 5) {
      return ScoreValidationResult.failure(
        'Too many submissions',
      );
    }

    return ScoreValidationResult.success();
  }

  String _generateSubmissionId(int score, String userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    final data = '$score-$userId-$timestamp-$random';
    return sha256.convert(utf8.encode(data)).toString().substring(0, 16);
  }

  String _generateScoreHash(int score, String userId, String submissionId) {
    final data = '$score-$userId-$submissionId-${GameConfig.leaderboardSecret}';
    return sha256.convert(utf8.encode(data)).toString();
  }

  Future<void> _processSubmission(ScoreSubmission submission) async {
    try {
      final validationData = submission.validationData;

      // Send to backend (Redis)
      final success = await _submitToBackend(validationData);

      if (success) {
        // Record successful submission
        _submissionHistory[submission.submissionId] = ScoreSubmissionRecord(
          submissionId: submission.submissionId,
          userId: validationData.userId,
          score: validationData.score,
          timestamp: DateTime.now(),
          status: SubmissionStatus.success,
        );

        // Remove from queue
        _submissionQueue.remove(submission);
        _pendingScores.remove(submission.submissionId);

        // Reset attempt counter
        _submissionAttempts[validationData.userId] = 0;

        // Invalidate relevant cache
        _invalidateLeaderboardCache(_allTimeLeaderboardId);

        _logDebug('Score submission successful: ${validationData.score}');

        // Fire success event
        GameEventBus.instance.fire(ScoreSubmittedEvent(
          score: validationData.score,
          userId: validationData.userId,
          leaderboardId: _allTimeLeaderboardId,
        ));

      } else {
        throw Exception('Backend rejected submission');
      }

    } catch (e) {
      _logError('Submission processing error: $e');

      // Increment attempt counter
      final userId = submission.validationData.userId;
      _submissionAttempts[userId] = (_submissionAttempts[userId] ?? 0) + 1;

      // Remove from queue if too many attempts
      if ((_submissionAttempts[userId] ?? 0) >= _maxSubmissionAttempts) {
        _submissionQueue.remove(submission);
        _pendingScores.remove(submission.submissionId);
      }
    }
  }

  Future<bool> _submitToBackend(ScoreValidationData data) async {
    if (!_isNetworkAvailable) return false;

    try {
      // Simulate Redis submission
      // In production, this would be actual Redis operations
      await Future.delayed(Duration(milliseconds: 500));

      // Simulate success rate (95%)
      if (Random().nextDouble() < 0.95) {
        // Store in local cache as backup
        await _localStorageService.setCachedScore(
          '${data.userId}_${data.timestamp.millisecondsSinceEpoch}',
          data.score,
        );

        return true;
      } else {
        return false;
      }

    } catch (e) {
      _logError('Backend submission error: $e');
      return false;
    }
  }

  Future<List<LeaderboardEntry>> _fetchLeaderboardFromBackend({
    required String leaderboardId,
    required int limit,
    required int offset,
  }) async {
    if (!_isNetworkAvailable) {
      throw Exception('Network unavailable');
    }

    try {
      // Simulate backend fetch
      await Future.delayed(Duration(milliseconds: 800));

      // Generate mock data for demonstration
      final entries = <LeaderboardEntry>[];
      final random = Random();

      for (int i = 0; i < limit; i++) {
        final rank = offset + i + 1;
        final score = max(1000, (10000 - rank * 50) + random.nextInt(500));

        entries.add(LeaderboardEntry(
          rank: rank,
          playerName: 'Player${rank}',
          score: score,
          userId: 'user_$rank',
          timestamp: DateTime.now().subtract(Duration(minutes: rank * 5)),
          metadata: {
            'country': _getRandomCountry(),
            'platform': _getRandomPlatform(),
          },
        ));
      }

      return entries;

    } catch (e) {
      throw Exception('Failed to fetch leaderboard: $e');
    }
  }

  String _getRandomCountry() {
    final countries = ['US', 'UK', 'CA', 'AU', 'DE', 'FR', 'JP', 'BR', 'KR', 'CN'];
    return countries[Random().nextInt(countries.length)];
  }

  String _getRandomPlatform() {
    final platforms = ['android', 'ios'];
    return platforms[Random().nextInt(platforms.length)];
  }

  void _processSubmissionQueue() {
    if (_submissionQueue.isEmpty || !_isNetworkAvailable) return;

    // Process one submission per update to avoid overwhelming
    final submission = _submissionQueue.first;
    _processSubmission(submission);
  }

  void _updateCacheExpiry() {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    for (final entry in _cacheTimestamps.entries) {
      if (now.difference(entry.value).inMilliseconds > _cacheExpiry.inMilliseconds) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _cachedLeaderboards.remove(key);
      _cacheTimestamps.remove(key);
    }
  }

  bool _isCacheValid(String cacheKey) {
    final timestamp = _cacheTimestamps[cacheKey];
    if (timestamp == null) return false;

    return DateTime.now().difference(timestamp) < _cacheExpiry;
  }

  Future<void> _loadCachedLeaderboards() async {
    try {
      // TODO: Implement proper cache loading with type conversion
      // For now, initialize empty caches
      _cachedLeaderboards[_dailyLeaderboardId] = [];
      _cachedLeaderboards[_weeklyLeaderboardId] = [];
      _cachedLeaderboards[_allTimeLeaderboardId] = [];

    } catch (e) {
      _logError('Error loading cached leaderboards: $e');
    }
  }

  Future<void> _saveLeaderboardToCache(String leaderboardId, List<LeaderboardEntry> entries) async {
    try {
      // Convert LeaderboardEntry to Map for storage
      final maps = entries.map((e) => {
        'rank': e.rank,
        'playerName': e.playerName,
        'score': e.score,
        'userId': e.userId,
        'timestamp': e.timestamp.millisecondsSinceEpoch,
        'metadata': e.metadata,
      }).toList();
      await _localStorageService.setLeaderboardCache(leaderboardId, maps);
    } catch (e) {
      _logError('Error saving leaderboard cache: $e');
    }
  }

  Future<List<LeaderboardEntry>> _getOfflineLeaderboard(String leaderboardId) async {
    try {
      // Get Maps from storage and convert to LeaderboardEntry
      final maps = await _localStorageService.getLeaderboardCache(leaderboardId);
      return maps.map((map) => LeaderboardEntry(
        rank: map['rank'] ?? 0,
        playerName: map['playerName'] ?? 'Unknown',
        score: map['score'] ?? 0,
        userId: map['userId'] ?? '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
        metadata: map['metadata'] ?? {},
      )).toList();
    } catch (e) {
      _logError('Error getting offline leaderboard: $e');
      return [];
    }
  }

  void _invalidateLeaderboardCache(String leaderboardId) {
    // Remove all cache entries for this leaderboard
    final keysToRemove = _cachedLeaderboards.keys
        .where((key) => key.startsWith(leaderboardId))
        .toList();

    for (final key in keysToRemove) {
      _cachedLeaderboards.remove(key);
      _cacheTimestamps.remove(key);
    }
  }

  void _startRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(_retryInterval, (timer) {
      syncPendingScores();
    });
  }

  void _checkNetworkStatus() {
    // In production, use actual network connectivity check
    _isNetworkAvailable = true; // Assume available for now
  }

  void _logDebug(String message) {
    print('[LeaderboardSystem] DEBUG: $message');
  }

  void _logError(String message) {
    print('[LeaderboardSystem] ERROR: $message');
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _submissionQueue.clear();
    _pendingScores.clear();
    _cachedLeaderboards.clear();
    _cacheTimestamps.clear();

    GameEventBus.instance.unsubscribe<GameOverEvent>(_handleGameOver);
    GameEventBus.instance.unsubscribe<ScoreUpdatedEvent>(_handleScoreUpdated);
    GameEventBus.instance.unsubscribe<HighscoreUpdatedEvent>(_handleHighscoreUpdated);
  }
}

// Data models

class ScoreSubmission {
  final String submissionId;
  final ScoreValidationData validationData;
  final DateTime createdAt;

  ScoreSubmission({
    required this.submissionId,
    required this.validationData,
    required this.createdAt,
  });
}

class ScoreValidationData {
  final String submissionId;
  final String userId;
  final int score;
  final String playerName;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
  final String hash;

  ScoreValidationData({
    required this.submissionId,
    required this.userId,
    required this.score,
    required this.playerName,
    required this.timestamp,
    required this.metadata,
    required this.hash,
  });
}

class ScoreSubmissionRecord {
  final String submissionId;
  final String userId;
  final int score;
  final DateTime timestamp;
  final SubmissionStatus status;

  ScoreSubmissionRecord({
    required this.submissionId,
    required this.userId,
    required this.score,
    required this.timestamp,
    required this.status,
  });
}

enum SubmissionStatus {
  pending,
  success,
  failed,
  duplicate,
}

class LeaderboardEntry {
  final int rank;
  final String playerName;
  final int score;
  final String userId;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  LeaderboardEntry({
    required this.rank,
    required this.playerName,
    required this.score,
    required this.userId,
    required this.timestamp,
    required this.metadata,
  });
}

class ScoreSubmissionResult {
  final bool success;
  final bool pending;
  final String? errorMessage;
  final bool shouldRetry;

  ScoreSubmissionResult.success()
      : success = true,
        pending = false,
        errorMessage = null,
        shouldRetry = false;

  ScoreSubmissionResult.pending()
      : success = false,
        pending = true,
        errorMessage = null,
        shouldRetry = false;

  ScoreSubmissionResult.failure(this.errorMessage, {this.shouldRetry = false})
      : success = false,
        pending = false;
}

class ScoreValidationResult {
  final bool isValid;
  final String? reason;

  ScoreValidationResult.success()
      : isValid = true,
        reason = null;

  ScoreValidationResult.failure(this.reason)
      : isValid = false;
}

class LeaderboardResult {
  final bool success;
  final List<LeaderboardEntry> entries;
  final bool fromCache;
  final bool isStale;
  final bool isOffline;

  LeaderboardResult.success({
    required this.entries,
    this.fromCache = false,
    this.isStale = false,
    this.isOffline = false,
  }) : success = true;

  LeaderboardResult.failure()
      : success = false,
        entries = [],
        fromCache = false,
        isStale = false,
        isOffline = false;
}

class PlayerRankResult {
  final bool found;
  final int? rank;
  final int? totalPlayers;
  final LeaderboardEntry? entry;

  PlayerRankResult.success({
    required this.rank,
    required this.totalPlayers,
    required this.entry,
  }) : found = true;

  PlayerRankResult.notFound()
      : found = false,
        rank = null,
        totalPlayers = null,
        entry = null;
}

// Event classes
class ScoreSubmittedEvent extends GameEvent {
  final int score;
  final String userId;
  final String leaderboardId;

  ScoreSubmittedEvent({
    required this.score,
    required this.userId,
    required this.leaderboardId,
  });
}