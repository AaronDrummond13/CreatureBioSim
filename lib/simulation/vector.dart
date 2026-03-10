/// 2D vector for simulation. Pure Dart, no Flutter.
class Vector2 {
  double x;
  double y;

  Vector2(this.x, this.y);

  Vector2 operator +(Vector2 other) => Vector2(x + other.x, y + other.y);
  Vector2 operator -(Vector2 other) => Vector2(x - other.x, y - other.y);
  Vector2 operator *(double s) => Vector2(x * s, y * s);
}
