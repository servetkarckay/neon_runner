import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Result of score validation
class ScoreValidationResult {
  final bool isValid;
  final String? reason;
  final Map<String, dynamic>? metadata;

  ScoreValidationResult({
    required this.isValid,
    this.reason,
    this.metadata,
  });

  factory ScoreValidationResult.success([Map<String, dynamic>? metadata]) {
    return ScoreValidationResult(
      isValid: true,
      metadata: metadata,
    );
  }

  factory ScoreValidationResult.failure(String reason) {
    return ScoreValidationResult(
      isValid: false,
      reason: reason,
    );
  }
}

/// Validates score submissions for legitimacy
class ScoreValidator {
  final String _secretKey;
  final Map<String, DateTime> _lastSubmissionTimes = {};
  final Map<String, int> _highScores = {};

  ScoreValidator({required String secretKey}) : _secretKey = secretKey;

  /// Validate a score increase for a player
  ScoreValidationResult validateScoreIncrease({
    required int oldScore,
    required int newScore,
    required dynamic player,
    required Duration timeDiff,
  }) {
    // Basic score increase validation
    if (newScore <= oldScore) {
      return ScoreValidationResult.failure('New score must be greater than old score');
    }

    // Validate score increase rate (prevent impossible scoring rates)
    final scoreIncrease = newScore - oldScore;
    final maxPossibleIncrease = _calculateMaxPossibleScore(timeDiff);

    if (scoreIncrease > maxPossibleIncrease) {
      return ScoreValidationResult.failure(
        'Score increase too rapid: $scoreIncrease points in ${timeDiff.inSeconds}s'
      );
    }

    // Additional validation based on player properties if available
    if (player != null) {
      // Basic position validation (prevent teleporting scoring)
      try {
        final position = player.position as dynamic?;
        if (position != null) {
          // Validate position is within reasonable bounds
          final x = position.x as double? ?? 0.0;
          final y = position.y as double? ?? 0.0;

          if (x < 0 || y < 0) {
            return ScoreValidationResult.failure('Invalid player position');
          }
        }
      } catch (e) {
        // If we can't access position, skip this validation
      }
    }

    return ScoreValidationResult.success({
      'scoreIncrease': scoreIncrease,
      'timeDiff': timeDiff.inMilliseconds,
      'rate': scoreIncrease / timeDiff.inSeconds.clamp(1, double.infinity),
    });
  }

  /// Generate a hash for score submission
  String generateScoreHash({
    required int score,
    required String playerId,
    required DateTime timestamp,
    Map<String, dynamic>? additionalData,
  }) {
    final data = {
      'score': score,
      'playerId': playerId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      if (additionalData != null) ...additionalData,
      'secret': _secretKey,
    };

    final dataString = json.encode(data);
    final bytes = utf8.encode(dataString);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verify a score hash
  bool verifyScoreHash({
    required int score,
    required String playerId,
    required DateTime timestamp,
    required String hash,
    Map<String, dynamic>? additionalData,
  }) {
    final expectedHash = generateScoreHash(
      score: score,
      playerId: playerId,
      timestamp: timestamp,
      additionalData: additionalData,
    );
    return hash == expectedHash;
  }

  /// Calculate maximum possible score increase in given time
  int _calculateMaxPossibleScore(Duration timeDiff) {
    // Assuming max reasonable score rate is 1000 points per second
    // This should be adjusted based on actual game mechanics
    const maxScorePerSecond = 1000;
    return (timeDiff.inSeconds * maxScorePerSecond).clamp(0, 100000);
  }

  /// Check if player can submit score (rate limiting)
  bool canSubmitScore(String playerId, {Duration cooldown = const Duration(seconds: 5)}) {
    final lastSubmission = _lastSubmissionTimes[playerId];
    if (lastSubmission == null) {
      _lastSubmissionTimes[playerId] = DateTime.now();
      return true;
    }

    final timeSinceLastSubmission = DateTime.now().difference(lastSubmission);
    if (timeSinceLastSubmission >= cooldown) {
      _lastSubmissionTimes[playerId] = DateTime.now();
      return true;
    }

    return false;
  }

  /// Update player's high score
  void updateHighScore(String playerId, int score) {
    final currentHighScore = _highScores[playerId] ?? 0;
    if (score > currentHighScore) {
      _highScores[playerId] = score;
    }
  }

  /// Get player's high score
  int getHighScore(String playerId) {
    return _highScores[playerId] ?? 0;
  }
}