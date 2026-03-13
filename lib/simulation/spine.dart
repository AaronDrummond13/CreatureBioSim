import 'dart:math' as math;

import 'package:creature_bio_sim/simulation/angle_util.dart';
import 'package:creature_bio_sim/simulation/spine_node.dart';
import 'package:creature_bio_sim/simulation/vector.dart';

/// Spine simulation engine: head-driven kinematic resolve with soft joint
/// constraints. Pure Dart; no rendering. Driven by segment count (e.g. from Creature).
class Spine {
  static const double defaultMoveSpeed = 4.0;
  static const double botPenalty = 0.9;
  static const double epicPenalty = 0.7;
  static const double mammothPenalty = 0.5;
  static const double defaultTurnAgility = 1;
  static const double minSegmentLength = 5.0;
  static const double maxSegmentLength = 30.0;
  static const int maxSegmentCount = 15;
  static const double minMaxJointAngleRad = 0.2;
  static const double maxMaxJointAngleRad = 0.6;
  static const double _kJointStiffness = 8.0;
  static const double _kCenteringForce = 0.04;
  static const double _kMaxAngleChangePerTick = 0.07;

  final int segmentCount;
  final double segmentLength;
  final double maxJointAngleRad;

  /// 0.0–1.0: fraction of maxJointAngleRad the head can turn per tick.
  /// 1.0 = full agility (player default), lower = sluggish turning (epics, mammoths).
  /// Applied as a lerp so turns are gradual rather than hard-capped.
  final double turnAgility;

  final List<SpineNode> nodes = [];
  final List<double> _segmentAngles = [];
  final List<double> _prevAngles = [];

  Spine({
    int segmentCount = 1,
    double segmentLength = 12.0,
    double maxJointAngleRad = 0.4,
    double turnAgility = defaultTurnAgility,
  }) : segmentCount = segmentCount.clamp(1, maxSegmentCount),
       segmentLength = segmentLength.clamp(minSegmentLength, maxSegmentLength),
       maxJointAngleRad = maxJointAngleRad.clamp(
         minMaxJointAngleRad,
         maxMaxJointAngleRad,
       ),
       turnAgility = turnAgility.clamp(0.05, 1.0) {
    for (var i = 0; i <= this.segmentCount; i++) {
      nodes.add(SpineNode(i * segmentLength, 0));
    }
    for (var i = 0; i < this.segmentCount; i++) {
      _segmentAngles.add(0.0);
      _prevAngles.add(0.0);
    }
  }

  int get headIndex => nodes.length - 1;

