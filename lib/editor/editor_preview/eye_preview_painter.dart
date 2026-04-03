import 'dart:math';
import 'package:bioism/creature.dart';
import 'package:bioism/render/eye_painter.dart';
import 'package:bioism/simulation/vector.dart';
import 'package:flutter/material.dart';

/// Preview when dragging + eye onto creature. Same render as CreaturePainter._drawConfigEyes.
class EyePreviewPainter extends CustomPainter {
  EyePreviewPainter({
    required this.segment,
    required this.offsetFromCenter,
    required this.positions,
    required this.segmentAngles,
    required this.centerX,
    required this.centerY,
    required this.cameraX,
    required this.cameraY,
    required this.zoom,
    required this.widthAtVertex,
    required this.creatureColor,
    this.creatureFinColor,
    this.pupilFraction = EyeConfig.pupilFractionDefault,
    this.radiusWorld = EyeConfig.radiusDefault,
  });

  final int segment;
  final double offsetFromCenter;
  final List<Vector2> positions;
  final List<double> segmentAngles;
  final double centerX;
  final double centerY;
  final double cameraX;
  final double cameraY;
  final double zoom;
  final double Function(int i) widthAtVertex;
  final Color creatureColor;
  final Color? creatureFinColor;
  final double pupilFraction;
  final double radiusWorld;

  static const double _irisFrac = 0.90;
  static const double _primaryHighlightOffset = 0.2;
  static const double _primaryHighlightRadiusFrac = 0.3;
  static const double _secondaryHighlightOffset = 0.26;
  static const double _secondaryHighlightRadiusFrac = 0.2;

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.length < 2 || segmentAngles.isEmpty) return;
    double sx(double wx) => centerX + (wx - cameraX) * zoom;
    double sy(double wy) => centerY + (wy - cameraY) * zoom;
    final seg = segment.clamp(0, positions.length - 2);
    final cx = (positions[seg].x + positions[seg + 1].x) / 2;
    final cy = (positions[seg].y + positions[seg + 1].y) / 2;
    final a = segmentAngles[seg];
    final halfW = widthAtVertex(seg);
    final r = radiusWorld;
    final rScreen = r * zoom;
    final strokeW = (rScreen * 0.12).clamp(1.2, 3.0);
    final isSingle = offsetFromCenter < EyeConfig.singleEyeThreshold;
    final centers = <Offset>[];
    if (isSingle) {
      centers.add(Offset(sx(cx), sy(cy)));
    } else {
      final off = offsetFromCenter * halfW;
      final dx = -sin(a) * off;
      final dy = cos(a) * off;
      centers.add(Offset(sx(cx + dx), sy(cy + dy)));
      centers.add(Offset(sx(cx - dx), sy(cy - dy)));
    }
    final finColor = creatureFinColor ?? creatureColor;
    final pupilFrac = pupilFraction.clamp(
      EyeConfig.pupilFractionMin,
      EyeConfig.pupilFractionMax,
    );
    for (final center in centers) {
      drawEye(
        canvas: canvas,
        center: center,
        radius: rScreen,
        strokeW: strokeW,
        irisFrac: _irisFrac,
        pupilFrac: pupilFrac,
        creatureColor: creatureColor,
        finColor: finColor,
        primaryHighlightOffset: _primaryHighlightOffset,
        primaryHighlightRadiusFrac: _primaryHighlightRadiusFrac,
        secondaryHighlightOffset: _secondaryHighlightOffset,
        secondaryHighlightRadiusFrac: _secondaryHighlightRadiusFrac,
      );
    }
  }

  @override
  bool shouldRepaint(covariant EyePreviewPainter old) =>
      old.segment != segment ||
      old.offsetFromCenter != offsetFromCenter ||
      old.radiusWorld != radiusWorld ||
      old.creatureColor != creatureColor ||
      old.creatureFinColor != creatureFinColor ||
      old.pupilFraction != pupilFraction ||
      old.positions != positions;
}
