import 'package:creature_bio_sim/creature.dart';
import 'package:creature_bio_sim/render/tail_painter.dart';
import 'package:creature_bio_sim/simulation/vector.dart';
import 'package:flutter/material.dart';

/// Draws the tail fin in red when dragging to remove (outside bounds).
class RemoveTailPainter extends CustomPainter {
  RemoveTailPainter({
    required this.creature,
    required this.positions,
    required this.segmentAngles,
    required this.centerX,
    required this.centerY,
    required this.cameraX,
    required this.cameraY,
    required this.zoom,
    required this.bodyColor,
    required this.widthAt,
  });

  final Creature creature;
  final List<Vector2> positions;
  final List<double> segmentAngles;
  final double centerX;
  final double centerY;
  final double cameraX;
  final double cameraY;
  final double zoom;
  final Color bodyColor;
  final double Function(int i) widthAt;

  @override
  void paint(Canvas canvas, Size size) {
    paintTailFin(
      canvas,
      creature,
      positions,
      segmentAngles,
      centerX,
      centerY,
      zoom,
      cameraX,
      cameraY,
      1.0,
      bodyColor,
      widthAt,
      overrideFinColor: Colors.red.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(covariant RemoveTailPainter old) => false;
}
