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
