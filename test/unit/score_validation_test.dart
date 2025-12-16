import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_neon_runner/leaderboard/score_validator.dart';
import 'package:flutter_neon_runner/game/components/player_component.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

void main() {
  group('Score Validation Tests', () {
    late ScoreValidator scoreValidator;
    late MockPlayerComponent player;

    setUp(() {
      scoreValidator = ScoreValidator(secretKey: 'test_secret_key');
      player = MockPlayerComponent();
    });

    test('should validate legitimate score increases', () {
      // Arrange
      player.score = 100;
      player.position.setValues(100, 200);
      player.lastScoreUpdateTime = DateTime.now().subtract(Duration(seconds: 5));

      // Act
      final validation = scoreValidator.validateScoreIncrease(
        oldScore: 0,
        newScore: 100,
        player: player,
        timeDiff: Duration(seconds: 5),
      );

      // Assert
      expect(validation.isValid, isTrue);
      expect(validation.reason, isNull);
    });

    test('should reject impossible score increases', () {
      // Arrange
      player.score = 10000;
      player.position.setValues(100, 200);
      player.lastScoreUpdateTime = DateTime.now().subtract(Duration(seconds: 1));

      // Act
      final validation = scoreValidator.validateScoreIncrease(
        oldScore: 0,
        newScore: 10000,
        player: player,
        timeDiff: Duration(seconds: 1),
      );

      // Assert
      expect(validation.isValid, isFalse);
      expect(validation.reason, contains('impossible score increase'));
    });

    test('should reject negative scores', () {
      // Arrange
      player.score = -100;

      // Act
      final validation = scoreValidator.validateScore(
        score: -100,
        player: player,
      );

      // Assert
      expect(validation.isValid, isFalse);
      expect(validation.reason, contains('negative score'));
    });

    test('should reject scores above maximum', () {
      // Arrange
      player.score = 1000000; // Above max score

      // Act
      final validation = scoreValidator.validateScore(
        score: 1000000,
        player: player,
      );

      // Assert
      expect(validation.isValid, isFalse);
      expect(validation.reason, contains('exceeds maximum'));
    });

    test('should validate score integrity hash', () {
      // Arrange
      final score = 5000;
      final userId = 'test_user_123';
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Act
      final hash = scoreValidator.generateScoreHash(score, userId, timestamp);
      final isValid = scoreValidator.validateScoreHash(score, userId, timestamp, hash);

      // Assert
      expect(isValid, isTrue);
    });

    test('should reject invalid score hash', () {
      // Arrange
      final score = 5000;
      final userId = 'test_user_123';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final invalidHash = 'invalid_hash';

      // Act
      final isValid = scoreValidator.validateScoreHash(score, userId, timestamp, invalidHash);

      // Assert
      expect(isValid, isFalse);
    });

    test('should detect score manipulation attempts', () {
      // Arrange
      player.score = 1000;
      player.lastScoreUpdateTime = DateTime.now().subtract(Duration(seconds: 10));

      // Simulate impossible score jump
      final validation = scoreValidator.validateScoreIncrease(
        oldScore: 1000,
        newScore: 50000,
        player: player,
        timeDiff: Duration(seconds: 10),
      );

      // Assert
      expect(validation.isValid, isFalse);
      expect(validation.reason, contains('manipulation'));
    });

    test('should validate score multipliers', () {
      // Arrange
      player.multiplier = 2;
      player.hasMultiplier = true;
      player.lastMultiplierTime = DateTime.now().subtract(Duration(seconds: 5));

      // Act
      final validation = scoreValidator.validateMultiplier(
        multiplier: 2,
        player: player,
      );

      // Assert
      expect(validation.isValid, isTrue);
    });

    test('should reject invalid multipliers', () {
      // Arrange
      player.multiplier = 10; // Too high

      // Act
      final validation = scoreValidator.validateMultiplier(
        multiplier: 10,
        player: player,
      );

      // Assert
      expect(validation.isValid, isFalse);
      expect(validation.reason, contains('invalid multiplier'));
    });

    test('should track score history consistency', () {
      // Arrange
      final scoreHistory = [
        ScoreRecord(score: 0, timestamp: DateTime.now().subtract(Duration(seconds: 30))),
        ScoreRecord(score: 100, timestamp: DateTime.now().subtract(Duration(seconds: 25))),
        ScoreRecord(score: 250, timestamp: DateTime.now().subtract(Duration(seconds: 20))),
        ScoreRecord(score: 450, timestamp: DateTime.now().subtract(Duration(seconds: 15))),
        ScoreRecord(score: 700, timestamp: DateTime.now().subtract(Duration(seconds: 10))),
      ];

      // Act
      final validation = scoreValidator.validateScoreHistory(scoreHistory);

      // Assert
      expect(validation.isValid, isTrue);
    });

    test('should detect inconsistent score history', () {
      // Arrange
      final scoreHistory = [
        ScoreRecord(score: 0, timestamp: DateTime.now().subtract(Duration(seconds: 30))),
        ScoreRecord(score: 100, timestamp: DateTime.now().subtract(Duration(seconds: 25))),
        ScoreRecord(score: 250, timestamp: DateTime.now().subtract(Duration(seconds: 20))),
        ScoreRecord(score: 100, timestamp: DateTime.now().subtract(Duration(seconds: 15))), // Decrease!
        ScoreRecord(score: 700, timestamp: DateTime.now().subtract(Duration(seconds: 10))),
      ];

      // Act
      final validation = scoreValidator.validateScoreHistory(scoreHistory);

      // Assert
      expect(validation.isValid, isFalse);
      expect(validation.reason, contains('inconsistent'));
    });

    test('should validate score submission data', () {
      // Arrange
      final submissionData = ScoreSubmissionData(
        score: 5000,
        userId: 'player123',
        playerName: 'TestPlayer',
        timestamp: DateTime.now(),
        hash: '',
      );

      // Generate proper hash
      submissionData.hash = scoreValidator.generateScoreHash(
        submissionData.score,
        submissionData.userId,
        submissionData.timestamp.millisecondsSinceEpoch,
      );

      // Act
      final validation = scoreValidator.validateSubmission(submissionData);

      // Assert
      expect(validation.isValid, isTrue);
    });

    test('should detect duplicate submissions', () {
      // Arrange
      final submissionId = 'unique_submission_123';

      // Act
      scoreValidator.recordSubmission(submissionId);
      final isDuplicate = scoreValidator.isDuplicateSubmission(submissionId);

      // Assert
      expect(isDuplicate, isTrue);
    });

    test('should validate scoring rate limits', () {
      // Arrange
      final userId = 'player123';

      // Act - Submit multiple scores rapidly
      for (int i = 0; i < 5; i++) {
        final canSubmit = scoreValidator.canSubmitScore(userId);
        if (i < 5) {
          expect(canSubmit, isTrue);
          scoreValidator.recordSubmission('${userId}_${i}');
        }
      }

      // Should be rate limited now
      final canSubmit = scoreValidator.canSubmitScore(userId);
      expect(canSubmit, isFalse);
    });

    test('should validate power-up influence on score', () {
      // Arrange
      player.hasShield = true;
      player.hasMultiplier = true;
      player.multiplier = 2;

      // Act
      final validation = scoreValidator.validatePowerUpScore(
        baseScore: 100,
        finalScore: 200,
        player: player,
      );

      // Assert
      expect(validation.isValid, isTrue);
    });

    test('should detect unreasonable power-up bonuses', () {
      // Arrange
      player.hasMultiplier = true;
      player.multiplier = 2; // Only 2x multiplier

      // Act - Score suggests 10x multiplier
      final validation = scoreValidator.validatePowerUpScore(
        baseScore: 100,
        finalScore: 1000,
        player: player,
      );

      // Assert
      expect(validation.isValid, isFalse);
      expect(validation.reason, contains('unreasonable'));
    });

    test('should maintain session integrity', () {
      // Arrange
      final sessionId = 'session_123';
      scoreValidator.startSession(sessionId);

      // Act
      final validation = scoreValidator.validateSessionScore(
        sessionId: sessionId,
        score: 1000,
        duration: Duration(minutes: 5),
      );

      // Assert
      expect(validation.isValid, isTrue);
    });

    test('should detect session violations', () {
      // Arrange
      final sessionId = 'session_123';
      scoreValidator.startSession(sessionId);

      // Act - Impossible score in short time
      final validation = scoreValidator.validateSessionScore(
        sessionId: sessionId,
        score: 100000,
        duration: Duration(seconds: 5),
      );

      // Assert
      expect(validation.isValid, isFalse);
      expect(validation.reason, contains('session violation'));
    });
  });
}

