import 'package:flutter/material.dart';
import 'package:flutter_neon_runner/config/build_config.dart';
import 'package:flutter_neon_runner/game/neon_runner_game.dart';
import 'package:flutter_neon_runner/performance/mobile_performance_system.dart';

/// Debug overlay for development and profiling
class DebugOverlay extends StatefulWidget {
  final NeonRunnerGame game;
  final MobilePerformanceSystem performanceSystem;

  const DebugOverlay({
    super.key,
    required this.game,
    required this.performanceSystem,
  });

  @override
  State<DebugOverlay> createState() => _DebugOverlayState();
}

class _DebugOverlayState extends State<DebugOverlay> {
  bool _isVisible = BuildConfig.enableDebugUI;

  @override
  Widget build(BuildContext context) {
    if (!BuildConfig.enableDebugUI || !_isVisible) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // FPS Counter
        if (BuildConfig.enableFPSCounter)
          Positioned(
            top: 60,
            left: 8,
            child: _buildFPSCounter(),
          ),

        // Performance Metrics
        if (BuildConfig.enablePerformanceMetrics)
          Positioned(
            top: 100,
            left: 8,
            child: _buildPerformanceMetrics(),
          ),

        // Memory Info
        if (BuildConfig.enableMemoryMonitoring)
          Positioned(
            top: 160,
            left: 8,
            child: _buildMemoryInfo(),
          ),

        // Toggle Button
        Positioned(
          top: 8,
          right: 8,
          child: _buildToggleButton(),
        ),

        // State Info
        Positioned(
          top: 8,
          left: 8,
          child: _buildStateInfo(),
        ),
      ],
    );
  }

  Widget _buildFPSCounter() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ValueListenableBuilder<double>(
        valueListenable: ValueNotifier(widget.performanceSystem.currentFPS),
        builder: (context, fps, child) {
          Color fpsColor;
          if (fps >= 55) {
            fpsColor = Colors.green;
          } else if (fps >= 30) {
            fpsColor = Colors.yellow;
          } else {
            fpsColor = Colors.red;
          }

          return Text(
            'FPS: ${fps.toStringAsFixed(1)}',
            style: TextStyle(
              color: fpsColor,
              fontSize: 12,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          );
        },
      ),
    );
  }

  Widget _buildPerformanceMetrics() {
    final stats = widget.performanceSystem.getPerformanceStats();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Update: ${stats.averageUpdateTime.toStringAsFixed(2)}ms',
            style: const TextStyle(
              color: Colors.cyan,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            'Render: ${stats.averageRenderTime.toStringAsFixed(2)}ms',
            style: const TextStyle(
              color: Colors.cyan,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            'Worst: ${stats.worstFrameTime.toStringAsFixed(2)}ms',
            style: const TextStyle(
              color: Colors.orange,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryInfo() {
    final stats = widget.performanceSystem.getPerformanceStats();
    final totalPools = stats.vector2PoolSize + stats.rectPoolSize + stats.paintPoolSize;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'V2: ${stats.vector2PoolSize}',
            style: const TextStyle(
              color: Colors.blue,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            'Rect: ${stats.rectPoolSize}',
            style: const TextStyle(
              color: Colors.blue,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            'Paint: ${stats.paintPoolSize}',
            style: const TextStyle(
              color: Colors.blue,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            'Total: $totalPools',
            style: TextStyle(
              color: totalPools > 100 ? Colors.red : Colors.green,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isVisible = !_isVisible;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        ),
        child: const Icon(
          Icons.bug_report,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildStateInfo() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Score: ${widget.game.score}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            'Player: (${widget.game.player.position.x.toStringAsFixed(0)}, ${widget.game.player.position.y.toStringAsFixed(0)})',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          if (widget.game.player.isDead)
            const Text(
              'DEAD',
              style: TextStyle(
                color: Colors.red,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          if (widget.game.player.isInvincible)
            const Text(
              'INVINCIBLE',
              style: TextStyle(
                color: Colors.yellow,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
        ],
      ),
    );
  }
}

/// Debug hitbox visualization component
class DebugHitboxOverlay extends StatelessWidget {
  final List<DebugHitbox> hitboxes;

  const DebugHitboxOverlay({
    super.key,
    required this.hitboxes,
  });

  @override
  Widget build(BuildContext context) {
    if (!BuildConfig.enableHitboxVisualization) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      painter: DebugHitboxPainter(hitboxes),
    );
  }
}

class DebugHitbox {
  final double x;
  final double y;
  final double width;
  final double height;
  final Color color;

  DebugHitbox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.color = Colors.green,
  });
}

class DebugHitboxPainter extends CustomPainter {
  final List<DebugHitbox> hitboxes;

  DebugHitboxPainter(this.hitboxes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final hitbox in hitboxes) {
      paint.color = hitbox.color;
      canvas.drawRect(
        Rect.fromLTWH(hitbox.x, hitbox.y, hitbox.width, hitbox.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DebugHitboxPainter oldDelegate) {
    return true;
  }
}

/// Touch input visualization
class DebugInputOverlay extends StatefulWidget {
  final List<TouchPoint> touchPoints;

  const DebugInputOverlay({
    super.key,
    required this.touchPoints,
  });

  @override
  State<DebugInputOverlay> createState() => _DebugInputOverlayState();
}

class _DebugInputOverlayState extends State<DebugInputOverlay>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(DebugInputOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.touchPoints.isNotEmpty) {
      _fadeController.forward();
    } else {
      _fadeController.reverse();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!BuildConfig.showTouchIndicators) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      painter: DebugInputPainter(
        widget.touchPoints,
        _fadeController,
      ),
    );
  }
}

class TouchPoint {
  final Offset position;
  final DateTime timestamp;

  TouchPoint({required this.position, required this.timestamp});
}

class DebugInputPainter extends CustomPainter {
  final List<TouchPoint> touchPoints;
  final AnimationController fadeController;

  DebugInputPainter(this.touchPoints, this.fadeController);

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = fadeController.value * BuildConfig.touchIndicatorOpacity;

    final paint = Paint()
      ..color = Colors.red.withValues(alpha: opacity)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    for (final point in touchPoints) {
      // Draw touch point
      canvas.drawCircle(point.position, 20, paint);

      // Draw crosshair
      canvas.drawLine(
        point.position - const Offset(30, 0),
        point.position + const Offset(30, 0),
        paint,
      );
      canvas.drawLine(
        point.position - const Offset(0, 30),
        point.position + const Offset(0, 30),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DebugInputPainter oldDelegate) {
    return true;
  }
}