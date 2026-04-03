import 'package:bioism/editor/node_painter.dart';
import 'package:bioism/simulation/vector.dart';
import 'package:flutter/material.dart';

/// Draws 3 dorsal adjust nodes (start, end, height) when a fin is selected.
class DorsalNodePainter extends CustomPainter {
  DorsalNodePainter({
    required this.positions,
    required this.startSeg,
    required this.endSeg,
    required this.centerX,
    required this.centerY,
    required this.cameraX,
    required this.cameraY,
    required this.zoom,
    this.activeNode,
  });

  final List<Vector2> positions;
  final int startSeg;
  final int endSeg;
  final double centerX;
  final double centerY;
  final double cameraX;
  final double cameraY;
  final double zoom;
  final int? activeNode;

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.length < 2 || startSeg < 0 || endSeg >= positions.length)
      return;
    double sx(double wx) => centerX + (wx - cameraX) * zoom;
    double sy(double wy) => centerY + (wy - cameraY) * zoom;
    final startCx = (positions[startSeg].x + positions[startSeg + 1].x) / 2;
    final startCy = (positions[startSeg].y + positions[startSeg + 1].y) / 2;
    final endCx = (positions[endSeg].x + positions[endSeg + 1].x) / 2;
    final endCy = (positions[endSeg].y + positions[endSeg + 1].y) / 2;
    final midSeg = (startSeg + endSeg) ~/ 2;
    final midCx = midSeg + 1 < positions.length
        ? (positions[midSeg].x + positions[midSeg + 1].x) / 2
        : (positions[midSeg].x + positions[endSeg].x) / 2;
    final midCy = midSeg + 1 < positions.length
        ? (positions[midSeg].y + positions[midSeg + 1].y) / 2
        : (positions[midSeg].y + positions[endSeg].y) / 2;
    final sx0 = sx(startCx);
    final sy0 = sy(startCy);
    final sx1 = sx(endCx);
    final sy1 = sy(endCy);
    final sx2 = sx(midCx);
    final sy2 = sy(midCy) - 24;

    final points = [Offset(sx0, sy0), Offset(sx1, sy1), Offset(sx2, sy2)];
    for (var i = 0; i < points.length; i++)
      drawNode(canvas, points[i], active: activeNode == i);
  }

  @override
  bool shouldRepaint(covariant DorsalNodePainter old) =>
      old.startSeg != startSeg ||
      old.endSeg != endSeg ||
      old.activeNode != activeNode;
}
