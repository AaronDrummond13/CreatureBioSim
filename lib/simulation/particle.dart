import 'vector.dart';

/// A point mass in the simulation (vertebra / spine point).
class Particle {
  final Vector2 position = Vector2(0, 0);
  final Vector2 previousPosition = Vector2(0, 0);

  Particle(double x, double y) {
    position.x = x;
    position.y = y;
    previousPosition.x = x;
    previousPosition.y = y;
  }

  void syncPrevious() {
    previousPosition.x = position.x;
    previousPosition.y = position.y;
  }
}
