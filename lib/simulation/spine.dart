import 'dart:math' as math;

import 'angle_util.dart';
import 'spine_node.dart';
import 'vector.dart';

/// Spine simulation engine: head-driven kinematic resolve, angle constraints,
/// curve spread. Pure Dart; no rendering. Driven by segment count (e.g. from Creature).
class Spine {
  static const double minSegmentLength = 5.0;
  static const double maxSegmentLength = 30.0;
  static const int maxSegmentCount = 15;
  static const double minMaxJointAngleRad = 0.2;
  static const double maxMaxJointAngleRad = 0.6;

  final int segmentCount;
  final double segmentLength;
  final double maxJointAngleRad;

  final List<SpineNode> nodes = [];
  final List<double> _segmentAngles = [];

  Spine({
    int segmentCount = 1,
    double segmentLength = 10.0,
    double maxJointAngleRad = .5,
  }) : segmentCount = segmentCount.clamp(1, maxSegmentCount),
       segmentLength = segmentLength.clamp(minSegmentLength, maxSegmentLength),
       maxJointAngleRad = maxJointAngleRad.clamp(
         minMaxJointAngleRad,
         maxMaxJointAngleRad,
       ) {
    for (var i = 0; i <= this.segmentCount; i++) {
      nodes.add(SpineNode(i * segmentLength, 0));
    }
    for (var i = 0; i < this.segmentCount; i++) {
      _segmentAngles.add(0.0);
    }
  }

  int get headIndex => nodes.length - 1;

  /// Kinematic resolve: set head to target, propagate toward base, clamp bends,
  /// then spread curve. Uses [intendedTargetX/Y] for reverse check when provided.
  void resolve(
    double targetX,
    double targetY, {
    double? intendedTargetX,
    double? intendedTargetY,
  }) {
    final n = headIndex;
    final checkX = intendedTargetX ?? targetX;
    final checkY = intendedTargetY ?? targetY;
    if (n >= 1) {
      final neck = nodes[n - 1].position;
      final headDir = _segmentAngles[n - 1];
      final dx = checkX - neck.x;
      final dy = checkY - neck.y;
      if (dx * dx + dy * dy > 1e-12) {
        final turn = relativeAngleDiff(headDir, math.atan2(dy, dx));
        if (turn.abs() > maxJointAngleRad) {
          final cap = turn > 0 ? maxJointAngleRad : -maxJointAngleRad;
          final dir = simplifyAngle(headDir + cap);
          targetX = neck.x + segmentLength * math.cos(dir);
          targetY = neck.y + segmentLength * math.sin(dir);
        }
      }
    }
    nodes[n].position.x = targetX;
    nodes[n].position.y = targetY;

    for (var i = n - 1; i >= 0; i--) {
      final next = nodes[i + 1];
      final cur = nodes[i];
      final dx = next.position.x - cur.position.x;
      final dy = next.position.y - cur.position.y;
      final curAngle = math.atan2(dy, dx);
      final anchor = i > 0
          ? _segmentAngles[i - 1]
          : (n > 1 ? _segmentAngles[1] : curAngle);
      final newAngle = constrainAngle(curAngle, anchor, maxJointAngleRad);
      _segmentAngles[i] = newAngle;
      nodes[i].position.x =
          next.position.x - math.cos(newAngle) * segmentLength;
      nodes[i].position.y =
          next.position.y - math.sin(newAngle) * segmentLength;
    }

    // Clamp pass: follow the leader — adjust tail-side segment to head-side when over limit.
    for (var j = n - 2; j >= 0; j--) {
      final leader = _segmentAngles[j + 1];
      final bend = relativeAngleDiff(leader, _segmentAngles[j]);
      if (bend.abs() > maxJointAngleRad) {
        _segmentAngles[j] = constrainAngle(
          _segmentAngles[j],
          leader,
          maxJointAngleRad,
        );
      }
    }
    // Curve spread: when at the limit, ease toward midpoint of neighbors (blend per pass)
    const double atLimitThreshold = 0.7;
    const int spreadPasses = 4;
    const double spreadStep = 0.2;
    for (var pass = 0; pass < spreadPasses; pass++) {
      for (var j = 1; j < n - 1; j++) {
        final aPrev = _segmentAngles[j - 1];
        final aNext = _segmentAngles[j + 1];
        final aJ = _segmentAngles[j];
        final bendAtJ = relativeAngleDiff(aNext, aJ);
        if (bendAtJ.abs() < maxJointAngleRad * atLimitThreshold) continue;
        final mid = angleLerp(aPrev, aNext, 0.5);
        _segmentAngles[j] = angleLerp(aJ, mid, spreadStep);
      }
      for (var j = n - 2; j >= 0; j--) {
        final leader = _segmentAngles[j + 1];
        final bend = relativeAngleDiff(leader, _segmentAngles[j]);
        if (bend.abs() > maxJointAngleRad) {
          _segmentAngles[j] = constrainAngle(
            _segmentAngles[j],
            leader,
            maxJointAngleRad,
          );
        }
      }
    }
    // Rebuild positions from clamped angles (head fixed at target).
    for (var i = n - 1; i >= 0; i--) {
      final next = nodes[i + 1];
      nodes[i].position.x =
          next.position.x - math.cos(_segmentAngles[i]) * segmentLength;
      nodes[i].position.y =
          next.position.y - math.sin(_segmentAngles[i]) * segmentLength;
    }
  }

  /// Rotates the entire creature around its base (first node) by [angleRad].
  /// Updates both node positions and segment angles so state stays consistent.
  /// Use when neck is at bend limit to "make up the difference" with global turn.
  void rotateAroundBase(double angleRad) {
    if (nodes.isEmpty) return;
    final base = nodes[0].position;
    final c = math.cos(angleRad);
    final s = math.sin(angleRad);
    for (var i = 1; i < nodes.length; i++) {
      final p = nodes[i].position;
      final dx = p.x - base.x;
      final dy = p.y - base.y;
      p.x = base.x + dx * c - dy * s;
      p.y = base.y + dx * s + dy * c;
    }
    for (var i = 0; i < _segmentAngles.length; i++) {
      _segmentAngles[i] = simplifyAngle(_segmentAngles[i] + angleRad);
    }
  }

  /// Ordered positions for rendering: [base, ..., head].
  List<Vector2> get positions =>
      nodes.map((p) => Vector2(p.position.x, p.position.y)).toList();

  /// Segment directions for rendering (angle of segment i is from vertex i toward i+1).
  List<double> get segmentAngles => List<double>.from(_segmentAngles);
}
