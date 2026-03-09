import 'dart:math' show cos, pi, sin;

import 'package:flutter/material.dart';

import 'package:creature_bio_sim/creature.dart';
import 'package:creature_bio_sim/simulation/angle_util.dart';
import 'package:creature_bio_sim/simulation/vector.dart';
import 'package:creature_bio_sim/render/render_utils.dart';

/// Shared tail (caudal) fin rendering. Use for full creature paint or editor thumbnails.
/// [positions] and [segmentAngles] from spine (world space). [centerX], [centerY], [zoom], [cameraX], [cameraY] define view transform.
/// [bodyScale] and [widthAt] match CreaturePainter semantics (e.g. 1.0 or baby/epic scale).
void paintTailFin(
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
  double Function(int i) widthAt, {
  Color? overrideFinColor,
}) {
  if (creature.tail == null) return;
  final tailFinType = creature.tail!.type;
  double sx(double wx) => centerX + (wx - cameraX) * zoom;
  double sy(double wy) => centerY + (wy - cameraY) * zoom;

  final tailX = positions[0].x;
  final tailY = positions[0].y;
  final tailA = segmentAngles[0];
  final tailBend = segmentAngles.length >= 2
      ? relativeAngleDiff(segmentAngles[1], segmentAngles[0])
      : 0.0;
  const maxAngle = 0.5;
  var sumAbsBend = 0.0;
  var count = 0;
  for (var i = 1; i < segmentAngles.length; i++) {
    sumAbsBend += relativeAngleDiff(segmentAngles[i], segmentAngles[i - 1]).abs();
    count++;
  }
  const caudalFinBaseFrac = 0.2;
  final avgBend = count > 0 ? sumAbsBend / count : 0.0;
  final ratio = (avgBend / maxAngle).clamp(0.0, 1.0);
  final innerScale = caudalFinBaseFrac + (1.0 - caudalFinBaseFrac) * ratio;
  final outerScale = caudalFinBaseFrac;
  final vws = creature.vertexWidths
      .map((w) => w.clamp(Creature.minVertexWidth, Creature.maxVertexWidth))
      .toList();
  final derivedRoot = vws.isEmpty ? widthAt(0) / bodyScale : vws.reduce((a, b) => a < b ? a : b);
  final derivedMax = vws.isEmpty ? derivedRoot / 2 : vws.reduce((a, b) => a > b ? a : b) / 2;
  final derivedLen = widthAt(0) * 3.0;

  final tailCfg = creature.tail!;
  final rootW = (tailCfg.rootWidth ?? derivedRoot) * bodyScale;
  final maxW = (tailCfg.maxWidth ?? derivedMax) * bodyScale;
  final len = tailCfg.length != null ? tailCfg.length! * bodyScale : derivedLen;

  final back = tailA + pi;
  final t = (maxAngle > 1e-6)
      ? (tailBend / maxAngle * 0.5 + 0.5).clamp(0.0, 1.0)
      : 0.5;
  final leftScale = outerScale + (innerScale - outerScale) * t;
  final rightScale = outerScale + (innerScale - outerScale) * (1.0 - t);
  final rootScale = caudalFinBaseFrac + (1.0 - caudalFinBaseFrac) * ratio;
  final rootHalfW = rootW * rootScale;
  final lo = rootHalfW < maxW ? rootHalfW : maxW;
  final hi = rootHalfW > maxW ? rootHalfW : maxW;
  final leftMax = (maxW * leftScale).clamp(lo, hi);
  final rightMax = (maxW * rightScale).clamp(lo, hi);

  final leftDirX = sin(tailA);
  final leftDirY = -cos(tailA);
  final rightDirX = -sin(tailA);
  final rightDirY = cos(tailA);
  final leftTailX = tailX + leftDirX * rootHalfW;
  final leftTailY = tailY + leftDirY * rootHalfW;
  final rightTailX = tailX + rightDirX * rootHalfW;
  final rightTailY = tailY + rightDirY * rootHalfW;
  final tipCx = tailX + cos(back) * len;
  final tipCy = tailY + sin(back) * len;

  final pts = <Offset>[];
  pts.add(Offset(sx(leftTailX), sy(leftTailY)));
  if (tailFinType == CaudalFinType.rounded) {
    pts.add(Offset(
      sx(leftTailX + cos(back) * len * 0.3 + leftDirX * leftMax * 0.8),
      sy(leftTailY + sin(back) * len * 0.3 + leftDirY * leftMax * 0.8),
    ));
  }
  if (tailFinType != CaudalFinType.pointed) {
    pts.add(Offset(
      sx(leftTailX + cos(back) * len * 0.7 + leftDirX * leftMax),
      sy(leftTailY + sin(back) * len * 0.7 + leftDirY * leftMax),
    ));
  }
  if (tailFinType == CaudalFinType.lunate) {
    pts.add(Offset(
      sx(leftTailX + cos(back) * len * 0.6 + leftDirX * leftMax * 0.7),
      sy(leftTailY + sin(back) * len * 0.6 + leftDirY * leftMax * 0.7),
    ));
  }
  if (tailFinType == CaudalFinType.pointed || tailFinType == CaudalFinType.rhomboid) {
    pts.add(Offset(sx(tipCx), sy(tipCy)));
  } else if (tailFinType == CaudalFinType.rounded) {
    pts.add(Offset(sx(tailX + cos(back) * len * 0.9), sy(tailY + sin(back) * len * 0.9)));
  } else if (tailFinType == CaudalFinType.forked) {
    pts.add(Offset(sx(tailX + cos(back) * len * 0.35), sy(tailY + sin(back) * len * 0.35)));
  } else if (tailFinType == CaudalFinType.lunate) {
    pts.add(Offset(sx(tailX + cos(back) * len * 0.45), sy(tailY + sin(back) * len * 0.45)));
  } else if (tailFinType == CaudalFinType.emarginate) {
    pts.add(Offset(sx(tailX + cos(back) * len * 0.65), sy(tailY + sin(back) * len * 0.65)));
  } else if (tailFinType == CaudalFinType.truncate) {
    pts.add(Offset(sx(tailX + cos(back) * len * 0.8), sy(tailY + sin(back) * len * 0.8)));
  }
  if (tailFinType == CaudalFinType.lunate) {
    pts.add(Offset(
      sx(rightTailX + cos(back) * len * 0.6 + rightDirX * rightMax * 0.7),
      sy(rightTailY + sin(back) * len * 0.6 + rightDirY * rightMax * 0.7),
    ));
  }
  if (tailFinType != CaudalFinType.pointed) {
    pts.add(Offset(
      sx(rightTailX + cos(back) * len * 0.7 + rightDirX * rightMax),
      sy(rightTailY + sin(back) * len * 0.7 + rightDirY * rightMax),
    ));
  }
  if (tailFinType == CaudalFinType.rounded) {
    pts.add(Offset(
      sx(rightTailX + cos(back) * len * 0.3 + rightDirX * rightMax * 0.8),
      sy(rightTailY + sin(back) * len * 0.3 + rightDirY * rightMax * 0.8),
    ));
  }
  pts.add(Offset(sx(rightTailX), sy(rightTailY)));

  final path = Path();
  path.moveTo(pts[0].dx, pts[0].dy);
  appendSmoothCurve(path, pts, 1.0 / 6.0);
  path.close();
  final finColor = overrideFinColor ??
      (creature.finColor != null
          ? Color(creature.finColor!)
          : Color.lerp(bodyColor, Colors.white, 0.12)!);
  final finPaint = Paint()..color = finColor..style = PaintingStyle.fill;
  final strokePaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = (2.0 * zoom).clamp(1.0, 2.0);
  canvas.drawPath(path, finPaint);
  canvas.drawPath(path, strokePaint);
}
