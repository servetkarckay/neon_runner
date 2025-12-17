import 'dart:async';
import 'package:flutter_neon_runner/ads/rewarded_ad_system.dart';
import 'package:flutter_neon_runner/ads/revive_validator.dart';
import 'package:flutter_neon_runner/game/events/game_events.dart';
import 'package:flutter_neon_runner/game/systems/base_game_system.dart';
import 'package:flutter_neon_runner/game/systems/game_state_controller.dart';
import 'package:flutter_neon_runner/game/systems/player_system.dart';
import 'package:flutter_neon_runner/game/systems/audio_system.dart';
import 'package:flutter_neon_runner/models/game_state.dart';
import 'package:flutter_neon_runner/utils/debug_utils.dart';

/// Integration system that coordinates all revive-related functionality
/// Ensures proper communication between ad system, validator, and game state
class ReviveIntegrationSystem {
  final GameStateController _gameStateController;
  final PlayerSystem _playerSystem;
  final AudioSystem _audioSystem;

  late RewardedAdSystem _rewardedAdSystem;
  late ReviveValidator _reviveValidator;

  // Integration state
  bool _isInitialized = false;
  ReviveFlowState _currentFlowState = ReviveFlowState.none;

  // Timers for revive flow
  Timer? _reviveTimeoutTimer;
  Timer? _adLoadCheckTimer;
  static const Duration _reviveTimeoutDuration = Duration(seconds: 30);
  static const Duration _adLoadCheckInterval = Duration(seconds: 1);

  ReviveIntegrationSystem({
    required GameStateController gameStateController,
    required PlayerSystem playerSystem,
    required AudioSystem audioSystem,
  }) : _gameStateController = gameStateController,
       _playerSystem = playerSystem,
       _audioSystem = audioSystem;

  // Getters
  bool get canRevive => _reviveValidator.canRevive;
  bool get reviveUsedThisRun => _reviveValidator.reviveUsedThisRun;
  bool get isAdReady => _rewardedAdSystem.isAdLoaded;
  ReviveFlowState get currentFlowState => _currentFlowState;

  /// Initialize the revive integration system
  Future<void> initialize() async {
    if (_isInitialized) return;

    _logDebug('Initializing revive integration system...');

    // Initialize subsystems
    _rewardedAdSystem = RewardedAdSystem(
      gameStateController: _gameStateController,
      playerSystem: _playerSystem,
    );

    _reviveValidator = ReviveValidator(
      gameStateController: _gameStateController,
      playerSystem: _playerSystem,
    );

    // Initialize subsystems
    await _rewardedAdSystem.initialize();
    _reviveValidator.initialize();

    // Subscribe to events
    _subscribeToEvents();

    // Start periodic ad loading check
    _startAdLoadCheck();

    _isInitialized = true;
    _logDebug('Revive integration system initialized');
  }

  /// Initiate revive flow with comprehensive validation
  Future<ReviveFlowResult> initiateReviveFlow() async {
    if (!_isInitialized) {
      return ReviveFlowResult.failure('System not initialized');
    }

    if (_currentFlowState != ReviveFlowState.none) {
      return ReviveFlowResult.failure('Revive already in progress');
    }

    _currentFlowState = ReviveFlowState.validating;
    _logDebug('Starting revive flow validation...');

    try {
      // Step 1: Validate revive request
      final validation = _reviveValidator.validateReviveRequest();
      if (!validation.isValid) {
        _currentFlowState = ReviveFlowState.none;
        return ReviveFlowResult.failure(
          'Validation failed: ${validation.issues.join(', ')}',
          canRetry: validation.canRetry,
        );
      }

      // Step 2: Check ad availability
      _currentFlowState = ReviveFlowState.checkingAd;
      if (!_rewardedAdSystem.isAdLoaded) {
        _currentFlowState = ReviveFlowState.loadingAd;
        await _rewardedAdSystem.loadRewardedAd();

        // Give ad loading a chance
        await Future.delayed(const Duration(seconds: 2));

        if (!_rewardedAdSystem.isAdLoaded) {
          _currentFlowState = ReviveFlowState.none;
          return ReviveFlowResult.failure('Ad not available', canRetry: true);
        }
      }

      // Step 3: Start revive flow
      _currentFlowState = ReviveFlowState.startingRevive;
      final success = await _startReviveFlow();

      if (success) {
        return ReviveFlowResult.success();
      } else {
        _currentFlowState = ReviveFlowState.none;
        return ReviveFlowResult.failure('Revive flow failed', canRetry: false);
      }

    } catch (e) {
      _currentFlowState = ReviveFlowState.none;
      _logError('Exception in revive flow: $e');
      return ReviveFlowResult.failure('Exception: $e', canRetry: false);
    }
  }

