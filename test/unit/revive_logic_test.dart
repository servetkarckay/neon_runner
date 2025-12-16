import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_neon_runner/models/game_state.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('ReviveLogic Tests', () {
    late ReviveSystem reviveSystem;
    late MockGameStateController gameStateController;
    late MockRewardedAdSystem adSystem;
    late MockPlayerComponent player;

    setUp(() {
      gameStateController = MockGameStateController();
      adSystem = MockRewardedAdSystem();
      player = MockPlayerComponent();
      reviveSystem = ReviveSystem(
        gameStateController: gameStateController,
        adSystem: adSystem,
      );
    });

    test('should allow revive when ad is available', () async {
      // Arrange
      adSystem.isAdAvailable = true;
      player.isDead = true;
      player.canRevive = true;
      player.revivesUsed = 0;

      // Act
      final canRevive = await reviveSystem.canRevive(player);

      // Assert
      expect(canRevive, isTrue);
    });

    test('should not allow revive when no ad is available', () async {
      // Arrange
      adSystem.isAdAvailable = false;
      player.isDead = true;
      player.canRevive = true;

      // Act
      final canRevive = await reviveSystem.canRevive(player);

      // Assert
      expect(canRevive, isFalse);
    });

    test('should not allow revive when player has already used revive', () async {
      // Arrange
      adSystem.isAdAvailable = true;
      player.isDead = true;
      player.canRevive = false; // Already used

      // Act
      final canRevive = await reviveSystem.canRevive(player);

      // Assert
      expect(canRevive, isFalse);
    });

    test('should not allow revive when player is not dead', () async {
      // Arrange
      adSystem.isAdAvailable = true;
      player.isDead = false;
      player.canRevive = true;

      // Act
      final canRevive = await reviveSystem.canRevive(player);

      // Assert
      expect(canRevive, isFalse);
    });

    test('should successfully complete revive flow', () async {
      // Arrange
      adSystem.isAdAvailable = true;
      adSystem.shouldAdSucceed = true;
      player.isDead = true;
      player.canRevive = true;
      player.position = Vector2(100, 100);

      // Act
      final revived = await reviveSystem.attemptRevive(player);

      // Assert
      expect(revived, isTrue);
      expect(player.isDead, isFalse);
      expect(player.canRevive, isFalse);
      expect(player.isInvincible, isTrue);
      expect(player.position.y, lessThan(100)); // Should be moved up
      expect(gameStateController.currentState, equals(GameState.playing));
    });

    test('should handle ad failure gracefully', () async {
      // Arrange
      adSystem.isAdAvailable = true;
      adSystem.shouldAdSucceed = false;
      player.isDead = true;
      player.canRevive = true;

      // Act
      final revived = await reviveSystem.attemptRevive(player);

      // Assert
      expect(revived, isFalse);
      expect(player.isDead, isTrue);
      expect(gameStateController.currentState, equals(GameState.gameOver));
    });

    test('should reset player state on revive', () async {
      // Arrange
      adSystem.isAdAvailable = true;
      adSystem.shouldAdSucceed = true;
      player.isDead = true;
      player.canRevive = true;
      player.velocity = Vector2(0, 5); // Falling
      player.invincibilityTimer = 0;

      // Act
      await reviveSystem.attemptRevive(player);

      // Assert
      expect(player.isDead, isFalse);
      expect(player.isInvincible, isTrue);
      expect(player.velocity.y, equals(0)); // Should reset velocity
      expect(player.invincibilityTimer, greaterThan(0));
    });

    test('should position player safely on revive', () async {
      // Arrange
      adSystem.isAdAvailable = true;
      adSystem.shouldAdSucceed = true;
      player.isDead = true;
      player.canRevive = true;
      player.position = Vector2(100, 300); // Low position

      // Act
      await reviveSystem.attemptRevive(player);

      // Assert
      expect(player.position.y, lessThan(200)); // Should be moved to safe height
      expect(player.position.x, equals(100)); // X position unchanged
    });

    test('should track revive usage correctly', () async {
      // Arrange
      adSystem.isAdAvailable = true;
      adSystem.shouldAdSucceed = true;
      player.isDead = true;
      player.canRevive = true;
      player.revivesUsed = 0;

      // Act
      await reviveSystem.attemptRevive(player);

      // Assert
      expect(player.revivesUsed, equals(1));
    });

    test('should not allow multiple revives in same run', () async {
      // Arrange
      adSystem.isAdAvailable = true;
      adSystem.shouldAdSucceed = true;
      player.isDead = true;
      player.canRevive = true;

      // Act - First revive
      await reviveSystem.attemptRevive(player);
      final canReviveAgain = await reviveSystem.canRevive(player);

      // Assert
      expect(canReviveAgain, isFalse);
    });

    test('should validate revive integrity', () {
      // Arrange
      player.isDead = true;
      player.canRevive = true;
      player.revivesUsed = 0;

      // Act
      final isValid = reviveSystem.validateReviveState(player);

      // Assert
      expect(isValid, isTrue);
    });

    test('should detect revive cheating attempts', () {
      // Arrange - Player trying to revive without dying
      player.isDead = false;
      player.canRevive = true;
      player.revivesUsed = 0;

      // Act
      final isValid = reviveSystem.validateReviveState(player);

      // Assert
      expect(isValid, isFalse);
    });

    test('should detect multiple revive attempts', () {
      // Arrange - Player trying to use multiple revives
      player.isDead = true;
      player.canRevive = true;
      player.revivesUsed = 2;

      // Act
      final isValid = reviveSystem.validateReviveState(player);

      // Assert
      expect(isValid, isFalse);
    });
  });
}

