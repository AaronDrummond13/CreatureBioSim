import 'dart:math';
import 'package:creature_bio_sim/creature.dart';
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
    final segHead = segment + 1 < segmentAngles.length ? segment + 1 : segment;
    final aLock = segmentAngles[segHead];
    final halfW = segWidth;
    final px = positions[segment].x;
    final py = positions[segment].y;
    final leftCx = px + sin(aAttach) * halfW,
        leftCy = py - cos(aAttach) * halfW;
    final rightCx = px - sin(aAttach) * halfW,
        rightCy = py + cos(aAttach) * halfW;
    final leftAngle = aLock + flareRad, rightAngle = aLock - flareRad;
    final fillColor = highlightForRemove
        ? Colors.red.withValues(alpha: 0.5)
        : (highlight
              ? Colors.white.withValues(alpha: 0.6)
              : finColor.withValues(alpha: 0.9));
    final strokeColor = highlightForRemove
        ? Colors.red
        : (highlight ? Colors.amber : Colors.white);
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = (2.0 * zoom).clamp(1.0, 2.0);
    void drawWing(Canvas c, double lS, double wS, {bool isLeft = true}) {
      if (wingType == LateralWingType.sharkWing) {
        final hLen = lS / 2, hWid = wS / 2;
        final path = Path()
          ..moveTo(hLen, -hWid)
          ..quadraticBezierTo(0.0, -hWid, -hLen, 0.0)
          ..quadraticBezierTo(0.0, hWid, hLen, hWid)
          ..close();
        c.drawPath(path, fillPaint);
        c.drawPath(path, strokePaint);
      } else if (wingType == LateralWingType.sharkConcave) {
        final hLen = lS / 2, hWid = wS / 2;
        final path = Path();
        if (isLeft) {
          path
            ..moveTo(hLen, -hWid)
            ..quadraticBezierTo(0.0, -hWid, -hLen, 0.0)
            ..quadraticBezierTo(0.0, 0.0, hLen, hWid)
            ..close();
        } else {
          path
            ..moveTo(hLen, -hWid)
            ..quadraticBezierTo(0.0, 0.0, -hLen, 0.0)
            ..quadraticBezierTo(0.0, hWid, hLen, hWid)
            ..close();
        }
        c.drawPath(path, fillPaint);
        c.drawPath(path, strokePaint);
      } else if (wingType == LateralWingType.paddle) {
        final hLen = lS / 2, hWid = wS / 2;
        final path = Path()
          ..moveTo(-hLen, -hWid)
          ..quadraticBezierTo(0.0, -hWid, hLen, 0.0)
          ..quadraticBezierTo(0.0, hWid, -hLen, hWid)
          ..close();
        c.drawPath(path, fillPaint);
        c.drawPath(path, strokePaint);
      } else if (wingType == LateralWingType.paddleConcave) {
        final hLen = lS / 2, hWid = wS / 2;
        final path = Path();
        if (isLeft) {
          path
            ..moveTo(-hLen, -hWid)
            ..quadraticBezierTo(0.0, -hWid, hLen, 0.0)
            ..quadraticBezierTo(0.0, 0.0, -hLen, hWid)
            ..close();
        } else {
          path
            ..moveTo(-hLen, -hWid)
            ..quadraticBezierTo(0.0, 0.0, hLen, 0.0)
            ..quadraticBezierTo(0.0, hWid, -hLen, hWid)
            ..close();
        }
        c.drawPath(path, fillPaint);
        c.drawPath(path, strokePaint);
      } else {
        final rect = Rect.fromCenter(
          center: Offset.zero,
          width: lS,
          height: wS,
        );
        c.drawOval(rect, fillPaint);
        c.drawOval(rect, strokePaint);
      }
    }

    canvas.save();
    canvas.translate(sx(leftCx), sy(leftCy));
    canvas.rotate(leftAngle);
    drawWing(canvas, lenScreen, widScreen, isLeft: true);
    canvas.restore();
    canvas.save();
    canvas.translate(sx(rightCx), sy(rightCy));
    canvas.rotate(rightAngle);
    drawWing(canvas, lenScreen, widScreen, isLeft: false);
    canvas.restore();
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
