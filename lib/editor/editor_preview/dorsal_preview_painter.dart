import 'dart:math';

import 'package:bioism/dorsal_fin_rules.dart';
import 'package:bioism/simulation/vector.dart';
import 'package:flutter/material.dart';

/// Highlights a [dorsalFinMinSegments]-segment dorsal fin on the creature when dragging + dorsal over the viewport.
class DorsalPreviewPainter extends CustomPainter {
  DorsalPreviewPainter({
    required this.startSeg,
    required this.positions,
    required this.centerX,
    required this.centerY,
    required this.cameraX,
    required this.cameraY,
    required this.zoom,
    required this.finColor,
  });

  final int startSeg;
  final List<Vector2> positions;
  final double centerX;
  final double centerY;
  final double cameraX;
  final double cameraY;
  final double zoom;
  final Color finColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.length < 2 || startSeg < 0) return;
    final endSeg = (startSeg + dorsalFinMinSegments - 1).clamp(
      startSeg,
      positions.length - 2,
    );
    double sx(double wx) => centerX + (wx - cameraX) * zoom;
    double sy(double wy) => centerY + (wy - cameraY) * zoom;
    const fullH = 14.0;
    const baseH = fullH * 0.3;
    final topPts = <Offset>[];
    final spinePts = <Offset>[];
    for (var i = startSeg; i <= endSeg + 1 && i < positions.length; i++) {
      final p = Offset(sx(positions[i].x), sy(positions[i].y));
      spinePts.add(p);
      final idx = i - startSeg;
      final isEnd = idx == 0 || idx == (endSeg - startSeg + 1);
      final h = (isEnd ? baseH : fullH * 0.7) * zoom;
      final prev = i > startSeg ? positions[i - 1] : positions[i];
      final dx = positions[i].x - prev.x;
      final dy = positions[i].y - prev.y;
      final perp = (dx * dx + dy * dy) > 0 ? h / sqrt(dx * dx + dy * dy) : 0.0;
      topPts.add(Offset(p.dx - dy * perp, p.dy + dx * perp));
    }
    if (topPts.isEmpty || spinePts.isEmpty) return;
    final path = Path()..moveTo(topPts.first.dx, topPts.first.dy);
    for (var i = 1; i < topPts.length; i++)
      path.lineTo(topPts[i].dx, topPts[i].dy);
    for (var i = spinePts.length - 1; i >= 0; i--)
      path.lineTo(spinePts[i].dx, spinePts[i].dy);
    path.close();
    canvas.drawPath(path, Paint()..color = finColor.withValues(alpha: 0.5));
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant DorsalPreviewPainter old) =>
      old.startSeg != startSeg;
}
