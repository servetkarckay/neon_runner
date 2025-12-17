import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_neon_runner/game/events/game_events.dart';
import 'package:flutter_neon_runner/game/systems/base_game_system.dart';
import 'package:logging/logging.dart';

/// Game loop safety system that prevents crashes and handles errors gracefully
/// Provides comprehensive error recovery and state protection
class GameLoopSafety {
  // final GameStateController _gameStateController; // Unused but kept for future integration

  // Logger instance
  static final _log = Logger('GameLoopSafety');

  // Error tracking
  final List<GameLoopError> _errorHistory = [];
  static const int _maxErrorHistory = 50;

  // Safety state
  bool _isInCriticalError = false;
  bool _isSafeModeActive = false;

  // Performance monitoring
  final List<FrameMetrics> _frameMetrics = [];
  static const int _maxFrameMetrics = 300; // 5 seconds at 60 FPS

  // Error recovery
  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 3;

  // Debug state
  static bool _debugMode = false;

  GameLoopSafety() {
    _debugMode = !kReleaseMode;
  }

  /// Safe wrapper for critical game loop operations
  T safeUpdate<T>(
    T Function() updateFunction,
    String operationName, {
    T? fallbackValue,
    bool silent = false,
  }) {
    final frameTime = DateTime.now();

    try {
      // Check if we're in critical error state
      if (_isInCriticalError) {
        if (!silent && _debugMode) {
          _log.warning('BLOCKED: $operationName (critical error active)');
        }
        return fallbackValue ?? _getDefaultFallback<T>();
      }

      // Check safe mode
      if (_isSafeModeActive && !operationName.startsWith('safe_')) {
        if (!silent && _debugMode) {
          _log.warning('BLOCKED: $operationName (safe mode active)');
        }
        return fallbackValue ?? _getDefaultFallback<T>();
      }

      // Execute operation
      final result = updateFunction();

      // Reset consecutive error count on success
      _consecutiveErrors = 0;

      // Record frame metrics
      _recordFrameMetrics(frameTime, true);

      return result;

    } catch (e, stackTrace) {
      // Handle error
      _handleGameLoopError(e, stackTrace, operationName, frameTime);

      // Return fallback if available
      if (fallbackValue != null) {
        return fallbackValue;
      }

      return _getDefaultFallback<T>();
    }
  }

