import 'package:flutter/material.dart';

/// Red circle at head when dragging mouth off to remove.
class RemoveMouthPainter extends CustomPainter {
  RemoveMouthPainter({
    required this.headSx,
    required this.headSy,
    required this.radius,
  });

  final double headSx;
  final double headSy;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(headSx, headSy), radius, paint);
    final stroke = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(headSx, headSy), radius, stroke);
  }

  @override
  bool shouldRepaint(covariant RemoveMouthPainter old) =>
      old.headSx != headSx || old.headSy != headSy || old.radius != radius;
}
