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

  // Arc along head front: middle forward, sides at head edge so side teeth aren't too far forward.
  const sideForward = 0.0;
  const bulgeForward = 0.6;
  final rightX = headX - perpX * halfW + forwardX * halfW * sideForward;
  final rightY = headY - perpY * halfW + forwardY * halfW * sideForward;
  final leftX = headX + perpX * halfW + forwardX * halfW * sideForward;
  final leftY = headY + perpY * halfW + forwardY * halfW * sideForward;
  final bulgeX = headX + forwardX * halfW * (1.0 + bulgeForward);
  final bulgeY = headY + forwardY * halfW * (1.0 + bulgeForward);

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
      bulgeX,
      bulgeY,
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
      bulgeX,
      bulgeY,
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

void _paintTentacleMouth(
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
  double bulgeX,
  double bulgeY,
  Paint fillPaint,
  Paint strokePaint,
  double Function(double) sx,
  double Function(double) sy,
) {
  const tentacleCount = 5;
  const jointCount = 4;
  const length = 25.0;
  const tentacleArcWidth = 0.9;
  const wobbleSpeed = 2.0;
  const wobbleAmplitude = 4.5;
  const wobblePhase = 0.85;
  const tentaclePhaseOffset = 2.4;
  const baseWidths = [3.6, 2.6, 1.5, 0.65, 0.18];

  final arcCenterX = (rightX + leftX) * 0.5;
  final arcCenterY = (rightY + leftY) * 0.5;
  final rX = arcCenterX + (rightX - arcCenterX) * tentacleArcWidth;
  final rY = arcCenterY + (rightY - arcCenterY) * tentacleArcWidth;
  final lX = arcCenterX + (leftX - arcCenterX) * tentacleArcWidth;
  final lY = arcCenterY + (leftY - arcCenterY) * tentacleArcWidth;

  for (var ti = 0; ti < tentacleCount; ti++) {
    final t = tentacleCount > 1 ? ti / (tentacleCount - 1) : 0.5;
    final oneMinusT = 1.0 - t;
    final baseX =
        oneMinusT * oneMinusT * rX + 2 * oneMinusT * t * bulgeX + t * t * lX;
    final baseY =
        oneMinusT * oneMinusT * rY + 2 * oneMinusT * t * bulgeY + t * t * lY;

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
  double bulgeX,
  double bulgeY,
  Paint fillPaint,
  Paint strokePaint,
  double Function(double) sx,
  double Function(double) sy,
) {
  const toothCount = 5;
  const jointCount = 4;
  const length = 25.0;

  /// Joint-angle curve: 0 = straight. >0 = tips bend away from centre, <0 = toward centre. Furthest joint bends most.
  const teethCurve = 0.0;
  const teethArcWidth = 0.9;
  const baseWidths = [3, 3, 2, 1, .5];

  final arcCenterX = (rightX + leftX) * 0.5;
  final arcCenterY = (rightY + leftY) * 0.5;
  final rX = arcCenterX + (rightX - arcCenterX) * teethArcWidth;
  final rY = arcCenterY + (rightY - arcCenterY) * teethArcWidth;
  final lX = arcCenterX + (leftX - arcCenterX) * teethArcWidth;
  final lY = arcCenterY + (leftY - arcCenterY) * teethArcWidth;

  final protrude = 0.25 + 0.125 * (1 + sin(timeSeconds * 2.5));

  for (var ti = 0; ti < toothCount; ti++) {
    final t = toothCount > 1 ? ti / (toothCount - 1) : 0.5;
    final oneMinusT = 1.0 - t;
    var baseX =
        oneMinusT * oneMinusT * rX + 2 * oneMinusT * t * bulgeX + t * t * lX;
    var baseY =
        oneMinusT * oneMinusT * rY + 2 * oneMinusT * t * bulgeY + t * t * lY;

    final sideSign = toothCount > 1
        ? (ti - (toothCount - 1) / 2) / ((toothCount - 1) / 2)
        : 0.0;

    final toothLen = length * sizeScale;
    final segmentLen = toothLen / jointCount;

    final protrudeOffset = (protrude - 0.5) * toothLen;
    baseX += forwardX * protrudeOffset;
    baseY += forwardY * protrudeOffset;

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
