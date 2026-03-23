import 'dart:math' show sqrt;

import 'package:bioism/creature.dart';
import 'package:bioism/render/creature_painter.dart' show CreaturePainter;
import 'package:bioism/simulation/spine.dart';

double _scaleForEntity({bool isEpic = false, bool isBaby = false}) {
  if (isEpic) return CreaturePainter.kEpicRenderScale;
  if (isBaby) return CreaturePainter.kBabyRenderScale;
  return 1.0;
}

/// Eater's head collision radius: widest head segment * scale * mouthFrac.
double eaterHeadRadius(
  Creature creature, {
  bool isEpic = false,
  bool isBaby = false,
  double mouthFrac = 0.8,
}) {
  final scale = _scaleForEntity(isEpic: isEpic, isBaby: isBaby);
  final raw = creature.segmentWidths.isNotEmpty
      ? creature.segmentWidths.last
      : 15.0;
  return raw * scale * mouthFrac;
}

/// Check if point (px, py) overlaps any segment of a target creature's body.
/// [attackRadius] is the eater's head collision radius (from [eaterHeadRadius]).
/// Returns true on first hit.
bool pointHitsCreature(
  double px,
  double py,
  Spine targetSpine,
  Creature targetCreature, {
  double attackRadius = 0.0,
  bool targetIsEpic = false,
  bool targetIsBaby = false,
}) {
  final positions = targetSpine.positions;
  if (positions.length < 2) return false;
  final scale = _scaleForEntity(isEpic: targetIsEpic, isBaby: targetIsBaby);
  final head = positions.last;

  for (var i = 0; i < positions.length - 1; i++) {
    final ax = positions[i].x;
    final ay = positions[i].y;
    final bx = positions[i + 1].x;
    final by = positions[i + 1].y;

    // Scale segment endpoints relative to head.
    final sax = head.x + (ax - head.x) * scale;
    final say = head.y + (ay - head.y) * scale;
    final sbx = head.x + (bx - head.x) * scale;
    final sby = head.y + (by - head.y) * scale;

    final mx = (sax + sbx) * 0.5;
    final my = (say + sby) * 0.5;
    final segWidth = targetCreature.widthAtVertex(i) * scale;
    final hitR = segWidth + attackRadius;
    final ddx = px - mx;
    final ddy = py - my;
    if (ddx * ddx + ddy * ddy <= hitR * hitR) return true;
  }
  return false;
}

/// Squared distance from point (px, py) to the nearest segment of a creature,
/// accounting for segment width. Returns (adjustedDistSq, segmentIndex).
/// adjustedDistSq = max(0, rawDist - segWidth)^2 so 0 means inside the body.
(double, int) nearestSegmentDistSq(
  double px,
  double py,
  Spine targetSpine,
  Creature targetCreature, {
  bool targetIsEpic = false,
  bool targetIsBaby = false,
}) {
  final positions = targetSpine.positions;
  if (positions.length < 2) return (double.infinity, 0);
  final scale = _scaleForEntity(isEpic: targetIsEpic, isBaby: targetIsBaby);
  final head = positions.last;
  var bestD2 = double.infinity;
  var bestSeg = 0;

  for (var i = 0; i < positions.length - 1; i++) {
    final ax = positions[i].x;
    final ay = positions[i].y;
    final bx = positions[i + 1].x;
    final by = positions[i + 1].y;

    final sax = head.x + (ax - head.x) * scale;
    final say = head.y + (ay - head.y) * scale;
    final sbx = head.x + (bx - head.x) * scale;
    final sby = head.y + (by - head.y) * scale;

    final mx = (sax + sbx) * 0.5;
    final my = (say + sby) * 0.5;
    final segWidth = targetCreature.widthAtVertex(i) * scale;
    final ddx = px - mx;
    final ddy = py - my;
    final d = ddx * ddx + ddy * ddy;
    final rd = d > 0 ? sqrt(d) - segWidth : -segWidth;
    final adj = rd > 0 ? rd * rd : 0.0;
    if (adj < bestD2) {
      bestD2 = adj;
      bestSeg = i;
    }
  }
  return (bestD2, bestSeg);
}
