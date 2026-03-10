import 'dart:math' show cos, pi, sin, sqrt;

import 'package:flutter/material.dart';

import 'package:creature_bio_sim/simulation/spine.dart';
import 'package:creature_bio_sim/world/consumed_remnant.dart';
import 'package:creature_bio_sim/world/food.dart' show CellType;
import 'package:creature_bio_sim/render/view.dart';

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

      // Flow starts at tip of head (front of creature), not center of head node.
      final head = positions[n];
      final neck = positions[n - 1];
      final dx = head.x - neck.x;
      final dy = head.y - neck.y;
      final len = sqrt(dx * dx + dy * dy);
      final halfHead = spine.segmentLength * 0.5;
      final tipX = len >= 1e-6
          ? head.x + (dx / len) * halfHead
          : head.x;
      final tipY = len >= 1e-6
          ? head.y + (dy / len) * halfHead
          : head.y;

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
        final v0x = idx0 == n ? tipX : positions[idx0].x;
        final v0y = idx0 == n ? tipY : positions[idx0].y;
        final v1x = idx1 == n ? tipX : positions[idx1].x;
        final v1y = idx1 == n ? tipY : positions[idx1].y;
        final vx = v0x + (v1x - v0x) * blend;
        final vy = v0y + (v1y - v0y) * blend;
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
