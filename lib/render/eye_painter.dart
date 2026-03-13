import 'package:flutter/material.dart';

void drawEye({
  required Canvas canvas,
  required Offset center,
  required double radius,
  required double strokeW,
  required double irisFrac,
  required double pupilFrac,
  required Color creatureColor,
  required Color finColor,
  required double primaryHighlightOffset,
  required double primaryHighlightRadiusFrac,
  required double secondaryHighlightOffset,
  required double secondaryHighlightRadiusFrac,
}) {
  final baseFill = Paint()
    ..color = creatureColor
    ..style = PaintingStyle.fill;

  final baseStroke = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeW * 3 / 4;

  canvas.drawCircle(center, radius, baseFill);
  canvas.drawCircle(center, radius, baseStroke);

  final irisR = radius * irisFrac;
  final irisRect = Rect.fromCircle(center: center, radius: irisR);

  final irisFill = Paint()
    ..shader = RadialGradient(
      center: Alignment.center,
      radius: 0.5,
      stops: [pupilFrac, 1 - ((1 - pupilFrac) / 2), 1.0],
      colors: [
        Color.lerp(creatureColor, Colors.white, 0.3)!,
        Color.lerp(finColor, creatureColor, 0.5)!,
        Color.lerp(finColor, Colors.black, 0.8)!,
      ],
    ).createShader(irisRect)
    ..style = PaintingStyle.fill;

  final irisStroke = Paint()
    ..color = Color.lerp(finColor, Colors.black, 0.6)!
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeW / 2;

  canvas.drawCircle(center, irisR, irisFill);
  canvas.drawCircle(center, irisR, irisStroke);

  final pupilR = radius * pupilFrac;

  final pupilFill = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.fill;

  final pupilStroke = Paint()
    ..color = Color.lerp(creatureColor, Colors.white, 0.2)!
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeW;

  canvas.drawCircle(center, pupilR, pupilFill);
  canvas.drawCircle(center, pupilR, pupilStroke);

  final primaryHighlight = Paint()
    ..color = Colors.white.withValues(alpha: 0.4)
    ..style = PaintingStyle.fill;

  final secondaryHighlight = Paint()
    ..color = Colors.white.withValues(alpha: 0.2)
    ..style = PaintingStyle.fill;

  canvas.drawCircle(
    Offset(
      center.dx - radius * primaryHighlightOffset,
      center.dy - radius * primaryHighlightOffset,
    ),
    radius * primaryHighlightRadiusFrac,
    primaryHighlight,
  );

  canvas.drawCircle(
    Offset(
      center.dx + radius * secondaryHighlightOffset,
      center.dy + radius * secondaryHighlightOffset,
    ),
    radius * secondaryHighlightRadiusFrac,
    secondaryHighlight,
  );
}
