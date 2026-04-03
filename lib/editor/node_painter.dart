import 'package:flutter/material.dart';

void drawNode(
  Canvas canvas,
  Offset position, {
  required bool active,
  double radius = 14,
  double strokeWidth = 2.5,
}) {
  final stroke = Paint()
    ..color = Colors.white.withValues(alpha: active ? 1.0 : 0.35)
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth;

  final fill = Paint()
    ..color = Colors.white.withValues(alpha: active ? 0.5 : 0.15)
    ..style = PaintingStyle.fill;

  canvas.drawCircle(position, radius, fill);
  canvas.drawCircle(position, radius, stroke);
}

const double nodeRadius = 14.0;
