import 'dart:math' show atan2, cos, pi, sin, sqrt;

import 'package:flutter/material.dart';

import 'package:creature_bio_sim/creature.dart';
import 'package:creature_bio_sim/simulation/vector.dart';
import 'package:creature_bio_sim/render/render_utils.dart';

/// Tentacle mouth: tentacles with multiple joints, bases on a curved arc across the head.
/// [timeSeconds] drives wobble at each joint for soft-bodied motion.
/// When [lastAteAt] is set and within 2s, mouth animation runs 3x faster.
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
  double timeSeconds, {
  double? lastAteAt,
  List<Offset>? faceCurveWorld,
}) {
  if (creature.mouth == null) return;
  if (positions.length < 2 || segmentAngles.isEmpty) return;

  const postEatDuration = 1.0;
  const postEatSpeedMultiplier = 10.0;
  final mouthTime =
      (lastAteAt != null &&
          (timeSeconds - lastAteAt) >= 0 &&
          (timeSeconds - lastAteAt) < postEatDuration)
      ? lastAteAt + (timeSeconds - lastAteAt) * postEatSpeedMultiplier
      : timeSeconds;

  final headX = positions.last.x;
  final headY = positions.last.y;
  final headA = segmentAngles.last;
  final forwardX = cos(headA);
  final forwardY = sin(headA);
  final perpX = -sin(headA);
  final perpY = cos(headA);

  double sx(double wx) => centerX + (wx - cameraX) * zoom;
  double sy(double wy) => centerY + (wy - cameraY) * zoom;

  const headSizeRef = 30.0;
  final halfW = headWidthWorld * bodyScale;
  final sizeScale = halfW / headSizeRef;

  // Fallback arc when no face curve (e.g. mandible or curve not computed).
  final rightX = headX - perpX * halfW;
  final rightY = headY - perpY * halfW;
  final leftX = headX + perpX * halfW;
  final leftY = headY + perpY * halfW;
  final tipX = headX + forwardX * halfW;
  final tipY = headY + forwardY * halfW;

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

  if (creature.mouth == MouthType.tentacle) {
    _paintTentacleMouth(
      canvas,
      mouthTime,
      forwardX,
      forwardY,
      perpX,
      perpY,
      halfW,
      sizeScale,
      faceCurveWorld,
      rightX,
      rightY,
      tipX,
      tipY,
      leftX,
      leftY,
      fillPaint,
      strokePaint,
      sx,
      sy,
    );
    return;
  }
  if (creature.mouth == MouthType.teeth) {
    _paintTeethMouth(
      canvas,
      mouthTime,
      forwardX,
      forwardY,
      perpX,
      perpY,
      halfW,
      sizeScale,
      faceCurveWorld,
      rightX,
      rightY,
      tipX,
      tipY,
      leftX,
      leftY,
      fillPaint,
      strokePaint,
      sx,
      sy,
    );
    return;
  }
  if (creature.mouth == MouthType.mandible) {
    _paintMandibleMouth(
      canvas,
      creature,
      centerX,
      centerY,
      zoom,
      cameraX,
      cameraY,
      bodyScale,
      headWidthWorld,
      mouthTime,
      headX,
      headY,
      forwardX,
      forwardY,
      perpX,
      perpY,
      halfW,
      sizeScale,
      rightX,
      rightY,
      leftX,
      leftY,
      fillPaint,
      strokePaint,
      sx,
      sy,
    );
  }
}

/// Base position on fallback quadratic arc at t (0 = right, 0.5 = tip, 1 = left).
void _fallbackArcAt(
  double t,
  double rightX,
  double rightY,
  double tipX,
  double tipY,
  double leftX,
  double leftY,
  List<double> out,
) {
  final oneMinusT = 1.0 - t;
  out[0] =
      oneMinusT * oneMinusT * rightX + 2 * oneMinusT * t * tipX + t * t * leftX;
  out[1] =
      oneMinusT * oneMinusT * rightY + 2 * oneMinusT * t * tipY + t * t * leftY;
}

/// Base position on face curve: use [faceCurveWorld] if valid, else fallback arc.
void _baseOnFaceCurve(
  double t,
  List<Offset>? faceCurveWorld,
  double rightX,
  double rightY,
  double tipX,
  double tipY,
  double leftX,
  double leftY,
  List<double> out,
) {
  if (faceCurveWorld != null && faceCurveWorld.length >= 2) {
    final idx = t * (faceCurveWorld.length - 1);
    final i0 = idx.floor().clamp(0, faceCurveWorld.length - 1);
    final i1 = (i0 + 1).clamp(0, faceCurveWorld.length - 1);
    final frac = idx - i0;
    final a = faceCurveWorld[i0];
    final b = faceCurveWorld[i1];
    out[0] = a.dx + (b.dx - a.dx) * frac;
    out[1] = a.dy + (b.dy - a.dy) * frac;
  } else {
    _fallbackArcAt(t, rightX, rightY, tipX, tipY, leftX, leftY, out);
  }
}

