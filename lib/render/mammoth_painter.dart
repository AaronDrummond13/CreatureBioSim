import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:creature_bio_sim/controller/mammoth_store.dart';
import 'package:creature_bio_sim/render/creature_painter.dart';
import 'package:creature_bio_sim/render/view.dart';

/// Paints all mammoths (parallax layer). Each mammoth has its own blur and layer opacity (0.01–0.5).
class MammothPainter extends CustomPainter {
  MammothPainter({
    required this.mammoths,
    required this.view,
    this.timeSeconds = 0.0,
    this.blurSigma = 5.0,
  });

  final List<StoredMammoth> mammoths;
  final CameraView view;
  final double timeSeconds;
  final double blurSigma;

  static const double _maxBlurSigma = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (mammoths.isEmpty) return;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final sigma = blurSigma.clamp(0.0, _maxBlurSigma);
    for (final mammoth in mammoths) {
      canvas.saveLayer(
        rect,
        Paint()..color = Colors.white.withValues(alpha: mammoth.layerOpacity),
      );
      canvas.saveLayer(
        rect,
        Paint()..imageFilter = ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      );
      CreaturePainter(
        creature: mammoth.creature,
        spine: mammoth.spine,
        view: view,
        timeSeconds: timeSeconds,
      ).paint(canvas, size);
      canvas.restore();
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant MammothPainter old) {
    return old.mammoths != mammoths ||
        old.view.cameraX != view.cameraX ||
        old.view.cameraY != view.cameraY ||
        old.view.zoom != view.zoom ||
        old.timeSeconds != timeSeconds ||
        old.blurSigma != blurSigma;
  }
}
