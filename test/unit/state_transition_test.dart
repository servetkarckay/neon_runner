import 'package:flutter_test/flutter_test.dart';

void main() {
  group('State Transition Tests', () {
    late GameStateMachine stateMachine;

    setUp(() {
      stateMachine = GameStateMachine();
    });

    test('should start in menu state', () {
      // Act
      final initialState = stateMachine.currentState;

      // Assert
      expect(initialState, equals(GameState.menu));
    });

    test('should transition from menu to playing', () {
      // Act
      final canTransition = stateMachine.canTransitionTo(GameState.playing);
      final transitioned = stateMachine.transitionTo(GameState.playing);

      // Assert
      expect(canTransition, isTrue);
      expect(transitioned, isTrue);
      expect(stateMachine.currentState, equals(GameState.playing));
    });

    test('should transition from playing to paused', () {
      // Arrange
      stateMachine.transitionTo(GameState.playing);

      // Act
      final canTransition = stateMachine.canTransitionTo(GameState.paused);
      final transitioned = stateMachine.transitionTo(GameState.paused);

      // Assert
      expect(canTransition, isTrue);
      expect(transitioned, isTrue);
      expect(stateMachine.currentState, equals(GameState.paused));
    });

    test('should transition from paused to playing', () {
      // Arrange
      stateMachine.transitionTo(GameState.playing);
      stateMachine.transitionTo(GameState.paused);

      // Act
      final canTransition = stateMachine.canTransitionTo(GameState.playing);
      final transitioned = stateMachine.transitionTo(GameState.playing);

      // Assert
      expect(canTransition, isTrue);
      expect(transitioned, isTrue);
      expect(stateMachine.currentState, equals(GameState.playing));
    });

    test('should transition from playing to gameOver', () {
      // Arrange
      stateMachine.transitionTo(GameState.playing);

      // Act
      final canTransition = stateMachine.canTransitionTo(GameState.gameOver);
      final transitioned = stateMachine.transitionTo(GameState.gameOver);

      // Assert
      expect(canTransition, isTrue);
      expect(transitioned, isTrue);
      expect(stateMachine.currentState, equals(GameState.gameOver));
    });

    test('should transition from gameOver to menu', () {
      // Arrange
      stateMachine.transitionTo(GameState.playing);
      stateMachine.transitionTo(GameState.gameOver);

      // Act
      final canTransition = stateMachine.canTransitionTo(GameState.menu);
      final transitioned = stateMachine.transitionTo(GameState.menu);

      // Assert
      expect(canTransition, isTrue);
      expect(transitioned, isTrue);
      expect(stateMachine.currentState, equals(GameState.menu));
    });

    test('should transition from playing to reviving', () {
      // Arrange
      stateMachine.transitionTo(GameState.playing);

      // Act
      final canTransition = stateMachine.canTransitionTo(GameState.reviving);
      final transitioned = stateMachine.transitionTo(GameState.reviving);

      // Assert
      expect(canTransition, isTrue);
      expect(transitioned, isTrue);
      expect(stateMachine.currentState, equals(GameState.reviving));
    });

    test('should transition from reviving to playing', () {
      // Arrange
      stateMachine.transitionTo(GameState.playing);
      stateMachine.transitionTo(GameState.reviving);

      // Act
      final canTransition = stateMachine.canTransitionTo(GameState.playing);
      final transitioned = stateMachine.transitionTo(GameState.playing);

      // Assert
      expect(canTransition, isTrue);
      expect(transitioned, isTrue);
      expect(stateMachine.currentState, equals(GameState.playing));
    });

    test('should transition from reviving to gameOver', () {
      // Arrange
      stateMachine.transitionTo(GameState.playing);
      stateMachine.transitionTo(GameState.reviving);

      // Act
      final canTransition = stateMachine.canTransitionTo(GameState.gameOver);
      final transitioned = stateMachine.transitionTo(GameState.gameOver);

      // Assert
      expect(canTransition, isTrue);
      expect(transitioned, isTrue);
      expect(stateMachine.currentState, equals(GameState.gameOver));
    });

    test('should not allow invalid transitions', () {
      // Arrange
      stateMachine.transitionTo(GameState.playing);

      // Test invalid transitions from playing
      expect(stateMachine.canTransitionTo(GameState.menu), isFalse);
      expect(stateMachine.canTransitionTo(GameState.leaderboardView), isFalse);
      expect(stateMachine.canTransitionTo(GameState.settings), isFalse);

      // Act & Assert
      final transitioned = stateMachine.transitionTo(GameState.menu);
      expect(transitioned, isFalse);
      expect(stateMachine.currentState, equals(GameState.playing));
    });

    test('should handle self-transitions correctly', () {
      // Arrange
      stateMachine.transitionTo(GameState.menu);

      // Act
      final canTransition = stateMachine.canTransitionTo(GameState.menu);
      final transitioned = stateMachine.transitionTo(GameState.menu);

      // Assert
      expect(canTransition, isTrue); // Self-transitions are allowed
      expect(transitioned, isTrue);
      expect(stateMachine.currentState, equals(GameState.menu));
    });

    test('should track transition history', () {
      // Arrange
      stateMachine.transitionTo(GameState.playing);
      stateMachine.transitionTo(GameState.paused);
      stateMachine.transitionTo(GameState.playing);
      stateMachine.transitionTo(GameState.gameOver);

      // Act
      final history = stateMachine.transitionHistory;

      // Assert
      expect(history.length, equals(4));
      expect(history[0].fromState, equals(GameState.menu));
      expect(history[0].toState, equals(GameState.playing));
      expect(history[1].fromState, equals(GameState.playing));
      expect(history[1].toState, equals(GameState.paused));
      expect(history[2].fromState, equals(GameState.paused));
      expect(history[2].toState, equals(GameState.playing));
      expect(history[3].fromState, equals(GameState.playing));
      expect(history[3].toState, equals(GameState.gameOver));
    });

    test('should validate all possible transitions', () {
      final validTransitions = {
        GameState.menu: [GameState.playing, GameState.leaderboardView, GameState.settings],
        GameState.playing: [GameState.paused, GameState.gameOver, GameState.reviving],
        GameState.paused: [GameState.playing, GameState.menu],
        GameState.gameOver: [GameState.menu, GameState.leaderboardView],
        GameState.reviving: [GameState.playing, GameState.gameOver],
        GameState.leaderboardView: [GameState.menu],
        GameState.settings: [GameState.menu],
      };

      for (final fromState in GameState.values) {
        final allowedStates = validTransitions[fromState] ?? [];

        for (final toState in GameState.values) {
          // Arrange
          // Initialize the state machine and set current state using transitionTo
          stateMachine.transitionTo(fromState);

          // Act
          final canTransition = stateMachine.canTransitionTo(toState);

          // Assert
          if (allowedStates.contains(toState) || fromState == toState) {
            expect(canTransition, isTrue,
              reason: 'Should allow transition from $fromState to $toState');
          } else {
            expect(canTransition, isFalse,
              reason: 'Should NOT allow transition from $fromState to $toState');
          }
        }
      }
    });

    test('should allow rapid consecutive transitions', () {
      // Act
      stateMachine.transitionTo(GameState.playing);

      // Try to transition again immediately
      final canTransition = stateMachine.canTransitionTo(GameState.paused);

      // Assert - Current implementation allows consecutive transitions
      expect(canTransition, isTrue);
    });

    test('should freeze state during revive', () {
      // Arrange
      stateMachine.transitionTo(GameState.playing);

      // Act
      stateMachine.transitionTo(GameState.reviving);

      // Assert
      expect(stateMachine.isStateFrozen, isTrue);
      expect(stateMachine.currentState, equals(GameState.reviving));

      // Should still be able to transition out of frozen state
      final canTransition = stateMachine.canTransitionTo(GameState.playing);
      expect(canTransition, isTrue);
    });

    test('should log state transitions', () {
      // Arrange
      final logs = <String>[];
      stateMachine.addTransitionListener((from, to) {
        logs.add('Transitioned from $from to $to');
      });

      // Act
      stateMachine.transitionTo(GameState.playing);
      stateMachine.transitionTo(GameState.paused);

      // Assert
      expect(logs.length, equals(2));
      expect(logs[0], equals('Transitioned from GameState.menu to GameState.playing'));
      expect(logs[1], equals('Transitioned from GameState.playing to GameState.paused'));
    });

    test('should handle transition errors gracefully', () {
      // Arrange
      stateMachine.transitionTo(GameState.playing);

      // Act & Assert - Attempt invalid transition
      expect(() => stateMachine.forceTransition(GameState.menu), returnsNormally);

      // Force transition should succeed
      stateMachine.forceTransition(GameState.menu);
      expect(stateMachine.currentState, equals(GameState.menu));
    });
  });
}

