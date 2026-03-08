import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../controller/mammoth_store.dart';
import 'spine_painter.dart';
import 'view.dart';

/// Paints all mammoths (parallax layer) in a single blur layer. Sigma clamped to avoid Skia Invalid argument.
class MammothPainter extends CustomPainter {
  MammothPainter({
    required this.mammoths,
    required this.view,
    this.timeSeconds = 0.0,
    this.blurSigma = 5.0,
    this.layerOpacity = 0.35,
  });

  final List<StoredMammoth> mammoths;
  final CameraView view;
  final double timeSeconds;
  final double blurSigma;
  final double layerOpacity;

  static const double _maxBlurSigma = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (mammoths.isEmpty) return;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.saveLayer(
      rect,
      Paint()..color = Colors.white.withValues(alpha: layerOpacity),
    );
    final sigma = blurSigma.clamp(0.0, _maxBlurSigma);
    canvas.saveLayer(
      rect,
      Paint()..imageFilter = ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
    );
    for (final mammoth in mammoths) {
      CreaturePainter(
        creature: mammoth.creature,
        spine: mammoth.spine,
        view: view,
        timeSeconds: timeSeconds,
      ).paint(canvas, size);
    }
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MammothPainter old) {
    return old.mammoths != mammoths ||
        old.view.cameraX != view.cameraX ||
        old.view.cameraY != view.cameraY ||
        old.view.zoom != view.zoom ||
        old.timeSeconds != timeSeconds ||
        old.blurSigma != blurSigma ||
        old.layerOpacity != layerOpacity;
  }
}
