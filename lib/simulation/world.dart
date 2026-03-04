import 'dart:math' as math;

import 'angle_util.dart';
import 'particle.dart';
import 'vector.dart';

/// Spine chain using inspiration-style kinematic resolve: head is set, then
/// each segment's angle is constrained relative to the previous (no Verlet,
/// no impulses), so bend distributes along the chain and there's no explosion.
class SimulationWorld {
  // --- Spine tuning (adjust here) ---
  static const int _segmentCount = 20;
  static const double _segmentLength = 10.0;

  /// Max bend per joint (radians). Larger = looser; smaller = stiffer. ~1.2 ≈ 69°, ~1.6 ≈ 92°.
  static const double _maxJointAngleRad = 0.4;
  // ----------------------------------

  final List<Particle> particles = [];
  final List<double> _segmentAngles = [];

  int get headIndex => particles.length - 1;
  int get segmentCount => _segmentCount;

  SimulationWorld() {
    for (var i = 0; i <= _segmentCount; i++) {
      particles.add(Particle(i * _segmentLength, 0));
    }
    for (var i = 0; i < _segmentCount; i++) {
      _segmentAngles.add(0.0);
    }
  }

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
      final newAngle = constrainAngle(curAngle, anchor, _maxJointAngleRad);
      _segmentAngles[i] = newAngle;
      particles[i].position.x =
          next.position.x - math.cos(newAngle) * _segmentLength;
      particles[i].position.y =
          next.position.y - math.sin(newAngle) * _segmentLength;
    }

    // Clamp pass: follow the leader — adjust tail-side segment to head-side when over limit.
    for (var j = n - 2; j >= 0; j--) {
      final leader = _segmentAngles[j + 1];
      final bend = relativeAngleDiff(leader, _segmentAngles[j]);
      if (bend.abs() > _maxJointAngleRad) {
        _segmentAngles[j] = constrainAngle(
          _segmentAngles[j],
          leader,
          _maxJointAngleRad,
        );
      }
    }
    // Curve spread: when at the limit, ease toward midpoint of neighbors (blend per pass)
    // so the change is smooth; trigger only when really at limit; re-clamp after each pass.
    const double atLimitThreshold = 0.75;
    const int spreadPasses = 2;
    const double spreadStep =
        0.1; // blend this much toward midpoint per pass (smoother)
    for (var pass = 0; pass < spreadPasses; pass++) {
      for (var j = 1; j < n - 1; j++) {
        final aPrev = _segmentAngles[j - 1];
        final aNext = _segmentAngles[j + 1];
        final aJ = _segmentAngles[j];
        final bendAtJ = relativeAngleDiff(aNext, aJ);
        if (bendAtJ.abs() < _maxJointAngleRad * atLimitThreshold) continue;
        final mid = angleLerp(aPrev, aNext, 0.5);
        _segmentAngles[j] = angleLerp(aJ, mid, spreadStep);
      }
      for (var j = n - 2; j >= 0; j--) {
        final leader = _segmentAngles[j + 1];
        final bend = relativeAngleDiff(leader, _segmentAngles[j]);
        if (bend.abs() > _maxJointAngleRad) {
          _segmentAngles[j] = constrainAngle(
            _segmentAngles[j],
            leader,
            _maxJointAngleRad,
          );
        }
      }
    }
    // Rebuild positions from clamped angles (head fixed at target).
    for (var i = n - 1; i >= 0; i--) {
      final next = particles[i + 1];
      particles[i].position.x =
          next.position.x - math.cos(_segmentAngles[i]) * _segmentLength;
      particles[i].position.y =
          next.position.y - math.sin(_segmentAngles[i]) * _segmentLength;
    }
  }

  /// Ordered positions for rendering: [base, ..., head].
  List<Vector2> get positions =>
      particles.map((p) => Vector2(p.position.x, p.position.y)).toList();

  /// Segment directions for rendering (angle of segment i is from vertex i toward i+1).
  /// Length = segmentCount; for vertex i use index min(i, segmentCount - 1).
  List<double> get segmentAngles => List<double>.from(_segmentAngles);
}
