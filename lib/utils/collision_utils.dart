import 'dart:ui';
import 'dart:math';
import 'package:flame/components.dart'; // For Flame's Vector2

/// Utility functions for advanced collision detection.

/// Checks for axis-aligned bounding box (AABB) collision between two rectangles.
/// Returns true if the rectangles overlap, false otherwise.
bool rectRectCollision(Rect rect1, Rect rect2) {
  return rect1.overlaps(rect2);
}

/// Performs a sweep test (continuous collision detection) for a moving rectangle
/// against a static rectangle.
///
/// [movingRect] is the initial position of the moving rectangle.
/// [movingRectVelocity] is the velocity vector of the moving rectangle for the current frame.
/// [staticRect] is the static rectangle.
///
/// Returns the time of impact (TOI) between 0.0 and 1.0 if a collision occurs
/// within the sweep, or null if no collision occurs or if the rectangles are
/// already overlapping at the start (use rectRectCollision for initial overlap).
///
/// Based on "Slab Method" for AABB-AABB sweep test.
double? sweepRectRectCollision(
  Rect movingRect,
  Vector2 movingRectVelocity,
  Rect staticRect,
) {
  // If no movement, check for overlap
  if (movingRectVelocity.x == 0 && movingRectVelocity.y == 0) {
    return null; // Or return 0 if already overlapping based on context
  }

  double dx = movingRectVelocity.x;
  double dy = movingRectVelocity.y;

  // Calculate entry and exit times for X and Y axes
  double xInvEntry, yInvEntry;
  double xInvExit, yInvExit;

  if (dx > 0.0) {
    xInvEntry = staticRect.left - (movingRect.left + movingRect.width);
    xInvExit = (staticRect.left + staticRect.width) - movingRect.left;
  } else {
    xInvEntry = (staticRect.left + staticRect.width) - movingRect.left;
    xInvExit = staticRect.left - (movingRect.left + movingRect.width);
  }

  if (dy > 0.0) {
    yInvEntry = staticRect.top - (movingRect.top + movingRect.height);
    yInvExit = (staticRect.top + staticRect.height) - movingRect.top;
  } else {
    yInvEntry = (staticRect.top + staticRect.height) - movingRect.top;
    yInvExit = staticRect.top - (movingRect.top + movingRect.height);
  }

  double xEntry, yEntry;
  double xExit, yExit;

  if (dx == 0.0) {
    xEntry = double.negativeInfinity;
    xExit = double.infinity;
  } else {
    xEntry = xInvEntry / dx;
    xExit = xInvExit / dx;
  }

  if (dy == 0.0) {
    yEntry = double.negativeInfinity;
    yExit = double.infinity;
  } else {
    yEntry = yInvEntry / dy;
    yExit = yInvExit / dy;
  }

  // Find the earliest time of collision
  double entryTime = max(xEntry, yEntry);
  // Find the latest time of collision exit
  double exitTime = min(xExit, yExit);

  // If there's no collision or the collision happened in the past
  if (entryTime > exitTime || entryTime < 0.0 || entryTime > 1.0) {
    return null;
  }

  // Check if rectangles are overlapping on initial position
  if (movingRect.overlaps(staticRect)) {
    return 0.0; // Already overlapping
  }
  
  return entryTime;
}

// TODO: Implement line-segment-to-line-segment collision
// TODO: Implement line-segment-to-rectangle collision (more robust than lineRect if needed)
// TODO: Implement point-in-polygon (for slanted surfaces, etc.)
// TODO: Implement more complex shape collisions as needed (e.g., circle-rect for falling drops)
// TODO: Implement specific collision checks for rotating lasers and laser grids.
