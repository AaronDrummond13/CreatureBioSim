import 'dart:math' show cos, sin;
import 'package:flutter/material.dart';
import '../world/biome_map.dart';
import 'render_utils.dart';
import 'view.dart';

/// Deterministic size variance from grid index: returns multiplier in [minFrac, 1].
double _sizeVariance(int i, int j, {double minFrac = 0.65}) {
  final t = sin(i * 1.7 + j * 2.3) * 0.5 + 0.5;
  return minFrac + (1.0 - minFrac) * t;
}

/// Single background color for the simulation (dots, blur layer fill). Change here only.
const Color kSimulationBackground = Color(0xFF556688);

/// Fills the canvas with a solid color. Use as the bottom layer so other painters draw on top.
class SolidBackgroundPainter extends CustomPainter {
  SolidBackgroundPainter({Color? color})
    : color = color ?? kSimulationBackground;

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant SolidBackgroundPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Paints the procedural background dots. Uses [view] for world→screen transform.
/// [parallaxBlobs] and [parallaxBubbles] scale camera position so layers move more slowly (depth).
/// When [biomeMap] is set, dots/blobs/bubbles are tinted by blended biome colour at their world position.
class BackgroundPainter extends CustomPainter {
  BackgroundPainter({
    required this.view,
    this.timeSeconds = 0.0,
    this.parallaxBlobs = 0.8,
    this.parallaxBubbles = 0.9,
    this.biomeMap,
    this.biomeTintFrac = 0.12,
  });

  final CameraView view;
  final double timeSeconds;
  final double parallaxBlobs;
  final double parallaxBubbles;
  final BiomeMap? biomeMap;

  /// When set with biomeMap, dots/bubbles/blobs are light with this fraction of biome colour (0 = pure white).
  final double biomeTintFrac;

  static const double _dotSpacing = 150.0;
  static const double _dotDriftAmount = 100.0;
  static const double _dotDriftSpeed = 0.3;
  static const double _dotRadius = 4.0;

  static const double _bubbleSpacing = 750.0;
  static const double _bubbleDriftAmount = 500.0;
  static const double _bubbleDriftSpeed = 0.1;
  static const double _bubbleRadius = 20.0;
  static const double _bubbleBlurRadius = 5.0;

  static const double _blobSpacing = 1500.0;
  static const double _blobDriftAmount = 1000.0;
  static const double _blobDriftSpeed = 0.05;
  static const double _blobRadius = 100.0;
  // Same shape as bubble: fill blur scaled by size (bubble 5 at r20 → blob 25 at r100).
  static const double _blobFillBlur =
      _blobRadius / _bubbleRadius * _bubbleBlurRadius;

  // Transparency for depth: blobs most transparent, then bubbles, dots opaque.
  static const double _blobFillOpacity = 0.12;
  static const double _blobRimOpacity = 0.15;
  static const double _blobPrimaryOpacity = 0.16;
  static const double _blobSecondaryOpacity = 0.08;
  static const double _bubbleFillOpacity = 0.18;
  static const double _bubbleRimOpacity = 0.3;
  static const double _bubblePrimaryOpacity = 0.25;
  static const double _bubbleSecondaryOpacity = 0.12;
  static const double _dotOpacity = 0.50;

  static const double _sizeVarianceMin = 0.4;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 1 || size.height < 1) return;
    final z = (view.zoom.isFinite && view.zoom >= 0.01) ? view.zoom : 1.0;
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    final halfW = size.width / (2 * z);
    final halfH = size.height / (2 * z);

    // Layer 1: distant blobs — parallax 0.25 (same as mammoths).
    final blobCamX = view.cameraX * parallaxBlobs;
    final blobCamY = view.cameraY * parallaxBlobs;
    double blobSx(double wx) => centerX + (wx - blobCamX) * z;
    double blobSy(double wy) => centerY + (wy - blobCamY) * z;
    final blobWorldLeft = blobCamX - halfW - size.width / z;
    final blobWorldRight = blobCamX + halfW + size.width / z;
    final blobWorldTop = blobCamY - halfH - size.height / z;
    final blobWorldBottom = blobCamY + halfH + size.height / z;

