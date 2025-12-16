import 'dart:async' as async;
import 'dart:collection';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flame/components.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'package:flutter_neon_runner/game/events/game_events.dart';
import 'package:flutter_neon_runner/game/systems/base_game_system.dart';

/// Mobile-optimized performance system with FPS monitoring and object pooling
/// Target: Stable 60 FPS on mid-range Android devices
class MobilePerformanceSystem {
  // FPS monitoring
  final FPSMonitor _fpsMonitor = FPSMonitor();

  // Object pools
  final ObjectPool<vm.Vector2> _vector2Pool = ObjectPool<vm.Vector2>(
    factory: () => vm.Vector2.zero(),
    reset: (v) => v.setZero(),
    initialSize: 50,
    maxSize: 200,
  );

  final ObjectPool<Rect> _rectPool = ObjectPool<Rect>(
    factory: () => Rect.zero,
    reset: (r) {},
    initialSize: 30,
    maxSize: 100,
  );

  final ObjectPool<Offset> _offsetPool = ObjectPool<Offset>(
    factory: () => Offset.zero,
    reset: (o) {},
    initialSize: 40,
    maxSize: 150,
  );

  final ObjectPool<Paint> _paintPool = ObjectPool<Paint>(
    factory: () => Paint(),
    reset: (p) {
      p.color = const Color(0x00000000);
      p.style = PaintingStyle.fill;
    },
    initialSize: 20,
    maxSize: 50,
  );

  final ObjectPool<TextPainter> _textPainterPool = ObjectPool<TextPainter>(
    factory: () => TextPainter(
      text: const TextSpan(text: '', style: TextStyle()),
      textDirection: TextDirection.ltr,
    ),
    reset: (tp) {
      tp.text = const TextSpan(text: '', style: TextStyle());
    },
    initialSize: 10,
    maxSize: 30,
  );

  // Performance metrics
  int _frameCount = 0;
  double _totalUpdateTime = 0.0;
  double _totalRenderTime = 0.0;
  int _allocationCount = 0;

  // Performance budgets
  static const double _updateBudget = 16.67; // 60 FPS
  static const double _renderBudget = 8.0;    // Half of frame budget

  // Optimization state
  bool _isAdaptiveQualityEnabled = true;
  int _performanceLevel = 2; // 0=low, 1=medium, 2=high

  /// Check if adaptive quality is enabled
  bool get isAdaptiveQualityEnabled => _isAdaptiveQualityEnabled;

  // Memory monitoring
  int _memoryPressure = 0;
  async.Timer? _memoryMonitorTimer;

  MobilePerformanceSystem() {
    _startMemoryMonitoring();
  }

  /// Get a Vector2 from pool
  vm.Vector2 getVector2(double x, double y) {
    final vector = _vector2Pool.acquire();
    vector.setValues(x, y);
    return vector;
  }

