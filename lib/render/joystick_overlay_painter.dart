import 'package:flutter/material.dart';

import 'package:creature_bio_sim/simulation_view_state.dart';

/// Faint white joystick circles: outer always visible (hint when inactive, slightly more when active). Knob when active.
class JoystickOverlayPainter extends CustomPainter {
  JoystickOverlayPainter({
    required this.viewState,
    required this.layerSize,
    this.knobRadius = 20.0,
  });

  final SimulationViewState viewState;
  final Size layerSize;
  final double knobRadius;

  static const double _joystickPadding = 24.0;
  static const double _strokeWidth = 1.5;
  static const double _fillOpacity = 0.22;
  static const double _strokeOpacity = 0.5;
  static const double _outerActiveStrokeOpacity = 0.2;
  static const double _hintStrokeOpacity = 0.08;

  Offset get _zoneCenter => Offset(
        _joystickPadding + viewState.joystickMaxRadius,
        layerSize.height - _joystickPadding - viewState.joystickMaxRadius,
      );

  @override
  void paint(Canvas canvas, Size size) {
    final center = viewState.isJoystickActive ? viewState.joystickCenter : _zoneCenter;
    final outerOpacity = viewState.isJoystickActive ? _outerActiveStrokeOpacity : _hintStrokeOpacity;
    final outerPaint = Paint()
      ..color = Colors.white.withValues(alpha: outerOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;
    canvas.drawCircle(center, viewState.joystickMaxRadius, outerPaint);

    // Knob: only when joystick active
    if (viewState.isJoystickActive) {
      final knobCenter = viewState.joystickOffset != null
          ? center + viewState.joystickOffset!
          : center;
      final fillPaint = Paint()
        ..color = Colors.white.withValues(alpha: _fillOpacity)
        ..style = PaintingStyle.fill;
      final strokePaint = Paint()
        ..color = Colors.white.withValues(alpha: _strokeOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth;
      canvas.drawCircle(knobCenter, knobRadius, fillPaint);
      canvas.drawCircle(knobCenter, knobRadius, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant JoystickOverlayPainter old) =>
      old.viewState != viewState || old.layerSize != layerSize;
}
