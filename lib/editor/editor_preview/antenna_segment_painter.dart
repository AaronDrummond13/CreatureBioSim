import 'package:creature_bio_sim/render/antenna_painter.dart';
import 'package:creature_bio_sim/simulation/vector.dart';
import 'package:flutter/material.dart';

/// Draws one antenna (left + right curves) at the given segment. Uses the same
/// [drawAntennaAtSegment] as [CreaturePainter] so editor overlay and creature
/// render identically. [highlightForRemove] = red stroke; [highlight] = amber.
class AntennaSegmentPainter extends CustomPainter {
  AntennaSegmentPainter({
    required this.segment,
    required this.length,
    required this.width,
    this.angleDegrees = 45.0,
    required this.positions,
    required this.segmentAngles,
    required this.centerX,
    required this.centerY,
    required this.cameraX,
    required this.cameraY,
    required this.zoom,
    required this.segWidth,
    this.highlight = false,
    this.highlightForRemove = false,
  });

  final int segment;
  final double length;
  final double width;
  final double angleDegrees;
  final List<Vector2> positions;
  final List<double> segmentAngles;
  final double centerX;
  final double centerY;
  final double cameraX;
  final double cameraY;
  final double zoom;
  final double segWidth;
  final bool highlight;
  final bool highlightForRemove;

  @override
  void paint(Canvas canvas, Size size) {
    double sx(double wx) => centerX + (wx - cameraX) * zoom;
    double sy(double wy) => centerY + (wy - cameraY) * zoom;
    final strokeColor = highlightForRemove
        ? Colors.red
        : (highlight ? Colors.amber : Colors.white);
    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = (3.0 * zoom).clamp(1.0, 3.0);
    drawAntennaAtSegment(
      canvas,
      segment,
      length,
      width,
      angleDegrees,
      positions,
      segmentAngles,
      segWidth,
      sx,
      sy,
      zoom,
      strokePaint,
    );
  }

  @override
  bool shouldRepaint(covariant AntennaSegmentPainter old) =>
      old.segment != segment ||
      old.length != length ||
      old.width != width ||
      old.angleDegrees != angleDegrees ||
      old.highlight != highlight ||
      old.highlightForRemove != highlightForRemove;
}
