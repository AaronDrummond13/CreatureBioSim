/// Shared view transform: world position at screen center and zoom.
/// Pass the same [CameraView] to every creature painter so they share one camera.
class CameraView {
  final double cameraX;
  final double cameraY;
  final double zoom;

  const CameraView({
    required this.cameraX,
    required this.cameraY,
    this.zoom = 1.0,
  });
}
