import 'package:flutter_neon_runner/config/game_config.dart';
import 'package:flutter_neon_runner/utils/math_utils.dart';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

class CollisionDebugger {
  static final List<String> _logs = [];
  static const int _maxLogs = 100;

  /// Log a collision-related event
  static void log(String message) {
    if (!GameConfig.debugShowHitboxes || !kDebugMode) return;

    _logs.add('[${DateTime.now().millisecondsSinceEpoch % 100000}] $message');
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }
    debugPrint('Collision: $message');
  }

  static void debugCollision(String type, ui.Rect rect1, ui.Rect rect2, {bool collided = false}) {
    if (GameConfig.debugShowHitboxes && kDebugMode) {
      debugPrint('Collision Check - $type: ${collided ? "COLLISION" : "No collision"}');
      debugPrint('  Rect1: ${rect1.toString()}');
      debugPrint('  Rect2: ${rect2.toString()}');

      if (collided) {
        log('Collision detected in $type');
      }
    }
  }

  static void warnOnPotentialTunneling(
    ui.Rect movingRect,
    ui.Rect staticRect,
    double velocity,
  ) {
    final double threshold = movingRect.width;
    if (velocity > threshold && !movingRect.overlaps(staticRect)) {
      if (GameConfig.debugShowHitboxes && kDebugMode) {
        debugPrint('WARNING: High velocity detected ($velocity), potential tunneling risk!');
        debugPrint('  Moving rect: ${movingRect.toString()}');
        debugPrint('  Static rect: ${staticRect.toString()}');
        log('High velocity warning: $velocity > $threshold');
      }
    }
  }

  /// Test line-line collision with debugging
  static bool testLineLine(
    double x1, double y1, double x2, double y2,
    double x3, double y3, double x4, double y4, {
    String? label,
  }) {
    final result = lineLine(x1, y1, x2, y2, x3, y3, x4, y4);

    if (GameConfig.debugShowHitboxes && kDebugMode) {
      debugPrint('LineLine Test $label: ${result ? "HIT" : "MISS"}');
      debugPrint('  Line1: ($x1,$y1) to ($x2,$y2)');
      debugPrint('  Line2: ($x3,$y3) to ($x4,$y4)');

      if (result) {
        log('Line collision: $label');
      }
    }

    return result;
  }

  /// Test line-rect collision with debugging
  static bool testLineRect(
    double x1, double y1, double x2, double y2,
    ui.Rect rect, {
    String? label,
  }) {
    final result = lineRect(x1, y1, x2, y2, rect);

    if (GameConfig.debugShowHitboxes && kDebugMode) {
      debugPrint('LineRect Test $label: ${result ? "HIT" : "MISS"}');
      debugPrint('  Line: ($x1,$y1) to ($x2,$y2)');
      debugPrint('  Rect: ${rect.toString()}');

      if (result) {
        log('Line-Rect collision: $label');
      }
    }

    return result;
  }

  /// Get all logs for debugging UI
  static List<String> get logs => List.unmodifiable(_logs);

  /// Clear all logs
  static void clearLogs() {
    _logs.clear();
  }
}