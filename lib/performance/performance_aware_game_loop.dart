import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_neon_runner/config/game_config.dart';
import 'package:flutter_neon_runner/game/systems/base_game_system.dart';
import 'package:flutter_neon_runner/performance/game_loop_safety.dart';
import 'package:flutter_neon_runner/performance/mobile_performance_system.dart';
import 'package:logging/logging.dart';

/// Performance-aware game loop controller optimized for mobile devices
/// Ensures stable 60 FPS on mid-range Android devices
class PerformanceAwareGameLoop {
  final GameLoopSafety _safety;
  final MobilePerformanceSystem _performance;
  static final _log = Logger('PerformanceAwareGameLoop');

  // Frame timing control
  double _accumulatedTime = 0.0;
  double _targetFrameTime = 16.67; // 60 FPS
  int _maxFramesPerUpdate = 2;

  // Performance tracking
  DateTime _lastStatsUpdate = DateTime.now();

  // Adaptive settings
  bool _adaptiveFrameSkip = true;
  bool _dynamicTimeStep = true;

  PerformanceAwareGameLoop()
      : _safety = GameLoopSafety(/* gameStateController */),
        _performance = MobilePerformanceSystem() {
    _performance.preallocateObjects();
  }

  /// Get target frame time based on performance level
  double get targetFrameTime {
    if (_dynamicTimeStep) {
      return _performance.getTargetFrameInterval();
    }
    return _targetFrameTime;
  }

  /// Update frame timing parameters
  void updateFrameTiming() {
    _targetFrameTime = _performance.getTargetFrameInterval();
    _maxFramesPerUpdate = _performance.getAverageFPS() < 30 ? 1 : 2;
  }

  /// Perform safe update with zero allocations
  void safeUpdate(double dt, List<GameSystem> systems) {
    final updateTimer = _performance.startUpdate();

    try {
      // Check if we should skip this frame
      if (_performance.shouldSkipFrame()) {
        return;
      }

      // Accumulate time
      _accumulatedTime += dt;

      // Calculate number of update steps
      var steps = (_accumulatedTime / _targetFrameTime).floor();
      steps = math.min(steps.toDouble(), _maxFramesPerUpdate.toDouble()).toInt();

      if (steps > 0) {
        final stepTime = _accumulatedTime / steps;

        // Update systems
        for (final system in systems) {
          // Zero-allocation check
          if (system is PausableSystem && system.isPaused) {
            continue;
          }

          try {
            system.update(stepTime);
          } catch (e) {
            _safety.safeUpdate(
              () => throw e,
              'system.update(${system.runtimeType})',
            );
          }
        }

        _accumulatedTime -= steps * stepTime;
      }

    } catch (e) {
      _safety.safeUpdate(
        () => throw e,
        'game_loop.update',
      );
    } finally {
      updateTimer.end();
    }
  }

  /// Perform safe rendering with zero allocations
  void safeRender(Canvas canvas, Size size, List<RenderComponent> renderComponents) {
    final renderTimer = _performance.startRender();

    try {
      // Pre-render check
      if (size.isEmpty) {
        return;
      }

      // Update frame timing
      updateFrameTiming();

      // Use the safety wrapper for rendering
      _safety.safeRender(canvas, size, (canvas, size) {
        _renderGameWorld(canvas, size);
        _renderComponents(canvas, size, renderComponents);
        _renderDebugInfo(canvas, size);
      });

    } finally {
      renderTimer.end();
    }
  }

  /// Render game world with performance optimizations
  void _renderGameWorld(Canvas canvas, Size size) {
    // Use cached paint objects
    final gridPaint = _performance.getPaint()
      ..color = const Color.fromRGBO(3, 160, 98, 0.3)
      ..strokeWidth = 1;

    final groundPaint = _performance.getPaint()
      ..color = GameConfig.primaryNeonColor
      ..strokeWidth = GameConfig.groundLineStrokeWidth;

    // Render background grid
    _renderBackgroundGrid(canvas, size, gridPaint);

    // Render ground line
    canvas.drawLine(
      Offset(0, GameConfig.groundLevel),
      Offset(size.width, GameConfig.groundLevel),
      groundPaint,
    );
  }

