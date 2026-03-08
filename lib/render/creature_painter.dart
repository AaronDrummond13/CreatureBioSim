import 'dart:math' show cos, pi, sin;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../creature.dart';
import '../simulation/angle_util.dart';
import '../simulation/spine.dart';
import '../simulation/vector.dart';
import 'render_utils.dart';
import 'tail_painter.dart';
import 'view.dart';

/// Paints one creature in world space. Uses [view] to transform world → screen.
/// For multiple creatures, pass the same [CameraView] to each painter so they share one camera.
class CreaturePainter extends CustomPainter {
  final Creature creature;
  final Spine spine;
  final CameraView view;

  /// Time in seconds for background dot drift (optional).
  final double timeSeconds;

  /// When set, creature is drawn as a blurred background layer (e.g. sigma 10, opacity 0.2).
  final double? blurSigma;
  final double? layerOpacity;

  /// Fill color for the blur layer so transparent pixels don't composite as black. Use simulation background color.
  final Color? blurLayerBackgroundColor;

  /// If false, skip drawing eyes (e.g. to draw inner-body cloud between body and eyes).
  final bool drawEyes;

  /// If true, draw only eyes (used after inner-body cloud for correct stacking).
  final bool eyesOnly;

  /// When true, draw at [kBabyRenderScale] (40%) and no eyes (baby creature).
  final bool isBaby;

  /// When true, draw at [kEpicRenderScale] (epic creature).
  final bool isEpic;

  /// Render scale for mammoths (normal size in parallax view).
  static const double kMammothRenderScale = 1.0;

  /// Render scale for epic creatures (main world, big).
  static const double kEpicRenderScale = 3.0;

  /// Render scale for baby creatures.
  static const double kBabyRenderScale = 0.33;

  static const double dorsalFinHeight = 18.0;
  static const double dorsalFinBaseFrac = 0.3;
  static const double caudalFinBaseFrac = 0.2;
  static const double _fallbackWidth = 30.0;

  CreaturePainter({
    required this.creature,
    required this.spine,
    required this.view,
    this.timeSeconds = 0.0,
    this.blurSigma,
    this.layerOpacity,
    this.blurLayerBackgroundColor,
    this.drawEyes = true,
    this.eyesOnly = false,
    this.isBaby = false,
    this.isEpic = false,
  });

  // Set during paint() for use by _drawTailFin, _drawBody, _drawDorsalFins, _drawEyes.
  late double _paintCenterX;
  late double _paintCenterY;
  late double _paintZ;
  late Color _paintFillColor;
  late List<Vector2> _paintPositions;
  late List<double> _paintSegmentAngles;
  late int _paintN;
  late double _bodyScale;
  late double _eyeScaleMultiplier;

  double _widthAt(int i) {
    final vw = creature.vertexWidths;
    double w;
    if (i < vw.length) {
      w = vw[i].clamp(Creature.minVertexWidth, Creature.maxVertexWidth);
    } else {
      w = _fallbackWidth.clamp(
        Creature.minVertexWidth,
        Creature.maxVertexWidth,
      );
    }
    return w * _bodyScale;
  }

  /// For babies: scale spine positions around head so creature is proportionally smaller (length and width).
  static List<Vector2> _positionsScaledFromHead(
    List<Vector2> positions,
    double scale,
  ) {
    if (positions.isEmpty) return positions;
    final head = positions.last;
    return [
      for (final p in positions)
        Vector2(
          head.x + (p.x - head.x) * scale,
          head.y + (p.y - head.y) * scale,
        ),
    ];
  }

