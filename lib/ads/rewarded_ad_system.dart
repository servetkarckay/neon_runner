import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_neon_runner/game/events/game_events.dart';
import 'package:flutter_neon_runner/game/systems/game_state_controller.dart';
import 'package:flutter_neon_runner/game/systems/player_system.dart';
import 'package:flutter_neon_runner/config/game_config.dart';
import 'package:flutter_neon_runner/game/systems/base_game_system.dart';
import 'package:flutter_neon_runner/config/build_config.dart';
import 'package:flutter_neon_runner/utils/debug_utils.dart';

/// Robust rewarded ad system with proper state management and error handling
/// Ensures one revive per run and handles all edge cases
class RewardedAdSystem {
  final GameStateController _gameStateController;
  final PlayerSystem _playerSystem;

  // Ad state
  RewardedAdWrapper? _rewardedAd;
  bool _isAdLoaded = false;
  bool _isReviveUsed = false;
  bool _isLoadingAd = false;

  // Revive state
  ReviveState _reviveState = ReviveState.none;
  final Map<String, dynamic> _reviveData = {};

  // Timers and timeouts
  Timer? _adLoadTimeout;
  Timer? _reviveTimer;
  static const Duration _adLoadTimeoutDuration = Duration(seconds: 10);
  static const Duration _adShowTimeoutDuration = Duration(seconds: 5);

  // Safety checkpoints
  final List<GameplaySnapshot> _snapshots = [];
  static const int _maxSnapshots = 30; // Keep last 30 frames

  RewardedAdSystem({
    required GameStateController gameStateController,
    required PlayerSystem playerSystem,
  })  : _gameStateController = gameStateController,
        _playerSystem = playerSystem;

  // Getters
  bool get isReviveUsed => _isReviveUsed;
  bool get isAdLoaded => _isAdLoaded;
  bool get canRevive => !_isReviveUsed && _gameStateController.isGameOver;
  bool get isLoadingAd => _isLoadingAd;
  ReviveState get reviveState => _reviveState;

  /// Initialize the rewarded ad system
  Future<void> initialize() async {
    // Start loading ads immediately
    await loadRewardedAd();

    // Listen to game state changes
    GameEventBus.instance.subscribe<GameOverEvent>(_handleGameOver);
    GameEventBus.instance.subscribe<RevivingEnterEvent>(_handleRevivingEnter);
    GameEventBus.instance.subscribe<ReviveStartedEvent>(_handleReviveStarted);
  }

  /// Load rewarded ad in advance with proper error handling
  Future<void> loadRewardedAd() async {
    if (_isAdLoaded || _isLoadingAd) return;

    _isLoadingAd = true;
    _logDebug('Loading rewarded ad...');

    try {
      // Clear previous timeout
      _adLoadTimeout?.cancel();

      // Set up timeout for ad loading
      _adLoadTimeout = Timer(_adLoadTimeoutDuration, () {
        _isLoadingAd = false;
        _logError('Ad loading timeout after ${_adLoadTimeoutDuration.inSeconds}s');
        _scheduleNextAdLoad();
      });

      // Platform-specific ad loading
      if (Platform.isAndroid || Platform.isIOS) {
        _rewardedAd = await RewardedAdWrapper.load(
          adUnitId: _getAdUnitId(),
          onAdLoaded: () {
            _adLoadTimeout?.cancel();
            _isLoadingAd = false;
            _isAdLoaded = true;
            _logDebug('Rewarded ad loaded successfully');
          },
          onAdFailedToLoad: (error) {
            _adLoadTimeout?.cancel();
            _isLoadingAd = false;
            _isAdLoaded = false;
            _logError('Ad failed to load: $error');
            _scheduleNextAdLoad();
          },
        );
      } else {
        // Mock ad for desktop testing
        _simulateAdLoading();
      }
    } catch (e) {
      _adLoadTimeout?.cancel();
      _isLoadingAd = false;
      _isAdLoaded = false;
      _logError('Exception during ad loading: $e');
      _scheduleNextAdLoad();
    }
  }

