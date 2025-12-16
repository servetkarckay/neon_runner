import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_neon_runner/game/collision_logic.dart';
import 'package:flutter_neon_runner/utils/math_utils.dart';
import 'package:flame/components.dart';
import 'dart:ui';

void main() {
  group('CollisionLogic Edge Cases', () {
    late CollisionLogic collisionLogic;

    setUp(() {
      collisionLogic = CollisionLogic();
    });

    test('should handle zero-width/height rectangles gracefully', () {
      final rect1 = Rect.fromLTWH(0, 0, 0, 10);
      final rect2 = Rect.fromLTWH(5, 0, 10, 10);

      // Should not throw an exception
      expect(() => collisionLogic.rectRectCollision(rect1, rect2), returnsNormally);
    });

    test('should handle negative dimensions without errors', () {
      // Creating a rect with negative width/height by flipping corners
      final rect1 = Rect.fromLTRB(10, 10, 0, 0);
      final rect2 = Rect.fromLTWH(5, 5, 10, 10);

      expect(() => collisionLogic.rectRectCollision(rect1, rect2), returnsNormally);
    });

    test('should handle very large coordinates', () {
      final rect1 = Rect.fromLTWH(1000000, 1000000, 10, 10);
      final rect2 = Rect.fromLTWH(1000005, 1000005, 10, 10);

      expect(collisionLogic.rectRectCollision(rect1, rect2), isTrue);
    });

    test('sweep collision should handle zero velocity', () {
      final movingRect = Rect.fromLTWH(0, 0, 10, 10);
      final staticRect = Rect.fromLTWH(15, 0, 10, 10);
      final velocity = Vector2.zero();

      final toi = collisionLogic.sweepRectRectCollision(
        movingRect,
        velocity,
        staticRect,
      );

      expect(toi, isNull);
    });

    test('sweep collision should handle infinite velocity', () {
      final movingRect = Rect.fromLTWH(0, 0, 10, 10);
      final staticRect = Rect.fromLTWH(15, 0, 10, 10);
      final velocity = Vector2(double.infinity, 0);

      // Should not throw
      expect(() => collisionLogic.sweepRectRectCollision(
        movingRect,
        velocity,
        staticRect,
      ), returnsNormally);
    });

    test('should handle NaN coordinates gracefully', () {
      final rect1 = Rect.fromLTWH(0, 0, 10, 10);
      final rect2 = Rect.fromLTWH(double.nan, 0, 10, 10);

      // Should handle NaN without crashing
      expect(() => collisionLogic.rectRectCollision(rect1, rect2), returnsNormally);
    });
  });

  group('LineLine Collision Edge Cases', () {
    test('should detect proper intersection of two crossing lines', () {
      // Lines cross in the middle
      final result = lineLine(0, 0, 10, 10, 0, 10, 10, 0);
      expect(result, isTrue);
    });

    test('should detect intersection at line endpoint', () {
      // Lines intersect at (10, 0)
      final result = lineLine(0, 0, 10, 0, 10, 0, 20, 10);
      expect(result, isTrue);
    });

    test('should not detect intersection when lines are parallel', () {
      // Parallel lines
      final result = lineLine(0, 0, 10, 0, 0, 5, 10, 5);
      expect(result, isFalse);
    });

    test('should not detect intersection when lines are collinear but separate', () {
      // Collinear lines that don't overlap
      final result = lineLine(0, 0, 10, 0, 20, 0, 30, 0);
      expect(result, isFalse);
    });

    test('should detect intersection for vertical lines', () {
      // Vertical lines crossing
      final result = lineLine(5, 0, 5, 10, 0, 5, 10, 5);
      expect(result, isTrue);
    });

    test('should detect intersection for diagonal and horizontal lines', () {
      // Diagonal crossing horizontal
      final result = lineLine(0, 0, 10, 10, 0, 5, 10, 5);
      expect(result, isTrue);
    });

    test('should NOT have false positives from the previous bug', () {
      // This test specifically checks for the bug where uB >= 1 was used
      // instead of uB <= 1, causing incorrect collision detection

      // Line segment 1: from (0,0) to (10,10)
      // Line segment 2: from (20,20) to (30,30) - should NOT intersect
      final result = lineLine(0, 0, 10, 10, 20, 20, 30, 30);
      expect(result, isFalse);
    });
  });

  group('LineRect Intersection Edge Cases', () {
    test('should detect when line starts inside rectangle', () {
      final rect = Rect.fromLTWH(10, 10, 20, 20);
      final result = lineRect(15, 15, 30, 30, rect);
      expect(result, isTrue);
    });

    test('should detect when line ends inside rectangle', () {
      final rect = Rect.fromLTWH(10, 10, 20, 20);
      final result = lineRect(0, 0, 15, 15, rect);
      expect(result, isTrue);
    });

    test('should detect when line passes through rectangle corner', () {
      final rect = Rect.fromLTWH(10, 10, 20, 20);
      // Line passes exactly through top-left corner
      final result = lineRect(0, 0, 10, 10, rect);
      expect(result, isTrue);
    });

    test('should detect when line grazes rectangle edge', () {
      final rect = Rect.fromLTWH(10, 10, 20, 20);
      // Line grazes top edge
      final result = lineRect(0, 10, 50, 10, rect);
      expect(result, isTrue);
    });

    test('should not detect intersection when line is far from rectangle', () {
      final rect = Rect.fromLTWH(10, 10, 20, 20);
      final result = lineRect(100, 100, 200, 200, rect);
      expect(result, isFalse);
    });
  });
}