import 'dart:async';
import 'package:flutter_neon_runner/game/events/game_events.dart';
import 'package:flutter_neon_runner/utils/debug_utils.dart';

/// Base interface for all game systems
abstract class GameSystem {
  /// Initialize the system
  Future<void> initialize();

  /// Update system logic
  void update(double dt);

  /// Cleanup resources
  void dispose();

  /// Get system name for debugging
  String get systemName;
}

/// Interface for systems that need to handle game events
abstract class EventHandlerSystem extends GameSystem {
  /// Handle incoming game events
  void handleEvent(GameEvent event);

  /// List of event types this system cares about
  List<Type> get handledEventTypes;
}

/// Interface for systems that need to be paused/resumed
abstract class PausableSystem extends GameSystem {
  /// Called when game is paused
  void onPause();

  /// Called when game is resumed
  void onResume();

  /// Current paused state
  bool get isPaused;
}

/// Interface for systems that can be reset
abstract class ResettableSystem extends GameSystem {
  /// Reset system to initial state
  void reset();
}

/// Event bus for decoupled system communication
class GameEventBus {
  static GameEventBus? _instance;
  static GameEventBus get instance => _instance ??= GameEventBus._internal();

  GameEventBus._internal();

  final Map<Type, List<Function>> _listeners = {};
  final StreamController<GameEvent> _eventStream = StreamController<GameEvent>.broadcast();

  /// Stream of all game events for debugging
  Stream<GameEvent> get eventStream => _eventStream.stream;

  /// Register a listener for specific event types
  void subscribe<T extends GameEvent>(Function(T event) listener) {
    final eventType = T;
    _listeners.putIfAbsent(eventType, () => []).add(listener);
  }

  /// Unregister a listener
  void unsubscribe<T extends GameEvent>(Function(T event) listener) {
    final eventType = T;
    _listeners[eventType]?.remove(listener);
  }

  /// Fire an event to all listeners
  void fire(GameEvent event) {
    _eventStream.add(event);

    final eventType = event.runtimeType;
    final listeners = _listeners[eventType];
    if (listeners != null) {
      for (final listener in listeners) {
        try {
          listener(event);
        } catch (e) {
          // Log error but don't crash the game
          DebugUtils.log('Error in event listener: $e');
        }
      }
    }
  }

  /// Clear all listeners
  void clear() {
    _listeners.clear();
  }

  /// Dispose the event bus
  void dispose() {
    clear();
    _eventStream.close();
  }
}