  /// Start the actual revive flow
  Future<bool> _startReviveFlow() async {
    _currentFlowState = ReviveFlowState.showingAd;
    _logDebug('Starting revive flow...');

    // Set revive timeout
    _reviveTimeoutTimer?.cancel();
    _reviveTimeoutTimer = Timer(_reviveTimeoutDuration, () {
      _logError('Revive flow timeout');
      _handleReviveTimeout();
    });

    // Initiate state transition to reviving
    _gameStateController.startReviving(
      onSuccess: () => _handleReviveSuccess(),
      onFailure: (reason) => _handleReviveFailure(reason),
    );

    // Show ad
    final adResult = await _rewardedAdSystem.showRewardedAdForRevive();

    _reviveTimeoutTimer?.cancel();

    switch (adResult.status) {
      case RewardedAdStatus.success:
        return true;
      case RewardedAdStatus.failure:
        _handleReviveFailure(adResult.reason ?? 'Ad failed');
        return false;
    }
  }

  /// Handle successful revive
  void _handleReviveSuccess() {
    _currentFlowState = ReviveFlowState.completing;

    // Apply post-revive validation
    final postValidation = _reviveValidator.validatePostReviveState();
    if (!postValidation.isValid) {
      _logError('Post-revive validation failed: ${postValidation.issues}');
      // Continue anyway but log the issue
    }

    // Play success sound
    _audioSystem.playSound('powerup');

    // Reset revive flow state
    _currentFlowState = ReviveFlowState.none;

    _logDebug('Revive completed successfully');
  }

  /// Handle revive failure
  void _handleReviveFailure(String reason) {
    _currentFlowState = ReviveFlowState.failing;

    // Record failure
    _reviveValidator.recordPlayerAction('revive_failure');

    // Play failure sound
    _audioSystem.playSound('crash');

    // Ensure game over state
    if (_gameStateController.currentState == GameState.reviving) {
      _gameStateController.failReviving(reason);
    }

    _currentFlowState = ReviveFlowState.none;
    _logDebug('Revive failed: $reason');
  }

  /// Handle revive timeout
  void _handleReviveTimeout() {
    _currentFlowState = ReviveFlowState.none;

    // Force game over state
    if (_gameStateController.currentState == GameState.reviving) {
      _gameStateController.failReviving('Revive timeout');
    }

    _logError('Revive flow timed out');
  }

  /// Cancel current revive flow
  void cancelReviveFlow() {
    if (_currentFlowState == ReviveFlowState.none) return;

    _reviveTimeoutTimer?.cancel();
    _currentFlowState = ReviveFlowState.canceling;

    // Cancel ad if showing
    if (_currentFlowState == ReviveFlowState.showingAd) {
      // Ad will handle its own cancellation
    }

    // Return to game over
    if (_gameStateController.currentState == GameState.reviving) {
      _gameStateController.failReviving('User cancelled');
    }

    _currentFlowState = ReviveFlowState.none;
    _logDebug('Revive flow cancelled by user');
  }

  /// Get revive flow status for UI
  ReviveFlowStatus getReviveStatus() {
    switch (_currentFlowState) {
      case ReviveFlowState.none:
        return ReviveFlowStatus.available(canRevive && isAdReady);
      case ReviveFlowState.validating:
        return ReviveFlowStatus.validating;
      case ReviveFlowState.checkingAd:
        return ReviveFlowStatus.checkingAd;
      case ReviveFlowState.loadingAd:
        return ReviveFlowStatus.loadingAd;
      case ReviveFlowState.startingRevive:
        return ReviveFlowStatus.starting;
      case ReviveFlowState.showingAd:
        return ReviveFlowStatus.showingAd;
      case ReviveFlowState.completing:
        return ReviveFlowStatus.completing;
      case ReviveFlowState.failing:
        return ReviveFlowStatus.failing;
      case ReviveFlowState.canceling:
        return ReviveFlowStatus.cancelling;
    }
  }

  /// Get comprehensive revive statistics
  ReviveIntegrationStats getStatistics() {
    final adStats = _rewardedAdSystem.isAdLoaded;
    final validatorStats = _reviveValidator.getStatistics();

    return ReviveIntegrationStats(
      canRevive: canRevive,
      reviveUsedThisRun: reviveUsedThisRun,
      adReady: adStats,
      currentFlowState: _currentFlowState,
      totalRevives: validatorStats.totalRevives,
      successfulRevives: validatorStats.successfulRevives,
      successRate: validatorStats.successRate,
      averageScoreAtRevive: validatorStats.averageScoreAtRevive,
    );
  }

