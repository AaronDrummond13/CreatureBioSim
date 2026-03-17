import 'dart:math';

import 'package:creature_bio_sim/creature.dart';
import 'package:creature_bio_sim/simulation/vector.dart';
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

void drawAntenna(
  Canvas canvas,
  double length,
  double width,
  Paint stroke, {
  required bool isLeft,
}) {
  final hLen = length / 2;
  final hWid = width / 2;

  Path path;

  path = Path();
  if (isLeft) {
    path
      ..moveTo(hLen, -hWid)
      ..quadraticBezierTo(0.0, -hWid * 3, -hLen * 2, 0.0);
    // ..quadraticBezierTo(0.0, 0.0, hLen, hWid)
    //..close();
  } else {
    path
      ..moveTo(-hLen * 2, 0.0)
      //  ..quadraticBezierTo(0.0, 0.0, -hLen, 0.0);
      ..quadraticBezierTo(0.0, hWid * 3, hLen, hWid);
    //..close();
  }

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