void _paintTentacleMouth(
  Canvas canvas,
  double timeSeconds,
  double forwardX,
  double forwardY,
  double perpX,
  double perpY,
  double halfW,
  double sizeScale,
  List<Offset>? faceCurveWorld,
  double rightX,
  double rightY,
  double tipX,
  double tipY,
  double leftX,
  double leftY,
  Paint fillPaint,
  Paint strokePaint,
  double Function(double) sx,
  double Function(double) sy,
) {
  const tentacleCount = 7;
  const jointCount = 5;
  const length = 25.0;
  const wobbleSpeed = 2.0;
  const wobbleAmplitude = 5;
  const wobblePhase = 0.85;
  const tentaclePhaseOffset = 2.4;
  const baseWidths = [3.6, 2.6, 1.5, 0.65, 0.18];
  const tMin = 0.2;
  const tMax = 0.8;

  final baseXY = <double>[0.0, 0.0];
  for (var ti = 0; ti < tentacleCount; ti++) {
    final t = tentacleCount > 1
        ? tMin + (ti / (tentacleCount - 1)) * (tMax - tMin)
        : (tMin + tMax) / 2;
    _baseOnFaceCurve(
      t,
      faceCurveWorld,
      rightX,
      rightY,
      tipX,
      tipY,
      leftX,
      leftY,
      baseXY,
    );
    final baseX = baseXY[0];
    final baseY = baseXY[1];

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

void _paintTeethMouth(
  Canvas canvas,
  double timeSeconds,
  double forwardX,
  double forwardY,
  double perpX,
  double perpY,
  double halfW,
  double sizeScale,
  List<Offset>? faceCurveWorld,
  double rightX,
  double rightY,
  double tipX,
  double tipY,
  double leftX,
  double leftY,
  Paint fillPaint,
  Paint strokePaint,
  double Function(double) sx,
  double Function(double) sy,
) {
  const toothCount = 4;
  const jointCount = 4;
  const length = 25.0;
  const teethCurve = -1;
  const baseWidths = [2, 1.5, 1.2, .5, .2];
  const tMin = 0.3;
  const tMax = 0.7;
  const retractFrac = 0.14; // small retract only (fraction of tooth length)

  final baseXY = <double>[0.0, 0.0];
  final toothLen = length * sizeScale;
  // Retract only: base stays on face, animates slightly inward (no protrusion).
  final retractAmount =
      toothLen * retractFrac * (0.5 + 0.5 * sin(timeSeconds * 2.5));

  for (var ti = 0; ti < toothCount; ti++) {
    final t = toothCount > 1
        ? tMin + (ti / (toothCount - 1)) * (tMax - tMin)
        : (tMin + tMax) / 2;
    _baseOnFaceCurve(
      t,
      faceCurveWorld,
      rightX,
      rightY,
      tipX,
      tipY,
      leftX,
      leftY,
      baseXY,
    );
    var baseX = baseXY[0];
    var baseY = baseXY[1];
    baseX -= forwardX * retractAmount;
    baseY -= forwardY * retractAmount;

    final sideSign = toothCount > 1
        ? (ti - (toothCount - 1) / 2) / ((toothCount - 1) / 2)
        : 0.0;

    final segmentLen = toothLen / jointCount;

    var dirX = forwardX;
    var dirY = forwardY;
    var curX = baseX;
    var curY = baseY;
    final pts = <(double, double)>[];
    for (var j = 0; j < jointCount; j++) {
      final frac = (j + 1) / jointCount;
      final angle = teethCurve * sideSign * frac * frac;
      final c = cos(angle);
      final s = sin(angle);
      final nextDirX = dirX * c - dirY * s;
      final nextDirY = dirX * s + dirY * c;
      curX += nextDirX * segmentLen;
      curY += nextDirY * segmentLen;
      pts.add((curX, curY));
      dirX = nextDirX;
      dirY = nextDirY;
    }

    final spine = <(double, double)>[];
    spine.add((baseX, baseY));
    for (final p in pts) spine.add(p);

    final widths = baseWidths.map((w) => w * sizeScale).toList();

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

void _paintMandibleMouth(
  Canvas canvas,
  Creature creature,
  double centerX,
  double centerY,
  double zoom,
  double cameraX,
  double cameraY,
  double bodyScale,
  double headWidthWorld,
  double timeSeconds,
  double headX,
  double headY,
  double forwardX,
  double forwardY,
  double perpX,
  double perpY,
  double halfW,
  double sizeScale,
  double rightX,
  double rightY,
  double leftX,
  double leftY,
  Paint fillPaint,
  Paint strokePaint,
  double Function(double) sx,
  double Function(double) sy,
) {
  const mandibleLength = 42.0;
  const mandibleWidth = 3.0;
  const mandibleArcWidth = 0.65;
  const openAngleBase = -0.2;
  const openAngleAmp = 0.18;
  const openAngleSpeed = 1.5;
  const jigJagTeeth = 10;
  const jigJagAmplitudeBase = 4.0;
  const outerArcSegments = 3;
  const outerArcBulge = 2;

  final headA = atan2(forwardY, forwardX);
  final arcCenterX = (rightX + leftX) * 0.5;
  final arcCenterY = (rightY + leftY) * 0.5;
  final rX = arcCenterX + (rightX - arcCenterX) * mandibleArcWidth;
  final rY = arcCenterY + (rightY - arcCenterY) * mandibleArcWidth;
  final lX = arcCenterX + (leftX - arcCenterX) * mandibleArcWidth;
  final lY = arcCenterY + (leftY - arcCenterY) * mandibleArcWidth;

  final openAngle =
      openAngleBase + openAngleAmp * sin(timeSeconds * openAngleSpeed);

  final len = mandibleLength * sizeScale;
  final wid = mandibleWidth * sizeScale;

  for (var side = 0; side < 2; side++) {
    final isLeft = side == 0;
    final rootX = isLeft ? lX : rX;
    final rootY = isLeft ? lY : rY;
    final angle = headA + (isLeft ? openAngle : -openAngle);
    final dirX = cos(angle);
    final dirY = sin(angle);
    final perpDirX = -sin(angle);
    final perpDirY = cos(angle);
    final outerSign = isLeft ? 1.0 : -1.0;
    final tipX = rootX + dirX * len;
    final tipY = rootY + dirY * len;
    final rootInnerX = rootX - perpDirX * wid * outerSign;
    final rootInnerY = rootY - perpDirY * wid * outerSign;
    final tipInnerX = tipX - perpDirX * wid * outerSign;
    final tipInnerY = tipY - perpDirY * wid * outerSign;

    final mainArcPts = <Offset>[];
    for (var i = 0; i <= outerArcSegments; i++) {
      final frac = i / outerArcSegments;
      final bulgeFrac = sin(frac * pi);
      final offset = wid * (1.0 + outerArcBulge * bulgeFrac) * outerSign;
      final wx = rootX + dirX * len * frac + perpDirX * offset;
      final wy = rootY + dirY * len * frac + perpDirY * offset;
      mainArcPts.add(Offset(sx(wx), sy(wy)));
    }
    final rootOuterPt = mainArcPts.first;
    final tipOuterPt = mainArcPts.last;
    final rootInnerPt = Offset(sx(rootInnerX), sy(rootInnerY));
    final tipInnerPt = Offset(sx(tipInnerX), sy(tipInnerY));

    const blendFrac = 0.35;
    final outerArcPts = <Offset>[
      rootInnerPt,
      Offset(
        rootInnerPt.dx + blendFrac * (rootOuterPt.dx - rootInnerPt.dx),
        rootInnerPt.dy + blendFrac * (rootOuterPt.dy - rootInnerPt.dy),
      ),
      ...mainArcPts,
      Offset(
        tipOuterPt.dx + (1.0 - blendFrac) * (tipInnerPt.dx - tipOuterPt.dx),
        tipOuterPt.dy + (1.0 - blendFrac) * (tipInnerPt.dy - tipOuterPt.dy),
      ),
      tipInnerPt,
    ];

    final path = Path();
    path.moveTo(outerArcPts[0].dx, outerArcPts[0].dy);
    appendSmoothCurve(path, outerArcPts, 1.0 / 6.0, closed: false);
    appendJigJag(
      path,
      Offset(sx(tipInnerX), sy(tipInnerY)),
      Offset(sx(rootInnerX), sy(rootInnerY)),
      jigJagTeeth,
      jigJagAmplitudeBase * zoom * sizeScale,
    );
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }
}
