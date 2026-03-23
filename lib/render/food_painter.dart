import 'dart:math' show cos, pi, sin, sqrt;

import 'package:flutter/material.dart';

import 'package:bioism/world/consumed_remnant.dart';
import 'package:bioism/world/food.dart' show CellType, FoodItem;
import 'package:bioism/render/render_utils.dart'
    show drawBubble, drawBubbleShape;
import 'package:bioism/render/view.dart';

/// Paints plant cells (green hollow hexagon) and animal cells (red hollow circle).
/// Also draws consumed remnants: burst (radial lines ~0.3s) and nucleus fading over 5s.
class FoodPainter extends CustomPainter {
  FoodPainter({
    required this.view,
    required this.items,
    this.consumedRemnants = const [],
    this.timeSeconds = 0.0,
    this.foodRadiusWorld = 20.0,
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
      _paintRemnant(canvas, r, size, z, centerX, centerY, sx, sy);
    }

    if (items.isEmpty) return;
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

    const bubbleFillOpacity = 0.22;
    const bubbleRimOpacity = 0.35;
    const bubblePrimaryOpacity = 0.28;
    const bubbleSecondaryOpacity = 0.14;
    final bubbleFillPaint = Paint()
      ..color = Colors.white.withValues(alpha: bubbleFillOpacity)
      ..style = PaintingStyle.fill;
    final bubbleRimPaint = Paint()
      ..color = Colors.white.withValues(alpha: bubbleRimOpacity)
      ..style = PaintingStyle.stroke;
    final bubblePrimaryPaint = Paint()
      ..color = Colors.white.withValues(alpha: bubblePrimaryOpacity)
      ..style = PaintingStyle.fill;
    final bubbleSecondaryPaint = Paint()
      ..color = Colors.white.withValues(alpha: bubbleSecondaryOpacity)
      ..style = PaintingStyle.fill;

    for (final food in items) {
      final rWorld = food.radiusWorld ?? foodRadiusWorld;
      final rScreen = rWorld * z;
      final cx = sx(food.x);
      final cy = sy(food.y);
      final rInner = rScreen * innerRadiusFrac.clamp(0.01, 0.99);
      if (food.cellType == CellType.plant || food.cellType == CellType.animal) {
        canvas.save();
        canvas.translate(cx, cy);
        canvas.rotate(timeSeconds * food.rotationSpeed + food.rotationPhase);
        canvas.translate(-cx, -cy);
      }
      if (food.cellType == CellType.bubble) {
        drawBubbleShape(
          canvas,
          Offset(cx, cy),
          rScreen,
          bubbleFillPaint,
          bubbleRimPaint,
          bubblePrimaryPaint,
          bubbleSecondaryPaint,
        );
        final baseStroke = (2.0 * z).clamp(1.0, 2.0);
        if (food.isGiant) {
          final scale = (rScreen / (foodRadiusWorld * z)).clamp(1.0, 3.0);
          strokePaint.strokeWidth = (baseStroke * scale).clamp(2.0, 6.0);
        }
        canvas.drawCircle(Offset(cx, cy), rScreen, strokePaint);
        if (food.isGiant) strokePaint.strokeWidth = baseStroke;
      } else if (food.cellType == CellType.animal) {
        final center = Offset(cx, cy);
        final baseStroke = (2.0 * z).clamp(1.0, 2.0);
        if (food.isGiant) {
          final scale = (rScreen / (foodRadiusWorld * z)).clamp(1.0, 3.0);
          strokePaint.strokeWidth = (baseStroke * scale).clamp(2.0, 6.0);
          innerStrokePaint.strokeWidth = strokePaint.strokeWidth;
        }
        canvas.saveLayer(
          Rect.fromCircle(
            center: center,
            radius: rScreen + strokePaint.strokeWidth,
          ),
          Paint(),
        );
        canvas.drawCircle(center, rScreen, animalFillPaint);
        canvas.drawCircle(center, rInner, Paint()..blendMode = BlendMode.clear);
        canvas.drawCircle(center, rInner, animalInnerFillPaint);
        canvas.drawCircle(center, rScreen, strokePaint);
        canvas.drawCircle(center, rInner, innerStrokePaint);
        canvas.restore();
        if (food.isGiant) {
          strokePaint.strokeWidth = baseStroke;
          innerStrokePaint.strokeWidth = baseStroke;
        }
      } else {
        if (food.isGiant && food.attachedOffsets != null)
          _drawGiantPlantAttachedCells(
            canvas,
            food.x,
            food.y,
            food.attachedOffsets!,
            sx,
            sy,
            foodRadiusWorld * z,
            innerRadiusFrac,
            nucleusRadiusFrac,
            fillPaint,
            innerFillPaint,
            strokePaint,
            innerStrokePaint,
            nucleusPaint,
            nucleusStrokePaint,
          );
        final baseStroke = (2.0 * z).clamp(1.0, 2.0);
        if (food.isGiant) {
          final scale = (rScreen / (foodRadiusWorld * z)).clamp(1.0, 3.0);
          strokePaint.strokeWidth = (baseStroke * scale).clamp(2.0, 6.0);
          innerStrokePaint.strokeWidth = strokePaint.strokeWidth;
        }
        final outer = _smoothHexagonPath(cx, cy, rScreen);
        final inner = _smoothHexagonPath(cx, cy, rInner);
        final ring = Path.combine(PathOperation.difference, outer, inner);
        canvas.drawPath(inner, innerFillPaint);
        canvas.drawPath(ring, fillPaint);
        canvas.drawPath(outer, strokePaint);
        canvas.drawPath(inner, innerStrokePaint);
        if (food.isGiant) {
          strokePaint.strokeWidth = baseStroke;
          innerStrokePaint.strokeWidth = baseStroke;
        }
      }
      if (food.cellType != CellType.bubble) {
        final nx = sx(food.x + food.nucleusOffsetX);
        final ny = sy(food.y + food.nucleusOffsetY);
        final nr = rScreen * nucleusRadiusFrac;
        canvas.drawCircle(Offset(nx, ny), nr, nucleusPaint);
        canvas.drawCircle(Offset(nx, ny), nr, nucleusStrokePaint);
      }
      if (food.cellType == CellType.plant || food.cellType == CellType.animal) {
        canvas.restore();
      }
    }
  }

