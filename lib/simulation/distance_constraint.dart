import 'constraint.dart';
import 'particle.dart';
import 'vector.dart';

/// Keeps two particles at a fixed distance.
class DistanceConstraint implements Constraint {
  final Particle a;
  final Particle b;
  final double restLength;

  DistanceConstraint(this.a, this.b, this.restLength);

  @override
  void solve() {
    final dx = b.position.x - a.position.x;
    final dy = b.position.y - a.position.y;
    final len = Vector2.hypot(dx, dy);
    if (len == 0) return;
    final diff = (restLength - len) / len;
    final half = diff * 0.5;
    a.position.x -= dx * half;
    a.position.y -= dy * half;
    b.position.x += dx * half;
    b.position.y += dy * half;
  }
}
