import 'dart:math';
import 'package:creature_bio_sim/simulation/vector.dart';
import 'package:flutter/material.dart';

/// Tail node OUTSIDE creature (after tail) for extend/contract.
class BodyNodePainter extends CustomPainter {
  BodyNodePainter({
    required this.positions,
    required this.centerX,
    required this.centerY,
    required this.cameraX,
    required this.cameraY,
    required this.zoom,
    this.activeNode,
  });

  final List<Vector2> positions;
  final double centerX;
  final double centerY;
  final double cameraX;
  final double cameraY;
  final double zoom;

  /// 0 = tail; null = none active (inactive look).
  final int? activeNode;

  static const double outsideOffset = 48.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.length < 2) return;
    final tail = positions.first;
    final second = positions[1];
    double dx = tail.x - second.x;
    double dy = tail.y - second.y;
    var len = sqrt(dx * dx + dy * dy);
    if (len < 1e-6) len = 1.0;
    final tailOutX = tail.x + dx / len * outsideOffset;
    final tailOutY = tail.y + dy / len * outsideOffset;
    final sx0 = centerX + (tailOutX - cameraX) * zoom;
    final sy0 = centerY + (tailOutY - cameraY) * zoom;
    const r = 24.0;
    final active = activeNode == 0;
    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: active ? 1.0 : 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final fill = Paint()
      ..color = Colors.white.withValues(alpha: active ? 0.5 : 0.15);
    canvas.drawCircle(Offset(sx0, sy0), r, fill);
    canvas.drawCircle(Offset(sx0, sy0), r, stroke);
  }

  @override
  bool shouldRepaint(covariant BodyNodePainter old) =>
      old.activeNode != activeNode;
}