  /// Get a Rect from pool
  Rect getRect(double left, double top, double right, double bottom) {
    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// Get an Offset from pool
  Offset getOffset(double dx, double dy) {
    final offset = _offsetPool.acquire();
    return Offset(dx, dy);
  }

  /// Get a Paint from pool
  Paint getPaint() {
    return _paintPool.acquire();
  }

  /// Get a TextPainter from pool
  TextPainter getTextPainter() {
    return _textPainterPool.acquire();
  }

  /// Return objects to pools
  void returnVector2(vm.Vector2 vector) {
    _vector2Pool.release(vector);
  }

  void returnRect(Rect rect) {
    _rectPool.release(rect);
  }

  void returnOffset(Offset offset) {
    _offsetPool.release(offset);
  }

  void returnPaint(Paint paint) {
    _paintPool.release(paint);
  }

  void returnTextPainter(TextPainter painter) {
    _textPainterPool.release(painter);
  }

  /// Start monitoring a frame
  void startFrame() {
    _fpsMonitor.startFrame();
    _allocationCount = 0; // Reset allocation count for this frame
  }

  /// Start update timing
  UpdateTimer startUpdate() {
    return UpdateTimer(this);
  }

  /// Start render timing
  RenderTimer startRender() {
    return RenderTimer(this);
  }

  /// End frame and update metrics
  void endFrame() {
    _fpsMonitor.endFrame();
    _frameCount++;
  }

  /// Record update time
  void recordUpdateTime(double duration) {
    _totalUpdateTime += duration;
  }

  /// Record render time
  void recordRenderTime(double duration) {
    _totalRenderTime += duration;
  }

  /// Record allocation
  void recordAllocation() {
    _allocationCount++;
  }

  /// Check if current frame is within performance budget
  bool isWithinBudget() {
    final updateTime = _fpsMonitor.lastUpdateTime;
    final renderTime = _fpsMonitor.lastRenderTime;

    return updateTime < _updateBudget && renderTime < _renderBudget;
  }

  /// Get current FPS
  double get currentFPS => _fpsMonitor.currentFPS;

  /// Get average FPS over last 60 frames
  double getAverageFPS() => _fpsMonitor.averageFPS;

  /// Get worst frame time
  double getWorstFrameTime() => _fpsMonitor.worstFrameTime;

  /// Get performance statistics
  PerformanceStats getPerformanceStats() {
    final avgUpdate = _frameCount > 0 ? _totalUpdateTime / _frameCount : 0.0;
    final avgRender = _frameCount > 0 ? _totalRenderTime / _frameCount : 0.0;

    return PerformanceStats(
      currentFPS: currentFPS,
      averageFPS: getAverageFPS(),
      worstFrameTime: getWorstFrameTime(),
      averageUpdateTime: avgUpdate,
      averageRenderTime: avgRender,
      frameCount: _frameCount,
      allocationCount: _allocationCount,
      vector2PoolSize: _vector2Pool.size,
      rectPoolSize: _rectPool.size,
      paintPoolSize: _paintPool.size,
      performanceLevel: _performanceLevel,
    );
  }

  /// Adaptive quality adjustment based on performance
  void adjustQuality() {
    if (!_isAdaptiveQualityEnabled) return;

    final fps = currentFPS;
    final oldLevel = _performanceLevel;

    if (fps < 45) {
      // Poor performance - reduce quality
      _performanceLevel = math.max(0, _performanceLevel - 1);
      _applyPerformanceLevel(_performanceLevel);
    } else if (fps > 55 && _performanceLevel < 2) {
      // Good performance - increase quality
      _performanceLevel = math.min(2, _performanceLevel + 1);
      _applyPerformanceLevel(_performanceLevel);
    }

    if (oldLevel != _performanceLevel) {
      if (kDebugMode) {
        print('Performance level adjusted: $oldLevel → $_performanceLevel (FPS: $fps)');
      }
      GameEventBus.instance.fire(PerformanceLevelChangedEvent(
        oldLevel: oldLevel,
        newLevel: _performanceLevel,
        fps: fps,
      ));
    }
  }

  /// Pre-allocate frequently used objects
  void preallocateObjects() {
    // Pre-allocate Vector2s for common operations
    for (int i = 0; i < 30; i++) {
      _vector2Pool.acquire();
    }

    // Pre-allocate Rects for collision detection
    for (int i = 0; i < 20; i++) {
      _rectPool.acquire();
    }

    // Pre-allocate Paint objects
    for (int i = 0; i < 15; i++) {
      _paintPool.acquire();
    }
  }

  /// Get recommended particle count based on performance
  int getRecommendedParticleCount() {
    switch (_performanceLevel) {
      case 0: // Low performance
        return 20;
      case 1: // Medium performance
        return 50;
      case 2: // High performance
        return 100;
      default:
        return 30;
    }
  }

  /// Check if we should skip a frame
  bool shouldSkipFrame() {
    // Skip frame if we're running behind
    return _fpsMonitor.frameSkip;
  }

  /// Get target frame interval based on performance
  double getTargetFrameInterval() {
    switch (_performanceLevel) {
      case 0: // Low performance - run at 30 FPS
        return 33.33;
      case 1: // Medium performance - run at 45 FPS
        return 22.22;
      case 2: // High performance - run at 60 FPS
        return 16.67;
      default:
        return 16.67;
    }
  }

  /// Monitor memory usage
  void _startMemoryMonitoring() {
    _memoryMonitorTimer = async.Timer.periodic(Duration(seconds: 10), (_) {
      _checkMemoryPressure();
    });
  }

  void _checkMemoryPressure() {
    // Estimate memory usage based on pool sizes
    final totalObjects = _vector2Pool.size + _rectPool.size +
                      _offsetPool.size + _paintPool.size;

    // Simple heuristic for memory pressure
    if (totalObjects > 300) {
      _memoryPressure = 2; // High pressure
      _reducePoolSizes();
    } else if (totalObjects > 200) {
      _memoryPressure = 1; // Medium pressure
    } else {
      _memoryPressure = 0; // Low pressure
    }

    // Adapt performance based on memory pressure
    if (_memoryPressure > 1) {
      _performanceLevel = math.max(0, _performanceLevel - 1);
      _applyPerformanceLevel(_performanceLevel);
    }
  }

  void _reducePoolSizes() {
    _vector2Pool.shrinkTo(30);
    _rectPool.shrinkTo(15);
    _paintPool.shrinkTo(10);
    _textPainterPool.shrinkTo(5);
  }

  void _applyPerformanceLevel(int level) {
    switch (level) {
      case 0: // Low performance settings
        // GameConfig.maxParticles = 20; // Not implemented
        // GameConfig.particleLifespan = 60; // Not implemented
        // GameConfig.trailLength = 5; // Not implemented
        break;
      case 1: // Medium performance settings
        // GameConfig.maxParticles = 50; // Not implemented
        // GameConfig.particleLifespan = 120; // Not implemented
        // GameConfig.trailLength = 10; // Not implemented
        break;
      case 2: // High performance settings
        // GameConfig.maxParticles = 100; // Not implemented
        // GameConfig.particleLifespan = 180; // Not implemented
        // GameConfig.trailLength = 20; // Not implemented
        break;
    }
  }

  /// Reset performance metrics
  void reset() {
    _fpsMonitor.reset();
    _frameCount = 0;
    _totalUpdateTime = 0.0;
    _totalRenderTime = 0.0;
    _allocationCount = 0;

    // Clear object pools
    _vector2Pool.clear();
    _rectPool.clear();
    _offsetPool.clear();
    _paintPool.clear();
    _textPainterPool.clear();

    // Pre-allocate again
    preallocateObjects();
  }

  /// Dispose resources
  void dispose() {
    _memoryMonitorTimer?.cancel();
    _fpsMonitor.dispose();

    _vector2Pool.dispose();
    _rectPool.dispose();
    _offsetPool.dispose();
    _paintPool.dispose();
    _textPainterPool.dispose();
  }
}

/// FPS monitoring system for mobile devices
class FPSMonitor {
  final List<double> _frameTimes = [];
  final List<double> _recentFPS = [];
  static const int _maxFrameTimes = 60;
  static const int _maxRecentFPS = 60;