  static const double _remnantBurstDuration = 5.0;
  static const double _remnantLineDuration = 3.3;
  static const double _remnantNucleusDuration = 7.5;
  static const double _remnantDotsDuration = 5.0;
  static const double _remnantBubbleDuration = 4.0;
  static const double _gasDriftSpeedWorld = 60.0;

  void _paintRemnant(
    Canvas canvas,
    ConsumedRemnant r,
    Size size,
    double z,
    double centerX,
    double centerY,
    double Function(double) sx,
    double Function(double) sy,
  ) {
    final age = timeSeconds - r.consumedAt;
    if (age < 0) return;
    final scale = r.scale;
    final isBubbleRemnant = r.cellType == CellType.bubble;

    if (!isBubbleRemnant && age < _remnantBurstDuration) {
      final (dirAx, dirAy) = _remnantDir(r.x - r.headX, r.y - r.headY);
      final (driftAway, spreadWorld, t) = _remnantBurstParams(age, scale);
      _drawRemnantPuffs(
        canvas,
        r,
        dirAx,
        dirAy,
        driftAway,
        spreadWorld,
        t,
        sx,
        sy,
        z,
        scale,
      );
      if (age < _remnantLineDuration) {
        _drawRemnantLines(
          canvas,
          r,
          dirAx,
          dirAy,
          driftAway,
          spreadWorld,
          t,
          age,
          sx,
          sy,
          z,
          scale,
        );
      }
    }
    if (!isBubbleRemnant && age < _remnantNucleusDuration) {
      _drawRemnantNucleus(canvas, r, age, sx, sy, z, scale);
    }
    if (age < _remnantDotsDuration) {
      _drawRemnantDots(canvas, r, age, sx, sy, z, scale);
    }
    if (age < _remnantBubbleDuration) {
      _drawRemnantBubbles(canvas, r, age, sx, sy, z, scale);
    }
  }

