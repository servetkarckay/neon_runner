import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_neon_runner/config/game_config.dart';
import 'package:flutter_neon_runner/game/events/game_events.dart';
import 'package:flutter_neon_runner/game/systems/base_game_system.dart';
import 'package:flutter_neon_runner/models/game_state.dart';

/// Comprehensive mobile touch control system optimized for arcade gameplay
class MobileTouchController {
  final BuildContext context;
  final VoidCallback? onJump;
  final VoidCallback? onDuck;
  final VoidCallback? onPause;
  final VoidCallback? onStart;

  // Touch zones
  Rect? _jumpZone;
  Rect? _duckZone;
  Rect? _pauseZone;

  // Touch state
  final Set<int> _activeTouches = {};
  final Map<int, Offset> _touchPositions = {};
  bool _isJumpPressed = false;
  bool _isDuckPressed = false;
  Timer? _holdTimer;

  // Visual feedback
  bool _showVisualFeedback = true;
  double _feedbackAlpha = 0.0;

  MobileTouchController({
    required this.context,
    this.onJump,
    this.onDuck,
    this.onPause,
    this.onStart,
  });

  /// Initialize touch zones based on screen size
  void initialize(Size screenSize) {
    final width = screenSize.width;
    final height = screenSize.height;

    // Define touch zones for mobile gameplay
    _jumpZone = Rect.fromLTWH(0, 0, width, height * 0.5);
    _duckZone = Rect.fromLTWH(0, height * 0.5, width, height * 0.5);
    _pauseZone = Rect.fromLTWH(width - 80, 20, 60, 40);

    // Enable haptic feedback if available
    _enableHapticFeedback();
  }

  /// Handle touch down event
  void onTouchDown(int pointerId, Offset position) {
    _activeTouches.add(pointerId);
    _touchPositions[pointerId] = position;

    // Check which zone was touched
    if (_pauseZone != null && _pauseZone!.contains(position)) {
      _handlePause();
      return;
    }

    if (_jumpZone != null && _jumpZone!.contains(position)) {
      _handleJumpStart();
    }

    if (_duckZone != null && _duckZone!.contains(position)) {
      _handleDuckStart();
    }

    // Start visual feedback
    _startVisualFeedback();
  }

  /// Handle touch up event
  void onTouchUp(int pointerId) {
    _activeTouches.remove(pointerId);
    _touchPositions.remove(pointerId);

    // Check if this was releasing jump or duck
    if (_activeTouches.isEmpty || !_isTouchInJumpZone() && _isJumpPressed) {
      _handleJumpEnd();
    }

    if (_activeTouches.isEmpty || !_isTouchInDuckZone() && _isDuckPressed) {
      _handleDuckEnd();
    }

    // Stop visual feedback if no active touches
    if (_activeTouches.isEmpty) {
      _stopVisualFeedback();
    }
  }

  /// Handle touch move event
  void onTouchMove(int pointerId, Offset position) {
    _touchPositions[pointerId] = position;

    // Handle sliding between zones
    if (_jumpZone != null && _duckZone != null) {
      if (_jumpZone!.contains(position)) {
        if (!_isJumpPressed) {
          _handleJumpStart();
        }
        if (_isDuckPressed) {
          _handleDuckEnd();
        }
      } else if (_duckZone!.contains(position)) {
        if (!_isDuckPressed) {
          _handleDuckStart();
        }
        if (_isJumpPressed) {
          _handleJumpEnd();
        }
      }
    }
  }