// Mock classes for testing
class MockGameStateController {
  GameState currentState = GameState.gameOver;

  void changeState(GameState newState) {
    currentState = newState;
  }
}

class MockRewardedAdSystem {
  bool isAdAvailable = true;
  bool shouldAdSucceed = true;

  Future<bool> isRewardedAdLoaded() async {
    return isAdAvailable;
  }

  Future<bool> showRewardedAd(VoidCallback? onUserEarnedReward) async {
    if (!isAdAvailable) return false;

    await Future.delayed(Duration(milliseconds: 100)); // Simulate ad loading

    if (shouldAdSucceed && onUserEarnedReward != null) {
      onUserEarnedReward();
    }

    return shouldAdSucceed;
  }
}

class MockPlayerComponent {
  bool isDead = false;
  bool canRevive = true;
  bool isInvincible = false;
  int revivesUsed = 0;
  double invincibilityTimer = 0;

  Vector2 position = Vector2.zero();
  Vector2 velocity = Vector2.zero();

  void setInvincible(double duration) {
    isInvincible = true;
    invincibilityTimer = duration;
  }

  void resetVelocity() {
    velocity = Vector2.zero();
  }
}

// Simplified revive system for testing
class ReviveSystem {
  final MockGameStateController gameStateController;
  final MockRewardedAdSystem adSystem;

  static const double safeReviveHeight = 150.0;
  static const double invincibilityDuration = 180.0; // 3 seconds at 60 FPS

  ReviveSystem({
    required this.gameStateController,
    required this.adSystem,
  });

  Future<bool> canRevive(MockPlayerComponent player) async {
    if (!player.isDead) return false;
    if (!player.canRevive) return false;
    final isAdLoaded = await adSystem.isRewardedAdLoaded();
    if (!isAdLoaded) return false;

    return true;
  }

  Future<bool> attemptRevive(MockPlayerComponent player) async {
    // Validate state before attempting revive
    if (!validateReviveState(player)) {
      gameStateController.changeState(GameState.gameOver);
      return false;
    }

    // Check if ad is available
    if (!await adSystem.isRewardedAdLoaded()) {
      gameStateController.changeState(GameState.gameOver);
      return false;
    }

    // Show ad and wait for completion
    final adCompleted = await adSystem.showRewardedAd(() {
      // Ad completed successfully
    });

    if (!adCompleted) {
      gameStateController.changeState(GameState.gameOver);
      return false;
    }

    // Perform revive
    await performRevive(player);

    return true;
  }

  Future<void> performRevive(MockPlayerComponent player) async {
    // Reset player state
    player.isDead = false;
    player.canRevive = false;
    player.revivesUsed++;
    player.resetVelocity();
    player.setInvincible(invincibilityDuration);

    // Move player to safe position
    if (player.position.y > safeReviveHeight) {
      player.position.y = safeReviveHeight;
    }

    // Change game state back to playing
    gameStateController.changeState(GameState.playing);
  }

  bool validateReviveState(MockPlayerComponent player) {
    // Player must be dead to revive
    if (!player.isDead) return false;

    // Player must have revive available
    if (!player.canRevive) return false;

    // Player should not have used revive already in this run
    if (player.revivesUsed >= 1) return false;

    return true;
  }
}