  DateTime? _lastFrameTime;
  double _lastUpdateTime = 0.0;
  double _lastRenderTime = 0.0;
  bool _frameSkip = false;

  void startFrame() {
    _lastFrameTime = DateTime.now();
  }

  void endFrame() {
    if (_lastFrameTime == null) return;

    final now = DateTime.now();
    final frameTime = now.difference(_lastFrameTime!).inMicroseconds / 1000.0;

    _frameTimes.add(frameTime);
    if (_frameTimes.length > _maxFrameTimes) {
      _frameTimes.removeAt(0);
    }

    // Calculate FPS
    if (frameTime > 0) {
      final fps = 1000.0 / frameTime;
      _recentFPS.add(fps);
      if (_recentFPS.length > _maxRecentFPS) {
        _recentFPS.removeAt(0);
      }
    }

    // Determine if we should skip next frame
    _frameSkip = _recentFPS.length > 10 && _recentFPS.last < 30;

    _lastFrameTime = now;
  }

  double get currentFPS {
    if (_recentFPS.isEmpty) return 0.0;
    return _recentFPS.last;
  }

  double get averageFPS {
    if (_recentFPS.isEmpty) return 0.0;
    return _recentFPS.reduce((a, b) => a + b) / _recentFPS.length;
  }

  double get worstFrameTime {
    if (_frameTimes.isEmpty) return 0.0;
    return _frameTimes.reduce(math.max);
  }