  /// Safe wrapper for critical rendering operations
  void safeRender(Canvas canvas, Size size, void Function(Canvas, Size) renderFunction) {
    try {
      if (_isInCriticalError) {
        // Render error screen instead
        _renderErrorScreen(canvas, size);
        return;
      }

      // Check canvas validity
      if (size.isEmpty) {
        if (_debugMode) {
          _log.warning('Invalid canvas or size');
        }
        return;
      }

      renderFunction(canvas, size);

    } catch (e, stackTrace) {
      _handleRenderError(e, stackTrace);

      // Try to render error screen
      try {
        _renderErrorScreen(canvas, size);
      } catch (renderError) {
        // If even error screen fails, clear and try minimal rendering
        canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Paint()..color = const Color(0xFF000000),
        );
      }
    }
  }

  /// Safe wrapper for asset loading
  Future<T?> safeLoadAsset<T>(
    Future<T> Function() loadFunction,
    String assetName, {
    T? fallbackValue,
  }) async {
    try {
      final result = await loadFunction();
      return result;
    } catch (e, stackTrace) {
      if (_debugMode) {
        _log.severe('Failed to load asset $assetName: $e');
        _log.fine('Stack trace: $stackTrace');
      }

      return fallbackValue;
    }
  }

  /// Safe wrapper for audio operations
  void safeAudioOperation(
    String operationName,
    void Function() audioFunction,
  ) {
    try {
      audioFunction();
    } catch (e) {
      if (_debugMode) {
        _log.warning('Audio error in $operationName: $e');
      }
      // Audio errors should never crash the game
    }
  }

  /// Check if system is in safe mode
  bool get isInSafeMode => _isSafeModeActive;

  /// Check if system is in critical error
  bool get isInCriticalError => _isInCriticalError;

  /// Get error history
  List<GameLoopError> getErrorHistory() => List.unmodifiable(_errorHistory);

  /// Get recent frame metrics
  FrameStats getRecentFrameStats() {
    if (_frameMetrics.isEmpty) {
      return FrameStats.empty();
    }

    final recentMetrics = _frameMetrics.length > 60
        ? _frameMetrics.sublist(_frameMetrics.length - 60)
        : List.from(_frameMetrics);

    final totalFrames = recentMetrics.length;
    final totalDuration = recentMetrics
        .map((m) => m.duration.inMicroseconds)
        .reduce((a, b) => a + b);

    final averageDuration = totalDuration / totalFrames;
    final averageFPS = 1000000 / averageDuration;

    final successfulFrames = recentMetrics
        .where((m) => m.success)
        .length;

    return FrameStats(
      averageFPS: averageFPS,
      frameCount: totalFrames,
      successRate: successfulFrames / totalFrames,
      worstFrameMS: recentMetrics
          .map((m) => m.duration.inMicroseconds / 1000)
          .reduce((a, b) => a > b ? a : b) /
          1000,
    );
  }

  /// Reset safe mode (call after recovery)
  void resetSafeMode() {
    _isSafeModeActive = false;
    _consecutiveErrors = 0;

    if (_debugMode) {
      _log.info('Safe mode reset');
    }

    GameEventBus.instance.fire(SafeModeResetEvent());
  }

  /// Force safe mode (call during issues)
  void forceSafeMode(String reason) {
    if (!_isSafeModeActive) {
      _isSafeModeActive = true;

      if (_debugMode) {
        _log.warning('Safe mode activated: $reason');
      }

      GameEventBus.instance.fire(SafeModeActivatedEvent(reason));
    }
  }

  /// Check system health
  GameLoopHealth checkSystemHealth() {
    final frameStats = getRecentFrameStats();
    final errorRate = _errorHistory.isEmpty
        ? 0.0
        : _errorHistory.where((e) => !e.recovered).length / _errorHistory.length;

    GameLoopHealthStatus status;
    if (_isInCriticalError) {
      status = GameLoopHealthStatus.critical;
    } else if (_isSafeModeActive) {
      status = GameLoopHealthStatus.degraded;
    } else if (frameStats.averageFPS < 30 || errorRate > 0.1) {
      status = GameLoopHealthStatus.warning;
    } else if (frameStats.averageFPS < 45) {
      status = GameLoopHealthStatus.good;
    } else {
      status = GameLoopHealthStatus.excellent;
    }

    return GameLoopHealth(
      status: status,
      averageFPS: frameStats.averageFPS,
      errorRate: errorRate,
      consecutiveErrors: _consecutiveErrors,
      isInSafeMode: _isSafeModeActive,
    );
  }

  // Private methods

  void _handleGameLoopError(
    Object error,
    StackTrace stackTrace,
    String operationName,
    DateTime frameTime,
  ) {
    _consecutiveErrors++;

    // Create error record
    final gameError = GameLoopError(
      error: error,
      stackTrace: stackTrace,
      operationName: operationName,
      timestamp: DateTime.now(),
      frameTime: frameTime,
      recovered: false,
    );

    // Add to history
    _errorHistory.add(gameError);
    if (_errorHistory.length > _maxErrorHistory) {
      _errorHistory.removeAt(0);
    }

    // Log in debug mode
    if (_debugMode) {
      _log.severe('ERROR in $operationName: $error');
      _log.fine('Stack trace: $stackTrace');
      _log.warning('Consecutive errors: $_consecutiveErrors');
    }

    // Check if we need to enter critical error state
    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      _enterCriticalError(gameError);
    } else if (_consecutiveErrors >= 2) {
      forceSafeMode('Consecutive errors detected');
    }

    // Record failed frame metrics
    _recordFrameMetrics(frameTime, false);

    // Fire error event
    GameEventBus.instance.fire(GameLoopErrorEvent(
      error: error,
      operationName: operationName,
      consecutiveErrors: _consecutiveErrors,
    ));
  }

  void _handleRenderError(Object error, StackTrace stackTrace) {
    if (_debugMode) {
      _log.severe('RENDER ERROR: $error');
      _log.fine('Stack trace: $stackTrace');
    }

    // Create render error record
    final renderError = GameLoopError(
      error: error,
      stackTrace: stackTrace,
      operationName: 'render',
      timestamp: DateTime.now(),
      frameTime: DateTime.now(),
      recovered: false,
    );

    _errorHistory.add(renderError);
    if (_errorHistory.length > _maxErrorHistory) {
      _errorHistory.removeAt(0);
    }
  }

  void _enterCriticalError(GameLoopError error) {
    _isInCriticalError = true;

    if (_debugMode) {
      _log.severe('CRITICAL ERROR: Entering safe mode');
      _log.severe('Error: ${error.error}');
      _log.severe('Operation: ${error.operationName}');
    }

    // Force safe mode
    forceSafeMode('Critical error detected');

    // Fire critical error event
    GameEventBus.instance.fire(CriticalGameLoopErrorEvent(
      error: error.error,
      operationName: error.operationName,
      timestamp: error.timestamp,
    ));
  }

  void _recordFrameMetrics(DateTime frameTime, bool success) {
    final metrics = FrameMetrics(
      frameTime: frameTime,
      success: success,
      timestamp: DateTime.now(),
    );

    _frameMetrics.add(metrics);
    if (_frameMetrics.length > _maxFrameMetrics) {
      _frameMetrics.removeAt(0);
    }
  }

  void _renderErrorScreen(Canvas canvas, Size size) {
    // Draw error screen with minimal operations
    final paint = Paint()
      ..color = const Color(0xFF1A1A1A);

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Draw error text
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Game Error\nTap to Restart',
        style: TextStyle(
          color: Color(0xFFFF6B6B),
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );
  }

  T _getDefaultFallback<T>() {
    // Provide type-safe fallbacks
    if (T == int) {
      return 0 as T;
    } else if (T == double) {
      return 0.0 as T;
    } else if (T == bool) {
      return false as T;
    } else if (T == String) {
      return '' as T;
    } else if (T.toString().startsWith('List')) {
      return [] as T;
    } else if (T.toString().startsWith('Map')) {
      return {} as T;
    } else {
      throw Exception('No fallback available for type $T');
    }
  }

  /// Dispose resources
  void dispose() {
    _errorHistory.clear();
    _frameMetrics.clear();
  }
}

