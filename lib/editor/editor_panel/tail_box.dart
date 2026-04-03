import 'package:bioism/creature.dart';
import 'package:bioism/editor/editor_panel/tail_preview_painter.dart';
import 'package:bioism/editor/editor_style.dart';
import 'package:flutter/material.dart';

/// One tail option: real tail via [paintTailFin] with creature colours and minimal spine. Wrapped in Draggable by caller.
class TailBox extends StatelessWidget {
  const TailBox({super.key, required this.creature, required this.tailFin});

  final Creature creature;
  final CaudalFinType tailFin;

  static const double _boxW = 52;
  static const double _boxH = 36;
  static const double tailWorldLeft = -25.0;
  static const double _tailLength = 60.0;
  static const double zoom = 0.87;
  static double get tailCenterWorld => tailWorldLeft - _tailLength / 2;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _boxW,
      height: _boxH,
      decoration: BoxDecoration(
        color: EditorStyle.fill,
        borderRadius: BorderRadius.circular(EditorStyle.radius),
        border: Border.all(
          color: EditorStyle.stroke,
          width: EditorStyle.strokeWidth,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(EditorStyle.radius),
        child: CustomPaint(
          painter: TailPreviewPainter2(creature: creature, tailFin: tailFin),
          size: const Size(_boxW, _boxH),
        ),
      ),
    );
  }
}
