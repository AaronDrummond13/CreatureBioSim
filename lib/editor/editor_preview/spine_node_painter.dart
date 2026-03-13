import 'package:creature_bio_sim/simulation/vector.dart';
import 'package:flutter/material.dart';

/// One node per spine segment for width edit: drag up = grow, down = shrink.
class SpineNodePainter extends CustomPainter {
  SpineNodePainter({
    required this.positions,
    required this.centerX,
    required this.centerY,
    required this.cameraX,
    required this.cameraY,
    required this.zoom,
    this.activeSegment,
  });

  final List<Vector2> positions;
  final double centerX;
  final double centerY;
  final double cameraX;
  final double cameraY;
  final double zoom;
  final int? activeSegment;

  static const double nodeRadius = 18.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.length < 2) return;
    final n = positions.length - 1;
    for (var seg = 0; seg < n; seg++) {
      final cx = (positions[seg].x + positions[seg + 1].x) / 2;
      final cy = (positions[seg].y + positions[seg + 1].y) / 2;
      final sx = centerX + (cx - cameraX) * zoom;
      final sy = centerY + (cy - cameraY) * zoom;
      final active = activeSegment == seg;
      final stroke = Paint()
        ..color = Colors.white.withValues(alpha: active ? 1.0 : 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      final fill = Paint()
        ..color = Colors.white.withValues(alpha: active ? 0.5 : 0.15);
      canvas.drawCircle(Offset(sx, sy), nodeRadius, fill);
      canvas.drawCircle(Offset(sx, sy), nodeRadius, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant SpineNodePainter old) =>
      old.activeSegment != activeSegment ||
      old.positions.length != positions.length;
}
