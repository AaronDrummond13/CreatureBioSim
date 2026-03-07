import 'package:flutter/material.dart';

import 'render/view.dart';

/// Holds view/camera and touch state for the simulation screen.
/// Camera = world position at screen center; zoom; touch target; time for drift/parallax.
class SimulationViewState {
  double cameraX = 0;
  double cameraY = 0;
  double zoom = 1.0;
  double touchX = 0;
  double touchY = 0;
  double timeSeconds = 0;
  double viewWidthWorld = 800;
  double viewHeightWorld = 600;

  /// Transient: set on pinch start, used in scale update, cleared on end.
  double? pinchStartZoom;

  /// While the user is touching, store screen position so we can refresh touch target each frame (camera moves).
  Offset? lastTouchLocal;
  Size? lastTouchScreenSize;

  static const double minZoom = 0.4;
  static const double maxZoom = 2.5;

  CameraView get cameraView =>
      CameraView(cameraX: cameraX, cameraY: cameraY, zoom: zoom);

  /// Parallax view for background layer (e.g. blurred creature).
  CameraView backgroundCameraView({
    double parallaxFactor = 0.25,
    double zoomScale = 5.0,
  }) =>
      CameraView(
        cameraX: cameraX * parallaxFactor,
        cameraY: cameraY * parallaxFactor,
        zoom: zoom * zoomScale,
      );

  void setViewSize(Size size) {
    viewWidthWorld = size.width / zoom;
    viewHeightWorld = size.height / zoom;
  }

  void updateTouchFromLocal(Size screenSize, Offset local) {
    touchX = cameraX + (local.dx - screenSize.width / 2) / zoom;
    touchY = cameraY + (local.dy - screenSize.height / 2) / zoom;
    lastTouchLocal = local;
    lastTouchScreenSize = screenSize;
  }

  /// Recompute touch target from stored screen position using current camera/zoom. Call each tick while finger is down.
  void refreshTouchFromStoredLocal() {
    final local = lastTouchLocal;
    final size = lastTouchScreenSize;
    if (local == null || size == null) return;
    touchX = cameraX + (local.dx - size.width / 2) / zoom;
    touchY = cameraY + (local.dy - size.height / 2) / zoom;
  }

  void clearLastTouch() {
    lastTouchLocal = null;
    lastTouchScreenSize = null;
  }

  /// Clamp [newZoom] to [minZoom]..[maxZoom].
  double clampZoom(double newZoom) =>
      newZoom.clamp(minZoom, maxZoom);
}
