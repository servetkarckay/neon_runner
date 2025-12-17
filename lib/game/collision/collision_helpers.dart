import 'dart:math';
import 'package:flutter/painting.dart';
import 'package:vector_math/vector_math.dart' hide Colors;

/// Extended collision detection helpers for the new modular collision system
class CollisionHelpers {
  /// Checks if a circle collides with a rectangle
  static bool rectCircleCollision(Rect rect, Vector2 circleCenter, double circleRadius) {
    final testX = max(rect.left, min(circleCenter.x, rect.right));
    final testY = max(rect.top, min(circleCenter.y, rect.bottom));

    final dx = circleCenter.x - testX;
    final dy = circleCenter.y - testY;

    return (dx * dx + dy * dy) <= (circleRadius * circleRadius);
  }

  /// Checks if a line segment intersects a rectangle
  static bool lineRect(double x1, double y1, double x2, double y2, Rect rect) {
    // Check if line endpoints are inside rectangle
    if (rect.contains(Offset(x1, y1)) || rect.contains(Offset(x2, y2))) {
      return true;
    }

    // Check if line intersects any of the rectangle's sides
    return lineLine(x1, y1, x2, y2, rect.left, rect.top, rect.right, rect.top) || // Top
           lineLine(x1, y1, x2, y2, rect.right, rect.top, rect.right, rect.bottom) || // Right
           lineLine(x1, y1, x2, y2, rect.right, rect.bottom, rect.left, rect.bottom) || // Bottom
           lineLine(x1, y1, x2, y2, rect.left, rect.bottom, rect.left, rect.top); // Left
  }

  /// Checks if two line segments intersect
  static bool lineLine(double x1, double y1, double x2, double y2, double x3, double y3, double x4, double y4) {
    final denominator = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4);
    if (denominator == 0) return false;

    final t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denominator;
    final u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / denominator;

    return t >= 0 && t <= 1 && u >= 0 && u <= 1;
  }

  /// Checks if a line segment intersects a circle
  static bool lineCircle(double x1, double y1, double x2, double y2, double circleX, double circleY, double circleRadius) {
    // Vector from line start to circle center
    final dx = circleX - x1;
    final dy = circleY - y1;

    // Vector along the line
    final lineDx = x2 - x1;
    final lineDy = y2 - y1;

    final lineLengthSq = lineDx * lineDx + lineDy * lineDy;
    if (lineLengthSq == 0) {
      // Line is a point, check if point is within circle
      return dx * dx + dy * dy <= circleRadius * circleRadius;
    }

    // Project circle center onto line
    final t = max(0, min(1, (dx * lineDx + dy * lineDy) / lineLengthSq));

    // Closest point on line to circle center
    final closestX = x1 + t * lineDx;
    final closestY = y1 + t * lineDy;

    // Distance from closest point to circle center
    final distX = circleX - closestX;
    final distY = circleY - closestY;

    return distX * distX + distY * distY <= circleRadius * circleRadius;
  }

  /// Checks if two circles collide
  static bool circleCircleCollision(Vector2 centerA, double radiusA, Vector2 centerB, double radiusB) {
    final dx = centerA.x - centerB.x;
    final dy = centerA.y - centerB.y;
    final distanceSq = dx * dx + dy * dy;
    final combinedRadius = radiusA + radiusB;
    return distanceSq <= combinedRadius * combinedRadius;
  }

  /// Calculates the distance between two points
  static double distance(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return sqrt(dx * dx + dy * dy);
  }

  /// Calculates the distance between two vectors
  static double vectorDistance(Vector2 a, Vector2 b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return sqrt(dx * dx + dy * dy);
  }

  /// Checks if a point is inside a rectangle
  static bool pointInRect(double x, double y, Rect rect) {
    return x >= rect.left && x <= rect.right && y >= rect.top && y <= rect.bottom;
  }

  /// Calculates the normal vector from point A to point B
  static Vector2 calculateNormal(Vector2 from, Vector2 to) {
    final direction = to - from;
    return direction.normalized();
  }

  /// Projects a point onto a line segment
  static Vector2 projectPointOntoLine(Vector2 point, Vector2 lineStart, Vector2 lineEnd) {
    final line = lineEnd - lineStart;
    final lineLengthSq = line.length2;

    if (lineLengthSq == 0) {
      return lineStart;
    }

    final pointMinusStart = point - lineStart;
    final t = max(0.0, min(1.0, pointMinusStart.dot(line) / lineLengthSq));

    return lineStart + line * t;
  }

  /// Finds the closest point on a rectangle to a given point
  static Vector2 closestPointOnRect(Vector2 point, Rect rect) {
    return Vector2(
      max(rect.left, min(point.x, rect.right)),
      max(rect.top, min(point.y, rect.bottom)),
    );
  }

  /// Separates two overlapping rectangles by the minimum amount
  static Vector2 separateRectangles(Rect rectA, Rect rectB) {
    final overlapX = min(rectA.right, rectB.right) - max(rectA.left, rectB.left);
    final overlapY = min(rectA.bottom, rectB.bottom) - max(rectA.top, rectB.top);

    // Choose the axis with minimum overlap for separation
    if (overlapX < overlapY) {
      // Separate horizontally
      final centerXDiff = (rectA.left + rectA.width / 2) - (rectB.left + rectB.width / 2);
      return Vector2(centerXDiff > 0 ? overlapX : -overlapX, 0);
    } else {
      // Separate vertically
      final centerYDiff = (rectA.top + rectA.height / 2) - (rectB.top + rectB.height / 2);
      return Vector2(0, centerYDiff > 0 ? overlapY : -overlapY);
    }
  }
}