// Mock classes and data structures
class MockPlayerComponent {
  int score = 0;
  int multiplier = 1;
  bool hasMultiplier = false;
  bool hasShield = false;
  DateTime lastScoreUpdateTime = DateTime.now();
  DateTime lastMultiplierTime = DateTime.now();
  final position = Vector2.zero();
}

class ScoreRecord {
  final int score;
  final DateTime timestamp;

  ScoreRecord({required this.score, required this.timestamp});
}

class ScoreSubmissionData {
  final int score;
  final String userId;
  final String playerName;
  final DateTime timestamp;
  String hash;

  ScoreSubmissionData({
    required this.score,
    required this.userId,
    required this.playerName,
    required this.timestamp,
    required this.hash,
  });
}

class ScoreValidationResult {
  final bool isValid;
  final String? reason;

  ScoreValidationResult({required this.isValid, this.reason});
}

// Simplified ScoreValidator for testing
class ScoreValidator {
  final String secretKey;
  final Set<String> _submittedIds = {};
  final Map<String, List<DateTime>> _submissionsByUser = {};
  final Map<String, DateTime> _sessionStarts = {};

  static const int maxScore = 999999;
  static const int maxMultiplier = 5;
  static const int maxSubmissionsPerMinute = 5;

  ScoreValidator({required this.secretKey});