  // Private methods
  void _subscribeToEvents() {
    GameEventBus.instance.subscribe<GameOverEvent>(_handleGameOverEvent);
    GameEventBus.instance.subscribe<ReviveCompletedEvent>(_handleReviveCompletedEvent);
  }

  void _startAdLoadCheck() {
    _adLoadCheckTimer = Timer.periodic(_adLoadCheckInterval, (timer) {
      if (!_rewardedAdSystem.isAdLoaded && !_rewardedAdSystem.isLoadingAd) {
        _rewardedAdSystem.loadRewardedAd();
      }
    });
  }

  // Event handlers
  void _handleGameOverEvent(GameOverEvent event) {
    _logDebug('Game over detected, checking revive availability');

    // Auto-start revive flow if available
    if (canRevive) {
      Future.delayed(const Duration(seconds: 1), () {
        if (canRevive && _gameStateController.isGameOver) {
          _logDebug('Auto-offering revive option');
          // UI will show revive option based on canRevive status
        }
      });
    }
  }

  void _handleReviveCompletedEvent(ReviveCompletedEvent event) {
    _logDebug('Revive completed event received');
    _handleReviveSuccess();
  }

  void _logDebug(String message) {
    DebugUtils.log('[ReviveIntegration] DEBUG: $message');
  }

  void _logError(String message) {
    DebugUtils.log('[ReviveIntegration] ERROR: $message');
  }

  void dispose() {
    _reviveTimeoutTimer?.cancel();
    _adLoadCheckTimer?.cancel();

    _rewardedAdSystem.dispose();
    _reviveValidator.dispose();

    GameEventBus.instance.unsubscribe<GameOverEvent>(_handleGameOverEvent);
    GameEventBus.instance.unsubscribe<ReviveCompletedEvent>(_handleReviveCompletedEvent);

    _currentFlowState = ReviveFlowState.none;
  }
}

/// Results of revive flow
class ReviveFlowResult {
  final bool success;
  final String? errorMessage;
  final bool canRetry;

  ReviveFlowResult.success()
      : success = true,
        errorMessage = null,
        canRetry = false;

  ReviveFlowResult.failure(this.errorMessage, {this.canRetry = false})
      : success = false;
}

/// Current state of revive flow
enum ReviveFlowState {
  none,           // No revive in progress
  validating,     // Validating revive request
  checkingAd,     // Checking ad availability
  loadingAd,      // Loading rewarded ad
  startingRevive, // Starting revive flow
  showingAd,      // Ad is currently showing
  completing,     // Completing revive
  failing,        // Handling revive failure
  canceling,      // User is canceling
}

/// Status for UI consumption
class ReviveFlowStatus {
  final ReviveUIState state;
  final bool canRetry;

  const ReviveFlowStatus(this.state, {this.canRetry = false});

  factory ReviveFlowStatus.available(bool adReady) {
    return ReviveFlowStatus(
      adReady ? ReviveUIState.available : ReviveUIState.adNotReady,
      canRetry: true,
    );
  }

  static const ReviveFlowStatus validating = ReviveFlowStatus(ReviveUIState.validating);
  static const ReviveFlowStatus checkingAd = ReviveFlowStatus(ReviveUIState.checkingAd);
  static const ReviveFlowStatus loadingAd = ReviveFlowStatus(ReviveUIState.loadingAd);
  static const ReviveFlowStatus starting = ReviveFlowStatus(ReviveUIState.starting);
  static const ReviveFlowStatus showingAd = ReviveFlowStatus(ReviveUIState.showingAd);
  static const ReviveFlowStatus completing = ReviveFlowStatus(ReviveUIState.completing);
  static const ReviveFlowStatus failing = ReviveFlowStatus(ReviveUIState.failing);
  static const ReviveFlowStatus cancelling = ReviveFlowStatus(ReviveUIState.cancelling);
}

/// UI states for revive flow
enum ReviveUIState {
  available,
  adNotReady,
  validating,
  checkingAd,
  loadingAd,
  starting,
  showingAd,
  completing,
  failing,
  cancelling,
}

/// Comprehensive revive statistics
class ReviveIntegrationStats {
  final bool canRevive;
  final bool reviveUsedThisRun;
  final bool adReady;
  final ReviveFlowState currentFlowState;
  final int totalRevives;
  final int successfulRevives;
  final double successRate;
  final double averageScoreAtRevive;

  ReviveIntegrationStats({
    required this.canRevive,
    required this.reviveUsedThisRun,
    required this.adReady,
    required this.currentFlowState,
    required this.totalRevives,
    required this.successfulRevives,
    required this.successRate,
    required this.averageScoreAtRevive,
  });
}