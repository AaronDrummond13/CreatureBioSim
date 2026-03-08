import 'dart:math' show sqrt;

/// 2D vector for simulation. Pure Dart, no Flutter.
class Vector2 {
  double x;
  double y;

  Vector2(this.x, this.y);

  Vector2 operator +(Vector2 other) => Vector2(x + other.x, y + other.y);
  Vector2 operator -(Vector2 other) => Vector2(x - other.x, y - other.y);
  Vector2 operator *(double s) => Vector2(x * s, y * s);

  double get length => hypot(x, y);
  double get lengthSq => x * x + y * y;

  Vector2 normalized() {
    final len = length;
    if (len == 0) return Vector2(1, 0);
    return Vector2(x / len, y / len);
  }

  Vector2 copy() => Vector2(x, y);

  static double hypot(double a, double b) {
    a = a.abs();
    b = b.abs();
    if (a > b) {
      final t = b / a;
      return a * sqrt(1 + t * t);
    }
    if (b > 0) {
      final t = a / b;
      return b * sqrt(1 + t * t);
    }
    return 0;
  }
}
