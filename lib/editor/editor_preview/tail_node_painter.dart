import 'dart:math';
import 'package:flutter/material.dart';

/// Three nodes for tail sizing: root width, max width, length (when creature has tail).
class TailNodePainter extends CustomPainter {
  TailNodePainter({
    required this.tailX,
    required this.tailY,
    required this.tailA,
    required this.rootW,
    required this.maxW,
    required this.len,
    required this.centerX,
    required this.centerY,
    required this.cameraX,
    required this.cameraY,
    required this.zoom,
    this.activeNode,
  });

  final double tailX;
  final double tailY;
  final double tailA;
  final double rootW;
  final double maxW;
  final double len;
  final double centerX;
  final double centerY;
  final double cameraX;
  final double cameraY;
  final double zoom;

  /// 0=root, 1=max, 2=length; null=none active.
  final int? activeNode;

  static const double nodeRadius = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    double sx(double wx) => centerX + (wx - cameraX) * zoom;
    double sy(double wy) => centerY + (wy - cameraY) * zoom;
    final back = tailA + pi;
    final leftDirX = sin(tailA);
    final leftDirY = -cos(tailA);
    final backDirX = cos(back);
    final backDirY = sin(back);
    final rootPx = tailX + leftDirX * rootW;
    final rootPy = tailY + leftDirY * rootW;
    final maxPx = tailX + backDirX * len * 0.7 + leftDirX * maxW;
    final maxPy = tailY + backDirY * len * 0.7 + leftDirY * maxW;
    final tipPx = tailX + backDirX * len;
    final tipPy = tailY + backDirY * len;
    final points = [
      Offset(sx(rootPx), sy(rootPy)),
      Offset(sx(maxPx), sy(maxPy)),
      Offset(sx(tipPx), sy(tipPy)),
    ];
    for (var i = 0; i < 3; i++) {
      final active = activeNode == i;
      final stroke = Paint()
        ..color = Colors.white.withValues(alpha: active ? 1.0 : 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      final fill = Paint()
        ..color = Colors.white.withValues(alpha: active ? 0.5 : 0.15);
      canvas.drawCircle(points[i], nodeRadius, fill);
      canvas.drawCircle(points[i], nodeRadius, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant TailNodePainter old) =>
      old.rootW != rootW ||
      old.maxW != maxW ||
      old.len != len ||
      old.activeNode != activeNode;
}
