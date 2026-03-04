import 'dart:math' as math;

import 'angle_util.dart';
import 'particle.dart';
import 'vector.dart';

/// Spine simulation engine: head-driven kinematic resolve, angle constraints,
/// curve spread. Pure Dart; no rendering. Driven by segment count (e.g. from Creature).
class Spine {
  final int segmentCount;
  final double segmentLength;
  final double maxJointAngleRad;

  final List<Particle> particles = [];
  final List<double> _segmentAngles = [];

  Spine({
    this.segmentCount = 20,
    this.segmentLength = 10.0,
    this.maxJointAngleRad = 0.4,
  }) {
    for (var i = 0; i <= segmentCount; i++) {
      particles.add(Particle(i * segmentLength, 0));
    }
    for (var i = 0; i < segmentCount; i++) {
      _segmentAngles.add(0.0);
    }
  }

  int get headIndex => particles.length - 1;

  /// Kinematic resolve: set head to target, propagate toward base, then
  /// clamp so every consecutive segment pair has bend <= maxJointAngle.
  void resolve(double targetX, double targetY) {
    final n = headIndex;
    particles[n].position.x = targetX;
    particles[n].position.y = targetY;

    for (var i = n - 1; i >= 0; i--) {
      final next = particles[i + 1];
      final cur = particles[i];
      final dx = next.position.x - cur.position.x;
      final dy = next.position.y - cur.position.y;
      final curAngle = math.atan2(dy, dx);
      final anchor = i > 0
          ? _segmentAngles[i - 1]
          : (n > 1 ? _segmentAngles[1] : curAngle);
      final newAngle = constrainAngle(curAngle, anchor, maxJointAngleRad);
      _segmentAngles[i] = newAngle;
      particles[i].position.x =
          next.position.x - math.cos(newAngle) * segmentLength;
      particles[i].position.y =
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
    const double atLimitThreshold = 0.75;
    const int spreadPasses = 2;
    const double spreadStep = 0.1;
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
      final next = particles[i + 1];
      particles[i].position.x =
          next.position.x - math.cos(_segmentAngles[i]) * segmentLength;
      particles[i].position.y =
          next.position.y - math.sin(_segmentAngles[i]) * segmentLength;
    }
  }

  /// Ordered positions for rendering: [base, ..., head].
  List<Vector2> get positions =>
      particles.map((p) => Vector2(p.position.x, p.position.y)).toList();

  /// Segment directions for rendering (angle of segment i is from vertex i toward i+1).
  List<double> get segmentAngles => List<double>.from(_segmentAngles);
}