  /// Builds the creature body outline path in screen coordinates for clipping (e.g. consumption effects).
  static Path buildBodyPath(
    Creature creature,
    Spine spine,
    CameraView view,
    Size size,
  ) {
    final positions = spine.positions;
    final segmentAngles = spine.segmentAngles;
    if (positions.length < 2 || segmentAngles.isEmpty) return Path();
    final n = positions.length - 1;
    final centerX = size.width / 2.0;
    final centerY = size.height / 2.0;
    final z = view.zoom;
    double sx(double wx) => centerX + (wx - view.cameraX) * z;
    double sy(double wy) => centerY + (wy - view.cameraY) * z;
    double widthAt(int i) {
      final vw = creature.vertexWidths;
      if (i < vw.length) {
        return vw[i].clamp(Creature.minVertexWidth, Creature.maxVertexWidth);
      }
      return _fallbackWidth.clamp(
        Creature.minVertexWidth,
        Creature.maxVertexWidth,
      );
    }

    double wAt(int i) => widthAt(i) * z;
    Offset rightAt(int i) {
      final a =
          segmentAngles[i < segmentAngles.length
              ? i
              : segmentAngles.length - 1];
      final w = wAt(i);
      return Offset(
        sx(positions[i].x) - sin(a) * w,
        sy(positions[i].y) + cos(a) * w,
      );
    }

    Offset leftAt(int i) {
      final a =
          segmentAngles[i < segmentAngles.length
              ? i
              : segmentAngles.length - 1];
      final w = wAt(i);
      return Offset(
        sx(positions[i].x) + sin(a) * w,
        sy(positions[i].y) - cos(a) * w,
      );
    }

    final tailA = segmentAngles[0];
    final headA = segmentAngles[segmentAngles.length - 1];
    final tailWWorld = widthAt(0);
    final headWWorld = widthAt(n);
    const int capSegments = 7;
    final curve = <Offset>[];
    for (var i = 0; i < capSegments; i++) {
      final t = i / (capSegments - 1);
      final a = tailA + 4 * pi / 3 + t * (2 * pi / 3 - 4 * pi / 3);
      curve.add(
        Offset(
          sx(positions[0].x + tailWWorld * cos(a)),
          sy(positions[0].y + tailWWorld * sin(a)),
        ),
      );
    }
    for (var i = 0; i <= n; i++) curve.add(rightAt(i));
    for (var i = 0; i < capSegments; i++) {
      final t = i / (capSegments - 1);
      final a = headA + pi / 3 - t * (2 * pi / 3);
      curve.add(
        Offset(
          sx(positions[n].x + headWWorld * cos(a)),
          sy(positions[n].y + headWWorld * sin(a)),
        ),
      );
    }
    for (var i = n; i >= 0; i--) curve.add(leftAt(i));
    const tension = 1.0 / 6.0;
    final path = Path();
    appendSmoothCurve(path, curve, tension, closed: true);
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final positions = spine.positions;
    final segmentAngles = spine.segmentAngles;
    if (positions.length < 2 || segmentAngles.isEmpty) return;

    final useBlurLayer = blurSigma != null;
    if (useBlurLayer) {
      // Skia/backend can reject large sigma (e.g. >20); clamp to avoid Invalid argument.
      final sigma = blurSigma!.clamp(0.0, 10.0);
      canvas.saveLayer(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()
          ..imageFilter = ImageFilter.blur(sigmaX: sigma, sigmaY: sigma)
          ..color = (layerOpacity != null
              ? Colors.white.withValues(alpha: layerOpacity!)
              : Colors.white)
          ..blendMode = BlendMode.modulate,
      );
      // Fill layer with background color so transparent pixels don't composite as black.
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = blurLayerBackgroundColor ?? Colors.white,
      );
    }

    _paintCenterX = size.width / 2;
    _paintCenterY = size.height / 2;
    _paintZ = view.zoom;
    _paintFillColor = Color(creature.color);
    _bodyScale = isEpic
        ? kEpicRenderScale
        : (isBaby ? kBabyRenderScale : kMammothRenderScale);
    final posScale = isEpic
        ? kEpicRenderScale
        : (isBaby ? kBabyRenderScale : kMammothRenderScale);
    _paintPositions = (isEpic || isBaby)
        ? _positionsScaledFromHead(positions, posScale)
        : positions;
    _paintSegmentAngles = segmentAngles;
    _paintN = _paintPositions.length - 1;
    _eyeScaleMultiplier = 1.0;

    if (eyesOnly) {
      if (!isBaby)
        _drawEyes(canvas); // babies have no eyes; epic has normal eyes
      if (useBlurLayer) canvas.restore();
      return;
    }
    _drawCreature(canvas);

