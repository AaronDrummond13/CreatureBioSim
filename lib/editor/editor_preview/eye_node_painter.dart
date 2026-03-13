import 'package:flutter/material.dart';

/// Mirrored node overlay for eye radius handles (one or two nodes, like lateral fin).
class EyeNodePainter extends CustomPainter {
  EyeNodePainter({required this.nodePositions, this.activeNodeIndex});

  final List<Offset> nodePositions;
  final int? activeNodeIndex;

  static const double radius = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < nodePositions.length; i++) {
      final active = activeNodeIndex == i;
      final pos = nodePositions[i];
      final fill = Paint()
        ..color = Colors.white.withValues(alpha: active ? 0.5 : 0.2)
        ..style = PaintingStyle.fill;
      final stroke = Paint()
        ..color = Colors.white.withValues(alpha: active ? 1.0 : 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(pos, radius, fill);
      canvas.drawCircle(pos, radius, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant EyeNodePainter old) {
    if (old.nodePositions.length != nodePositions.length ||
        old.activeNodeIndex != activeNodeIndex)
      return true;
    for (var i = 0; i < nodePositions.length; i++) {
      if (nodePositions[i] != old.nodePositions[i]) return true;
    }
    return false;
  }
}
