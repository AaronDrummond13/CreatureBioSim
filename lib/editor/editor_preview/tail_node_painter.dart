import 'dart:math';
import 'package:bioism/editor/node_painter.dart';
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
    for (var i = 0; i < 3; i++)
      drawNode(canvas, points[i], active: activeNode == i);
  }

  @override
  bool shouldRepaint(covariant TailNodePainter old) =>
      old.rootW != rootW ||
      old.maxW != maxW ||
      old.len != len ||
      old.activeNode != activeNode;
}
