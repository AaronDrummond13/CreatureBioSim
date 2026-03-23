import 'package:bioism/creature.dart';
import 'package:bioism/render/tail_painter.dart';
import 'package:bioism/simulation/vector.dart';
import 'package:flutter/material.dart';

/// Draws the tail fin as preview when dragging a new tail type onto the creature.
class TailPreviewPainter extends CustomPainter {
  TailPreviewPainter({
    required this.creature,
    required this.previewTailFin,
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
  final CaudalFinType previewTailFin;
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
    final previewCreature = Creature(
      segmentWidths: creature.segmentWidths,
      color: creature.color,
      dorsalFins: creature.dorsalFins,
      finColor: creature.finColor,
      tail: TailConfig(
        previewTailFin,
        rootWidth: creature.tail?.rootWidth ?? 12.0,
        maxWidth: creature.tail?.maxWidth ?? 20.0,
        length: creature.tail?.length ?? 90.0,
      ),
      lateralFins: creature.lateralFins,
    );
    paintTailFin(
      canvas,
      previewCreature,
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
      overrideFinColor: Colors.white.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant TailPreviewPainter old) =>
      old.previewTailFin != previewTailFin;
}