  String generateScoreHash(int score, String userId, int timestamp) {
    final data = '$score-$userId-$timestamp-$secretKey';
    return sha256.convert(utf8.encode(data)).toString();
  }

  bool validateScoreHash(int score, String userId, int timestamp, String hash) {
    final expectedHash = generateScoreHash(score, userId, timestamp);
    return hash == expectedHash;
  }

  ScoreValidationResult validateScore({
    required int score,
    required MockPlayerComponent player,
  }) {
    if (score < 0) {
      return ScoreValidationResult(
        isValid: false,
        reason: 'Negative score detected',
      );
    }

    if (score > maxScore) {
      return ScoreValidationResult(
        isValid: false,
        reason: 'Score exceeds maximum allowed value',
      );
    }

    return ScoreValidationResult(isValid: true);
  }

  ScoreValidationResult validateScoreIncrease({
    required int oldScore,
    required int newScore,
    required MockPlayerComponent player,
    required Duration timeDiff,
  }) {
    final increase = newScore - oldScore;

    if (increase < 0) {
      return ScoreValidationResult(
        isValid: false,
        reason: 'Score decrease detected',
      );
    }

    // Calculate reasonable maximum score increase
    final maxIncrease = _calculateMaxScoreIncrease(timeDiff, player);

    if (increase > maxIncrease) {
      return ScoreValidationResult(
        isValid: false,
        reason: 'Impossible score increase detected: $increase > $maxIncrease',
      );
    }

    return ScoreValidationResult(isValid: true);
  }

  int _calculateMaxScoreIncrease(Duration timeDiff, MockPlayerComponent player) {
    // Base scoring rate: 100 points per second
    double baseRate = 100.0;

    // Apply multiplier if active
    if (player.hasMultiplier) {
      baseRate *= player.multiplier;
    }

    // Add buffer for legitimate variations
    final timeSeconds = timeDiff.inMilliseconds / 1000.0;
    final maxIncrease = (baseRate * timeSeconds * 1.5).round();

    return maxIncrease;
  }

