import 'dart:math' as math;

import 'constraint.dart';
import 'particle.dart';
import 'vector.dart';

/// Limits the bend angle at a joint B between segments A-B and B-C.
/// Angle is the turn from A->B to B->C; clamped to [-maxAngle, maxAngle].
class AngleConstraint implements Constraint {
  final Particle a;
  final Particle b;
  final Particle c;
  final double maxAngleRad;

  AngleConstraint(this.a, this.b, this.c, this.maxAngleRad);

  @override
  void solve() {
    final ax = a.position.x - b.position.x;
    final ay = a.position.y - b.position.y;
    final cx = c.position.x - b.position.x;
    final cy = c.position.y - b.position.y;
    final len1 = Vector2.hypot(ax, ay);
    final len2 = Vector2.hypot(cx, cy);
    if (len1 == 0 || len2 == 0) return;

    // Angle from A->B to C->B (turn at B). atan2(cross, dot) gives signed angle.
    final dot = -ax * cx - ay * cy;
    final cross = -ax * cy + ay * cx;
    var angle = math.atan2(cross, dot);

    if (angle > maxAngleRad) {
      angle = maxAngleRad;
    } else if (angle < -maxAngleRad) {
      angle = -maxAngleRad;
    } else {
      return;
    }

    // Rotate A around B so the angle becomes exactly angle.
    // Current: A-B points (ax,ay), we want C-B to make angle with (B-A).
    // Target direction from B toward A: rotate (C-B) by -angle and flip => (B-A)_target.
    // B-A_target = -rotate(C-B, -angle) = rotate(C-B, angle). Normalize and scale by len1.
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    final tx = cx * cosA - cy * sinA;
    final ty = cx * sinA + cy * cosA;
    final tLen = Vector2.hypot(tx, ty);
    if (tLen == 0) return;
    final scale = len1 / tLen;
    a.position.x = b.position.x - tx * scale;
    a.position.y = b.position.y - ty * scale;
  }
}