  /// Show rewarded ad for revive
  Future<RewardedAdResult> showRewardedAdForRevive() async {
    // Validate preconditions
    if (!canRevive) {
      _logError('Cannot revive: conditions not met');
      return RewardedAdResult.failure('Cannot revive');
    }

    if (!_isAdLoaded) {
      _logError('Cannot show ad: not loaded');
      return RewardedAdResult.failure('Ad not loaded');
    }

    if (_reviveState != ReviveState.none) {
      _logError('Cannot revive: already in progress');
      return RewardedAdResult.failure('Revive already in progress');
    }

    _reviveState = ReviveState.showingAd;
    _logDebug('Showing rewarded ad for revive...');

    try {
      // Store game state before ad
      _storeGameplaySnapshot();

      // Set timeout for ad showing
      _reviveTimer?.cancel();
      _reviveTimer = Timer(_adShowTimeoutDuration, () {
        _logError('Ad showing timeout');
        _completeAdShow(RewardedAdResult.failure('Ad timeout'));
      });

      // Show ad
      final result = await _rewardedAd?.show(
        onAdDismissed: () {
          _logDebug('Ad dismissed without reward');
          _completeAdShow(RewardedAdResult.failure('Ad dismissed'));
        },
        onAdFailedToShow: (error) {
          _logError('Ad failed to show: $error');
          _completeAdShow(RewardedAdResult.failure('Ad show failed'));
        },
        onUserEarnedReward: (reward) {
          _logDebug('User earned reward: ${reward.amount} ${reward.type}');
          _completeAdShow(RewardedAdResult.success());
        },
      );

      return result ?? RewardedAdResult.failure('Ad wrapper error');
    } catch (e) {
      _reviveTimer?.cancel();
      _logError('Exception during ad show: $e');
      _reviveState = ReviveState.none;
      return RewardedAdResult.failure('Exception: $e');
    }
  }

  /// Complete the ad show process
  void _completeAdShow(RewardedAdResult result) {
    _reviveTimer?.cancel();

    switch (result.status) {
      case RewardedAdStatus.success:
        _reviveState = ReviveState.reviving;
        _executeRevive();
        break;

      case RewardedAdStatus.failure:
        _reviveState = ReviveState.none;
        _gameStateController.failReviving(result.reason ?? 'Unknown error');
        break;
    }

    // Mark ad as used and start loading next one
    _isAdLoaded = false;
    _rewardedAd = null;
    loadRewardedAd(); // Preload next ad
  }

  /// Execute the revive process with safety checks
  void _executeRevive() {
    if (_isReviveUsed) {
      _logError('Revive already used in this session');
      _gameStateController.failReviving('Revive already used');
      return;
    }

    try {
      // Mark revive as used
      _isReviveUsed = true;

      // Restore safe game state
      _restoreSafeGameplayState();

      // Apply revive benefits
      _applyReviveBenefits();

      // Complete revive transition
      _gameStateController.completeReviving(bonusScore: GameConfig.reviveBonusScore);

      // Fire revive completed event
      GameEventBus.instance.fire(ReviveCompletedEvent(
        bonusScore: GameConfig.reviveBonusScore,
      ));

      _logDebug('Revive completed successfully');
    } catch (e) {
      _logError('Error during revive execution: $e');
      _gameStateController.failReviving('Revive execution failed');
    }

    _reviveState = ReviveState.none;
  }

  /// Store gameplay snapshot for safe restore
  void _storeGameplaySnapshot() {
    final playerData = _playerSystem.playerData;

    _reviveData['playerPosition'] = {
      'x': playerData.x,
      'y': playerData.y,
      'velocityY': playerData.velocityY,
    };

    _reviveData['score'] = _gameStateController.score;
    _reviveData['highscore'] = _gameStateController.highscore;
    _reviveData['speed'] = _gameStateController.speed;
    _reviveData['timestamp'] = DateTime.now().millisecondsSinceEpoch;

    _logDebug('Gameplay snapshot stored');
  }

  /// Restore safe gameplay state
  void _restoreSafeGameplayState() {
    final playerData = _playerSystem.playerData;

    // Restore player to safe position
    playerData.x = 50.0; // Safe X position
    playerData.y = GameConfig.groundLevel - playerData.height; // Ground level
    playerData.velocityY = 0.0;
    playerData.isJumping = false;
    playerData.isDucking = false;
    playerData.isHoldingJump = false;

    // Clear any dangerous state
    playerData.invincibleTimer = 0;
    playerData.hasShield = false;

    _logDebug('Safe gameplay state restored');
  }

  /// Apply revive benefits
  void _applyReviveBenefits() {
    final playerData = _playerSystem.playerData;

    // Short invincibility window
    playerData.invincibleTimer = GameConfig.reviveInvincibilityDuration;

    // Clear nearby obstacles (optional - depends on game design)
    GameEventBus.instance.fire(GameResetEvent()); // Reset obstacles

    // Apply bonus score
    final currentScore = _gameStateController.score;
    _gameStateController.updateScore(currentScore + GameConfig.reviveBonusScore);

    _logDebug('Revive benefits applied');
  }

  /// Take gameplay snapshot for collision prevention
  void takeGameplaySnapshot() {
    if (_snapshots.length >= _maxSnapshots) {
      _snapshots.removeAt(0);
    }

    _snapshots.add(GameplaySnapshot(
      playerData: _playerSystem.playerData,
      timestamp: DateTime.now(),
    ));
  }

  /// Get snapshot from safe time before collision
  GameplaySnapshot? getSafeSnapshot() {
    if (_snapshots.isEmpty) return null;

    // Return snapshot from 1 second ago if available
    final safeTime = DateTime.now().subtract(const Duration(seconds: 1));

    for (int i = _snapshots.length - 1; i >= 0; i--) {
      if (_snapshots[i].timestamp.isBefore(safeTime)) {
        return _snapshots[i];
      }
    }

    return _snapshots.first;
  }

