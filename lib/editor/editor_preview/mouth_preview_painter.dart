import 'package:bioism/creature.dart';
import 'package:bioism/render/mouth_painter.dart';
import 'package:bioism/simulation/vector.dart';
import 'package:flutter/material.dart';

/// Draws the mouth only as preview when dragging a mouth type onto the creature.
/// Uses same face curve as actual render so preview matches in-game mouth placement.
class MouthPreviewPainter extends CustomPainter {
  MouthPreviewPainter({
    required this.creature,
    required this.previewMouthType,
    this.previewMouthCount,
    required this.positions,
    required this.segmentAngles,
    required this.centerX,
    required this.centerY,
    required this.cameraX,
    required this.cameraY,
    required this.zoom,
    required this.headWidthWorld,
    required this.bodyColor,
    this.faceCurveWorld,
  });

  final Creature creature;
  final MouthType previewMouthType;
  final int? previewMouthCount;
  final List<Vector2> positions;
  final List<double> segmentAngles;
  final double centerX;
  final double centerY;
  final double cameraX;
  final double cameraY;
  final double zoom;
  final double headWidthWorld;
  final Color bodyColor;
  final List<Offset>? faceCurveWorld;

  @override
  void paint(Canvas canvas, Size size) {
    final previewCreature = Creature(
      segmentWidths: creature.segmentWidths,
      color: creature.color,
      dorsalFins: creature.dorsalFins,
      finColor: creature.finColor,
      tail: creature.tail,
      lateralFins: creature.lateralFins,
      trophicType: creature.trophicType,
      mouth: previewMouthType,
      mouthCount: previewMouthCount,
      mouthLength: creature.mouthLength ?? MouthParams.lengthDefault,
      mouthCurve: creature.mouthCurve ?? MouthParams.curveDefault,
      mouthWobbleAmplitude:
          creature.mouthWobbleAmplitude ?? MouthParams.wobbleDefault,
    );
    paintMouth(
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
      headWidthWorld,
      0.0,
      faceCurveWorld: faceCurveWorld,
    );
  }

  @override
  bool shouldRepaint(covariant MouthPreviewPainter old) =>
      old.previewMouthType != previewMouthType ||
      old.previewMouthCount != previewMouthCount ||
      old.positions != positions ||
      old.segmentAngles != segmentAngles ||
      old.centerX != centerX ||
      old.centerY != centerY ||
      old.zoom != zoom ||
      old.faceCurveWorld != faceCurveWorld;
}
