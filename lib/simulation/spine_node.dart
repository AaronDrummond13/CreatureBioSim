import 'package:bioism/simulation/vector.dart';

/// A point on the spine (base, joint, or head). Position is updated by [Spine] via head-driven kinematic resolve.
class SpineNode {
  final Vector2 position = Vector2(0, 0);

  SpineNode(double x, double y) {
    position.x = x;
    position.y = y;
  }
}