  (double, double) _remnantDir(double dx, double dy) {
    final len = sqrt(dx * dx + dy * dy);
    if (len < 1e-6) return (1.0, 0.0);
    return (dx / len, dy / len);
  }

  (double, double, double) _remnantBurstParams(double age, double scale) {
    final driftAway = age * _gasDriftSpeedWorld * scale;
    final t = age / _remnantBurstDuration;
    final spreadWorld = (0.12 + t) * (foodRadiusWorld * 4.2) * scale;
    return (driftAway, spreadWorld, t);
  }

  void _drawRemnantPuff(
    Canvas canvas,
    double px,
    double py,
    double radius,
    Color fill,
    double opacity,
  ) {
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

  void _drawRemnantPuffs(
    Canvas canvas,
    ConsumedRemnant r,
    double dirAx,
    double dirAy,
    double driftAway,
    double spreadWorld,
    double t,
    double Function(double) sx,
    double Function(double) sy,
    double z,
    double scale,
  ) {
    final color = r.cellType == CellType.animal ? animalCellColor : fillColor;
    final puffRadiusBase = (foodRadiusWorld * z * 1.35 * scale).clamp(
      10.0,
      42.0 * scale,
    );
    final growFrac = 0.5 + 1.0 * t;
    final alphaFade = (1 - t).clamp(0.0, 1.0);

    final centerWx = r.x + dirAx * driftAway;
    final centerWy = r.y + dirAy * driftAway;
    _drawRemnantPuff(
      canvas,
      sx(centerWx),
      sy(centerWy),
      puffRadiusBase * 1.2 * growFrac,
      color,
      alphaFade * 0.5,
    );
    const puffs = 12;
    for (var i = 0; i < puffs; i++) {
      final angle = (i / puffs) * 2 * pi + (i * 0.17) + t * 0.4;
      final dist = spreadWorld * (0.35 + 0.65 * ((i * 0.73) % 1.0));
      final puffWx = r.x + cos(angle) * dist + dirAx * driftAway;
      final puffWy = r.y + sin(angle) * dist + dirAy * driftAway;
      final rPuff = puffRadiusBase * (0.7 + 0.4 * ((i * 0.5) % 1.0)) * growFrac;
      final useLighter = i % 2 == 1;
      final opacity = (useLighter ? 0.32 : 0.5) * alphaFade;
      _drawRemnantPuff(canvas, sx(puffWx), sy(puffWy), rPuff, color, opacity);
    }
  }

  void _drawRemnantLines(
    Canvas canvas,
    ConsumedRemnant r,
    double dirAx,
    double dirAy,
    double driftAway,
    double spreadWorld,
    double t,
    double age,
    double Function(double) sx,
    double Function(double) sy,
    double z,
    double scale,
  ) {
    final lineScale = foodRadiusWorld * 0.48 * scale;
    final tLine = age / _remnantLineDuration;
    final baseAlpha =
        (tLine <= 0.5 ? 1.0 : (1.0 - (tLine - 0.5) / 0.5).clamp(0.0, 1.0)) *
        0.7;
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = (3.0 * z).clamp(1.0, 3.0)
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < 6; i++) {
      final placeAngle = (i / 6) * 2 * pi + (i * 0.19) + t * 0.4;
      final dist = spreadWorld * (0.35 + 0.65 * ((i * 0.73) % 1.0));
      final lineCx = r.x + cos(placeAngle) * dist + dirAx * driftAway;
      final lineCy = r.y + sin(placeAngle) * dist + dirAy * driftAway;
      final segAngle = (i * 1.11 + r.x * 0.002 + age * 0.06) % (2 * pi);
      final halfLen = (i % 2 == 0 ? 0.9 : 0.4) * lineScale;
      final lineAlpha = i % 2 == 0 ? baseAlpha : baseAlpha * 0.45;
      linePaint.color = Colors.white.withValues(alpha: lineAlpha);
      final startWx = lineCx - cos(segAngle) * halfLen;
      final startWy = lineCy - sin(segAngle) * halfLen;
      final endWx = lineCx + cos(segAngle) * halfLen;
      final endWy = lineCy + sin(segAngle) * halfLen;
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
        final path = Path()
          ..moveTo(start.dx, start.dy)
          ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
        canvas.drawPath(path, linePaint);
      } else {
        canvas.drawLine(start, end, linePaint);
      }
    }
  }

  void _drawRemnantNucleus(
    Canvas canvas,
    ConsumedRemnant r,
    double age,
    double Function(double) sx,
    double Function(double) sy,
    double z,
    double scale,
  ) {
    final baseNx = r.x + r.nucleusOffsetX;
    final baseNy = r.y + r.nucleusOffsetY;
    final (dx, dy) = _remnantDir(baseNx - r.headX, baseNy - r.headY);
    const maxDriftWorld = 320.0;
    final t = (age / _remnantNucleusDuration).clamp(0.0, 1.0);
    final drift = maxDriftWorld * (2 * t - t * t) * scale;
    final nucleusWx = baseNx + dx * drift;
    final nucleusWy = baseNy + dy * drift;
    final nx = sx(nucleusWx);
    final ny = sy(nucleusWy);
    final nr = (foodRadiusWorld * z * 0.22 * scale).clamp(2.0, 12.0 * scale);
    final alpha = (1 - age / _remnantNucleusDuration).clamp(0.0, 1.0);
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

  void _drawRemnantDots(
    Canvas canvas,
    ConsumedRemnant r,
    double age,
    double Function(double) sx,
    double Function(double) sy,
    double z,
    double scale,
  ) {
    final dotsAlpha =
        (1 - age / _remnantDotsDuration).clamp(0.0, 1.0) * 0.85 * 0.5;
    final dotRadiusScreen = (foodRadiusWorld * z * 0.18 * scale).clamp(
      2.0,
      8.0,
    );
    const maxSpreadWorld = 100.0;
    final t = (age / _remnantDotsDuration).clamp(0.0, 1.0);
    final nDots = 3 + ((r.x * 0.1 + r.y * 0.13 + r.consumedAt).floor() % 3);
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: dotsAlpha)
      ..style = PaintingStyle.fill;
    for (var d = 0; d < nDots; d++) {
      final jitter =
          ((d * 0.73 + r.x * 0.017 + r.y * 0.013 + r.consumedAt * 0.7) % 1.0) *
              1.4 -
          0.7;
      final angle = (d / nDots) * 2 * pi + jitter;
      final dist =
          (0.2 + 0.8 * t) *
          maxSpreadWorld *
          (0.4 + 0.6 * ((d * 1.31 + r.x * 0.011 + r.y * 0.009) % 1.0)) *
          scale;
      final dotWx = r.x + cos(angle) * dist;
      final dotWy = r.y + sin(angle) * dist;
      canvas.drawCircle(
        Offset(sx(dotWx), sy(dotWy)),
        dotRadiusScreen,
        dotPaint,
      );
    }
  }

  void _drawRemnantBubbles(
    Canvas canvas,
    ConsumedRemnant r,
    double age,
    double Function(double) sx,
    double Function(double) sy,
    double z,
    double scale,
  ) {
    final (ax, ay) = _remnantDir(r.x - r.headX, r.y - r.headY);
    final tb = (age / _remnantBubbleDuration).clamp(0.0, 1.0);
    const bubbleMaxDriftWorld = 90.0;
    final drift = bubbleMaxDriftWorld * (2 * tb - tb * tb) * scale;
    final bubbleAlpha = (1 - age / _remnantBubbleDuration).clamp(0.0, 1.0);
    const spreadRad = 0.55;
    const bubbleSizeSmall = 0.7;
    const bubbleSizeMedium = 1.0;
    const bubbleSizeLarge = 1.3;
    final sizes = [bubbleSizeSmall, bubbleSizeMedium, bubbleSizeLarge];
    final bubbleSizes = r.bubbleSizes;
    if (bubbleSizes.isEmpty) return;
    final nBubbles = bubbleSizes.length.clamp(1, 3);
    final baseBubbleR = (foodRadiusWorld * z * 0.36 * scale).clamp(
      3.0,
      14.0 * scale,
    );
    for (var b = 0; b < nBubbles; b++) {
      final angle = nBubbles == 1
          ? 0.0
          : -spreadRad + (b * 2 * spreadRad / (nBubbles - 1));
      final sizeIndex = bubbleSizes[b].clamp(0, 2);
      final sizeScale = sizes[sizeIndex];
      final cosA = cos(angle);
      final sinA = sin(angle);
      final bx = ax * cosA - ay * sinA;
      final by = ax * sinA + ay * cosA;
      final bubbleWx = r.x + bx * drift;
      final bubbleWy = r.y + by * drift;
      final bubbleR = baseBubbleR * sizeScale;
      drawBubble(
        canvas,
        Offset(sx(bubbleWx), sy(bubbleWy)),
        bubbleR,
        Colors.white,
        alpha: bubbleAlpha * 0.45,
      );
    }
  }

  /// Small “bud” circles at hex vertices so the giant plant reads as a big cell with attached smaller cells.
  void _drawGiantPlantAttachedCells(
    Canvas canvas,
    double giantX,
    double giantY,
    List<(double, double)> offsets,
    double Function(double) sx,
    double Function(double) sy,
    double rScreen,
    double innerRadiusFracVal,
    double nucleusRadiusFracVal,
    Paint fillPaint,
    Paint innerFillPaint,
    Paint strokePaint,
    Paint innerStrokePaint,
    Paint nucleusPaint,
    Paint nucleusStrokePaint,
  ) {
    const double attachedCellRotation = pi / 6;
    final rInner = rScreen * innerRadiusFracVal.clamp(0.01, 0.99);
    for (final (ox, oy) in offsets) {
      final cx = sx(giantX + ox);
      final cy = sy(giantY + oy);
      final outer = _smoothHexagonPath(cx, cy, rScreen, attachedCellRotation);
      final inner = _smoothHexagonPath(cx, cy, rInner, attachedCellRotation);
      final ring = Path.combine(PathOperation.difference, outer, inner);
      canvas.drawPath(inner, innerFillPaint);
      canvas.drawPath(ring, fillPaint);
      canvas.drawPath(outer, strokePaint);
      canvas.drawPath(inner, innerStrokePaint);
      final nr = rScreen * nucleusRadiusFracVal;
      canvas.drawCircle(Offset(cx, cy), nr, nucleusPaint);
      canvas.drawCircle(Offset(cx, cy), nr, nucleusStrokePaint);
    }
  }

  /// Closed path: smooth curved hexagon (rounded edges via quadratic bezier). [rotation] rotates the hex in radians.
  Path _smoothHexagonPath(
    double cx,
    double cy,
    double radius, [
    double rotation = 0,
  ]) {
    const int sides = 6;
    final path = Path();
    final points = <Offset>[];
    for (var i = 0; i < sides; i++) {
      final t = (i / sides) * 2 * pi - pi / 2 + rotation;
      points.add(Offset(cx + radius * cos(t), cy + radius * sin(t)));
    }
    path.moveTo(points[0].dx, points[0].dy);
    for (var i = 1; i <= sides; i++) {
      final curr = points[i % sides];
      final prev = points[i - 1];
      final mid = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
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
