import 'package:creature_bio_sim/creature.dart';
import 'package:creature_bio_sim/editor/editor_panel/tail_box.dart';
import 'package:creature_bio_sim/editor/editor_style.dart';
import 'package:creature_bio_sim/render/tail_painter.dart';
import 'package:creature_bio_sim/simulation/vector.dart';
import 'package:flutter/material.dart';

/// Paints tail using shared [paintTailFin]; horizontal in box, centered.
class TailPreviewPainter extends CustomPainter {
  TailPreviewPainter({required this.creature, required this.tailFin});

  final Creature creature;
  final CaudalFinType? tailFin;

  @override
  void paint(Canvas canvas, Size size) {
    final bodyColor = Color(creature.color);
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    if (tailFin == null) {
      canvas.drawCircle(
        Offset(centerX, centerY),
        8,
        Paint()..color = bodyColor,
      );
      canvas.drawCircle(
        Offset(centerX, centerY),
        8,
        Paint()
          ..color = EditorStyle.stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      return;
    }
    final minimal = Creature(
      segmentWidths: [20.0, 25.0],
      color: creature.color,
      finColor: creature.finColor,
      tail: TailConfig(tailFin!),
    );
    final positions = [
      Vector2(TailBox.tailWorldLeft, 0),
      Vector2(TailBox.tailWorldLeft + 10, 0),
      Vector2(TailBox.tailWorldLeft + 20, 0),
    ];
    const segmentAngles = [0.0, 0.0];
    double widthAt(int i) => minimal.widthAtVertex(i);
    paintTailFin(
      canvas,
      minimal,
      positions,
      segmentAngles,
      centerX,
      centerY,
      TailBox.zoom,
      TailBox.tailCenterWorld,
      0,
      1.0,
      bodyColor,
      widthAt,
    );
  }

  @override
  bool shouldRepaint(covariant TailPreviewPainter old) =>
      old.creature.color != creature.color ||
      old.creature.finColor != creature.finColor ||
      old.tailFin != tailFin;
}
