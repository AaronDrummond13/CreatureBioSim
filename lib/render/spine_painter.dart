import 'dart:math' show cos, pi, sin;

import 'package:flutter/material.dart';

import '../creature.dart';
import '../simulation/angle_util.dart';
import '../simulation/spine.dart';
import 'view.dart';

/// Paints one creature in world space. Uses [view] to transform world → screen.
/// For multiple creatures, pass the same [CameraView] to each painter so they share one camera.
class CreaturePainter extends CustomPainter {
  final Creature creature;
  final Spine spine;
  final CameraView view;

  /// Time in seconds for background dot drift (optional).
  final double timeSeconds;

  static const double dorsalFinHeight = 18.0;
  static const double dorsalFinBaseFrac = 0.3;
  static const double minDefaultWidth = 10.0;
  static const double maxDefaultWidth = 50.0;
  static const double _fallbackWidth = 30.0;
  static const double _dotDriftAmount = 50.0;

  CreaturePainter({
    required this.creature,
    required this.spine,
    required this.view,
    this.timeSeconds = 0.0,
  });

  double _widthAt(int i) {
    final vw = creature.vertexWidths;
    if (i < vw.length) return vw[i].clamp(minDefaultWidth, maxDefaultWidth);
    return _fallbackWidth.clamp(minDefaultWidth, maxDefaultWidth);
  }

  /// Appends Catmull-Rom style cubic segments through [points] to [path].
  static void _appendSmoothCurve(
    Path path,
    List<Offset> points,
    double tension,
  ) {
    if (points.length < 2) return;
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[0];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i + 2 < points.length ? points[i + 2] : points[i + 1];
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
  }

  @override
  void paint(Canvas canvas, Size size) {
    final positions = spine.positions;
    final segmentAngles = spine.segmentAngles;
    if (positions.length < 2 || segmentAngles.length < 1) return;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final n = positions.length - 1;
    final z = view.zoom;

    double sx(double wx) => centerX + (wx - view.cameraX) * z;
    double sy(double wy) => centerY + (wy - view.cameraY) * z;
    double wAt(int i) => _widthAt(i) * z;
    final fillColor = Color(creature.color);

    // Background dots: infinite grid in world space; sample only the visible region (plus padding).
    const double dotSpacing = 120.0;
    final halfW = size.width / (2 * z);
    final halfH = size.height / (2 * z);
    final worldLeft = view.cameraX - halfW - size.width / z;
    final worldRight = view.cameraX + halfW + size.width / z;
    final worldTop = view.cameraY - halfH - size.height / z;
    final worldBottom = view.cameraY + halfH + size.height / z;
    final iMin = (worldLeft / dotSpacing).floor();
    final iMax = (worldRight / dotSpacing).ceil();
    final jMin = (worldTop / dotSpacing).floor();
    final jMax = (worldBottom / dotSpacing).ceil();
    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.fill;
    const dotRadius = 2.0;
    const double _dotDriftSpeed = 0.4;
    for (var i = iMin; i <= iMax; i++) {
      for (var j = jMin; j <= jMax; j++) {
        final t = timeSeconds * _dotDriftSpeed;
        final driftX = sin(i * 1.1 + j * 0.7 + t) * _dotDriftAmount;
        final driftY = cos(i * 0.9 + j * 1.3 + t * 0.8) * _dotDriftAmount;
        final wx = i * dotSpacing + driftX;
        final wy = j * dotSpacing + driftY;
        final px = sx(wx);
        final py = sy(wy);
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
      ..strokeWidth = (3.0 * z).clamp(1.0, 3.0);

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);

    // Dorsal fins: tapered ends, height from bend (smoothstep), inward fixed at baseFrac.
    final fins = creature.dorsalFins;
    if (fins != null && fins.isNotEmpty) {
      final finColorResolved = creature.finColor != null
          ? Color(creature.finColor!)
          : Color.lerp(fillColor, Colors.white, 0.15)!;
      final finFill = Paint()
        ..color = finColorResolved
        ..style = PaintingStyle.fill;
      final finStroke = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = (2.0 * z).clamp(1.0, 2.0);
      const tension = 1.0 / 6.0;
      final maxAngle = spine.maxJointAngleRad;
      for (final fin in fins) {
        final run = fin.$1;
        final fullH = fin.$2 ?? dorsalFinHeight;
        if (run.isEmpty) continue;
        final s = run.first;
        final e = run.last;
        if (s < 0 || e >= segmentAngles.length || e + 1 >= positions.length)
          continue;
        final baseH = fullH * dorsalFinBaseFrac;
        final pts = <({double x, double y, double a, double bend})>[];
        for (var i = s; i <= e + 1; i++) {
          final ai = i < segmentAngles.length ? i : e;
          final bend = (i == s || i == e + 1)
              ? 0.0
              : relativeAngleDiff(segmentAngles[ai], segmentAngles[ai - 1]);
          pts.add((
            x: positions[i].x,
            y: positions[i].y,
            a: segmentAngles[ai],
            bend: bend,
          ));
        }
        final top = <Offset>[];
        final bottom = <Offset>[];
        final nPts = pts.length;
        for (var i = 0; i < nPts; i++) {
          final p = pts[i];
          final isEndpoint = i == 0 || i == nPts - 1;
          double hTop;
          double hBottom;
          if (isEndpoint) {
            hTop = hBottom = 0;
          } else {
            final r = (p.bend.abs() / maxAngle).clamp(0.0, 1.0);
            final ratio = r * r * (3.0 - 2.0 * r);
            final hOut = baseH + (fullH - baseH) * ratio;
            if (p.bend > 0) {
              hTop = hOut;
              hBottom = baseH;
            } else if (p.bend < 0) {
              hTop = baseH;
              hBottom = hOut;
            } else {
              hTop = hBottom = baseH;
            }
            final taper = nPts > 1 ? sin(pi * i / (nPts - 1)) : 1.0;
            hTop *= taper;
            hBottom *= taper;
          }
          final dxTop = -sin(p.a) * hTop;
          final dyTop = cos(p.a) * hTop;
          final dxBottom = -sin(p.a) * hBottom;
          final dyBottom = cos(p.a) * hBottom;
          top.add(Offset(sx(p.x + dxTop), sy(p.y + dyTop)));
          bottom.add(Offset(sx(p.x - dxBottom), sy(p.y - dyBottom)));
        }
        final path = Path();
        path.moveTo(top[0].dx, top[0].dy);
        _appendSmoothCurve(path, top, tension);
        path.lineTo(bottom.last.dx, bottom.last.dy);
        _appendSmoothCurve(path, bottom.reversed.toList(), tension);
        path.close();
        canvas.drawPath(path, finFill);
        canvas.drawPath(path, finStroke);
      }
    }

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
  bool shouldRepaint(covariant CreaturePainter oldDelegate) =>
      oldDelegate.creature != creature ||
      oldDelegate.spine != spine ||
      oldDelegate.view != view ||
      oldDelegate.timeSeconds != timeSeconds;
}
