import 'package:flutter_neon_runner/models/game_state.dart';
import 'dart:ui' as ui; // Import dart:ui for native Rect

class PowerUpData {
  int id;
  PowerUpType type;
  bool active;
  double floatOffset;
  ui.Rect _rect; // Use ui.Rect for the bounding box

  PowerUpData({
    required this.id,
    required this.type,
    required this.active,
    required this.floatOffset,
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

  // Method to update the position of the power-up (since ui.Rect is immutable)
  void updatePosition(double newX, double newY, {double? newWidth, double? newHeight}) {
    _rect = ui.Rect.fromLTWH(newX, newY, newWidth ?? width, newHeight ?? height);
  }

  void reset(int newId) {
    id = newId;
    _rect = ui.Rect.zero; // Reset to an empty rect or a default starting one
    type = PowerUpType.shield; // Default or a common type
    active = false;
    floatOffset = 0;
  }
}
