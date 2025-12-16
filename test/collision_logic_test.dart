import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_neon_runner/game/collision_logic.dart';
import 'package:flame/components.dart';
import 'dart:ui';

void main() {
  group('CollisionLogic', () {
    late CollisionLogic collisionLogic;

    setUp(() {
      collisionLogic = CollisionLogic();
    });

    group('rectRectCollision', () {
      test('should return true for overlapping rectangles', () {
        final rect1 = Rect.fromLTWH(0, 0, 10, 10);
        final rect2 = Rect.fromLTWH(5, 5, 10, 10);
        expect(collisionLogic.rectRectCollision(rect1, rect2), isTrue);
      });

      test('should return false for non-overlapping rectangles', () {
        final rect1 = Rect.fromLTWH(0, 0, 10, 10);
        final rect2 = Rect.fromLTWH(15, 15, 10, 10);
        expect(collisionLogic.rectRectCollision(rect1, rect2), isFalse);
      });

      test('should return true for rectangles touching at a corner', () {
        final rect1 = Rect.fromLTWH(0, 0, 10, 10);
        final rect2 = Rect.fromLTWH(10, 10, 10, 10);
        expect(collisionLogic.rectRectCollision(rect1, rect2), isTrue);
      });

      test('should return false for rectangles with a 1px gap', () {
        final rect1 = Rect.fromLTWH(0, 0, 10, 10);
        final rect2 = Rect.fromLTWH(11, 0, 10, 10);
        expect(collisionLogic.rectRectCollision(rect1, rect2), isFalse);
      });
    });

    group('sweepRectRectCollision', () {
      test('should return toi when collision is detected', () {
        final movingRect = Rect.fromLTWH(0, 0, 10, 10);
        final staticRect = Rect.fromLTWH(15, 0, 10, 10);
        final velocity = Vector2(20, 0);
        final toi = collisionLogic.sweepRectRectCollision(
          movingRect,
          velocity,
          staticRect,
        );
        expect(toi, isNotNull);
        expect(toi, closeTo(0.25, 0.001));
      });

      test('should return null when no collision is detected', () {
        final movingRect = Rect.fromLTWH(0, 0, 10, 10);
        final staticRect = Rect.fromLTWH(30, 0, 10, 10);
        final velocity = Vector2(10, 0);
        final toi = collisionLogic.sweepRectRectCollision(
          movingRect,
          velocity,
          staticRect,
        );
        expect(toi, isNull);
      });

      test('should return 0.0 for already overlapping rectangles', () {
        final movingRect = Rect.fromLTWH(0, 0, 10, 10);
        final staticRect = Rect.fromLTWH(5, 5, 10, 10);
        final velocity = Vector2(10, 0);
        final toi = collisionLogic.sweepRectRectCollision(
          movingRect,
          velocity,
          staticRect,
        );
        expect(toi, 0.0);
      });

      test('should detect collision for high-speed movement without tunneling', () {
        final movingRect = Rect.fromLTWH(0, 0, 5, 5); // Small moving rect
        final staticRect = Rect.fromLTWH(100, 0, 5, 5); // Far away static rect
        final velocity = Vector2(
          100,
          0,
        ); // High velocity, should pass over staticRect in one frame if not handled
        final toi = collisionLogic.sweepRectRectCollision(
          movingRect,
          velocity,
          staticRect,
        );
        expect(toi, isNotNull);
        // The moving rect starts at x=0, width=5. The static rect starts at x=100.
        // The relative distance to travel for collision is 100 - 5 = 95.
        // Time = Distance / Speed = 95 / 100 = 0.95.
        expect(toi, closeTo(0.95, 0.001));
      });
    });
  });
}