    final blobIMin = (blobWorldLeft / _blobSpacing).floor();
    final blobIMax = (blobWorldRight / _blobSpacing).ceil();
    final blobJMin = (blobWorldTop / _blobSpacing).floor();
    final blobJMax = (blobWorldBottom / _blobSpacing).ceil();
    final blobFill = Paint()
      ..color = Colors.white.withValues(alpha: _blobFillOpacity)
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, _blobFillBlur);
    final blobRim = Paint()
      ..color = Colors.white.withValues(alpha: _blobRimOpacity);
    final blobPrimary = Paint()
      ..color = Colors.white.withValues(alpha: _blobPrimaryOpacity)
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, _blobFillBlur * 0.5);
    final blobSecondary = Paint()
      ..color = Colors.white.withValues(alpha: _blobSecondaryOpacity)
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, _blobFillBlur * 0.4);
    final blobT = timeSeconds * _blobDriftSpeed;
    for (var i = blobIMin; i <= blobIMax; i++) {
      for (var j = blobJMin; j <= blobJMax; j++) {
        final rWorld =
            _blobRadius * _sizeVariance(i, j, minFrac: _sizeVarianceMin);
        final r = rWorld * z;
        final driftX = sin(i * 0.6 + j * 0.5 + blobT) * _blobDriftAmount;
        final driftY = cos(i * 0.5 + j * 0.7 + blobT * 1.2) * _blobDriftAmount;
        final wx = i * _blobSpacing + driftX;
        final wy = j * _blobSpacing + driftY;
        if (biomeMap != null) {
          final c = biomeMap!.blendedColorAt(wx, wy);
          blobFill.color = Color.lerp(
            Colors.white,
            c,
            biomeTintFrac,
          )!.withValues(alpha: _blobFillOpacity);
          blobRim.color = Color.lerp(
            Colors.white,
            c,
            biomeTintFrac,
          )!.withValues(alpha: _blobRimOpacity);
          blobPrimary.color = Color.lerp(
            Colors.white,
            c,
            biomeTintFrac,
          )!.withValues(alpha: _blobPrimaryOpacity);
          blobSecondary.color = Color.lerp(
            Colors.white,
            c,
            biomeTintFrac,
          )!.withValues(alpha: _blobSecondaryOpacity);
        }
        final px = blobSx(wx);
        final py = blobSy(wy);
        if (px >= -r &&
            px <= size.width + r &&
            py >= -r &&
            py <= size.height + r) {
          drawBubbleShape(
            canvas,
            Offset(px, py),
            r,
            blobFill,
            blobRim,
            blobPrimary,
            blobSecondary,
          );
        }
      }
    }

    // Layer 2: bubbles (mid distance) — parallax 0.5.
    final bubbleCamX = view.cameraX * parallaxBubbles;
    final bubbleCamY = view.cameraY * parallaxBubbles;
    double bubbleSx(double wx) => centerX + (wx - bubbleCamX) * z;
    double bubbleSy(double wy) => centerY + (wy - bubbleCamY) * z;
    final bubbleWorldLeft = bubbleCamX - halfW - size.width / z;
    final bubbleWorldRight = bubbleCamX + halfW + size.width / z;
    final bubbleWorldTop = bubbleCamY - halfH - size.height / z;
    final bubbleWorldBottom = bubbleCamY + halfH + size.height / z;

    final bubbleIMin = (bubbleWorldLeft / _bubbleSpacing).floor();
    final bubbleIMax = (bubbleWorldRight / _bubbleSpacing).ceil();
    final bubbleJMin = (bubbleWorldTop / _bubbleSpacing).floor();
    final bubbleJMax = (bubbleWorldBottom / _bubbleSpacing).ceil();
    final bubbleFill = Paint()
      ..color = Colors.white.withValues(alpha: _bubbleFillOpacity)
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, _bubbleBlurRadius);
    final bubbleRim = Paint()
      ..color = Colors.white.withValues(alpha: _bubbleRimOpacity);
    final bubblePrimary = Paint()
      ..color = Colors.white.withValues(alpha: _bubblePrimaryOpacity)
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, _bubbleBlurRadius * 0.5);
    final bubbleSecondary = Paint()
      ..color = Colors.white.withValues(alpha: _bubbleSecondaryOpacity)
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, _bubbleBlurRadius * 0.4);
    final bubbleT = timeSeconds * _bubbleDriftSpeed;
    for (var i = bubbleIMin; i <= bubbleIMax; i++) {
      for (var j = bubbleJMin; j <= bubbleJMax; j++) {
        final rWorld =
            _bubbleRadius * _sizeVariance(i, j, minFrac: _sizeVarianceMin);
        final r = rWorld * z;
        final driftX = sin(i * 0.8 + j * 0.6 + bubbleT) * _bubbleDriftAmount;
        final driftY =
            cos(i * 0.7 + j * 0.9 + bubbleT * 1.1) * _bubbleDriftAmount;
        final wx = i * _bubbleSpacing + driftX;
        final wy = j * _bubbleSpacing + driftY;
        if (biomeMap != null) {
          final c = biomeMap!.blendedColorAt(wx, wy);
          bubbleFill.color = Color.lerp(
            Colors.white,
            c,
            biomeTintFrac,
          )!.withValues(alpha: _bubbleFillOpacity);
          bubbleRim.color = Color.lerp(
            Colors.white,
            c,
            biomeTintFrac,
          )!.withValues(alpha: _bubbleRimOpacity);
          bubblePrimary.color = Color.lerp(
            Colors.white,
            c,
            biomeTintFrac,
          )!.withValues(alpha: _bubblePrimaryOpacity);
          bubbleSecondary.color = Color.lerp(
            Colors.white,
            c,
            biomeTintFrac,
          )!.withValues(alpha: _bubbleSecondaryOpacity);
        }
        final px = bubbleSx(wx);
        final py = bubbleSy(wy);
        if (px >= -r &&
            px <= size.width + r &&
            py >= -r &&
            py <= size.height + r) {
          drawBubbleShape(
            canvas,
            Offset(px, py),
            r,
            bubbleFill,
            bubbleRim,
            bubblePrimary,
            bubbleSecondary,
          );
        }
      }
    }

    // Layer 3: main dots (full camera) — same bubble shape, smallest, slight layer blur.
    final dotWorldLeft = view.cameraX - halfW - size.width / z;
    final dotWorldRight = view.cameraX + halfW + size.width / z;
    final dotWorldTop = view.cameraY - halfH - size.height / z;
    final dotWorldBottom = view.cameraY + halfH + size.height / z;
    double dotSx(double wx) => centerX + (wx - view.cameraX) * z;
    double dotSy(double wy) => centerY + (wy - view.cameraY) * z;

    final iMin = (dotWorldLeft / _dotSpacing).floor();
    final iMax = (dotWorldRight / _dotSpacing).ceil();
    final jMin = (dotWorldTop / _dotSpacing).floor();
    final jMax = (dotWorldBottom / _dotSpacing).ceil();
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: _dotOpacity)
      ..style = PaintingStyle.fill;

    final t = timeSeconds * _dotDriftSpeed;
    for (var i = iMin; i <= iMax; i++) {
      for (var j = jMin; j <= jMax; j++) {
        final rWorld =
            _dotRadius * _sizeVariance(i, j, minFrac: _sizeVarianceMin);
        final r = rWorld * z;
        final driftX = sin(i * 1.1 + j * 0.7 + t) * _dotDriftAmount;
        final driftY = cos(i * 0.9 + j * 1.3 + t * 0.8) * _dotDriftAmount;
        final wx = i * _dotSpacing + driftX;
        final wy = j * _dotSpacing + driftY;
        if (biomeMap != null) {
          dotPaint.color = Color.lerp(
            Colors.white,
            biomeMap!.blendedColorAt(wx, wy),
            biomeTintFrac,
          )!.withValues(alpha: _dotOpacity);
        } else {
          dotPaint.color = Colors.white.withValues(alpha: _dotOpacity);
        }
        final px = dotSx(wx);
        final py = dotSy(wy);
        if (px >= -r &&
            px <= size.width + r &&
            py >= -r &&
            py <= size.height + r) {
          canvas.drawCircle(Offset(px, py), r, dotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant BackgroundPainter oldDelegate) =>
      oldDelegate.view != view ||
      oldDelegate.timeSeconds != timeSeconds ||
      oldDelegate.parallaxBlobs != parallaxBlobs ||
      oldDelegate.parallaxBubbles != parallaxBubbles ||
      oldDelegate.biomeMap != biomeMap ||
      oldDelegate.biomeTintFrac != biomeTintFrac;
}