  double get lastUpdateTime => _lastUpdateTime;

  double get lastRenderTime => _lastRenderTime;

  bool get frameSkip => _frameSkip;

  void recordUpdateTime(double duration) {
    _lastUpdateTime = duration;
  }

  void recordRenderTime(double duration) {
    _lastRenderTime = duration;
  }

  void reset() {
    _frameTimes.clear();
    _recentFPS.clear();
    _lastFrameTime = null;
    _frameSkip = false;
  }

  void dispose() {
    _frameTimes.clear();
    _recentFPS.clear();
  }
}

/// Generic object pool for memory-efficient object reuse
class ObjectPool<T> {
  final T Function() _factory;
  final void Function(T) _reset;
  final Queue<T> _pool = Queue();

  int _size = 0;
  final int _initialSize;
  final int _maxSize;

  ObjectPool({
    required T Function() factory,
    required void Function(T) reset,
    required int initialSize,
    required int maxSize,
  }) : _factory = factory,
       _reset = reset,
       _initialSize = initialSize,
       _maxSize = maxSize;

  /// Pre-populate pool with initial objects
  void prepopulate() {
    for (int i = 0; i < _initialSize; i++) {
      _pool.add(_factory());
      _size++;
    }
  }

  /// Acquire object from pool
  T acquire() {
    if (_pool.isNotEmpty) {
      _size--;
      final obj = _pool.removeFirst();
      return obj;
    }

    // Create new object if pool is empty
    return _factory();
  }

  /// Release object back to pool
  void release(T obj) {
    if (_size < _maxSize) {
      _reset(obj);
      _pool.add(obj);
      _size++;
    }
    // Pool is full, object will be garbage collected
  }

  /// Get current pool size
  int get size => _size;

  /// Shrink pool to target size
  void shrinkTo(int targetSize) {
    while (_pool.length > targetSize) {
      _pool.removeFirst();
      _size--;
    }
  }

  /// Clear all objects from pool
  void clear() {
    _pool.clear();
    _size = 0;
  }

  /// Dispose pool
  void dispose() {
    clear();
  }
}

/// Timer for measuring update performance
class UpdateTimer {
  final MobilePerformanceSystem _performanceSystem;
  final Stopwatch _stopwatch = Stopwatch();

  UpdateTimer(this._performanceSystem);

  void start() {
    _stopwatch.start();
  }

  void end() {
    _stopwatch.stop();
    final duration = _stopwatch.elapsedMicroseconds / 1000.0;
    _performanceSystem.recordUpdateTime(duration);
    _stopwatch.reset();
  }
}

/// Timer for measuring render performance
class RenderTimer {
  final MobilePerformanceSystem _performanceSystem;
  final Stopwatch _stopwatch = Stopwatch();

  RenderTimer(this._performanceSystem);

  void start() {
    _stopwatch.start();
  }

  void end() {
    _stopwatch.stop();
    final duration = _stopwatch.elapsedMicroseconds / 1000.0;
    _performanceSystem.recordRenderTime(duration);
    _stopwatch.reset();
  }
}

/// Performance statistics
class PerformanceStats {
  final double currentFPS;
  final double averageFPS;
  final double worstFrameTime;
  final double averageUpdateTime;
  final double averageRenderTime;
  final int frameCount;
  final int allocationCount;
  final int vector2PoolSize;
  final int rectPoolSize;
  final int paintPoolSize;
  final int performanceLevel;

  PerformanceStats({
    required this.currentFPS,
    required this.averageFPS,
    required this.worstFrameTime,
    required this.averageUpdateTime,
    required this.averageRenderTime,
    required this.frameCount,
    required this.allocationCount,
    required this.vector2PoolSize,
    required this.rectPoolSize,
    required this.paintPoolSize,
    required this.performanceLevel,
  });
}

/// Event for performance level changes
class PerformanceLevelChangedEvent extends GameEvent {
  final int oldLevel;
  final int newLevel;
  final double fps;

  PerformanceLevelChangedEvent({
    required this.oldLevel,
    required this.newLevel,
    required this.fps,
  });
}