import 'dart:math';
import 'package:creature_bio_sim/editor/node_painter.dart';
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
    drawNode(canvas, Offset(sx0, sy0), active: activeNode == 0, radius: 14);
  }

  @override
  bool shouldRepaint(covariant BodyNodePainter old) =>
      old.activeNode != activeNode;
}