// Data models for game loop safety

class GameLoopError {
  final Object error;
  final StackTrace stackTrace;
  final String operationName;
  final DateTime timestamp;
  final DateTime frameTime;
  bool recovered;

  GameLoopError({
    required this.error,
    required this.stackTrace,
    required this.operationName,
    required this.timestamp,
    required this.frameTime,
    this.recovered = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'error': error.toString(),
      'operationName': operationName,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'frameTime': frameTime.millisecondsSinceEpoch,
      'recovered': recovered,
    };
  }
}

class FrameMetrics {
  final DateTime frameTime;
  final bool success;
  final DateTime timestamp;

  FrameMetrics({
    required this.frameTime,
    required this.success,
    required this.timestamp,
  });

  Duration get duration => timestamp.difference(frameTime);
}

class FrameStats {
  final double averageFPS;
  final int frameCount;
  final double successRate;
  final double worstFrameMS;

  FrameStats({
    required this.averageFPS,
    required this.frameCount,
    required this.successRate,
    required this.worstFrameMS,
  });

  factory FrameStats.empty() {
    return FrameStats(
      averageFPS: 0.0,
      frameCount: 0,
      successRate: 0.0,
      worstFrameMS: 0.0,
    );
  }
}

class GameLoopHealth {
  final GameLoopHealthStatus status;
  final double averageFPS;
  final double errorRate;
  final int consecutiveErrors;
  final bool isInSafeMode;

  GameLoopHealth({
    required this.status,
    required this.averageFPS,
    required this.errorRate,
    required this.consecutiveErrors,
    required this.isInSafeMode,
  });
}

enum GameLoopHealthStatus {
  critical,    // Multiple consecutive errors
  degraded,    // Safe mode active
  warning,     // Low FPS or error rate
  good,        // Acceptable performance
  excellent,   // Optimal performance
}

// Event classes for game loop safety

class GameLoopErrorEvent extends GameEvent {
  final Object error;
  final String operationName;
  final int consecutiveErrors;

  GameLoopErrorEvent({
    required this.error,
    required this.operationName,
    required this.consecutiveErrors,
  });
}

class CriticalGameLoopErrorEvent extends GameEvent {
  final Object error;
  final String operationName;
  final DateTime timestamp;

  CriticalGameLoopErrorEvent({
    required this.error,
    required this.operationName,
    required this.timestamp,
  });
}

class SafeModeActivatedEvent extends GameEvent {
  final String reason;

  SafeModeActivatedEvent(this.reason);
}

class SafeModeResetEvent extends GameEvent {}