  // Event handlers
  void _handleGameOver(GameOverEvent event) {
    _logDebug('Game over detected, checking revive availability');

    // Store immediate snapshot on game over
    _storeGameplaySnapshot();
  }

  void _handleRevivingEnter(RevivingEnterEvent event) {
    _logDebug('Entering revive state');
  }

  void _handleReviveStarted(ReviveStartedEvent event) {
    _logDebug('Revive started');

    // Safety check
    if (_isReviveUsed) {
      _logError('Revive attempt when already used');
      event.onFailure?.call('Revive already used');
      return;
    }

    // Show ad
    showRewardedAdForRevive().then((result) {
      if (result.status == RewardedAdStatus.success) {
        event.onSuccess?.call();
      } else {
        event.onFailure?.call(result.reason ?? 'Ad failed');
      }
    });
  }

  // Private helper methods
  void _simulateAdLoading() {
    _logDebug('Simulating ad loading for desktop');
    _adLoadTimeout?.cancel();

    Timer(const Duration(seconds: 2), () {
      _isLoadingAd = false;
      _isAdLoaded = true;
      _logDebug('Mock ad loaded (desktop)');
    });
  }

  void _scheduleNextAdLoad() {
    // Schedule next ad load attempt
    Timer(const Duration(seconds: 30), () {
      loadRewardedAd();
    });
  }

  String _getAdUnitId() {
    // Return platform-specific ad unit ID
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917'; // Test Android ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313'; // Test iOS ID
    }
    return 'test_ad_unit_id';
  }

  void _logDebug(String message) {
    if (!BuildConfig.enableLogs) return;
    DebugUtils.log('[RewardedAdSystem] DEBUG: $message');
  }

  void _logError(String message) {
    if (!BuildConfig.enableLogs) return;
    DebugUtils.log('[RewardedAdSystem] ERROR: $message');
  }

  void dispose() {
    _adLoadTimeout?.cancel();
    _reviveTimer?.cancel();
    _rewardedAd?.dispose();
    _snapshots.clear();

    GameEventBus.instance.unsubscribe<GameOverEvent>(_handleGameOver);
    GameEventBus.instance.unsubscribe<RevivingEnterEvent>(_handleRevivingEnter);
    GameEventBus.instance.unsubscribe<ReviveStartedEvent>(_handleReviveStarted);
  }
}

/// Wrapper for rewarded ad functionality
class RewardedAdWrapper {
  final String adUnitId;
  final VoidCallback? onAdLoaded;
  final Function(String)? onAdFailedToLoad;

  RewardedAdWrapper({
    required this.adUnitId,
    this.onAdLoaded,
    this.onAdFailedToLoad,
  });

  static Future<RewardedAdWrapper?> load({
    required String adUnitId,
    VoidCallback? onAdLoaded,
    Function(String)? onAdFailedToLoad,
  }) async {
    // Mock implementation for now
    // In production, this would integrate with Google Mobile Ads
    return RewardedAdWrapper(
      adUnitId: adUnitId,
      onAdLoaded: onAdLoaded,
      onAdFailedToLoad: onAdFailedToLoad,
    );
  }

  Future<RewardedAdResult> show({
    VoidCallback? onAdDismissed,
    Function(String)? onAdFailedToShow,
    Function(Reward)? onUserEarnedReward,
  }) async {
    // Mock ad show for testing
    // In production, this would show the actual ad

    // Simulate ad completion after 3 seconds
    await Future.delayed(const Duration(seconds: 3));

    // Simulate 80% success rate
    if (DateTime.now().millisecond % 100 < 80) {
      onUserEarnedReward?.call(Reward(type: 'coins', amount: 1));
      return RewardedAdResult.success();
    } else {
      onAdDismissed?.call();
      return RewardedAdResult.failure('User dismissed');
    }
  }

  void dispose() {
    // Dispose ad resources
  }
}

/// Result of rewarded ad operation
class RewardedAdResult {
  final RewardedAdStatus status;
  final String? reason;

  RewardedAdResult.success({this.reason})
      : status = RewardedAdStatus.success;

  RewardedAdResult.failure(this.reason)
      : status = RewardedAdStatus.failure;
}

/// Status of rewarded ad operation
enum RewardedAdStatus {
  success,
  failure,
}

/// Reward information from ad
class Reward {
  final String type;
  final int amount;

  Reward({required this.type, required this.amount});
}

/// Revive state tracking
enum ReviveState {
  none,           // No revive in progress
  showingAd,      // Ad is currently showing
  reviving,       // Revive is being processed
}

/// Gameplay snapshot for safe restore
class GameplaySnapshot {
  final dynamic playerData;
  final DateTime timestamp;

  GameplaySnapshot({
    required this.playerData,
    required this.timestamp,
  });
}