  /// Kinematic resolve: set head to target, propagate toward base, clamp bends,
  /// then spread curve.
  ///
  /// When [speed] > 0 (moving): two-phase advance+steer. The head always
  /// advances at [speed] along its current heading while gradually steering
  /// toward [targetX, targetY]. Within [speed] distance of the target the
  /// head moves directly to it for precision arrival.
  ///
  /// When [speed] == 0 (stationary): the head stays in place, rotating toward
  /// [intendedTargetX/Y] (or target) subject to turn-rate capping.
  void resolve(
    double targetX,
    double targetY, {
    double speed = 0.0,
    double? intendedTargetX,
    double? intendedTargetY,
  }) {
    final n = headIndex;

    if (speed > 0 && n >= 1) {
      final head = nodes[n].position;
      final headDir = _segmentAngles[n - 1];
      final dtx = targetX - head.x;
      final dty = targetY - head.y;
      final dist = math.sqrt(dtx * dtx + dty * dty);

      if (dist > speed) {
        final desiredDir = math.atan2(dty, dtx);
        final turn = relativeAngleDiff(headDir, desiredDir);
        final maxTurn = maxJointAngleRad * turnAgility;
        final steeredDir = turn.abs() <= maxTurn
            ? desiredDir
            : simplifyAngle(headDir + (turn > 0 ? maxTurn : -maxTurn));
        targetX = head.x + math.cos(steeredDir) * speed;
        targetY = head.y + math.sin(steeredDir) * speed;
      }
      // else dist <= speed: move directly to target (precision arrival)
    } else if (n >= 1) {
      final checkX = intendedTargetX ?? targetX;
      final checkY = intendedTargetY ?? targetY;
      final neck = nodes[n - 1].position;
      final headDir = _segmentAngles[n - 1];
      final dx = checkX - neck.x;
      final dy = checkY - neck.y;
      if (dx * dx + dy * dy > 1e-12) {
        final turn = relativeAngleDiff(headDir, math.atan2(dy, dx));
        final effectiveMaxTurn = maxJointAngleRad * turnAgility;
        if (turn.abs() > effectiveMaxTurn) {
          final cap = turn > 0 ? effectiveMaxTurn : -effectiveMaxTurn;
          final dir = simplifyAngle(headDir + cap);
          targetX = neck.x + segmentLength * math.cos(dir);
          targetY = neck.y + segmentLength * math.sin(dir);
        }
      }
    }

    nodes[n].position.x = targetX;
    nodes[n].position.y = targetY;

    // Snapshot angles so every anchor in the backward pass is consistently
    // from the previous frame (avoids tail-whip from cascading updates).
    for (var i = 0; i < n; i++) {
      _prevAngles[i] = _segmentAngles[i];
    }

    // Backward pass (head→tail): soft-constrain against prev-frame tail-side neighbour.
    for (var i = n - 1; i >= 0; i--) {
      final next = nodes[i + 1];
      final dx = next.position.x - nodes[i].position.x;
      final dy = next.position.y - nodes[i].position.y;
      final curAngle = math.atan2(dy, dx);
      final anchor = i > 0
          ? _prevAngles[i - 1]
          : (n > 1 ? _prevAngles[1] : curAngle);
      _segmentAngles[i] = softConstrainAngle(
        curAngle,
        anchor,
        maxJointAngleRad,
        _kJointStiffness,
      );
      nodes[i].position.x =
          next.position.x - math.cos(_segmentAngles[i]) * segmentLength;
      nodes[i].position.y =
          next.position.y - math.sin(_segmentAngles[i]) * segmentLength;
    }

    // Forward smoothing (tail→head): soft-constrain against head-side neighbour,
    // then gently center toward it to unravel hooks.
    for (var i = 0; i < n - 1; i++) {
      _segmentAngles[i] = softConstrainAngle(
        _segmentAngles[i],
        _segmentAngles[i + 1],
        maxJointAngleRad,
        _kJointStiffness,
      );
      _segmentAngles[i] = angleLerp(
        _segmentAngles[i],
        _segmentAngles[i + 1],
        _kCenteringForce,
      );
    }

    // Rate-limit body segments (not head): cap per-tick angle change to
    // prevent explosive unwinding. Head (n-1) is exempt — turnAgility governs it.
    for (var i = 0; i < n - 1; i++) {
      final delta = relativeAngleDiff(_prevAngles[i], _segmentAngles[i]);
      if (delta.abs() > _kMaxAngleChangePerTick) {
        _segmentAngles[i] = angleLerp(
          _prevAngles[i],
          _segmentAngles[i],
          _kMaxAngleChangePerTick / delta.abs(),
        );
      }
    }

    // Rebuild positions from final angles (head stays at target).
    for (var i = n - 1; i >= 0; i--) {
      nodes[i].position.x =
          nodes[i + 1].position.x - math.cos(_segmentAngles[i]) * segmentLength;
      nodes[i].position.y =
          nodes[i + 1].position.y - math.sin(_segmentAngles[i]) * segmentLength;
    }
  }

  /// Ordered positions for rendering: [base, ..., head].
  List<Vector2> get positions =>
      nodes.map((p) => Vector2(p.position.x, p.position.y)).toList();

  /// Segment directions for rendering (angle of segment i is from vertex i toward i+1).
  List<double> get segmentAngles => List<double>.from(_segmentAngles);
}
