import 'dart:math' show cos, sin;

import 'package:flutter/material.dart';

import 'view.dart';

/// Paints the procedural background dots. Uses [view] for world→screen transform.
/// Add as the bottom layer of the stack so creatures draw on top.
class BackgroundPainter extends CustomPainter {
  final CameraView view;
  final double timeSeconds;

  static const double _dotSpacing = 120.0;
  static const double _dotDriftAmount = 40.0;
  static const double _dotDriftSpeed = 0.4;
  static const double _dotRadius = 2.0;

  BackgroundPainter({required this.view, this.timeSeconds = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    final z = view.zoom;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    double sx(double wx) => centerX + (wx - view.cameraX) * z;
    double sy(double wy) => centerY + (wy - view.cameraY) * z;

    final halfW = size.width / (2 * z);
    final halfH = size.height / (2 * z);
    final worldLeft = view.cameraX - halfW - size.width / z;
    final worldRight = view.cameraX + halfW + size.width / z;
    final worldTop = view.cameraY - halfH - size.height / z;
    final worldBottom = view.cameraY + halfH + size.height / z;
    final iMin = (worldLeft / _dotSpacing).floor();
    final iMax = (worldRight / _dotSpacing).ceil();
    final jMin = (worldTop / _dotSpacing).floor();
    final jMax = (worldBottom / _dotSpacing).ceil();

    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    final t = timeSeconds * _dotDriftSpeed;
    for (var i = iMin; i <= iMax; i++) {
      for (var j = jMin; j <= jMax; j++) {
        final driftX = sin(i * 1.1 + j * 0.7 + t) * _dotDriftAmount;
        final driftY = cos(i * 0.9 + j * 1.3 + t * 0.8) * _dotDriftAmount;
        final wx = i * _dotSpacing + driftX;
        final wy = j * _dotSpacing + driftY;
        final px = sx(wx);
        final py = sy(wy);
        if (px >= -_dotRadius &&
            px <= size.width + _dotRadius &&
            py >= -_dotRadius &&
            py <= size.height + _dotRadius) {
          canvas.drawCircle(Offset(px, py), _dotRadius, dotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant BackgroundPainter oldDelegate) =>
      oldDelegate.view != view || oldDelegate.timeSeconds != timeSeconds;
}
