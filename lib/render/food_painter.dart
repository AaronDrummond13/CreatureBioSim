import 'package:flutter/material.dart';

import '../world/food.dart';
import 'view.dart';

/// Paints food as circles: green = initial generation, blue = later. White stroke, same view as creatures.
class FoodPainter extends CustomPainter {
  FoodPainter({
    required this.view,
    required this.items,
    this.foodRadiusWorld = 14.0,
    this.initialColor = const Color(0xFF4A7C59),
    this.laterColor = const Color(0xFF4A6B9E),
  });

  final CameraView view;
  final List<FoodItem> items;
  final double foodRadiusWorld;
  final Color initialColor;
  final Color laterColor;

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

    for (final food in items) {
      final fillPaint = Paint()
        ..color = food.isInitial ? initialColor : laterColor
        ..style = PaintingStyle.fill;
      final cx = sx(food.x);
      final cy = sy(food.y);
      final path = Path()
        ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: rScreen));
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant FoodPainter oldDelegate) =>
      oldDelegate.view != view ||
      oldDelegate.items != items ||
      oldDelegate.foodRadiusWorld != foodRadiusWorld ||
      oldDelegate.initialColor != initialColor ||
      oldDelegate.laterColor != laterColor;
}
