import 'dart:math' show cos, sin;

import 'package:flutter/material.dart';

import 'view.dart';

/// Single background color for the simulation (dots, blur layer fill). Change here only.
const Color kSimulationBackground = Color(0xFF556688);

/// Fills the canvas with a solid color. Use as the bottom layer so other painters draw on top.
class SolidBackgroundPainter extends CustomPainter {
  SolidBackgroundPainter({Color? color}) : color = color ?? kSimulationBackground;

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
/// Add as the bottom layer of the stack so creatures draw on top.
class BackgroundPainter extends CustomPainter {
  BackgroundPainter({
    required this.view,
    this.timeSeconds = 0.0,
    this.parallaxBlobs = 0.8,
    this.parallaxBubbles = 0.9,
  });

  final CameraView view;
  final double timeSeconds;
  final double parallaxBlobs;
  final double parallaxBubbles;

  static const double _dotSpacing = 120.0;
  static const double _dotDriftAmount = 60.0; // +50% variance
  static const double _dotDriftSpeed = 0.4;
  static const double _dotRadius = 2.0;

  // Second layer: bubbles in the distance — bigger, slower, more spaced, blurred.
  static const double _bubbleSpacing = 320.0;
  static const double _bubbleDriftAmount = 210.0; // +100% variance
  static const double _bubbleDriftSpeed = 0.12;
  static const double _bubbleRadius = 7.0;
  static const double _bubbleBlurRadius = 5.0;

  // Third layer: distant blobs — even bigger, slower, more spaced, more blurred.
  static const double _blobSpacing = 520.0;
  static const double _blobDriftAmount = 510.0; // +200% variance
  static const double _blobDriftSpeed = 0.06;
  static const double _blobRadius = 14.0;
  static const double _blobBlurRadius = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final z = view.zoom;
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    final halfW = size.width / (2 * z);
    final halfH = size.height / (2 * z);

    // Layer 1: distant blobs — parallax 0.25 (same as big background creature).
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
    final blobPaint = Paint()
      ..color = Colors.white.withOpacity(0.14)
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, _blobBlurRadius);
    final blobT = timeSeconds * _blobDriftSpeed;
    for (var i = blobIMin; i <= blobIMax; i++) {
      for (var j = blobJMin; j <= blobJMax; j++) {
        final driftX = sin(i * 0.6 + j * 0.5 + blobT) * _blobDriftAmount;
        final driftY = cos(i * 0.5 + j * 0.7 + blobT * 1.2) * _blobDriftAmount;
        final wx = i * _blobSpacing + driftX;
        final wy = j * _blobSpacing + driftY;
        final px = blobSx(wx);
        final py = blobSy(wy);
        if (px >= -_blobRadius &&
            px <= size.width + _blobRadius &&
            py >= -_blobRadius &&
            py <= size.height + _blobRadius) {
          canvas.drawCircle(Offset(px, py), _blobRadius, blobPaint);
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
    final bubblePaint = Paint()
      ..color = Colors.white.withOpacity(0.22)
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, _bubbleBlurRadius);
    final bubbleT = timeSeconds * _bubbleDriftSpeed;
    for (var i = bubbleIMin; i <= bubbleIMax; i++) {
      for (var j = bubbleJMin; j <= bubbleJMax; j++) {
        final driftX = sin(i * 0.8 + j * 0.6 + bubbleT) * _bubbleDriftAmount;
        final driftY = cos(i * 0.7 + j * 0.9 + bubbleT * 1.1) * _bubbleDriftAmount;
        final wx = i * _bubbleSpacing + driftX;
        final wy = j * _bubbleSpacing + driftY;
        final px = bubbleSx(wx);
        final py = bubbleSy(wy);
        if (px >= -_bubbleRadius &&
            px <= size.width + _bubbleRadius &&
            py >= -_bubbleRadius &&
            py <= size.height + _bubbleRadius) {
          canvas.drawCircle(Offset(px, py), _bubbleRadius, bubblePaint);
        }
      }
    }

    // Layer 3: main dots (full camera, no parallax).
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
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    final t = timeSeconds * _dotDriftSpeed;
    for (var i = iMin; i <= iMax; i++) {
      for (var j = jMin; j <= jMax; j++) {
        final driftX = sin(i * 1.1 + j * 0.7 + t) * _dotDriftAmount;
        final driftY = cos(i * 0.9 + j * 1.3 + t * 0.8) * _dotDriftAmount;
        final wx = i * _dotSpacing + driftX;
        final wy = j * _dotSpacing + driftY;
        final px = dotSx(wx);
        final py = dotSy(wy);
        if (px >= -_dotRadius &&
            px <= size.width + _dotRadius &&
            py >= -_dotRadius &&
            py <= size.height + _dotRadius) {
          canvas.drawCircle(Offset(px, py), _dotRadius, dotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant BackgroundPainter oldDelegate) =>
      oldDelegate.view != view ||
      oldDelegate.timeSeconds != timeSeconds ||
      oldDelegate.parallaxBlobs != parallaxBlobs ||
      oldDelegate.parallaxBubbles != parallaxBubbles;
}
