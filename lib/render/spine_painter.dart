import 'dart:math' show cos, pi, sin;

import 'package:flutter/material.dart';

import '../simulation/vector.dart';

/// Paints a spine (body outline, caps, eyes) in world space using a camera transform.
/// Positions and segmentAngles are in world space; [cameraX], [cameraY], [zoom] define the view.
class SpinePainter extends CustomPainter {
  final List<Vector2> positions;
  final List<double> segmentAngles;

  /// Per-vertex width (half-width from spine to outline). If null, uses [defaultWidth].
  final List<double>? vertexWidths;

  /// Camera: world position at screen center. Creature positions are in world space; camera only affects view.
  final double cameraX;
  final double cameraY;

  /// View zoom: world units scale by this when drawing. 1 = 1:1, < 1 = zoom out.
  final double zoom;

  /// Fill colour for the creature body (from creature.color).
  final Color fillColor;

  static const double _defaultWidth = 40.0;

  SpinePainter({
    required this.positions,
    required this.segmentAngles,
    this.vertexWidths,
    required this.cameraX,
    required this.cameraY,
    this.zoom = 1.0,
    this.fillColor = const Color(0xFF2E7D32),
  });

  double _widthAt(int i) {
    if (vertexWidths != null && i < vertexWidths!.length)
      return vertexWidths![i];
    return _defaultWidth;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.length < 2 || segmentAngles.length < 1) return;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final n = positions.length - 1;
    final z = zoom;

    // World → screen: camera at center. Positions are in world space; camera does not move the creature.
    double sx(double wx) => centerX + (wx - cameraX) * z;
    double sy(double wy) => centerY + (wy - cameraY) * z;
    double wAt(int i) => _widthAt(i) * z;

    // Background dots: infinite grid in world space; sample only the visible region (plus padding).
    const double dotSpacing = 120.0;
    final halfW = size.width / (2 * z);
    final halfH = size.height / (2 * z);
    final worldLeft = cameraX - halfW - size.width / z;
    final worldRight = cameraX + halfW + size.width / z;
    final worldTop = cameraY - halfH - size.height / z;
    final worldBottom = cameraY + halfH + size.height / z;
    final iMin = (worldLeft / dotSpacing).floor();
    final iMax = (worldRight / dotSpacing).ceil();
    final jMin = (worldTop / dotSpacing).floor();
    final jMax = (worldBottom / dotSpacing).ceil();
    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.fill;
    const dotRadius = 2.0;
    for (var i = iMin; i <= iMax; i++) {
      for (var j = jMin; j <= jMax; j++) {
        final px = sx(i * dotSpacing);
        final py = sy(j * dotSpacing);
        if (px >= -dotRadius &&
            px <= size.width + dotRadius &&
            py >= -dotRadius &&
            py <= size.height + dotRadius) {
          canvas.drawCircle(Offset(px, py), dotRadius, dotPaint);
        }
      }
    }

    Offset rightAt(int i) {
      final a =
          segmentAngles[i < segmentAngles.length
              ? i
              : segmentAngles.length - 1];
      final w = wAt(i);
      return Offset(
        sx(positions[i].x) - sin(a) * w,
        sy(positions[i].y) + cos(a) * w,
      );
    }

    Offset leftAt(int i) {
      final a =
          segmentAngles[i < segmentAngles.length
              ? i
              : segmentAngles.length - 1];
      final w = wAt(i);
      return Offset(
        sx(positions[i].x) + sin(a) * w,
        sy(positions[i].y) - cos(a) * w,
      );
    }

    final tailA = segmentAngles[0];
    final headA = segmentAngles[segmentAngles.length - 1];
    final tailWWorld = _widthAt(0);
    final headWWorld = _widthAt(n);

    const int capSegments =
        7; // Points on each cap semicircle (more = rounder).
    final curve = <Offset>[];
    // Tail cap: semicircle from left body edge (4π/3) via tip (π) to right body edge (2π/3).
    for (var i = 0; i < capSegments; i++) {
      final t = i / (capSegments - 1);
      final a = tailA + 4 * pi / 3 + t * (2 * pi / 3 - 4 * pi / 3);
      curve.add(
        Offset(
          sx(positions[0].x + tailWWorld * cos(a)),
          sy(positions[0].y + tailWWorld * sin(a)),
        ),
      );
    }
    for (var i = 0; i <= n; i++) curve.add(rightAt(i));
    // Head cap: semicircle from right (π/3) via tip (0) to left (−π/3).
    for (var i = 0; i < capSegments; i++) {
      final t = i / (capSegments - 1);
      final a = headA + pi / 3 - t * (2 * pi / 3);
      curve.add(
        Offset(
          sx(positions[n].x + headWWorld * cos(a)),
          sy(positions[n].y + headWWorld * sin(a)),
        ),
      );
    }
    for (var i = n; i >= 0; i--) curve.add(leftAt(i));

    // Connect all points with one smooth curve (Catmull-Rom style cubic between consecutive points).
    const tension = 1.0 / 6.0;
    final path = Path();
    path.moveTo(curve[0].dx, curve[0].dy);
    final len = curve.length;
    for (var i = 0; i < len; i++) {
      final p0 = curve[(i - 1 + len) % len];
      final p1 = curve[i];
      final p2 = curve[(i + 1) % len];
      final p3 = curve[(i + 2) % len];
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
    path.close();

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = (3 * z).clamp(1.0, 3.0);

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);

    // Eyes at head: left and right vertex, slightly inward.
    const eyeInset = 0.55;
    final headW = wAt(n);
    final headCx = sx(positions[n].x);
    final headCy = sy(positions[n].y);
    final rightEye = Offset(
      headCx - sin(headA) * headW * eyeInset,
      headCy + cos(headA) * headW * eyeInset,
    );
    final leftEye = Offset(
      headCx + sin(headA) * headW * eyeInset,
      headCy - cos(headA) * headW * eyeInset,
    );
    final eyeRadius = headW * 0.24;
    final eyePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(rightEye, eyeRadius, eyePaint);
    canvas.drawCircle(leftEye, eyeRadius, eyePaint);
  }

  @override
  bool shouldRepaint(covariant SpinePainter oldDelegate) =>
      oldDelegate.zoom != zoom ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.cameraX != cameraX ||
      oldDelegate.cameraY != cameraY ||
      oldDelegate.positions.length != positions.length ||
      oldDelegate.segmentAngles.length != segmentAngles.length;
}
