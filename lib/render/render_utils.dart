import 'package:flutter/material.dart';

/// Draws a bubble shape: filled circle plus a highlight for a 3D look.
/// [fillColor] is the main bubble color (e.g. white or food color); highlight is drawn lighter.
void drawBubble(
  Canvas canvas,
  Offset center,
  double radius,
  Color fillColor, {
  double alpha = 1.0,
}) {
  if (radius <= 0) return;
  final fill = Paint()
    ..color = fillColor.withValues(alpha: alpha)
    ..style = PaintingStyle.fill;
  canvas.drawCircle(center, radius, fill);
  final highlightRadius = radius * 0.35;
  final highlightCenter = Offset(
    center.dx - radius * 0.25,
    center.dy - radius * 0.25,
  );
  final highlightRect = Rect.fromCircle(center: highlightCenter, radius: highlightRadius);
  final highlightPaint = Paint()
    ..shader = RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: [
        Colors.white.withValues(alpha: alpha * 0.6),
        Colors.white.withValues(alpha: 0.0),
      ],
    ).createShader(highlightRect);
  canvas.drawOval(highlightRect, highlightPaint);
}

/// Appends Catmull-Rom style cubic segments through [points] to [path].
/// [closed]: if true, uses wrap-around indexing and closes the path; otherwise open curve.
void appendSmoothCurve(
  Path path,
  List<Offset> points,
  double tension, {
  bool closed = false,
}) {
  if (points.length < 2) return;
  final len = points.length;
  if (closed) path.moveTo(points[0].dx, points[0].dy);
  final count = closed ? len : len - 1;
  for (var i = 0; i < count; i++) {
    final p0 = closed
        ? points[(i - 1 + len) % len]
        : (i > 0 ? points[i - 1] : points[0]);
    final p1 = points[i];
    final p2 = closed ? points[(i + 1) % len] : points[i + 1];
    final p3 = closed
        ? points[(i + 2) % len]
        : (i + 2 < len ? points[i + 2] : points[i + 1]);
    final c0 = Offset(
      p1.dx + (p2.dx - p0.dx) * tension,
      p1.dy + (p2.dy - p0.dy) * tension,
    );
    final c1 = Offset(
      p2.dx - (p3.dx - p1.dx) * tension,
      p2.dy - (p3.dy - p1.dy) * tension,
    );
    path.cubicTo(c0.dx, c0.dy, c1.dx, c1.dy, p2.dx, p2.dy);
  }
  if (closed) path.close();
}
