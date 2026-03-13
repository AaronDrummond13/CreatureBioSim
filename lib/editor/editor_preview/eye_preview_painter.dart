import 'dart:math';
import 'dart:ui';

import 'package:creature_bio_sim/creature.dart';
import 'package:creature_bio_sim/simulation/vector.dart';
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
    this.radiusWorld,
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

  /// When null, uses default 6.0 (add preview); when set, uses for move preview.
  final double? radiusWorld;

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
    final r = radiusWorld ?? 6.0;
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
      final baseFill = Paint()
        ..color = creatureColor
        ..style = PaintingStyle.fill;
      final baseStroke = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW * 3 / 4;
      canvas.drawCircle(center, rScreen, baseFill);
      canvas.drawCircle(center, rScreen, baseStroke);
      final irisR = rScreen * _irisFrac;
      final irisRect = Rect.fromCircle(center: center, radius: irisR);
      final irisFill = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.5,
          stops: [pupilFrac, 1 - ((1 - pupilFrac) / 2), 1.0],
          colors: [
            Color.lerp(creatureColor, Colors.white, 0.3)!,
            Color.lerp(finColor, creatureColor, 0.5)!,
            Color.lerp(finColor, Colors.black, 0.8)!,
          ],
        ).createShader(irisRect)
        ..style = PaintingStyle.fill;
      final irisStroke = Paint()
        ..color = Color.lerp(finColor, Colors.black, 0.6)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW / 2;
      canvas.drawCircle(center, irisR, irisFill);
      canvas.drawCircle(center, irisR, irisStroke);
      final pupilFill = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill;
      final pupilStroke = Paint()
        ..color = Color.lerp(creatureColor, Colors.white, 0.2)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW;
      canvas.drawCircle(center, rScreen * pupilFrac, pupilFill);
      canvas.drawCircle(center, rScreen * pupilFrac, pupilStroke);
      final primaryHighlight = Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..style = PaintingStyle.fill;
      final secondaryHighlight = Paint()
        ..color = Colors.white.withValues(alpha: 0.2)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(
          center.dx - rScreen * _primaryHighlightOffset,
          center.dy - rScreen * _primaryHighlightOffset,
        ),
        rScreen * _primaryHighlightRadiusFrac,
        primaryHighlight,
      );
      canvas.drawCircle(
        Offset(
          center.dx + rScreen * _secondaryHighlightOffset,
          center.dy + rScreen * _secondaryHighlightOffset,
        ),
        rScreen * _secondaryHighlightRadiusFrac,
        secondaryHighlight,
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
