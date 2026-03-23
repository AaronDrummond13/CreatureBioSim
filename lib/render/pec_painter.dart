import 'dart:math';

import 'package:bioism/creature.dart';
import 'package:bioism/simulation/vector.dart';
import 'package:flutter/material.dart';

class FinAnchors {
  final Offset left;
  final Offset right;
  final double leftAngle;
  final double rightAngle;

  FinAnchors(this.left, this.right, this.leftAngle, this.rightAngle);
}

FinAnchors computeFinAnchors({
  required List<Vector2> positions,
  required List<double> segmentAngles,
  required int segment,
  required double halfWidth,
  required double flareRad,
}) {
  final px = positions[segment].x;
  final py = positions[segment].y;

  final aAttach = segmentAngles[segment];
  final segHead = segment + 1 < segmentAngles.length ? segment + 1 : segment;
  final aLock = segmentAngles[segHead];

  final leftCx = px + sin(aAttach) * halfWidth;
  final leftCy = py - cos(aAttach) * halfWidth;

  final rightCx = px - sin(aAttach) * halfWidth;
  final rightCy = py + cos(aAttach) * halfWidth;

  return FinAnchors(
    Offset(leftCx, leftCy),
    Offset(rightCx, rightCy),
    aLock + flareRad,
    aLock - flareRad,
  );
}

void drawLateralWing(
  Canvas canvas,
  LateralWingType type,
  double length,
  double width,
  Paint fill,
  Paint stroke, {
  required bool isLeft,
}) {
  final hLen = length / 2;
  final hWid = width / 2;

  Path path;

  switch (type) {
    case LateralWingType.sharkWing:
      path = Path()
        ..moveTo(hLen, -hWid)
        ..quadraticBezierTo(0.0, -hWid, -hLen, 0.0)
        ..quadraticBezierTo(0.0, hWid, hLen, hWid)
        ..close();
      break;

    case LateralWingType.paddle:
      path = Path()
        ..moveTo(-hLen, -hWid)
        ..quadraticBezierTo(0.0, -hWid, hLen, 0.0)
        ..quadraticBezierTo(0.0, hWid, -hLen, hWid)
        ..close();
      break;

    case LateralWingType.sharkConcave:
      path = Path();
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
      break;

    case LateralWingType.paddleConcave:
      path = Path();
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
      break;

    default:
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: length,
        height: width,
      );
      canvas.drawOval(rect, fill);
      canvas.drawOval(rect, stroke);
      return;
  }

  canvas.drawPath(path, fill);
  canvas.drawPath(path, stroke);
}

void drawTransformed(
  Canvas canvas,
  Offset pos,
  double angle,
  VoidCallback draw,
) {
  canvas.save();
  canvas.translate(pos.dx, pos.dy);
  canvas.rotate(angle);
  draw();
  canvas.restore();
}
