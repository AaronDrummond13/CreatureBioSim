import 'vector.dart';

/// A point mass in the simulation (vertebra / spine point).
/// Position is updated by [Spine] via head-driven kinematic resolve.
class Particle {
  final Vector2 position = Vector2(0, 0);

  Particle(double x, double y) {
    position.x = x;
    position.y = y;
  }
}