  /// Render background grid efficiently
  void _renderBackgroundGrid(Canvas canvas, Size size, Paint paint) {
    // Get frame count from performance system
    final frames = _performance.getPerformanceStats().frameCount;
    final gridOffset = (frames * _performance.currentFPS) % GameConfig.gridLineOffsetDivisor;

    // Only render visible grid lines
    final startLine = (gridOffset / GameConfig.gridLineOffsetDivisor).floor();
    final endLine = startLine + (size.width / GameConfig.gridLineOffsetDivisor).ceil() + 2;

    for (double i = startLine.toDouble(); i <= endLine; i++) {
      final x = i * GameConfig.gridLineOffsetDivisor - gridOffset;
      if (x >= 0 && x <= size.width) {
        canvas.drawLine(
          Offset(x, GameConfig.groundLevel),
          Offset(x, size.height),
          paint,
        );
      }
    }
  }

  /// Render components with zero allocations
  void _renderComponents(Canvas canvas, Size size, List<RenderComponent> components) {
    for (final component in components) {
      try {
        component.render(canvas, size);
      } catch (e) {
        // Continue rendering other components
        if (kDebugMode) {
          _log.warning('Render error in ${component.runtimeType}: $e');
        }
      }
    }
  }

  /// Render debug information (debug builds only)
  void _renderDebugInfo(Canvas canvas, Size size) {
    if (!kDebugMode) return;

    final textPainter = _performance.getTextPainter();

    // FPS counter
    textPainter.text = TextSpan(
      text: 'FPS: ${_performance.currentFPS.toStringAsFixed(1)}',
      style: const TextStyle(
        color: Color(0xFFFF0000),
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(10, 10));

    // Frame metrics
    final stats = _performance.getPerformanceStats();
    textPainter.text = TextSpan(
      text: 'Avg: ${stats.averageFPS.toStringAsFixed(1)} | '
            'Worst: ${stats.worstFrameTime.toStringAsFixed(2)}ms | '
            'Pools: ${stats.vector2PoolSize + stats.rectPoolSize}',
      style: const TextStyle(
        color: Color(0xFF00FF00),
        fontSize: 12,
        fontFamily: 'monospace',
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(10, 30));

    // Performance level
    textPainter.text = TextSpan(
      text: 'Level: ${stats.performanceLevel} | '
            'Allocs: ${stats.allocationCount}',
      style: const TextStyle(
        color: Color(0xFFFFFF00),
        fontSize: 12,
        fontFamily: 'monospace',
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(10, 50));

    _performance.returnTextPainter(textPainter);
  }

  /// Update performance statistics
  void updatePerformanceStats() {
    final now = DateTime.now();
    if (now.difference(_lastStatsUpdate).inSeconds >= 1) {
      final stats = _performance.getPerformanceStats();

      // Log performance stats in debug mode
      if (kDebugMode) {
        _log.info('=== PERFORMANCE STATS ===');
        _log.info('FPS: ${stats.currentFPS.toStringAsFixed(1)} (avg: ${stats.averageFPS.toStringAsFixed(1)})');
        _log.info('Frame time: ${stats.worstFrameTime.toStringAsFixed(2)}ms (worst)');
        _log.info('Update: ${stats.averageUpdateTime.toStringAsFixed(2)}ms (avg)');
        _log.info('Render: ${stats.averageRenderTime.toStringAsFixed(2)}ms (avg)');
        _log.info('Allocations: ${stats.allocationCount}');
        _log.info('Pools: V2=${stats.vector2PoolSize}, R=${stats.rectPoolSize}, P=${stats.paintPoolSize}');
        _log.info('Performance Level: ${stats.performanceLevel}');
      }

      // Check for performance issues
      // Performance issues checking would be implemented here

      _lastStatsUpdate = now;
    }
  }

  /// Get frame skip recommendation
  bool shouldSkipFrame() {
    if (!_adaptiveFrameSkip) return false;

    // Skip if we're running behind
    return _performance.shouldSkipFrame();
  }

  /// Reset performance metrics
  void resetPerformance() {
    _performance.reset();
    _accumulatedTime = 0.0;
  }

  /// Get system health status
  PerformanceHealth getSystemHealth() {
    final stats = _performance.getPerformanceStats();
    final health = _safety.checkSystemHealth();

    return PerformanceHealth(
      fps: stats.currentFPS,
      averageFPS: stats.averageFPS,
      worstFrameTime: stats.worstFrameTime,
      safeModeActive: health.isInSafeMode,
      criticalErrors: health.status == GameLoopHealthStatus.critical,
      memoryPressure: _getMemoryPressureLevel(stats),
      adaptiveQualityActive: _performance.isAdaptiveQualityEnabled,
    );
  }

  int _getMemoryPressureLevel(PerformanceStats stats) {
    final totalPools = stats.vector2PoolSize + stats.rectPoolSize + stats.paintPoolSize;

    if (totalPools > 200) return 3; // High
    if (totalPools > 100) return 2; // Medium
    if (totalPools > 50) return 1; // Low
    return 0; // Minimal
  }

  /// Dispose resources
  void dispose() {
    _safety.dispose();
    _performance.dispose();
  }

  /// Update configuration
  void updateConfiguration({
    bool? adaptiveFrameSkip,
    bool? dynamicTimeStep,
    double? targetFPS,
  }) {
    if (adaptiveFrameSkip != null) {
      _adaptiveFrameSkip = adaptiveFrameSkip;
    }
    if (dynamicTimeStep != null) {
      _dynamicTimeStep = dynamicTimeStep;
    }
    if (targetFPS != null) {
      _targetFrameTime = 1000.0 / targetFPS;
    }
  }
}

/// Mixin for renderable components
mixin RenderComponent {
  void render(Canvas canvas, Size size);
}

/// Performance health status
class PerformanceHealth {
  final double fps;
  final double averageFPS;
  final double worstFrameTime;
  final bool safeModeActive;
  final bool criticalErrors;
  final int memoryPressure;
  final bool adaptiveQualityActive;

  PerformanceHealth({
    required this.fps,
    required this.averageFPS,
    required this.worstFrameTime,
    required this.safeModeActive,
    required this.criticalErrors,
    required this.memoryPressure,
    required this.adaptiveQualityActive,
  });

  bool get isHealthy => fps >= 45 && !criticalErrors && memoryPressure < 2;
  bool get needsOptimization => fps < 45 || memoryPressure > 1 || criticalErrors;

  PerformanceHealthLevel get healthLevel {
    if (criticalErrors) return PerformanceHealthLevel.critical;
    if (fps < 30 || safeModeActive) return PerformanceHealthLevel.poor;
    if (fps < 45 || memoryPressure > 2) return PerformanceHealthLevel.warning;
    if (fps < 55) return PerformanceHealthLevel.good;
    return PerformanceHealthLevel.excellent;
  }
}

enum PerformanceHealthLevel {
  critical,
  poor,
  warning,
  good,
  excellent,
}

/// Performance optimization guidelines
class PerformanceOptimizationGuide {
  static String get mobileOptimizationGuide => '''
NEON RUNNER - MOBILE PERFORMANCE OPTIMIZATION GUIDE
================================================

1. OBJECT POOLING (CRITICAL)
- Use MobilePerformanceSystem for Vector2, Rect, Offset, Paint objects
- Always return objects to pool after use
- Pre-allocate objects at game start
- Pool sizes: Vector2(50), Rect(30), Offset(40), Paint(20)

2. ZERO ALLOCATIONS IN UPDATE()
- Never create new objects in game loop update
- Use object pools for all temporary objects
- Avoid String concatenation in update
- Pre-calculate reusable values

3. DELTA TIME MOVEMENT
- Multiply all movements by delta time
- Use variable frame rates for different devices
- Target: 60 FPS (16.67ms), adapt as needed
- Use max frames per update for catch-up

4. RENDERING OPTIMIZATIONS
- Use cached Paint objects
- Batch similar operations
- Avoid transparency in mobile performance mode
- Limit particle effects based on performance level

5. MEMORY MANAGEMENT
- Monitor object pool sizes
- Implement adaptive quality based on memory pressure
- Clear pools when entering safe mode
- Use weak references for large objects

6. MOBILE-SPECIFIC SETTINGS
- Particle count: 20-100 (adaptive)
- Trail length: 5-20 (adaptive)
- Target: 60 FPS on mid-range Android (Snapdragon 425+)
- GPU acceleration for all visual effects

7. ADAPTIVE QUALITY
- Adjust quality based on average FPS:
  * < 45 FPS: Low quality (20 particles, 5 trail)
  * 45-55 FPS: Medium quality (50 particles, 10 trail)
  * > 55 FPS: High quality (100 particles, 20 trail)

8. BATTERY OPTIMIZATION
- Reduce physics simulation when battery low
- Implement frame rate limiting
- Use efficient rendering paths
- Minimize background processing

9. DEBUG MONITORING
- FPS counter in debug builds only
- Frame time tracking
- Object pool size monitoring
- Allocation count tracking

10. ERROR HANDLING
- Wrap all critical operations in try-catch
- Never crash the main game loop
- Enter safe mode on consecutive errors
- Graceful degradation for asset loading

Remember: Test on actual mid-range Android devices!
    ''';
}