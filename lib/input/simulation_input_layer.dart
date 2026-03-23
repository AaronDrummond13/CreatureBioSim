import 'package:flutter/material.dart';

import 'package:bioism/input/simulation_gesture_region.dart';
import 'package:bioism/render/joystick_overlay_painter.dart';
import 'package:bioism/simulation/spine.dart';
import 'package:bioism/simulation_view_state.dart';

/// Gesture region and joystick overlay for the simulation (play) screen.
class SimulationInputLayer extends StatelessWidget {
  const SimulationInputLayer({
    super.key,
    required this.viewState,
    required this.spine,
    required this.layerSize,
    this.joystickPadding = 24.0,
    this.knobRadius = 20.0,
  });

  final SimulationViewState viewState;
  final Spine spine;
  final Size layerSize;
  final double joystickPadding;
  final double knobRadius;

  @override
  Widget build(BuildContext context) {
    if (layerSize.width < 1 || layerSize.height < 1) {
      return const SizedBox.expand();
    }
    final joystickCenter = Offset(
      joystickPadding + viewState.joystickMaxRadius,
      layerSize.height - joystickPadding - viewState.joystickMaxRadius,
    );
    final joystickZoneRadius = viewState.joystickMaxRadius;
    bool isInJoystickZone(Offset local) {
      final dx = local.dx - joystickCenter.dx;
      final dy = local.dy - joystickCenter.dy;
      return dx * dx + dy * dy <= joystickZoneRadius * joystickZoneRadius;
    }

    return Stack(
      children: [
        SimulationGestureRegion(
          onSinglePointerDown: (local) {
            if (isInJoystickZone(local)) {
              viewState.startJoystick(joystickCenter, local);
            } else {
              viewState.updateTouchFromLocal(layerSize, local);
              viewState.onTouchDown();
            }
          },
          onSinglePointerMove: (local) {
            if (viewState.isJoystickActive) {
              viewState.updateJoystick(local);
            } else {
              viewState.updateTouchFromLocal(layerSize, local);
            }
          },
          onSinglePointerUp: () {
            if (viewState.isJoystickActive) {
              final head = spine.positions.isNotEmpty
                  ? spine.positions.last
                  : null;
              if (head != null) {
                viewState.endJoystick(head.x, head.y);
              } else {
                viewState.endJoystick(viewState.cameraX, viewState.cameraY);
              }
            } else {
              viewState.clearLastTouch();
            }
          },
          onScaleStart: (details) {
            if (details.pointerCount >= 2) {
              final pos = spine.positions;
              if (pos.isNotEmpty) {
                final head = pos.last;
                viewState.touchX = head.x;
                viewState.touchY = head.y;
              }
            }
            viewState.startPinch(details.pointerCount >= 2);
          },
          onScaleUpdate: (details) {
            viewState.touchTargetFrozen = details.pointerCount >= 2;
            if (viewState.pinchStartZoom != null) {
              viewState.applyPinchZoom(
                viewState.pinchStartZoom! * details.scale,
              );
            }
          },
          onScaleEnd: () {
            viewState.endPinch();
          },
        ),
        IgnorePointer(
          child: ListenableBuilder(
            listenable: viewState.joystickListenable,
            builder: (context, _) => CustomPaint(
              size: layerSize,
              painter: JoystickOverlayPainter(
                viewState: viewState,
                layerSize: layerSize,
                knobRadius: knobRadius,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
