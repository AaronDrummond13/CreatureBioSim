import 'dart:math' show cos, pi, sin;

import 'package:flutter/material.dart';

import '../world/food.dart';
import 'view.dart';

/// Paints food as smooth curved hollow hexagons (ring: outer and inner path, green between).
class FoodPainter extends CustomPainter {
  FoodPainter({
    required this.view,
    required this.items,
    this.foodRadiusWorld = 14.0,
    this.fillColor = const Color(0xFF4A7C59),
    this.innerRadiusFrac = 0.5,
  });

  final CameraView view;
  final List<FoodItem> items;
  final double foodRadiusWorld;
  final Color fillColor;
  /// Inner radius as fraction of outer (0..1). Ring = area between outer and inner.
  final double innerRadiusFrac;

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty) return;
    final z = view.zoom;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    double sx(double wx) => centerX + (wx - view.cameraX) * z;
    double sy(double wy) => centerY + (wy - view.cameraY) * z;
    final rScreen = foodRadiusWorld * z;
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = (2.0 * z).clamp(1.0, 2.0);
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    for (final food in items) {
      final cx = sx(food.x);
      final cy = sy(food.y);
      final outer = _smoothHexagonPath(cx, cy, rScreen);
      final inner = _smoothHexagonPath(cx, cy, rScreen * innerRadiusFrac.clamp(0.01, 0.99));
      final ring = Path.combine(PathOperation.difference, outer, inner);
      canvas.drawPath(ring, fillPaint);
      canvas.drawPath(outer, strokePaint);
    }
  }

  /// Closed path: smooth curved hexagon (rounded edges via quadratic bezier).
  Path _smoothHexagonPath(double cx, double cy, double radius) {
    const int sides = 6;
    final path = Path();
    final points = <Offset>[];
    for (var i = 0; i < sides; i++) {
      final t = (i / sides) * 2 * pi - pi / 2;
      points.add(Offset(cx + radius * cos(t), cy + radius * sin(t)));
    }
    path.moveTo(points[0].dx, points[0].dy);
    for (var i = 1; i <= sides; i++) {
      final curr = points[i % sides];
      final prev = points[i - 1];
      final mid = Offset(
        (prev.dx + curr.dx) / 2,
        (prev.dy + curr.dy) / 2,
      );
      final bulge = 1.12;
      final ctrlX = mid.dx + (mid.dx - cx) * (bulge - 1);
      final ctrlY = mid.dy + (mid.dy - cy) * (bulge - 1);
      path.quadraticBezierTo(ctrlX, ctrlY, curr.dx, curr.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant FoodPainter oldDelegate) =>
      oldDelegate.view != view ||
      oldDelegate.items != items ||
      oldDelegate.foodRadiusWorld != foodRadiusWorld ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.innerRadiusFrac != innerRadiusFrac;
}
