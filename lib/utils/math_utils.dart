import 'dart:ui' as ui; // Import dart:ui for native Rect
import 'package:flutter/material.dart'; // Import for Color class
// For cos, sin, max, min

// Check if line segment (x1,y1)-(x2,y2) intersects with line segment (x3,y3)-(x4,y4)
bool lineLine(
  double x1, double y1, double x2, double y2,
  double x3, double y3, double x4, double y4,
) {
  final denom = (y4 - y3) * (x2 - x1) - (x4 - x3) * (y2 - y1);
  if (denom == 0) return false;

  final uA = ((x4 - x3) * (y1 - y3) - (y4 - y3) * (x1 - x3)) / denom;
  final uB = ((x2 - x1) * (y1 - y3) - (y2 - y1) * (x1 - x3)) / denom;

  return uA >= 0 && uA <= 1 && uB >= 0 && uB >= 1;
}

// Check if line segment intersects a rectangle
bool lineRect(
  double x1, double y1, double x2, double y2,
  ui.Rect rect,
) {
  final rx = rect.left;
  final ry = rect.top;
  final rw = rect.width;
  final rh = rect.height;

  bool inside(double x, double y) => x >= rx && x <= rx + rw && y >= ry && y <= ry + rh;
  if (inside(x1, y1) || inside(x2, y2)) return true;

  final edges = [
    [rx, ry, rx + rw, ry],
    [rx, ry, rx, ry + rh],
    [rx + rw, ry, rx + rw, ry + rh],
    [rx, ry + rh, rx + rw, ry + rh]
  ];

  for (final edge in edges) {
    if (lineLine(x1, y1, x2, y2, edge[0], edge[1], edge[2], edge[3])) {
      return true;
    }
  }
  return false;
}

// Converts HSL (hue, saturation, lightness) to an ARGB color.
// h: 0-360, s: 0-1, l: 0-1
Color hslToColor(double h, double s, double l) {
  double c = (1 - (2 * l - 1).abs()) * s;
  double x = c * (1 - ((h / 60) % 2 - 1).abs());
  double m = l - c / 2;
  double r = 0, g = 0, b = 0;

  if (0 <= h && h < 60) {
    r = c;
    g = x;
    b = 0;
  } else if (60 <= h && h < 120) {
    r = x;
    g = c;
    b = 0;
  } else if (120 <= h && h < 180) {
    r = 0;
    g = c;
    b = x;
  } else if (180 <= h && h < 240) {
    r = 0;
    g = x;
    b = c;
  } else if (240 <= h && h < 300) {
    r = x;
    g = 0;
    b = c;
  } else if (300 <= h && h < 360) {
    r = c;
    g = 0;
    b = x;
  }
  return Color.fromARGB(
    255, // Alpha
    ((r + m) * 255).round(),
    ((g + m) * 255).round(),
    ((b + m) * 255).round(),
  );
}
