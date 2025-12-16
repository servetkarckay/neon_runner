import 'dart:ui' as ui;
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter_neon_runner/models/game_state.dart';
import 'package:flutter_neon_runner/models/player_data.dart';
import 'package:flutter_neon_runner/models/obstacle_data.dart';
import 'package:flutter_neon_runner/utils/math_utils.dart';
import 'package:flutter_neon_runner/config/game_config.dart';

class CollisionLogic {
  bool checkDetailedCollision(
    PlayerData player,
    ObstacleData obs,
    ui.Rect playerRect,
    ui.Rect obsRect,
    double obsCurrentAngle,
  ) {
    const padding = 10.0;
    final paddedPlayerRect = ui.Rect.fromLTWH(
      playerRect.left + padding,
      playerRect.top + padding,
      playerRect.width - padding * 2,
      playerRect.height - padding * 2,
    );

    switch (obs.type) {
      case ObstacleType.rotatingLaser:
        return _checkRotatingLaserCollision(
          obs as RotatingLaserObstacleData,
          paddedPlayerRect,
          obsRect,
          obsCurrentAngle,
        );
      case ObstacleType.laserGrid:
        return _checkLaserGridCollision(
          obs as LaserGridObstacleData,
          paddedPlayerRect,
          obsRect,
        );
      case ObstacleType.fallingDrop:
        return _checkFallingDropCollision(paddedPlayerRect, obsRect);
      case ObstacleType.spike:
        return _checkSpikeCollision(paddedPlayerRect, obsRect);
      case ObstacleType.aerial:
      case ObstacleType.movingAerial:
        return _checkAerialCollision(paddedPlayerRect, obsRect);
      case ObstacleType.slantedSurface:
        return _checkSlantedSurfaceCollision(
          obs as SlantedObstacleData,
          paddedPlayerRect,
          obsRect,
        );
      default:
        return rectRectCollision(paddedPlayerRect, obsRect);
    }
  }

  bool _checkRotatingLaserCollision(
    RotatingLaserObstacleData obs,
    ui.Rect playerRect,
    ui.Rect obsRect,
    double obsCurrentAngle,
  ) {
    if (rectRectCollision(playerRect, obsRect)) {
      return true;
    }
    final double cx = obsRect.left + obsRect.width / 2;
    final double cy = obsRect.top + obsRect.height / 2;
    final double beamLen = obs.beamLength;
    final double endX = cx + cos(obsCurrentAngle) * beamLen;
    final double endY = cy + sin(obsCurrentAngle) * beamLen;
    return lineRect(cx, cy, endX, endY, playerRect);
  }

  bool _checkLaserGridCollision(
    LaserGridObstacleData obs,
    ui.Rect playerRect,
    ui.Rect obsRect,
  ) {
    if (playerRect.left + playerRect.width > obsRect.left + 5 &&
        playerRect.left < obsRect.left + obsRect.width - 5) {
      final double gapY = obs.gapY;
      final double gapH = obs.gapHeight;
      final double safeTop = gapY - gapH / 2 + 5;
      final double safeBottom = gapY + gapH / 2 - 5;
      if (playerRect.top < safeTop ||
          (playerRect.top + playerRect.height) > safeBottom) {
        return true;
      }
    }
    return false;
  }

  bool _checkFallingDropCollision(ui.Rect playerRect, ui.Rect obsRect) {
    final double cx = obsRect.left + obsRect.width / 2;
    final double cy = obsRect.top + obsRect.height / 2;
    final double r = obsRect.width / 2 - 6;
    final double testX = max(
      playerRect.left,
      min(cx, playerRect.left + playerRect.width),
    );
    final double testY = max(
      playerRect.top,
      min(cy, playerRect.top + playerRect.height),
    );
    final double dx = cx - testX;
    final double dy = cy - testY;
    return (dx * dx + dy * dy) < (r * r);
  }

  bool _checkSpikeCollision(ui.Rect playerRect, ui.Rect obsRect) {
    if (rectRectCollision(playerRect, obsRect)) {
      final double tipX = obsRect.left + obsRect.width / 2;
      final double tipY = obsRect.top;
      if (lineRect(
        obsRect.left,
        obsRect.top + obsRect.height,
        tipX,
        tipY,
        playerRect,
      )) {
        return true;
      }
      if (lineRect(
        tipX,
        tipY,
        obsRect.left + obsRect.width,
        obsRect.top + obsRect.height,
        playerRect,
      )) {
        return true;
      }
      final double centerX = playerRect.left + playerRect.width / 2;
      final double bottomY = playerRect.top + playerRect.height;
      if (centerX > obsRect.left &&
          centerX < obsRect.left + obsRect.width &&
          bottomY > obsRect.top + obsRect.height / 2) {
        return true;
      }
    }
    return false;
  }

  bool _checkAerialCollision(ui.Rect playerRect, ui.Rect obsRect) {
    if (rectRectCollision(playerRect, obsRect)) {
      final double cx = obsRect.left + obsRect.width / 2;
      final double cy = obsRect.top + obsRect.height / 2;
      final double px = playerRect.left;
      final double py = playerRect.top;
      final double pw = playerRect.width;
      final double ph = playerRect.height;
      if (lineRect(
            obsRect.left,
            cy,
            cx,
            obsRect.top,
            ui.Rect.fromLTWH(px, py, pw, ph),
          ) ||
          lineRect(
            cx,
            obsRect.top,
            obsRect.left + obsRect.width,
            cy,
            ui.Rect.fromLTWH(px, py, pw, ph),
          ) ||
          lineRect(
            obsRect.left + obsRect.width,
            cy,
            cx,
            obsRect.top + obsRect.height,
            ui.Rect.fromLTWH(px, py, pw, ph),
          ) ||
          lineRect(
            cx,
            obsRect.top + obsRect.height,
            obsRect.left,
            cy,
            ui.Rect.fromLTWH(px, py, pw, ph),
          )) {
        return true;
      }
      if ((playerRect.left + playerRect.width / 2 - cx).abs() < 10 &&
          (playerRect.top + playerRect.height / 2 - cy).abs() < 10) {
        return true;
      }
    }
    return false;
  }

  bool _checkSlantedSurfaceCollision(
    SlantedObstacleData obs,
    ui.Rect playerRect,
    ui.Rect obsRect,
  ) {
    final double x1 = obsRect.left + obs.lineX1;
    final double y1 = obsRect.top + obs.lineY1;
    final double x2 = obsRect.left + obs.lineX2;
    final double y2 = obsRect.top + obs.lineY2;
    return lineRect(x1, y1, x2, y2, playerRect);
  }

  bool rectRectCollision(ui.Rect rect1, ui.Rect rect2) {
    final epsilon = GameConfig.collisionEpsilon;
    return rect1.left <= rect2.right + epsilon &&
        rect1.right >= rect2.left - epsilon &&
        rect1.top <= rect2.bottom + epsilon &&
        rect1.bottom >= rect2.top - epsilon;
  }

  double? sweepRectRectCollision(
    ui.Rect movingRect,
    Vector2 movingRectVelocity,
    ui.Rect staticRect,
  ) {
    // If rectangles are already overlapping or touching, return 0.0
    if (rectRectCollision(movingRect, staticRect)) {
      return 0.0;
    }

    // If no movement, and not already overlapping, then no collision will occur
    if (movingRectVelocity.x == 0 && movingRectVelocity.y == 0) {
      return null;
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
    final epsilon = GameConfig.collisionEpsilon;
    if (entryTime > exitTime - epsilon ||
        entryTime < -epsilon ||
        entryTime > 1.0 + epsilon) {
      return null;
    }

    return entryTime;
  }
}
