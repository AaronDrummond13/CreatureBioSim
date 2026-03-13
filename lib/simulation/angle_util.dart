import 'dart:math' as math;

/// Angle helpers matching inspiration/Util.pde: constrain angle to [anchor ± constraint].
const double _twoPi = 2.0 * math.pi;

double simplifyAngle(double angle) {
  while (angle >= _twoPi) angle -= _twoPi;
  while (angle < 0) angle += _twoPi;
  return angle;
}

/// Signed difference in radians to turn from angle to anchor (handles 0/2π wrap).
double relativeAngleDiff(double angle, double anchor) {
  angle = simplifyAngle(angle + math.pi - anchor);
  anchor = math.pi;
  return anchor - angle;
}

/// Clamp angle to [anchor - constraint, anchor + constraint].
double constrainAngle(double angle, double anchor, double constraint) {
  final diff = relativeAngleDiff(angle, anchor);
  if (diff.abs() <= constraint) return simplifyAngle(angle);
  if (diff > constraint) return simplifyAngle(anchor - constraint);
  return simplifyAngle(anchor + constraint);
}

/// Soft-clamp angle toward [anchor ± limit] with linear spring resistance.
/// Within [limit]: no correction. Beyond: linearly ramps to full clamp over
/// 1/[stiffness] rad. Guarantees zero residual past that zone.
double softConstrainAngle(
  double angle, double anchor, double limit, double stiffness,
) {
  final diff = relativeAngleDiff(angle, anchor);
  if (diff.abs() <= limit) return simplifyAngle(angle);
  final excess = diff.abs() - limit;
  final t = (excess * stiffness).clamp(0.0, 1.0);
  final boundary = diff > 0
      ? simplifyAngle(anchor - limit)
      : simplifyAngle(anchor + limit);
  return angleLerp(angle, boundary, t);
}

/// Interpolate from a toward b by factor t (0..1), short way.
double angleLerp(double a, double b, double t) {
  final d = relativeAngleDiff(a, b);
  return simplifyAngle(a + d * t);
}
