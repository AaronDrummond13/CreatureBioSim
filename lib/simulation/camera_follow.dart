/// Shared camera-follow logic for play and editor test mode.
/// Lerp camera position toward head each frame so both use the same behavior.

const double kCameraFollowK = 0.1;

/// Returns (newCameraX, newCameraY) by moving [cx], [cy] toward [hx], [hy]
/// by fraction [k] (default [kCameraFollowK]) per frame.
(double, double) lerpCameraToward(
  double cx,
  double cy,
  double hx,
  double hy, [
  double? k,
]) {
  final t = k ?? kCameraFollowK;
  return (
    cx + (hx - cx) * t,
    cy + (hy - cy) * t,
  );
}