    if (useBlurLayer) canvas.restore();
  }

  /// Draw order: tail fin (under body) → lateral fins → body → dorsal fins → eyes.
  void _drawCreature(Canvas canvas) {
    _drawTailFin(canvas);
    _drawLateralFins(canvas);
    _drawBody(canvas);
    _drawDorsalFins(canvas);
    if (drawEyes && !isBaby) _drawEyes(canvas);
  }

  void _drawTailFin(Canvas canvas) {
    paintTailFin(
      canvas,
      creature,
      _paintPositions,
      _paintSegmentAngles,
      _paintCenterX,
      _paintCenterY,
      _paintZ,
      view.cameraX,
      view.cameraY,
      _bodyScale,
      _paintFillColor,
      _widthAt,
    );
  }

  /// Lateral fins: ellipses under the body, attached at segment vertices.
  /// Angle locked to the segment closer to the head (seg+1). Neutral flare ~45° from inline.
  void _drawLateralFins(Canvas canvas) {
    final fins = creature.lateralFins;
    if (fins == null || fins.isEmpty) return;
    final positions = _paintPositions;
    final segmentAngles = _paintSegmentAngles;
    final n = _paintN;
    double sx(double wx) => _paintCenterX + (wx - view.cameraX) * _paintZ;
    double sy(double wy) => _paintCenterY + (wy - view.cameraY) * _paintZ;
    final finColor = creature.finColor != null
        ? Color(creature.finColor!)
        : Color.lerp(_paintFillColor, Colors.white, 0.12)!;
    final fillPaint = Paint()
      ..color = finColor
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = (2.0 * _paintZ).clamp(1.0, 2.0);
    const flareRad = 45.0 * pi / 180.0; // 35° from inline when neutral
    for (final seg in fins) {
      if (seg < 0 || seg >= n) continue;
      final segW = _widthAt(seg);
      final len = segW * 1.5;
      final wid = len / 3.0;
      final lenScreen = len * _paintZ;
      final widScreen = wid * _paintZ;
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: lenScreen,
        height: widScreen,
      );
      final aAttach = segmentAngles[seg < segmentAngles.length ? seg : seg - 1];
      final segHead = seg + 1 < segmentAngles.length ? seg + 1 : seg;
      final aLock = segmentAngles[segHead];
      final halfW = segW;
      final px = positions[seg].x;
      final py = positions[seg].y;
      final leftCx = px + sin(aAttach) * halfW;
      final leftCy = py - cos(aAttach) * halfW;
      final rightCx = px - sin(aAttach) * halfW;
      final rightCy = py + cos(aAttach) * halfW;
      final leftAngle = aLock + flareRad;
      final rightAngle = aLock - flareRad;
      canvas.save();
      canvas.translate(sx(leftCx), sy(leftCy));
      canvas.rotate(leftAngle);
      canvas.drawOval(rect, fillPaint);
      canvas.drawOval(rect, strokePaint);
      canvas.restore();
      canvas.save();
      canvas.translate(sx(rightCx), sy(rightCy));
      canvas.rotate(rightAngle);
      canvas.drawOval(rect, fillPaint);
      canvas.drawOval(rect, strokePaint);
      canvas.restore();
    }
  }

  void _drawBody(Canvas canvas) {
    final positions = _paintPositions;
    final segmentAngles = _paintSegmentAngles;
    final n = _paintN;
    double sx(double wx) => _paintCenterX + (wx - view.cameraX) * _paintZ;
    double sy(double wy) => _paintCenterY + (wy - view.cameraY) * _paintZ;
    double wAt(int i) => _widthAt(i) * _paintZ;
    Offset rightAt(int i) {
      final a =
          segmentAngles[i < segmentAngles.length
              ? i
              : segmentAngles.length - 1];
      final w = wAt(i);
      return Offset(
        sx(positions[i].x) - sin(a) * w,
        sy(positions[i].y) + cos(a) * w,
      );
    }

    Offset leftAt(int i) {
      final a =
          segmentAngles[i < segmentAngles.length
              ? i
              : segmentAngles.length - 1];
      final w = wAt(i);
      return Offset(
        sx(positions[i].x) + sin(a) * w,
        sy(positions[i].y) - cos(a) * w,
      );
    }

    final tailA = segmentAngles[0];
    final headA = segmentAngles[segmentAngles.length - 1];
    final tailWWorld = _widthAt(0);
    final headWWorld = _widthAt(n);
    const int capSegments = 7;
    final curve = <Offset>[];
    for (var i = 0; i < capSegments; i++) {
      final t = i / (capSegments - 1);
      final a = tailA + 4 * pi / 3 + t * (2 * pi / 3 - 4 * pi / 3);
      curve.add(
        Offset(
          sx(positions[0].x + tailWWorld * cos(a)),
          sy(positions[0].y + tailWWorld * sin(a)),
        ),
      );
    }
    for (var i = 0; i <= n; i++) curve.add(rightAt(i));
    for (var i = 0; i < capSegments; i++) {
      final t = i / (capSegments - 1);
      final a = headA + pi / 3 - t * (2 * pi / 3);
      curve.add(
        Offset(
          sx(positions[n].x + headWWorld * cos(a)),
          sy(positions[n].y + headWWorld * sin(a)),
        ),
      );
    }
    for (var i = n; i >= 0; i--) curve.add(leftAt(i));
    const tension = 1.0 / 6.0;
    final path = Path();
    appendSmoothCurve(path, curve, tension, closed: true);
    final fillPaint = Paint()
      ..color = _paintFillColor
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = (3.0 * _paintZ).clamp(1.0, 3.0);
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  void _drawDorsalFins(Canvas canvas) {
    final fins = creature.dorsalFins;
    if (fins == null || fins.isEmpty) return;
    final positions = _paintPositions;
    final segmentAngles = _paintSegmentAngles;
    double sx(double wx) => _paintCenterX + (wx - view.cameraX) * _paintZ;
    double sy(double wy) => _paintCenterY + (wy - view.cameraY) * _paintZ;
    final finColorResolved = creature.finColor != null
        ? Color(creature.finColor!)
        : Color.lerp(_paintFillColor, Colors.white, 0.15)!;
    final finFill = Paint()
      ..color = finColorResolved
      ..style = PaintingStyle.fill;
    final finStroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = (2.0 * _paintZ).clamp(1.0, 2.0);
    const tension = 1.0 / 6.0;
    final maxAngle = spine.maxJointAngleRad;
    for (final fin in fins) {
      final run = fin.$1;
      final fullH = (fin.$2 ?? dorsalFinHeight) * _bodyScale;
      if (run.isEmpty) continue;
      final s = run.first;
      final e = run.last;
      if (s < 0 || e >= segmentAngles.length || e + 1 >= positions.length)
        continue;
      final baseH = fullH * dorsalFinBaseFrac;
      final pts = <({double x, double y, double a, double bend})>[];
      for (var i = s; i <= e + 1; i++) {
        final ai = i < segmentAngles.length ? i : e;
        final bend = (i == s || i == e + 1)
            ? 0.0
            : relativeAngleDiff(segmentAngles[ai], segmentAngles[ai - 1]);
        pts.add((
          x: positions[i].x,
          y: positions[i].y,
          a: segmentAngles[ai],
          bend: bend,
        ));
      }
      final top = <Offset>[];
      final bottom = <Offset>[];
      final nPts = pts.length;
      for (var i = 0; i < nPts; i++) {
        final p = pts[i];
        final isEndpoint = i == 0 || i == nPts - 1;
        double hTop;
        double hBottom;
        if (isEndpoint) {
          hTop = hBottom = 0;
        } else {
          final r = (p.bend.abs() / maxAngle).clamp(0.0, 1.0);
          final ratio = r * r * (3.0 - 2.0 * r);
          final hOut = baseH + (fullH - baseH) * ratio;
          if (p.bend > 0) {
            hTop = hOut;
            hBottom = baseH;
          } else if (p.bend < 0) {
            hTop = baseH;
            hBottom = hOut;
          } else {
            hTop = hBottom = baseH;
          }
          final taper = nPts > 1 ? sin(pi * i / (nPts - 1)) : 1.0;
          hTop *= taper;
          hBottom *= taper;
        }
        final dxTop = -sin(p.a) * hTop;
        final dyTop = cos(p.a) * hTop;
        final dxBottom = -sin(p.a) * hBottom;
        final dyBottom = cos(p.a) * hBottom;
        top.add(Offset(sx(p.x + dxTop), sy(p.y + dyTop)));
        bottom.add(Offset(sx(p.x - dxBottom), sy(p.y - dyBottom)));
      }
      final path = Path();
      path.moveTo(top[0].dx, top[0].dy);
      appendSmoothCurve(path, top, tension);
      path.lineTo(bottom.last.dx, bottom.last.dy);
      appendSmoothCurve(path, bottom.reversed.toList(), tension);
      path.close();
      canvas.drawPath(path, finFill);
      canvas.drawPath(path, finStroke);
    }
  }

  void _drawEyes(Canvas canvas) {
    final positions = _paintPositions;
    final segmentAngles = _paintSegmentAngles;
    final n = _paintN;
    double sx(double wx) => _paintCenterX + (wx - view.cameraX) * _paintZ;
    double sy(double wy) => _paintCenterY + (wy - view.cameraY) * _paintZ;
    double wAt(int i) => _widthAt(i) * _paintZ;
    final headA = segmentAngles[segmentAngles.length - 1];
    const eyeInset = 0.55;
    final headW = wAt(n);
    final headCx = sx(positions[n].x);
    final headCy = sy(positions[n].y);
    final rightEye = Offset(
      headCx - sin(headA) * headW * eyeInset,
      headCy + cos(headA) * headW * eyeInset,
    );
    final leftEye = Offset(
      headCx + sin(headA) * headW * eyeInset,
      headCy - cos(headA) * headW * eyeInset,
    );
    final eyeRadius = headW * 0.24 * _eyeScaleMultiplier;
    final eyePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(rightEye, eyeRadius, eyePaint);
    canvas.drawCircle(leftEye, eyeRadius, eyePaint);
  }

  @override
  bool shouldRepaint(covariant CreaturePainter oldDelegate) =>
      oldDelegate.creature != creature ||
      oldDelegate.spine != spine ||
      oldDelegate.view != view ||
      oldDelegate.timeSeconds != timeSeconds ||
      oldDelegate.blurSigma != blurSigma ||
      oldDelegate.layerOpacity != layerOpacity ||
      oldDelegate.blurLayerBackgroundColor != blurLayerBackgroundColor ||
      oldDelegate.drawEyes != drawEyes ||
      oldDelegate.eyesOnly != eyesOnly ||
      oldDelegate.isBaby != isBaby ||
      oldDelegate.isEpic != isEpic;
}
