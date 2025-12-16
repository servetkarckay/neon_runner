import 'package:flutter_neon_runner/game/systems/game_state_controller.dart';
import 'package:flutter_neon_runner/utils/debug_utils.dart';
import 'package:flutter_neon_runner/config/build_config.dart';

/// Examples of how the finite state machine works in practice
class StateMachineExamples {

  /// Example 1: Normal Game Flow
  /// Menu → Tap → Playing → Hit → GameOver → Retry → Playing
  static void exampleNormalGameFlow(GameStateController controller) {
    if (BuildConfig.enableLogs) DebugUtils.log('=== NORMAL GAME FLOW ===');

    // 1. Start from menu
    if (BuildConfig.enableLogs) DebugUtils.log('State: ${controller.currentState}'); // GameState.menu

    // 2. Player taps start
    controller.startGame();
    if (BuildConfig.enableLogs) DebugUtils.log('State: ${controller.currentState}'); // GameState.playing

    // 3. Player hits obstacle
    controller.gameOver(finalScore: 1000);
    if (BuildConfig.enableLogs) DebugUtils.log('State: ${controller.currentState}'); // GameState.gameOver

    // 4. Player chooses to retry
    controller.startGame();
    if (BuildConfig.enableLogs) DebugUtils.log('State: ${controller.currentState}'); // GameState.playing

    // 5. Player pauses game
    controller.pauseGame();
    if (BuildConfig.enableLogs) DebugUtils.log('State: ${controller.currentState}'); // GameState.paused

    // 6. Player resumes
    controller.resumeGame();
    if (BuildConfig.enableLogs) DebugUtils.log('State: ${controller.currentState}'); // GameState.playing
  }

  /// Example 2: Revive Flow with Rewarded Ad
  /// Menu → Playing → GameOver → Watch Ad → Reviving → Playing
  static void exampleReviveFlow(GameStateController controller) {
    if (BuildConfig.enableLogs) DebugUtils.log('=== REVIVE FLOW ===');

    // 1. Game over happens
    controller.gameOver(finalScore: 2500);
    if (BuildConfig.enableLogs) DebugUtils.log('State: ${controller.currentState}'); // GameState.gameOver

    // 2. Player chooses to watch ad for revive
    controller.startReviving(
      onSuccess: () {
        if (BuildConfig.enableLogs) DebugUtils.log('Ad completed successfully');
        controller.completeReviving(bonusScore: 500);
      },
      onFailure: (reason) {
        if (BuildConfig.enableLogs) DebugUtils.log('Ad failed: $reason');
        controller.failReviving(reason);
      },
    );
    if (BuildConfig.enableLogs) DebugUtils.log('State: ${controller.currentState}'); // GameState.reviving

    // 3. During revive state, game world is frozen
    if (BuildConfig.enableLogs) DebugUtils.log('Can update game world: ${controller.canUpdate}'); // false
    if (BuildConfig.enableLogs) DebugUtils.log('Is world frozen: ${controller.isFrozen}'); // true

    // 4. Ad completes successfully
    controller.completeReviving(bonusScore: 500);
    if (BuildConfig.enableLogs) DebugUtils.log('State: ${controller.currentState}'); // GameState.playing
    if (BuildConfig.enableLogs) DebugUtils.log('Revived with bonus score!');
  }

  /// Example 3: Invalid Transitions (Blocked)
  static void exampleInvalidTransitions(GameStateController controller) {
    if (BuildConfig.enableLogs) DebugUtils.log('=== INVALID TRANSITIONS ===');

    // Start from menu
    controller.returnToMenu();
    if (BuildConfig.enableLogs) DebugUtils.log('State: ${controller.currentState}'); // GameState.menu

    // Try to pause from menu (should be blocked)
    controller.pauseGame();
    if (BuildConfig.enableLogs) DebugUtils.log('State after pause from menu: ${controller.currentState}'); // Still GameState.menu

    // Try to resume from menu (should be blocked)
    controller.resumeGame();
    if (BuildConfig.enableLogs) DebugUtils.log('State after resume from menu: ${controller.currentState}'); // Still GameState.menu

    // Start playing
    controller.startGame();
    if (BuildConfig.enableLogs) DebugUtils.log('State: ${controller.currentState}'); // GameState.playing

    // Try to start game while already playing (should be blocked)
    controller.startGame();
    if (BuildConfig.enableLogs) DebugUtils.log('State after start while playing: ${controller.currentState}'); // Still GameState.playing
  }

  /// Example 4: State Data and Validation
  static void exampleStateDataAndValidation(GameStateController controller) {
    if (BuildConfig.enableLogs) DebugUtils.log('=== STATE DATA AND VALIDATION ===');

    // Start game with player data
    controller.startGame();

    // Update score
    controller.updateScore(1500);
    controller.updateHighscore(2000);

    // Get state machine statistics
    final stateMachine = controller;
    final stats = stateMachine.getStatistics();

    if (BuildConfig.enableLogs) DebugUtils.log('Current state: ${stats['currentState']}');
    if (BuildConfig.enableLogs) DebugUtils.log('Previous state: ${stats['previousState']}');
    if (BuildConfig.enableLogs) DebugUtils.log('Transition count: ${stats['stateTransitionCount']}');
    if (BuildConfig.enableLogs) DebugUtils.log('State duration: ${stats['stateDuration']}ms');
    if (BuildConfig.enableLogs) DebugUtils.log('State data: ${stats['stateData']}');

    // Validate state machine
    bool isValid = stateMachine.validateState();
    if (BuildConfig.enableLogs) DebugUtils.log('State machine is valid: $isValid');
  }

  /// Example 5: Debug Logging and Monitoring
  static void exampleDebugLogging(GameStateController controller) {
    if (BuildConfig.enableLogs) DebugUtils.log('=== DEBUG LOGGING ===');

    // Enable debug logging
    controller.setDebugMode(true);

    // Perform state transitions with logging
    controller.startGame();
    controller.pauseGame();
    controller.resumeGame();
    controller.gameOver(finalScore: 800);

    // Check state duration
    if (BuildConfig.enableLogs) DebugUtils.log('Time in current state: ${controller.stateDuration.inMilliseconds}ms');

    // Get state transition history
    final history = controller.getStateHistory();
    if (BuildConfig.enableLogs) DebugUtils.log('State transition history:');
    for (final transition in history) {
      if (BuildConfig.enableLogs) {
        // Assuming transition is a Map with these keys
        final from = transition['from'] ?? 'Unknown';
        final to = transition['to'] ?? 'Unknown';
        final timestamp = transition['timestamp'] ?? 'Unknown';
        DebugUtils.log('  $from → $to at $timestamp');
      }
    }
  }
}