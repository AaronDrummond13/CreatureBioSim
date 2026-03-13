import 'package:flutter/material.dart';

/// Four nodes for selected lateral fin (mirrored left/right): 0,2 = length; 1,3 = width. activeNode = raw index 0..3.
class PecFinNodePainter extends CustomPainter {
  PecFinNodePainter({required this.positions, this.activeNode});

  final List<Offset> positions;
  final int? activeNode;

  static const double nodeRadius = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < positions.length; i++) {
      final active = activeNode == i;
      final stroke = Paint()
        ..color = Colors.white.withValues(alpha: active ? 1.0 : 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      final fill = Paint()
        ..color = Colors.white.withValues(alpha: active ? 0.5 : 0.15);
      canvas.drawCircle(positions[i], nodeRadius, fill);
      canvas.drawCircle(positions[i], nodeRadius, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant PecFinNodePainter old) =>
      old.activeNode != activeNode || old.positions.length != positions.length;
}
