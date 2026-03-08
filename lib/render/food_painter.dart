import 'dart:math' show cos, pi, sin, sqrt;

import 'package:flutter/material.dart';

import '../simulation/spine.dart';
import '../world/food.dart' show CellType, ConsumedRemnant, FoodItem;
import 'render_utils.dart' show drawBubble, drawBubbleShape;
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
      final scale = r.scale;
      final isBubbleRemnant = r.cellType == CellType.bubble;
      const burstDuration = 5.0;
      if (!isBubbleRemnant && age < burstDuration) {
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
        final driftAway = age * gasDriftSpeedWorld * scale;
        final t = age / burstDuration;
        final spreadWorld = (0.12 + t * 1.0) * (foodRadiusWorld * 4.2) * scale;
        final alphaFade = (1 - t).clamp(0.0, 1.0);
        final color = r.cellType == CellType.animal
            ? animalCellColor
            : fillColor;
        final puffRadiusBase = (foodRadiusWorld * z * 1.35 * scale).clamp(
          10.0,
          42.0 * scale,
        );
        final growFrac = 0.5 + 1.0 * t;
        void drawPuff(
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

        final centerWx = r.x + dirAx * driftAway;
        final centerWy = r.y + dirAy * driftAway;
        drawPuff(
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
          final px = sx(puffWx);
          final py = sy(puffWy);
          final rPuff =
              puffRadiusBase * (0.7 + 0.4 * ((i * 0.5) % 1.0)) * growFrac;
          final useLighter = i % 2 == 1;
          final opacity = (useLighter ? 0.32 : 0.5) * alphaFade;
          drawPuff(px, py, rPuff, color, opacity);
        }
      }
      const lineDuration = 3.3;
      if (!isBubbleRemnant && age < lineDuration) {
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
        final driftAway = age * gasDriftSpeedWorld * scale;
        const burstDurationSec = 5.0;
        final t = age / burstDurationSec;
        final spreadWorld = (0.12 + t * 1.0) * (foodRadiusWorld * 4.2) * scale;
        final lineScale = foodRadiusWorld * 0.48 * scale;
        final tLine = age / lineDuration;
        final baseAlpha =
            (tLine <= 0.5 ? 1.0 : (1.0 - (tLine - 0.5) / 0.5).clamp(0.0, 1.0)) *
            0.7;
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
            final mid = Offset(
              (start.dx + end.dx) / 2,
              (start.dy + end.dy) / 2,
            );
            final segDx = end.dx - start.dx;
            final segDy = end.dy - start.dy;
            final len = sqrt(segDx * segDx + segDy * segDy);
            final bulge = len > 1e-6 ? len * 0.28 : 0.0;
            final perpX = -segDy / len;
            final perpY = segDx / len;
            final control = Offset(
              mid.dx + perpX * bulge,
              mid.dy + perpY * bulge,
            );
            final path = Path()
              ..moveTo(start.dx, start.dy)
              ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
            canvas.drawPath(path, linePaint);
          } else {
            canvas.drawLine(start, end, linePaint);
          }
        }
      }
      if (!isBubbleRemnant && age < 7.5) {
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
        final drift = maxDriftWorld * (2 * t - t * t) * scale;
        final nucleusWx = baseNx + dx * drift;
        final nucleusWy = baseNy + dy * drift;
        final nx = sx(nucleusWx);
        final ny = sy(nucleusWy);
        final nr = (foodRadiusWorld * z * 0.22 * scale).clamp(
          2.0,
          12.0 * scale,
        );
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
      const dotsDuration = 5.0;
      if (age < dotsDuration) {
        final dotsAlpha = (1 - age / dotsDuration).clamp(0.0, 1.0) * 0.85 * 0.5;
        final dotRadiusScreen = (foodRadiusWorld * z * 0.18 * scale).clamp(
          2.0,
          8.0,
        );
        const maxSpreadWorld = 100.0;
        final t = (age / dotsDuration).clamp(0.0, 1.0);
        final nDots = 3 + ((r.x * 0.1 + r.y * 0.13 + r.consumedAt).floor() % 3);
        for (var d = 0; d < nDots; d++) {
          final jitter =
              ((d * 0.73 + r.x * 0.017 + r.y * 0.013 + r.consumedAt * 0.7) %
                      1.0) *
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
          final dotPaint = Paint()
            ..color = Colors.white.withValues(alpha: dotsAlpha)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(
            Offset(sx(dotWx), sy(dotWy)),
            dotRadiusScreen,
            dotPaint,
          );
        }
      }
      const bubbleDuration = 4.0;
      if (age < bubbleDuration) {
        var ax = r.x - r.headX;
        var ay = r.y - r.headY;
        var lenA = sqrt(ax * ax + ay * ay);
        if (lenA < 1e-6) {
          ax = 1.0;
          ay = 0.0;
          lenA = 1.0;
        } else {
          ax /= lenA;
          ay /= lenA;
        }
        final tb = (age / bubbleDuration).clamp(0.0, 1.0);
        const bubbleMaxDriftWorld = 90.0;
        final drift = bubbleMaxDriftWorld * (2 * tb - tb * tb) * scale;
        final bubbleAlpha = (1 - age / bubbleDuration).clamp(0.0, 1.0);
        const spreadRad = 0.55;
        const bubbleSizeSmall = 0.7;
        const bubbleSizeMedium = 1.0;
        const bubbleSizeLarge = 1.3;
        final sizes = [bubbleSizeSmall, bubbleSizeMedium, bubbleSizeLarge];
        final bubbleSizes = r.bubbleSizes;
        if (bubbleSizes.isEmpty) continue;
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
          final bubblePx = sx(bubbleWx);
          final bubblePy = sy(bubbleWy);
          final bubbleR = baseBubbleR * sizeScale;
          drawBubble(
            canvas,
            Offset(bubblePx, bubblePy),
            bubbleR,
            Colors.white,
            alpha: bubbleAlpha * 0.45,
          );
        }
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
      final cx = sx(food.x);
      final cy = sy(food.y);
      final rInner = rScreen * innerRadiusFrac.clamp(0.01, 0.99);
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
        canvas.drawCircle(Offset(cx, cy), rScreen, strokePaint);
      } else if (food.cellType == CellType.animal) {
        final outer = Path()
          ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: rScreen));
        final inner = Path()
          ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: rInner));
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
      if (food.cellType != CellType.bubble) {
        final nx = sx(food.x + food.nucleusOffsetX);
        final ny = sy(food.y + food.nucleusOffsetY);
        final nr = rScreen * nucleusRadiusFrac;
        canvas.drawCircle(Offset(nx, ny), nr, nucleusPaint);
        canvas.drawCircle(Offset(nx, ny), nr, nucleusStrokePaint);
      }
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

