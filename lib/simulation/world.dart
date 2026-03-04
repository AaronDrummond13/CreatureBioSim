import 'dart:math' as math;

import 'angle_util.dart';
import 'particle.dart';
import 'vector.dart';

/// Spine chain using inspiration-style kinematic resolve: head is set, then
/// each segment's angle is constrained relative to the previous (no Verlet,
/// no impulses), so bend distributes along the chain and there's no explosion.
class SimulationWorld {
  // --- Spine tuning (adjust here) ---
  static const int _segmentCount = 10;
  static const double _segmentLength = 40.0;

  /// Max bend per joint (radians). Larger = looser; smaller = stiffer. ~1.2 ≈ 69°, ~1.6 ≈ 92°.
  static const double _maxJointAngleRad = 1.0;
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
      final anchor = i > 0 ? _segmentAngles[i - 1] : _segmentAngles[1];
      final newAngle = constrainAngle(curAngle, anchor, _maxJointAngleRad);
      _segmentAngles[i] = newAngle;
      particles[i].position.x =
          next.position.x - math.cos(newAngle) * _segmentLength;
      particles[i].position.y =
          next.position.y - math.sin(newAngle) * _segmentLength;
    }

    // Clamp pass: ensure each joint bend is truly <= max (fixes drift from
    // using previous-frame anchor). Propagate base→head then rebuild positions.
    for (var j = 0; j < n - 1; j++) {
      final bend = relativeAngleDiff(_segmentAngles[j + 1], _segmentAngles[j]);
      if (bend.abs() > _maxJointAngleRad) {
        _segmentAngles[j + 1] = constrainAngle(
          _segmentAngles[j + 1],
          _segmentAngles[j],
          _maxJointAngleRad,
        );
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
