import 'dart:math' show cos, pi, sin, sqrt;

import 'package:flutter/material.dart';

import '../world/food.dart' show CellType, ConsumedRemnant, FoodItem;
import 'view.dart';

/// Paints plant cells (green hollow hexagon) and animal cells (red hollow circle).
/// Also draws consumed remnants: burst (radial lines ~0.3s) and nucleus fading over 5s.
class FoodPainter extends CustomPainter {
  FoodPainter({
    required this.view,
    required this.items,
    this.consumedRemnants = const [],
    this.timeSeconds = 0.0,
    this.foodRadiusWorld = 14.0,
    this.fillColor = const Color(0xFF4A7C59),
    this.animalCellColor = const Color(0xFFb83c3c),
    this.innerRadiusFrac = 0.68,
  });

  final CameraView view;
  final List<FoodItem> items;
  final List<ConsumedRemnant> consumedRemnants;
  final double timeSeconds;
  final double foodRadiusWorld;
  final Color fillColor;
  final Color animalCellColor;
  final double innerRadiusFrac;

  @override
  void paint(Canvas canvas, Size size) {
    final z = view.zoom;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    double sx(double wx) => centerX + (wx - view.cameraX) * z;
    double sy(double wy) => centerY + (wy - view.cameraY) * z;

    for (final r in consumedRemnants) {
      final age = timeSeconds - r.consumedAt;
      if (age < 0) continue;
      const burstDuration = 5.0;
      if (age < burstDuration) {
        var dirAx = r.x - r.headX;
        var dirAy = r.y - r.headY;
        var lenA = sqrt(dirAx * dirAx + dirAy * dirAy);
        if (lenA < 1e-6) {
          dirAx = 1.0;
          dirAy = 0.0;
        } else {
          dirAx /= lenA;
          dirAy /= lenA;
        }
        const gasDriftSpeedWorld = 60.0;
        final driftAway = age * gasDriftSpeedWorld;
        final t = age / burstDuration;
        final spreadWorld = (0.12 + t * 1.0) * (foodRadiusWorld * 4.2);
        final alphaFade = (1 - t).clamp(0.0, 1.0);
        final color = r.cellType == CellType.animal ? animalCellColor : fillColor;
        final puffRadiusBase = (foodRadiusWorld * z * 1.35).clamp(10.0, 42.0);
        final growFrac = 0.5 + 1.0 * t;
        void drawPuff(double px, double py, double radius, Color fill, double opacity) {
          final rect = Rect.fromCircle(center: Offset(px, py), radius: radius);
          final paint = Paint()
            ..shader = RadialGradient(
              center: Alignment.center,
              radius: 1.0,
              colors: [
                fill.withValues(alpha: opacity),
                fill.withValues(alpha: 0.0),
              ],
            ).createShader(rect);
          canvas.drawCircle(Offset(px, py), radius, paint);
        }
        final centerWx = r.x + dirAx * driftAway;
        final centerWy = r.y + dirAy * driftAway;
        drawPuff(sx(centerWx), sy(centerWy), puffRadiusBase * 1.2 * growFrac, color, alphaFade * 0.5);
        const puffs = 12;
        for (var i = 0; i < puffs; i++) {
          final angle = (i / puffs) * 2 * pi + (i * 0.17) + t * 0.4;
          final dist = spreadWorld * (0.35 + 0.65 * ((i * 0.73) % 1.0));
          final puffWx = r.x + cos(angle) * dist + dirAx * driftAway;
          final puffWy = r.y + sin(angle) * dist + dirAy * driftAway;
          final px = sx(puffWx);
          final py = sy(puffWy);
          final rPuff = puffRadiusBase * (0.7 + 0.4 * ((i * 0.5) % 1.0)) * growFrac;
          final useLighter = i % 2 == 1;
          final opacity = (useLighter ? 0.32 : 0.5) * alphaFade;
          drawPuff(px, py, rPuff, color, opacity);
        }
      }
      const lineDuration = 3.3;
      if (age < lineDuration) {
        var dirAx = r.x - r.headX;
        var dirAy = r.y - r.headY;
        var lenA = sqrt(dirAx * dirAx + dirAy * dirAy);
        if (lenA < 1e-6) {
          dirAx = 1.0;
          dirAy = 0.0;
        } else {
          dirAx /= lenA;
          dirAy /= lenA;
        }
        const gasDriftSpeedWorld = 60.0;
        final driftAway = age * gasDriftSpeedWorld;
        const burstDurationSec = 5.0;
        final t = age / burstDurationSec;
        final spreadWorld = (0.12 + t * 1.0) * (foodRadiusWorld * 4.2);
        final lineScale = foodRadiusWorld * 0.48;
        final tLine = age / lineDuration;
        final baseAlpha = (tLine <= 0.5 ? 1.0 : (1.0 - (tLine - 0.5) / 0.5).clamp(0.0, 1.0)) * 0.7;
        for (var i = 0; i < 6; i++) {
          final placeAngle = (i / 6) * 2 * pi + (i * 0.19) + t * 0.4;
          final dist = spreadWorld * (0.35 + 0.65 * ((i * 0.73) % 1.0));
          final lineCx = r.x + cos(placeAngle) * dist + dirAx * driftAway;
          final lineCy = r.y + sin(placeAngle) * dist + dirAy * driftAway;
          final segAngle = (i * 1.11 + r.x * 0.002 + age * 0.06) % (2 * pi);
          final halfLen = (i % 2 == 0 ? 0.9 : 0.4) * lineScale;
          final lineAlpha = i % 2 == 0 ? baseAlpha : baseAlpha * 0.45;
          final startWx = lineCx - cos(segAngle) * halfLen;
          final startWy = lineCy - sin(segAngle) * halfLen;
          final endWx = lineCx + cos(segAngle) * halfLen;
          final endWy = lineCy + sin(segAngle) * halfLen;
          final linePaint = Paint()
            ..color = Colors.white.withValues(alpha: lineAlpha)
            ..strokeWidth = (3.0 * z).clamp(1.0, 3.0)
            ..style = PaintingStyle.stroke;
          final start = Offset(sx(startWx), sy(startWy));
          final end = Offset(sx(endWx), sy(endWy));
          if (r.cellType == CellType.animal) {
            final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
            final segDx = end.dx - start.dx;
            final segDy = end.dy - start.dy;
            final len = sqrt(segDx * segDx + segDy * segDy);
            final bulge = len > 1e-6 ? len * 0.28 : 0.0;
            final perpX = -segDy / len;
            final perpY = segDx / len;
            final control = Offset(mid.dx + perpX * bulge, mid.dy + perpY * bulge);
            final path = Path()..moveTo(start.dx, start.dy)..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
            canvas.drawPath(path, linePaint);
          } else {
            canvas.drawLine(start, end, linePaint);
          }
        }
      }
      if (age < 7.5) {
        final baseNx = r.x + r.nucleusOffsetX;
        final baseNy = r.y + r.nucleusOffsetY;
        var dx = baseNx - r.headX;
        var dy = baseNy - r.headY;
        var len = sqrt(dx * dx + dy * dy);
        if (len < 1e-6) {
          dx = 1.0;
          dy = 0.0;
          len = 1.0;
        } else {
          dx /= len;
          dy /= len;
        }
        const maxDriftWorld = 320.0;
        final t = (age / 7.5).clamp(0.0, 1.0);
        final drift = maxDriftWorld * (2 * t - t * t);
        final nucleusWx = baseNx + dx * drift;
        final nucleusWy = baseNy + dy * drift;
        final nx = sx(nucleusWx);
        final ny = sy(nucleusWy);
        final nr = (foodRadiusWorld * z * 0.22).clamp(2.0, 12.0);
        final alpha = (1 - age / 7.5).clamp(0.0, 1.0);
        final nucleusPaint = Paint()
          ..color = const Color(0xFF3d2914).withValues(alpha: alpha)
          ..style = PaintingStyle.fill;
        final strokePaint = Paint()
          ..color = Colors.white.withValues(alpha: alpha * 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (1.0 * z).clamp(0.5, 1.5);
        canvas.drawCircle(Offset(nx, ny), nr, nucleusPaint);
        canvas.drawCircle(Offset(nx, ny), nr, strokePaint);
      }
    }

    if (items.isEmpty) return;
    final rScreen = foodRadiusWorld * z;
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = (2.0 * z).clamp(1.0, 2.0);
    final innerStrokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (2.0 * z).clamp(1.0, 2.0);
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    final innerFillPaint = Paint()
      ..color = fillColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final animalFillPaint = Paint()
      ..color = animalCellColor
      ..style = PaintingStyle.fill;
    final animalInnerFillPaint = Paint()
      ..color = animalCellColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final nucleusRadiusFrac = 0.22;
    final nucleusPaint = Paint()
      ..color = const Color(0xFF3d2914)
      ..style = PaintingStyle.fill;
    final nucleusStrokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (1.0 * z).clamp(0.5, 1.5);

    for (final food in items) {
      final cx = sx(food.x);
      final cy = sy(food.y);
      final rInner = rScreen * innerRadiusFrac.clamp(0.01, 0.99);
      if (food.cellType == CellType.animal) {
        final outer = Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: rScreen));
        final inner = Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: rInner));
        final ring = Path.combine(PathOperation.difference, outer, inner);
        canvas.drawPath(inner, animalInnerFillPaint);
        canvas.drawPath(ring, animalFillPaint);
        canvas.drawPath(outer, strokePaint);
        canvas.drawPath(inner, innerStrokePaint);
      } else {
        final outer = _smoothHexagonPath(cx, cy, rScreen);
        final inner = _smoothHexagonPath(cx, cy, rInner);
        final ring = Path.combine(PathOperation.difference, outer, inner);
        canvas.drawPath(inner, innerFillPaint);
        canvas.drawPath(ring, fillPaint);
        canvas.drawPath(outer, strokePaint);
        canvas.drawPath(inner, innerStrokePaint);
      }
      final nx = sx(food.x + food.nucleusOffsetX);
      final ny = sy(food.y + food.nucleusOffsetY);
      final nr = rScreen * nucleusRadiusFrac;
      canvas.drawCircle(Offset(nx, ny), nr, nucleusPaint);
      canvas.drawCircle(Offset(nx, ny), nr, nucleusStrokePaint);
    }
  }

  /// Closed path: smooth curved hexagon (rounded edges via quadratic bezier).
  Path _smoothHexagonPath(double cx, double cy, double radius) {
    const int sides = 6;
    final path = Path();
    final points = <Offset>[];
    for (var i = 0; i < sides; i++) {
      final t = (i / sides) * 2 * pi - pi / 2;
      points.add(Offset(cx + radius * cos(t), cy + radius * sin(t)));
    }
    path.moveTo(points[0].dx, points[0].dy);
    for (var i = 1; i <= sides; i++) {
      final curr = points[i % sides];
      final prev = points[i - 1];
      final mid = Offset(
        (prev.dx + curr.dx) / 2,
        (prev.dy + curr.dy) / 2,
      );
      final bulge = 1.12;
      final ctrlX = mid.dx + (mid.dx - cx) * (bulge - 1);
      final ctrlY = mid.dy + (mid.dy - cy) * (bulge - 1);
      path.quadraticBezierTo(ctrlX, ctrlY, curr.dx, curr.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant FoodPainter oldDelegate) =>
      oldDelegate.view != view ||
      oldDelegate.items != items ||
      oldDelegate.consumedRemnants != consumedRemnants ||
      oldDelegate.timeSeconds != timeSeconds ||
      oldDelegate.foodRadiusWorld != foodRadiusWorld ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.animalCellColor != animalCellColor ||
      oldDelegate.innerRadiusFrac != innerRadiusFrac;
}
