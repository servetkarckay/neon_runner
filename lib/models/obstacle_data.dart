import 'package:flutter_neon_runner/models/game_state.dart';
import 'dart:ui' as ui; // Import dart:ui for native Rect

abstract class ObstacleData {
  int id;
  ObstacleType type;
  bool passed;
  bool grazed;
  ui.Rect _rect; // Use ui.Rect for the bounding box

  ObstacleData({
    required this.id,
    required this.type,
    required this.passed,
    required this.grazed,
    required double x,
    required double y,
    required double width,
    required double height,
  }) : _rect = ui.Rect.fromLTWH(x, y, width, height);

  // Getters for properties of the internal ui.Rect
  double get x => _rect.left;
  double get y => _rect.top;
  double get width => _rect.width;
  double get height => _rect.height;
  double get left => _rect.left;
  double get top => _rect.top;
  double get right => _rect.right;
  double get bottom => _rect.bottom;

  // Setters for properties of the internal ui.Rect
  set x(double newX) => updatePosition(newX, y);
  set y(double newY) => updatePosition(x, newY);
  set width(double newWidth) => updatePosition(x, y, newWidth: newWidth);
  set height(double newHeight) => updatePosition(x, y, newHeight: newHeight);

  // Method to get the ui.Rect directly
  ui.Rect toRect() => _rect;

  // Method to update the position of the obstacle (since ui.Rect is immutable)
  void updatePosition(double newX, double newY, {double? newWidth, double? newHeight}) {
    _rect = ui.Rect.fromLTWH(newX, newY, newWidth ?? width, newHeight ?? height);
  }

  void reset(int newId) {
    id = newId;
    _rect = ui.Rect.zero; // Reset to an empty rect or a default starting one
    passed = false;
    grazed = false;
  }
}

class SimpleObstacleData extends ObstacleData {
  SimpleObstacleData({
    required super.id,
    required super.type,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
  }) : super(
          passed: false,
          grazed: false,
        );
}

class HazardObstacleData extends ObstacleData {
  double initialY;

  HazardObstacleData({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required this.initialY,
  }) : super(
          type: ObstacleType.hazardZone,
          passed: false,
          grazed: false,
        );

  @override
  void reset(int newId) {
    super.reset(newId);
    initialY = 0;
  }
}

class MovingAerialObstacleData extends ObstacleData {
  double initialY;

  MovingAerialObstacleData({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required this.initialY,
  }) : super(
          type: ObstacleType.movingAerial,
          passed: false,
          grazed: false,
        );

  @override
  void reset(int newId) {
    super.reset(newId);
    initialY = 0;
  }
}

enum OscillationAxis { vertical, horizontal }

class MovingPlatformObstacleData extends ObstacleData {
  double initialY;
  OscillationAxis oscillationAxis;

  MovingPlatformObstacleData({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required this.initialY,
    this.oscillationAxis = OscillationAxis.vertical,
  }) : super(
          type: ObstacleType.movingPlatform,
          passed: false,
          grazed: false,
        );

  @override
  void reset(int newId) {
    super.reset(newId);
    initialY = 0;
    oscillationAxis = OscillationAxis.vertical;
  }
}

class FallingObstacleData extends ObstacleData {
  double velocityY;
  double initialY;

  FallingObstacleData({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required this.initialY,
    this.velocityY = 0,
  }) : super(
          type: ObstacleType.fallingDrop,
          passed: false,
          grazed: false,
        );

  @override
  void reset(int newId) {
    super.reset(newId);
    velocityY = 0;
    initialY = 0;
  }
}

class RotatingLaserObstacleData extends ObstacleData {
  double initialY;
  double angle;
  double rotationSpeed;
  double beamLength;

  RotatingLaserObstacleData({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required this.initialY,
    this.angle = 0,
    this.rotationSpeed = 0,
    this.beamLength = 0,
  }) : super(
          type: ObstacleType.rotatingLaser,
          passed: false,
          grazed: false,
        );

  @override
  void reset(int newId) {
    super.reset(newId);
    initialY = 0;
    angle = 0;
    rotationSpeed = 0;
    beamLength = 0;
  }
}

class LaserGridObstacleData extends ObstacleData {
  double gapY;
  double gapHeight;

  LaserGridObstacleData({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required this.gapY,
    required this.gapHeight,
  }) : super(
          type: ObstacleType.laserGrid,
          passed: false,
          grazed: false,
        );

  @override
  void reset(int newId) {
    super.reset(newId);
    gapY = 0;
    gapHeight = 0;
  }
}

class SlantedObstacleData extends ObstacleData {
  final double lineX1, lineY1, lineX2, lineY2;

  SlantedObstacleData({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required this.lineX1,
    required this.lineY1,
    required this.lineX2,
    required this.lineY2,
  }) : super(
          type: ObstacleType.slantedSurface,
          passed: false,
          grazed: false,
        );

}