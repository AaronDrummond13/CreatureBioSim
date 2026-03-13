import 'dart:math';
import 'package:creature_bio_sim/creature.dart';
import 'package:creature_bio_sim/render/pec_painter.dart';
import 'package:creature_bio_sim/simulation/vector.dart';
import 'package:flutter/material.dart';

/// Draws one lateral fin on the creature at the given segment (for add/move preview). [highlight] = draw in highlight color; [highlightForRemove] = red (will be removed).
class PecFinSegmentPainter extends CustomPainter {
  PecFinSegmentPainter({
    required this.segment,
    required this.length,
    required this.width,
    this.angleDegrees = 45.0,
    this.wingType = LateralWingType.ellipse,
    required this.positions,
    required this.segmentAngles,
    required this.centerX,
    required this.centerY,
    required this.cameraX,
    required this.cameraY,
    required this.zoom,
    required this.segWidth,
    required this.creatureColor,
    required this.finColor,
    this.highlight = false,
    this.highlightForRemove = false,
  });

  final int segment;
  final double length;
  final double width;
  final double angleDegrees;
  final LateralWingType wingType;
  final List<Vector2> positions;
  final List<double> segmentAngles;
  final double centerX;
  final double centerY;
  final double cameraX;
  final double cameraY;
  final double zoom;
  final double segWidth;
  final Color creatureColor;
  final Color finColor;
  final bool highlight;
  final bool highlightForRemove;

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.length < 2 || segment < 0 || segment >= positions.length - 1)
      return;
    if (segment >= segmentAngles.length) return;
    double sx(double wx) => centerX + (wx - cameraX) * zoom;
    double sy(double wy) => centerY + (wy - cameraY) * zoom;
    final flareRad = angleDegrees * pi / 180.0;
    final len = length;
    final wid = width;
    final lenScreen = len * zoom;
    final widScreen = wid * zoom;
    final aAttach = segmentAngles[segment];
    final halfW = segWidth;
    final px = positions[segment].x;
    final py = positions[segment].y;
    final leftCx = px + sin(aAttach) * halfW,
        leftCy = py - cos(aAttach) * halfW;
    final rightCx = px - sin(aAttach) * halfW,
        rightCy = py + cos(aAttach) * halfW;
    final strokeColor = highlightForRemove
        ? Colors.red
        : (highlight ? Colors.amber : Colors.white);
    final fillPaintL = Paint()
      ..shader =
          LinearGradient(
            transform: GradientRotation(pi / 2 - flareRad),
            colors: highlightForRemove
                ? [Colors.red.withValues(alpha: 0.5)]
                : [finColor, creatureColor, creatureColor],
          ).createShader(
            Rect.fromCenter(
              center: Offset.zero,
              width: lenScreen / 2,
              height: lenScreen / 2,
            ),
          )
      ..style = PaintingStyle.fill;
    final fillPaintR = Paint()
      ..shader =
          LinearGradient(
            transform: GradientRotation(-pi / 2 + flareRad),
            colors: highlightForRemove
                ? [Colors.red.withValues(alpha: 0.5)]
                : [finColor, creatureColor, creatureColor],
          ).createShader(
            Rect.fromCenter(
              center: Offset.zero,
              width: lenScreen / 2,
              height: lenScreen / 2,
            ),
          )
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = (2.0 * zoom).clamp(1.0, 2.0);

    final anchors = computeFinAnchors(
      flareRad: flareRad,
      halfWidth: halfW,
      positions: positions,
      segment: segment,
      segmentAngles: segmentAngles,
    );

    drawTransformed(
      canvas,
      Offset(sx(leftCx), sy(leftCy)),
      anchors.leftAngle,
      () {
        drawLateralWing(
          canvas,
          wingType,
          lenScreen,
          widScreen,
          fillPaintL,
          strokePaint,
          isLeft: true,
        );
      },
    );

    drawTransformed(
      canvas,
      Offset(sx(rightCx), sy(rightCy)),
      anchors.rightAngle,
      () {
        drawLateralWing(
          canvas,
          wingType,
          lenScreen,
          widScreen,
          fillPaintR,
          strokePaint,
          isLeft: false,
        );
      },
    );
  }

  @override
  bool shouldRepaint(covariant PecFinSegmentPainter old) =>
      old.segment != segment ||
      old.length != length ||
      old.width != width ||
      old.angleDegrees != angleDegrees ||
      old.wingType != wingType ||
      old.highlight != highlight ||
      old.highlightForRemove != highlightForRemove;
}
