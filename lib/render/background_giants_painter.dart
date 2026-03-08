import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../controller/background_giant_store.dart';
import 'spine_painter.dart';
import 'view.dart';

/// Paints all background giants in a single blur layer. Sigma clamped to avoid Skia Invalid argument.
class BackgroundGiantsPainter extends CustomPainter {
  BackgroundGiantsPainter({
    required this.giants,
    required this.view,
    this.timeSeconds = 0.0,
    this.blurSigma = 5.0,
    this.layerOpacity = 0.35,
  });

  final List<StoredBackgroundGiant> giants;
  final CameraView view;
  final double timeSeconds;
  final double blurSigma;
  final double layerOpacity;

  static const double _maxBlurSigma = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (giants.isEmpty) return;
    final sigma = blurSigma.clamp(0.0, _maxBlurSigma);
    canvas.saveLayer(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..imageFilter = ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
    );
    for (final g in giants) {
      CreaturePainter(
        creature: g.creature,
        spine: g.spine,
        view: view,
        timeSeconds: timeSeconds,
      ).paint(canvas, size);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BackgroundGiantsPainter old) {
    return old.giants != giants ||
        old.view.cameraX != view.cameraX ||
        old.view.cameraY != view.cameraY ||
        old.view.zoom != view.zoom ||
        old.timeSeconds != timeSeconds ||
        old.blurSigma != blurSigma ||
        old.layerOpacity != layerOpacity;
  }
}
