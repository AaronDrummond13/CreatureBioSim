import 'dart:math' show cos, sin, sqrt;

import 'package:flutter/material.dart';

import 'package:creature_bio_sim/creature.dart';
import 'package:creature_bio_sim/simulation/vector.dart';
import 'package:creature_bio_sim/render/render_utils.dart';

/// Tentacle mouth: tentacles with multiple joints, bases on a curved arc across the head.
/// [timeSeconds] drives wobble at each joint for soft-bodied motion.
void paintMouth(
  Canvas canvas,
  Creature creature,
  List<Vector2> positions,
  List<double> segmentAngles,
  double centerX,
  double centerY,
  double zoom,
  double cameraX,
  double cameraY,
  double bodyScale,
  Color bodyColor,
  double headWidthWorld,
  double timeSeconds,
) {
  if (creature.mouth != MouthType.tentacle) return;
  if (positions.length < 2 || segmentAngles.isEmpty) return;

  final headX = positions.last.x;
  final headY = positions.last.y;
  final headA = segmentAngles.last;
  final forwardX = cos(headA);
  final forwardY = sin(headA);
  final perpX = -sin(headA);
  final perpY = cos(headA);

  double sx(double wx) => centerX + (wx - cameraX) * zoom;
  double sy(double wy) => centerY + (wy - cameraY) * zoom;

  //the following seem good to adjust in game
  const tentacleCount = 5;
  const jointCount = 3;
  const length = 30.0;

  //these are better controlled by state, eating ect or not changed at all
  const wobbleSpeed = 2.0;
  const wobbleAmplitude = 4.5;
  const wobblePhase = 0.85;
  const tentaclePhaseOffset = 2.4;
  const headSizeRef = 30.0;
  final halfW = headWidthWorld * bodyScale;
  final sizeScale = halfW / headSizeRef;

  final rightX = headX - perpX * halfW;
  final rightY = headY - perpY * halfW;
  final leftX = headX + perpX * halfW;
  final leftY = headY + perpY * halfW;
  final bulgeX = headX + forwardX * halfW * 1.0;
  final bulgeY = headY + forwardY * halfW * 1.0;

  final fillColor = creature.finColor != null
      ? Color(creature.finColor!)
      : Color.lerp(bodyColor, Colors.white, 0.15)!;
  final fillPaint = Paint()
    ..color = fillColor
    ..style = PaintingStyle.fill;
  final strokePaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = (1.5 * zoom).clamp(1.0, 2.0);

  const baseWidths = [3.6, 2.6, 1.5, 0.65, 0.18];

  for (var ti = 0; ti < tentacleCount; ti++) {
    final t = tentacleCount > 1 ? ti / (tentacleCount - 1) : 0.5;
    final oneMinusT = 1.0 - t;
    final baseX =
        oneMinusT * oneMinusT * rightX +
        2 * oneMinusT * t * bulgeX +
        t * t * leftX;
    final baseY =
        oneMinusT * oneMinusT * rightY +
        2 * oneMinusT * t * bulgeY +
        t * t * leftY;

    final centerDist = tentacleCount > 1
        ? (ti - (tentacleCount - 1) / 2).abs() / ((tentacleCount - 1) / 2)
        : 0.0;
    final tentacleScale = 1.06 - 0.40 * centerDist;

    double jointWobble(int j) =>
        wobbleAmplitude *
        sin(
          timeSeconds * wobbleSpeed +
              j * wobblePhase +
              ti * tentaclePhaseOffset,
        );

    final tentacleLen = length * tentacleScale * sizeScale;
    final pts = <(double, double)>[];
    for (var j = 0; j < jointCount; j++) {
      final frac = (j + 1) / jointCount;
      final wx = baseX + forwardX * tentacleLen * frac + perpX * jointWobble(j);
      final wy = baseY + forwardY * tentacleLen * frac + perpY * jointWobble(j);
      pts.add((wx, wy));
    }

    final spine = <(double, double)>[];
    spine.add((baseX, baseY));
    for (final p in pts) spine.add(p);

    final widths = baseWidths
        .map((w) => w * tentacleScale * sizeScale)
        .toList();

    double dx(int i) {
      if (i <= 0) return spine[1].$1 - spine[0].$1;
      if (i >= spine.length - 1) return spine[i].$1 - spine[i - 1].$1;
      return spine[i + 1].$1 - spine[i - 1].$1;
    }

    double dy(int i) {
      if (i <= 0) return spine[1].$2 - spine[0].$2;
      if (i >= spine.length - 1) return spine[i].$2 - spine[i - 1].$2;
      return spine[i + 1].$2 - spine[i - 1].$2;
    }

    final leftPts = <Offset>[];
    final rightPts = <Offset>[];
    for (var i = 0; i < spine.length; i++) {
      var ddx = dx(i);
      var ddy = dy(i);
      final len = sqrt(ddx * ddx + ddy * ddy);
      if (len > 1e-6) {
        ddx /= len;
        ddy /= len;
      } else {
        ddx = perpX;
        ddy = perpY;
      }
      final nx = -ddy;
      final ny = ddx;
      final w = i < widths.length ? widths[i] : 0.2;
      leftPts.add(Offset(sx(spine[i].$1 + nx * w), sy(spine[i].$2 + ny * w)));
      rightPts.add(Offset(sx(spine[i].$1 - nx * w), sy(spine[i].$2 - ny * w)));
    }

    final outline = <Offset>[...leftPts, ...rightPts.reversed.skip(1)];
    final path = Path();
    path.moveTo(outline[0].dx, outline[0].dy);
    appendSmoothCurve(path, outline, 1.0 / 6.0, closed: true);

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }
}