// Simplified GameStateMachine for testing
class GameStateMachine {
  GameState _currentState = GameState.menu;
  final List<StateTransition> _transitionHistory = [];
  final List<TransitionListener> _listeners = [];

  GameState get currentState => _currentState;

  bool get isStateFrozen => _currentState == GameState.reviving;

  List<StateTransition> get transitionHistory =>
    List.unmodifiable(_transitionHistory);

  bool canTransitionTo(GameState targetState) {
    // Self-transitions are always allowed
    if (targetState == _currentState) return true;

    // Define valid transitions
    final validTransitions = {
      GameState.menu: [GameState.playing, GameState.leaderboardView, GameState.settings],
      GameState.playing: [GameState.paused, GameState.gameOver, GameState.reviving],
      GameState.paused: [GameState.playing, GameState.menu],
      GameState.gameOver: [GameState.menu, GameState.leaderboardView],
      GameState.reviving: [GameState.playing, GameState.gameOver],
      GameState.leaderboardView: [GameState.menu],
      GameState.settings: [GameState.menu],
    };

    final allowedStates = validTransitions[_currentState] ?? [];
    return allowedStates.contains(targetState);
  }

  bool transitionTo(GameState targetState) {
    if (!canTransitionTo(targetState)) {
      return false;
    }

    final transition = StateTransition(
      fromState: _currentState,
      toState: targetState,
      timestamp: DateTime.now(),
    );

    _currentState = targetState;
    _transitionHistory.add(transition);

    // Notify listeners
    for (final listener in _listeners) {
      listener(transition.fromState, transition.toState);
    }

    return true;
  }

  void forceTransition(GameState targetState) {
    final transition = StateTransition(
      fromState: _currentState,
      toState: targetState,
      timestamp: DateTime.now(),
      forced: true,
    );

    _currentState = targetState;
    _transitionHistory.add(transition);

    // Notify listeners
    for (final listener in _listeners) {
      listener(transition.fromState, transition.toState);
    }
  }

  
  void addTransitionListener(TransitionListener listener) {
    _listeners.add(listener);
  }

  void removeTransitionListener(TransitionListener listener) {
    _listeners.remove(listener);
  }

  void reset() {
    _currentState = GameState.menu;
    _transitionHistory.clear();
  }
}

// Data classes
class StateTransition {
  final GameState fromState;
  final GameState toState;
  final DateTime timestamp;
  final bool forced;

  StateTransition({
    required this.fromState,
    required this.toState,
    required this.timestamp,
    this.forced = false,
  });
}

typedef TransitionListener = void Function(GameState from, GameState to);

// GameState enum
enum GameState {
  menu,
  playing,
  paused,
  gameOver,
  reviving,
  leaderboardView,
  settings,
}