  /// Render touch zones (for debugging/tutorial)
  void renderTouchZones(Canvas canvas, Size screenSize) {
    if (!_showVisualFeedback) return;

    // Render jump zone (upper half)
    if (_jumpZone != null) {
      final jumpPaint = Paint()
        ..color = Colors.blue.withValues(alpha: _feedbackAlpha * 0.2)
        ..style = PaintingStyle.fill;
      canvas.drawRect(_jumpZone!, jumpPaint);

      final borderPaint = Paint()
        ..color = Colors.blue.withValues(alpha: _feedbackAlpha * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRect(_jumpZone!, borderPaint);

      // Draw jump indicator
      _drawTouchIndicator(canvas, _jumpZone!.center, Colors.blue, 'JUMP');
    }

    // Render duck zone (lower half)
    if (_duckZone != null) {
      final duckPaint = Paint()
        ..color = Colors.green.withValues(alpha: _feedbackAlpha * 0.2)
        ..style = PaintingStyle.fill;
      canvas.drawRect(_duckZone!, duckPaint);

      final borderPaint = Paint()
        ..color = Colors.green.withValues(alpha: _feedbackAlpha * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRect(_duckZone!, borderPaint);

      // Draw duck indicator
      _drawTouchIndicator(canvas, _duckZone!.center, Colors.green, 'DUCK');
    }

    // Render pause button
    if (_pauseZone != null) {
      final pausePaint = Paint()
        ..color = Colors.white.withValues(alpha: _feedbackAlpha * 0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(_pauseZone!.center, _pauseZone!.shortestSide / 2, pausePaint);

      _drawPauseIcon(canvas, _pauseZone!.center);
    }
  }

  /// Update visual feedback animation
  void update(double dt) {
    if (_showVisualFeedback && _feedbackAlpha > 0) {
      _feedbackAlpha = max(0, _feedbackAlpha - dt * 2);
    }
  }

  // Private methods
  void _handleJumpStart() {
    if (!_isJumpPressed) {
      _isJumpPressed = true;
      GameEventBus.instance.fire(InputEvent(InputAction.jump, true));
      onJump?.call();

      // Light haptic feedback
      _triggerHapticFeedback(HapticFeedbackType.light);
    }
  }

  void _handleJumpEnd() {
    if (_isJumpPressed) {
      _isJumpPressed = false;
      GameEventBus.instance.fire(InputEvent(InputAction.jump, false));
    }
  }

  void _handleDuckStart() {
    if (!_isDuckPressed) {
      _isDuckPressed = true;
      GameEventBus.instance.fire(InputEvent(InputAction.duck, true));
      onDuck?.call();

      // Light haptic feedback
      _triggerHapticFeedback(HapticFeedbackType.light);
    }
  }

  void _handleDuckEnd() {
    if (_isDuckPressed) {
      _isDuckPressed = false;
      GameEventBus.instance.fire(InputEvent(InputAction.duck, false));
    }
  }

  void _handlePause() {
    onPause?.call();
    _triggerHapticFeedback(HapticFeedbackType.medium);
  }

  bool _isTouchInJumpZone() {
    return _touchPositions.values.any((pos) => _jumpZone?.contains(pos) ?? false);
  }

  bool _isTouchInDuckZone() {
    return _touchPositions.values.any((pos) => _duckZone?.contains(pos) ?? false);
  }

  void _startVisualFeedback() {
    _showVisualFeedback = true;
    _feedbackAlpha = 1.0;
  }

  void _stopVisualFeedback() {
    _feedbackAlpha = 0.0;
  }

  void _drawTouchIndicator(Canvas canvas, Offset center, Color color, String text) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color.withValues(alpha: _feedbackAlpha),
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
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  void _drawPauseIcon(Canvas canvas, Offset center) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: _feedbackAlpha * 0.7)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Draw pause bars
    canvas.drawLine(
      Offset(center.dx - 8, center.dy - 10),
      Offset(center.dx - 8, center.dy + 10),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + 8, center.dy - 10),
      Offset(center.dx + 8, center.dy + 10),
      paint,
    );
  }

  void _enableHapticFeedback() {
    // Enable haptic feedback for better mobile experience
    // This would integrate with device vibration APIs
  }

  void _triggerHapticFeedback(HapticFeedbackType type) {
    // Trigger haptic feedback based on type
    // This would use platform-specific vibration APIs
  }

  void dispose() {
    _holdTimer?.cancel();
    _activeTouches.clear();
    _touchPositions.clear();
  }
}

/// Mobile UI patterns optimized for arcade games
class MobileUIPatterns {
  /// Create mobile-optimized game button
  static Widget createGameButton({
    required String text,
    required VoidCallback onPressed,
    Color? color,
    double? width,
    double? height,
    bool isPrimary = false,
  }) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height ?? 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? (isPrimary ? GameConfig.primaryNeonColor : Colors.grey[800]),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isPrimary
                ? BorderSide(color: GameConfig.accentNeonColor, width: 2)
                : BorderSide.none,
          ),
          elevation: isPrimary ? 8 : 4,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Share Tech Mono',
          ),
        ),
      ),
    );
  }

  /// Create mobile-optimized icon button
  static Widget createIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    double size = 48,
    Color? color,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color ?? Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: size * 0.6),
      ),
    );
  }

  /// Create mobile-optimized stats display
  static Widget createStatsDisplay({
    required int score,
    required int highscore,
    required double speed,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: GameConfig.primaryNeonColor.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatRow('SCORE', '$score', GameConfig.accentNeonColor),
          const SizedBox(height: 8),
          _buildStatRow('HIGHSCORE', '$highscore', GameConfig.primaryNeonColor),
          const SizedBox(height: 8),
          _buildStatRow('SPEED', '${speed.toStringAsFixed(1)}', Colors.cyan),
        ],
      ),
    );
  }

  static Widget _buildStatRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.7),
            fontSize: 14,
            fontFamily: 'Share Tech Mono',
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Share Tech Mono',
          ),
        ),
      ],
    );
  }
}

/// Haptic feedback types for mobile devices
enum HapticFeedbackType {
  light,
  medium,
  heavy,
  success,
  error,
  warning,
}

/// Mobile performance settings
class MobilePerformanceSettings {
  static const bool enableParticles = true;
  static const bool enableTrailEffects = true;
  static const bool enableBackgroundEffects = true;
  static const int maxParticles = 50;
  static const double targetFPS = 60.0;
  static const bool enableAdaptiveQuality = true;
}