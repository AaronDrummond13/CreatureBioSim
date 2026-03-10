import 'package:flutter/material.dart';

import 'package:creature_bio_sim/render/view.dart';

/// Holds view/camera and touch state for the simulation screen.
/// Camera = world position at screen center; zoom; touch target; time for drift/parallax.
/// Extends [ChangeNotifier] so the view subtree rebuilds on tick/gesture; gesture region stays stable.
/// [joystickListenable] notifies only on joystick start/update/end so the joystick overlay doesn't rebuild every frame.
class SimulationViewState extends ChangeNotifier {
  SimulationViewState() : _joystickNotifier = ChangeNotifier();

  final ChangeNotifier _joystickNotifier;
  Listenable get joystickListenable => _joystickNotifier;

  double cameraX = 0;
  double cameraY = 0;
  double zoom = 0.7;
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

  /// Joystick: active when touch is in bottom-left zone. Target is head + (joystick direction × distance).
  bool isJoystickActive = false;
  Offset? joystickOffset;
  Offset joystickCenter = Offset.zero;
  double joystickMaxRadius = 60.0;
  double? joystickGrabTime;

  static const double minZoom = 0.1;
  static const double maxZoom = 5;

  CameraView get cameraView =>
      CameraView(cameraX: cameraX, cameraY: cameraY, zoom: zoom);

  /// Parallax view for background layer (e.g. mammoths).
  CameraView backgroundCameraView({
    double parallaxFactor = 0.25,
    double zoomScale = 5.0,
  }) => CameraView(
    cameraX: cameraX * parallaxFactor,
    cameraY: cameraY * parallaxFactor,
    zoom: zoom * zoomScale,
  );

  void setViewSize(Size size) {
    viewWidthWorld = size.width / zoom;
    viewHeightWorld = size.height / zoom;
  }

  /// Render rect in world coords with buffer so things don't pop at edges. (left, right, top, bottom).
  (double, double, double, double) renderRectWithBuffer([
    double bufferFrac = 0.15,
  ]) {
    final w = viewWidthWorld * (0.5 + bufferFrac);
    final h = viewHeightWorld * (0.5 + bufferFrac);
    return (cameraX - w, cameraX + w, cameraY - h, cameraY + h);
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

  /// Notify after touch down so view repaints; move repaints are handled by tick.
  void onTouchDown() => notifyListeners();

  /// Recompute touch target from stored screen position. No-op if pinching or joystick (joystick target set in sim step).
  void refreshTouchFromStoredLocal() {
    if (touchTargetFrozen || isJoystickActive) return;
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
    notifyListeners();
  }

  void startJoystick(Offset center, Offset localPosition) {
    joystickCenter = center;
    final offset = localPosition - center;
    final len = offset.distance;
    joystickOffset = len <= joystickMaxRadius
        ? offset
        : Offset(
            offset.dx / len * joystickMaxRadius,
            offset.dy / len * joystickMaxRadius,
          );
    joystickGrabTime = timeSeconds;
    isJoystickActive = true;
    _joystickNotifier.notifyListeners();
  }

  void updateJoystick(Offset localPosition) {
    if (!isJoystickActive) return;
    final offset = localPosition - joystickCenter;
    final len = offset.distance;
    joystickOffset = len <= joystickMaxRadius
        ? offset
        : Offset(
            offset.dx / len * joystickMaxRadius,
            offset.dy / len * joystickMaxRadius,
          );
    _joystickNotifier.notifyListeners();
  }

  void endJoystick(double headX, double headY) {
    touchX = headX;
    touchY = headY;
    isJoystickActive = false;
    joystickOffset = null;
    joystickGrabTime = null;
    lastTouchLocal = null;
    lastTouchScreenSize = null;
    _joystickNotifier.notifyListeners();
  }

  /// Apply pinch zoom; notifies only if [z] differs from current zoom.
  void applyPinchZoom(double z) {
    final clamped = clampZoom(z);
    if (clamped != zoom) {
      zoom = clamped;
      notifyListeners();
    }
  }

  /// Pinch started (2 fingers); freeze target and store baseline zoom.
  void startPinch(bool twoFingers) {
    pinchStartZoom = zoom;
    touchTargetFrozen = twoFingers;
    notifyListeners();
  }

  /// Pinch ended; clear baseline and touch so zoom/target don’t stick.
  void endPinch() {
    pinchStartZoom = null;
    clearLastTouch();
  }

  /// Clamp [newZoom] to [minZoom]..[maxZoom].
  double clampZoom(double newZoom) => newZoom.clamp(minZoom, maxZoom);

  /// Called each tick so the view subtree rebuilds; gesture region does not.
  void onTick() => notifyListeners();
}