  ScoreValidationResult validateMultiplier({
    required int multiplier,
    required MockPlayerComponent player,
  }) {
    if (multiplier < 1) {
      return ScoreValidationResult(
        isValid: false,
        reason: 'Multiplier cannot be less than 1',
      );
    }

    if (multiplier > maxMultiplier) {
      return ScoreValidationResult(
        isValid: false,
        reason: 'Multiplier exceeds maximum allowed value',
      );
    }

    return ScoreValidationResult(isValid: true);
  }

  ScoreValidationResult validateScoreHistory(List<ScoreRecord> history) {
    if (history.isEmpty) {
      return ScoreValidationResult(isValid: true);
    }

    for (int i = 1; i < history.length; i++) {
      final prev = history[i - 1];
      final curr = history[i];

      if (curr.score < prev.score) {
        return ScoreValidationResult(
          isValid: false,
          reason: 'Score history is inconsistent: score decreased',
        );
      }

      if (curr.timestamp.isBefore(prev.timestamp)) {
        return ScoreValidationResult(
          isValid: false,
          reason: 'Score history timestamps are out of order',
        );
      }
    }

    return ScoreValidationResult(isValid: true);
  }

  ScoreValidationResult validateSubmission(ScoreSubmissionData data) {
    // Validate hash
    final expectedHash = generateScoreHash(
      data.score,
      data.userId,
      data.timestamp.millisecondsSinceEpoch,
    );

    if (data.hash != expectedHash) {
      return ScoreValidationResult(
        isValid: false,
        reason: 'Invalid score hash',
      );
    }

    return validateScore(score: data.score, player: MockPlayerComponent());
  }

  void recordSubmission(String submissionId) {
    _submittedIds.add(submissionId);
  }

  bool isDuplicateSubmission(String submissionId) {
    return _submittedIds.contains(submissionId);
  }

  bool canSubmitScore(String userId) {
    final now = DateTime.now();
    final userSubmissions = _submissionsByUser[userId] ?? [];

    // Remove submissions older than 1 minute
    userSubmissions.removeWhere((time) =>
      now.difference(time).inMinutes > 0
    );

    // Check if under rate limit
    if (userSubmissions.length >= maxSubmissionsPerMinute) {
      return false;
    }

    return true;
  }

  ScoreValidationResult validatePowerUpScore({
    required int baseScore,
    required int finalScore,
    required MockPlayerComponent player,
  }) {
    if (!player.hasMultiplier && finalScore != baseScore) {
      return ScoreValidationResult(
        isValid: false,
        reason: 'Score changed without active multiplier',
      );
    }

    if (player.hasMultiplier) {
      final expectedScore = baseScore * player.multiplier;
      if (finalScore != expectedScore) {
        return ScoreValidationResult(
          isValid: false,
          reason: 'Unreasonable power-up score bonus',
        );
      }
    }

    return ScoreValidationResult(isValid: true);
  }

  void startSession(String sessionId) {
    _sessionStarts[sessionId] = DateTime.now();
  }

  ScoreValidationResult validateSessionScore({
    required String sessionId,
    required int score,
    required Duration duration,
  }) {
    final sessionStart = _sessionStarts[sessionId];
    if (sessionStart == null) {
      return ScoreValidationResult(
        isValid: false,
        reason: 'Session not found',
      );
    }

    // Calculate reasonable maximum score for session
    final maxSessionScore = _calculateMaxSessionScore(duration);

    if (score > maxSessionScore) {
      return ScoreValidationResult(
        isValid: false,
        reason: 'Session violation: score too high for duration',
      );
    }

    return ScoreValidationResult(isValid: true);
  }

  int _calculateMaxSessionScore(Duration duration) {
    // Maximum reasonable scoring rate with all power-ups
    const maxScoringRate = 500; // points per second
    final seconds = duration.inMilliseconds / 1000.0;
    return (maxScoringRate * seconds).round();
  }
}

// Simplified Vector2 for testing
class Vector2 {
  double x = 0.0;
  double y = 0.0;

  Vector2.zero();

  void setValues(double x, double y) {
    this.x = x;
    this.y = y;
  }
}