/// Gas flow from head to tail along the spine, drawn inside the creature body (clipped).
/// Driven by spine/creature location only; consumption only triggers the effect.
class InnerBodyCloudPainter extends CustomPainter {
  InnerBodyCloudPainter({
    required this.view,
    required this.spine,
    required this.consumedRemnants,
    required this.timeSeconds,
    required this.bodyClipPath,
    this.puffRadiusWorld = 12.0,
    this.fillColor = const Color(0xFF4A7C59),
    this.animalCellColor = const Color(0xFFb83c3c),
  });

  final CameraView view;
  final Spine spine;
  final List<ConsumedRemnant> consumedRemnants;
  final double timeSeconds;
  final Path bodyClipPath;
  final double puffRadiusWorld;
  final Color fillColor;
  final Color animalCellColor;

  static const double _duration = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    final positions = spine.positions;
    if (positions.length < 2) return;
    final z = view.zoom;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    double sx(double wx) => centerX + (wx - view.cameraX) * z;
    double sy(double wy) => centerY + (wy - view.cameraY) * z;

    canvas.save();
    canvas.clipPath(bodyClipPath);
    final baseRadiusWorld = puffRadiusWorld * 2.2;
    final baseRadius = (baseRadiusWorld * z).clamp(14.0, 52.0);
    const numPuffs = 22;

    for (final r in consumedRemnants) {
      if (r.cellType == CellType.bubble) continue;
      final age = timeSeconds - r.consumedAt;
      if (age < 0 || age > _duration) continue;
      final scale = r.scale;
      final t = age / _duration;
      final alpha = (1 - t).clamp(0.0, 1.0) * 0.5;
      final base = r.cellType == CellType.animal ? animalCellColor : fillColor;
      final dark = Color.lerp(base, const Color(0xFF000000), 0.32)!;
      final light = Color.lerp(base, const Color(0xFFFFFFFF), 0.35)!;
      final n = positions.length - 1;
      final flowEndIndex = (n * (1 - t)).round().clamp(0, n);
      final startIndex = n;
      final endIndex = flowEndIndex;
      if (startIndex < endIndex) continue;
      for (var p = 0; p < numPuffs; p++) {
        final useLight = (sin(p * 2.7 + r.consumedAt) * 0.5 + 0.5) > 0.5;
        final shade = useLight ? light : dark;
        final frac = numPuffs > 1 ? p / (numPuffs - 1) : 1.0;
        final segFrac =
            frac * 0.95 + (sin(frac * pi * 3 + t * 2) * 0.08 + 0.04);
        final idxF =
            endIndex + segFrac.clamp(0.0, 1.0) * (startIndex - endIndex);
        final idx0 = idxF.floor().clamp(0, n);
        final idx1 = (idx0 + 1).clamp(0, n);
        final blend = (idxF - idx0).clamp(0.0, 1.0);
        final v0 = positions[idx0];
        final v1 = positions[idx1];
        final vx = v0.x + (v1.x - v0.x) * blend;
        final vy = v0.y + (v1.y - v0.y) * blend;
        final perp = p * 1.7 + t * 4.3 + r.consumedAt;
        final offWorld =
            baseRadiusWorld *
            (0.15 + 0.75 * (sin(perp * 1.1) * 0.5 + 0.5)) *
            scale;
        final angle = perp * 0.9 + cos(p * 2.3) * 2;
        final jitterX = cos(angle) * offWorld;
        final jitterY = sin(angle) * offWorld;
        final wx = vx + jitterX;
        final wy = vy + jitterY;
        final px = sx(wx);
        final py = sy(wy);
        final rPuff =
            baseRadius * (0.5 + 0.85 * (sin(p * 2.1 + t) * 0.5 + 0.5)) * scale;
        final rect = Rect.fromCircle(center: Offset(px, py), radius: rPuff);
        final puffAlpha = alpha * (0.6 + 0.4 * (cos(p * 1.3) * 0.5 + 0.5));
        final paint = Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            radius: 1.0,
            colors: [
              shade.withValues(alpha: puffAlpha),
              shade.withValues(alpha: 0.0),
            ],
          ).createShader(rect);
        canvas.drawCircle(Offset(px, py), rPuff, paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant InnerBodyCloudPainter oldDelegate) =>
      oldDelegate.view != view ||
      oldDelegate.spine != spine ||
      oldDelegate.consumedRemnants != consumedRemnants ||
      oldDelegate.timeSeconds != timeSeconds ||
      oldDelegate.bodyClipPath != bodyClipPath;
}
