import 'dart:math';
import 'package:creature_bio_sim/simulation/vector.dart';
import 'package:flutter/material.dart';

/// Draws a dorsal fin range with highlight (e.g. when dragging to delete).
class RemoveDorsalPainter extends CustomPainter {
  RemoveDorsalPainter({
    required this.startSeg,
    required this.endSeg,
    required this.positions,
    required this.centerX,
    required this.centerY,
    required this.cameraX,
    required this.cameraY,
    required this.zoom,
  });

  final int startSeg;
  final int endSeg;
  final List<Vector2> positions;
  final double centerX;
  final double centerY;
  final double cameraX;
  final double cameraY;
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.length < 2 || startSeg < 0 || endSeg < startSeg) return;
    final lastSeg = endSeg.clamp(startSeg, positions.length - 2);
    double sx(double wx) => centerX + (wx - cameraX) * zoom;
    double sy(double wy) => centerY + (wy - cameraY) * zoom;
    const fullH = 14.0;
    const baseH = fullH * 0.3;
    final topPts = <Offset>[];
    final spinePts = <Offset>[];
    for (var i = startSeg; i <= lastSeg + 1 && i < positions.length; i++) {
      final p = Offset(sx(positions[i].x), sy(positions[i].y));
      spinePts.add(p);
      final idx = i - startSeg;
      final isEnd = idx == 0 || idx == (lastSeg - startSeg + 1);
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
    canvas.drawPath(path, Paint()..color = Colors.red.withValues(alpha: 0.5));
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant RemoveDorsalPainter old) =>
      old.startSeg != startSeg || old.endSeg != endSeg;
}
