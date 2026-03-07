import 'package:flutter/material.dart';

/// Handles touch (single-pointer) and pinch-to-zoom over the simulation.
/// Tracks pointer count internally; touch callbacks run only for single-finger.
/// Zoom is reported as scale factors; parent holds zoom state and clamps.
class SimulationGestureRegion extends StatefulWidget {
  /// Called when the first pointer goes down (single-finger start). [local] is in local coordinates.
  final void Function(Offset local) onSinglePointerDown;

  /// Called when the single pointer moves. [local] is in local coordinates.
  final void Function(Offset local) onSinglePointerMove;

  /// Called when pinch starts. Use [ScaleStartDetails.localFocalPoint] for touch target; store zoom for scale updates.
  final void Function(ScaleStartDetails details) onScaleStart;

  /// [details.scale] = cumulative scale since start; [details.localFocalPoint] for touch target.
  final void Function(ScaleUpdateDetails details) onScaleUpdate;

  /// Called when pinch ends. Parent can clear stored start zoom.
  final VoidCallback onScaleEnd;

  const SimulationGestureRegion({
    super.key,
    required this.onSinglePointerDown,
    required this.onSinglePointerMove,
    required this.onScaleStart,
    required this.onScaleUpdate,
    required this.onScaleEnd,
  });

  @override
  State<SimulationGestureRegion> createState() => _SimulationGestureRegionState();
}

class _SimulationGestureRegionState extends State<SimulationGestureRegion> {
  int _pointerCount = 0;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        _pointerCount++;
        if (_pointerCount == 1) {
          widget.onSinglePointerDown(e.localPosition);
        }
      },
      onPointerMove: (e) {
        if (_pointerCount == 1) {
          widget.onSinglePointerMove(e.localPosition);
        }
      },
      onPointerUp: (_) {
        _pointerCount = (_pointerCount - 1).clamp(0, 10);
      },
      onPointerCancel: (_) {
        _pointerCount = (_pointerCount - 1).clamp(0, 10);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onScaleStart: (d) => widget.onScaleStart(d),
        onScaleUpdate: (d) => widget.onScaleUpdate(d),
        onScaleEnd: (_) => widget.onScaleEnd(),
        child: const SizedBox.expand(),
      ),
    );
  }
}
