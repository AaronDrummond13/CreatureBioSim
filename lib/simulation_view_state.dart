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

  /// True while user has two fingers down (pinch). Target is frozen so zoom doesn't move it and cause shaking.
  bool touchTargetFrozen = false;

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

  /// Use zoom at touch start (pinchStartZoom) when set so target is independent of zoom during the gesture.
  void updateTouchFromLocal(Size screenSize, Offset local) {
    if (touchTargetFrozen) return;
    final z = pinchStartZoom ?? zoom;
    touchX = cameraX + (local.dx - screenSize.width / 2) / z;
    touchY = cameraY + (local.dy - screenSize.height / 2) / z;
    lastTouchLocal = local;
    lastTouchScreenSize = screenSize;
  }

  /// Recompute touch target from stored screen position. No-op if pinching (target frozen).
  void refreshTouchFromStoredLocal() {
    if (touchTargetFrozen) return;
    final local = lastTouchLocal;
    final size = lastTouchScreenSize;
    if (local == null || size == null) return;
    final z = pinchStartZoom ?? zoom;
    touchX = cameraX + (local.dx - size.width / 2) / z;
    touchY = cameraY + (local.dy - size.height / 2) / z;
  }

  void clearLastTouch() {
    lastTouchLocal = null;
    lastTouchScreenSize = null;
    touchTargetFrozen = false;
  }

  /// Clamp [newZoom] to [minZoom]..[maxZoom].
  double clampZoom(double newZoom) =>
      newZoom.clamp(minZoom, maxZoom);
}
