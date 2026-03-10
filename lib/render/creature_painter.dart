import 'dart:math' show cos, pi, sin;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:creature_bio_sim/creature.dart';
import 'package:creature_bio_sim/simulation/angle_util.dart';
import 'package:creature_bio_sim/simulation/spine.dart';
import 'package:creature_bio_sim/simulation/vector.dart';
import 'package:creature_bio_sim/render/mouth_painter.dart';
import 'package:creature_bio_sim/render/render_utils.dart';
import 'package:creature_bio_sim/render/tail_painter.dart';
import 'package:creature_bio_sim/render/view.dart';

/// Contour line style: [schematic] = uniform line weight (clean schematic look);
/// [tubular] = thinner at body edges, thicker toward spine (true tubular form).
enum BodyContourStyle { schematic, tubular }

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

  /// When set, mouth animation runs 3x for 2s after this time (e.g. after eating).
  final double? lastAteAt;

  /// Contour line style. [BodyContourStyle.tubular] = thinner at edges, thicker at center.
  final BodyContourStyle bodyContourStyle;

  /// When false, do not draw the white contour lines between bands (fills only).
  final bool showContourLines;

  /// When true, blur the band fills so layer boundaries blend together.
  final bool blurBodyLayers;

  CreaturePainter({
    required this.creature,
    required this.spine,
    required this.view,
    this.timeSeconds = 0.0,
    this.lastAteAt,
    this.blurSigma,
    this.layerOpacity,
    this.blurLayerBackgroundColor,
    this.drawEyes = true,
    this.eyesOnly = false,
    this.isBaby = false,
    this.isEpic = false,
    this.bodyContourStyle = BodyContourStyle.tubular,
    this.showContourLines = false,
    this.blurBodyLayers = false,
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
    final w = creature.segmentWidths.isEmpty
        ? _fallbackWidth.clamp(Creature.minVertexWidth, Creature.maxVertexWidth)
        : creature.widthAtVertex(i);
    return w * _bodyScale;
  }

  /// Smooth outline so both sides stay symmetric (no center split). Uses spine and half-offsets:
  /// spine at each vertex, smooth the half-offset once, then rebuild right = spine + offset, left = spine - offset.
  /// Skips the two points at each end so the curve meets the head/tail cap arcs with matching tangent.
  static void _smoothBodyOutlineSymmetric(
    List<Offset> rightSide,
    List<Offset> leftSide,
    List<Offset> rightOut,
    List<Offset> leftOut,
  ) {
    assert(rightSide.length == leftSide.length && rightSide.length >= 5);
    final n = rightSide.length - 1;
    final spine = <Offset>[];
    final halfOffset = <Offset>[];
    for (var k = 0; k <= n; k++) {
      final r = rightSide[k];
      final l = leftSide[n - k];
      spine.add(Offset((r.dx + l.dx) / 2, (r.dy + l.dy) / 2));
      halfOffset.add(Offset((r.dx - l.dx) / 2, (r.dy - l.dy) / 2));
    }
    const prevFrac = 0.4;
    const nextFrac = 0.4;
    const currFrac = 0.2;
    for (var i = 2; i < halfOffset.length - 2; i++) {
      halfOffset[i] = Offset(
        halfOffset[i - 1].dx * prevFrac + halfOffset[i].dx * currFrac + halfOffset[i + 1].dx * nextFrac,
        halfOffset[i - 1].dy * prevFrac + halfOffset[i].dy * currFrac + halfOffset[i + 1].dy * nextFrac,
      );
    }
    rightOut.clear();
    leftOut.clear();
    for (var k = 0; k <= n; k++) {
      rightOut.add(Offset(spine[k].dx + halfOffset[k].dx, spine[k].dy + halfOffset[k].dy));
      leftOut.add(Offset(spine[n - k].dx - halfOffset[n - k].dx, spine[n - k].dy - halfOffset[n - k].dy));
    }
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
      if (creature.segmentWidths.isEmpty) {
        return _fallbackWidth.clamp(Creature.minVertexWidth, Creature.maxVertexWidth);
      }
      return creature.widthAtVertex(i);
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
    const tension = 1.0 / 6.0;
    final path = Path();
    final tailCenter = Offset(sx(positions[0].x), sy(positions[0].y));
    final tailLeft = Offset(
      tailCenter.dx + tailWWorld * z * cos(tailA + 3 * pi / 2),
      tailCenter.dy + tailWWorld * z * sin(tailA + 3 * pi / 2),
    );
    path.moveTo(tailLeft.dx, tailLeft.dy);
    path.arcTo(
      Rect.fromCircle(center: tailCenter, radius: tailWWorld * z),
      tailA + 3 * pi / 2,
      -pi,
      false,
    );
    final rightSide = <Offset>[for (var i = 0; i <= n; i++) rightAt(i)];
    final leftSide = <Offset>[for (var i = n; i >= 0; i--) leftAt(i)];
    final rightOut = <Offset>[];
    final leftOut = <Offset>[];
    if (rightSide.length >= 5) {
      CreaturePainter._smoothBodyOutlineSymmetric(rightSide, leftSide, rightOut, leftOut);
    } else {
      rightOut.addAll(rightSide);
      leftOut.addAll(leftSide);
    }
    appendSmoothCurve(path, rightOut, tension, closed: false);
    final headCenter = Offset(sx(positions[n].x), sy(positions[n].y));
    path.arcTo(
      Rect.fromCircle(center: headCenter, radius: headWWorld * z),
      headA + pi / 2,
      -pi,
      false,
    );
    appendSmoothCurve(path, leftOut, tension, closed: false);
    path.close();
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

  /// Draw order: tail fin (under body) → lateral fins → mouth → body → dorsal fins → eyes.
  void _drawCreature(Canvas canvas) {
    _drawTailFin(canvas);
    _drawLateralFins(canvas);
    _drawMouth(canvas);
    _drawBody(canvas);
    _drawDorsalFins(canvas);
    if (drawEyes && !isBaby) _drawEyes(canvas);
  }

  void _drawMouth(Canvas canvas) {
    if (creature.mouth == null) return;
    final n = _paintN;
    final headWidthWorld = creature.segmentWidths.isEmpty
        ? _fallbackWidth
        : creature.widthAtVertex(n);
    paintMouth(
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
      headWidthWorld,
      timeSeconds,
      lastAteAt: lastAteAt,
    );
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
    const tension = 1.0 / 6.0;
    final path = Path();
    final tailCenter = Offset(sx(positions[0].x), sy(positions[0].y));
    final tailLeft = Offset(
      tailCenter.dx + tailWWorld * _paintZ * cos(tailA + 3 * pi / 2),
      tailCenter.dy + tailWWorld * _paintZ * sin(tailA + 3 * pi / 2),
    );
    path.moveTo(tailLeft.dx, tailLeft.dy);
    path.arcTo(
      Rect.fromCircle(center: tailCenter, radius: tailWWorld * _paintZ),
      tailA + 3 * pi / 2,
      -pi,
      false,
    );
    final rightSide = <Offset>[for (var i = 0; i <= n; i++) rightAt(i)];
    final leftSide = <Offset>[for (var i = n; i >= 0; i--) leftAt(i)];
    final rightOut = <Offset>[];
    final leftOut = <Offset>[];
    if (rightSide.length >= 5) {
      _smoothBodyOutlineSymmetric(rightSide, leftSide, rightOut, leftOut);
    } else {
      rightOut.addAll(rightSide);
      leftOut.addAll(leftSide);
    }
    appendSmoothCurve(path, rightOut, tension, closed: false);
    final headCenter = Offset(sx(positions[n].x), sy(positions[n].y));
    path.arcTo(
      Rect.fromCircle(center: headCenter, radius: headWWorld * _paintZ),
      headA + pi / 2,
      -pi,
      false,
    );
    appendSmoothCurve(path, leftOut, tension, closed: false);
    path.close();
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = (3.0 * _paintZ).clamp(1.0, 3.0);

    canvas.save();
    canvas.clipPath(path);
    if (blurBodyLayers) {
      final dark = Color.lerp(_paintFillColor, Colors.black, _shadeDarkBlend)!;
      canvas.drawPath(
        path,
        Paint()
          ..color = dark
          ..style = PaintingStyle.fill,
      );
      final bounds = path.getBounds().inflate(24);
      canvas.saveLayer(
        bounds,
        Paint()..imageFilter = ImageFilter.blur(sigmaX: 1.0, sigmaY: 1.0),
      );
    }
    _drawBodyShadedBands(
      canvas,
      outlinePath: path,
      positions: positions,
      n: n,
      sx: sx,
      sy: sy,
      tailA: tailA,
      headA: headA,
      tailWWorld: tailWWorld,
      headWWorld: headWWorld,
      rightAt: rightAt,
      leftAt: leftAt,
    );
    if (blurBodyLayers) canvas.restore();
    canvas.restore();

    if (showContourLines) {
      _drawBodyContourLines(
        canvas,
        positions: positions,
        n: n,
        sx: sx,
        sy: sy,
        tailA: tailA,
        headA: headA,
        tailWWorld: tailWWorld,
        headWWorld: headWWorld,
        rightAt: rightAt,
        leftAt: leftAt,
      );
    }

    canvas.drawPath(path, strokePaint);
  }

  static const double _contourStrokeWidthFrac = 0.5;
  static const double _contourOpacity = 0.45;
  static const double _shadeDarkBlend = 0.4;
  static const double _shadeBrightBlend = 0.01;

  Path _buildContourPath(
    double t,
    List<Vector2> positions,
    int n,
    double Function(double) sx,
    double Function(double) sy,
    double tailA,
    double headA,
    double tailWWorld,
    double headWWorld,
    Offset Function(int) rightAt,
    Offset Function(int) leftAt, {
    bool reverse = false,
  }) {
    const tension = 1.0 / 6.0;
    final tailRadius = tailWWorld * (1 - t) * _paintZ;
    final headRadius = headWWorld * (1 - t) * _paintZ;
    final tailCenter = Offset(sx(positions[0].x), sy(positions[0].y));
    final headCenter = Offset(sx(positions[n].x), sy(positions[n].y));
    final tailLeft = Offset(
      tailCenter.dx + tailRadius * cos(tailA + 3 * pi / 2),
      tailCenter.dy + tailRadius * sin(tailA + 3 * pi / 2),
    );
    final rightSide = <Offset>[
      for (var i = 0; i <= n; i++)
        Offset.lerp(
          rightAt(i),
          Offset(sx(positions[i].x), sy(positions[i].y)),
          t,
        )!,
    ];
    final leftSide = <Offset>[
      for (var i = n; i >= 0; i--)
        Offset.lerp(
          leftAt(i),
          Offset(sx(positions[i].x), sy(positions[i].y)),
          t,
        )!,
    ];
    final rightOut = <Offset>[];
    final leftOut = <Offset>[];
    if (rightSide.length >= 5) {
      _smoothBodyOutlineSymmetric(rightSide, leftSide, rightOut, leftOut);
    } else {
      rightOut.addAll(rightSide);
      leftOut.addAll(leftSide);
    }
    final path = Path();
    if (!reverse) {
      path.moveTo(tailLeft.dx, tailLeft.dy);
      path.arcTo(
        Rect.fromCircle(center: tailCenter, radius: tailRadius),
        tailA + 3 * pi / 2,
        -pi,
        false,
      );
      appendSmoothCurve(path, rightOut, tension, closed: false);
      path.arcTo(
        Rect.fromCircle(center: headCenter, radius: headRadius),
        headA + pi / 2,
        -pi,
        false,
      );
      appendSmoothCurve(path, leftOut, tension, closed: false);
    } else {
      path.moveTo(tailLeft.dx, tailLeft.dy);
      appendSmoothCurve(
        path,
        leftOut.reversed.toList(),
        tension,
        closed: false,
      );
      path.arcTo(
        Rect.fromCircle(center: headCenter, radius: headRadius),
        headA + 3 * pi / 2,
        pi,
        false,
      );
      appendSmoothCurve(
        path,
        rightOut.reversed.toList(),
        tension,
        closed: false,
      );
      path.arcTo(
        Rect.fromCircle(center: tailCenter, radius: tailRadius),
        tailA + pi / 2,
        pi,
        false,
      );
    }
    path.close();
    return path;
  }

  /// Band boundaries: schematic = even spacing; tubular = each band gets wider from outline to spine (monotonic).
  List<double> _contourTValues() {
    switch (bodyContourStyle) {
      case BodyContourStyle.schematic:
        return [0.0, 0.25, 0.5, 0.75, 1.0];
      case BodyContourStyle.tubular:
        return [0.0, 0.1, 0.25, 1.0];
    }
  }

  int _contourTCount() => _contourTValues().length - 1;

  void _drawBodyShadedBands(
    Canvas canvas, {
    required Path outlinePath,
    required List<Vector2> positions,
    required int n,
    required double Function(double) sx,
    required double Function(double) sy,
    required double tailA,
    required double headA,
    required double tailWWorld,
    required double headWWorld,
    required Offset Function(int) rightAt,
    required Offset Function(int) leftAt,
  }) {
    final dark = Color.lerp(_paintFillColor, Colors.black, _shadeDarkBlend)!;
    final bright = Color.lerp(
      _paintFillColor,
      Colors.white,
      _shadeBrightBlend,
    )!;
    final mid = _paintFillColor;

    final contourT = _contourTValues();
    final bandColors = <Color>[
      dark,
      Color.lerp(dark, mid, 0.6)!,
      Color.lerp(mid, bright, 0.5)!,
      bright,
    ];

    for (var b = 0; b < _contourTCount(); b++) {
      final outerPath = b == 0
          ? outlinePath
          : _buildContourPath(
              contourT[b],
              positions,
              n,
              sx,
              sy,
              tailA,
              headA,
              tailWWorld,
              headWWorld,
              rightAt,
              leftAt,
            );
      final innerPath = _buildContourPath(
        contourT[b + 1],
        positions,
        n,
        sx,
        sy,
        tailA,
        headA,
        tailWWorld,
        headWWorld,
        rightAt,
        leftAt,
        reverse: true,
      );
      final bandPath = Path()
        ..addPath(outerPath, Offset.zero)
        ..addPath(innerPath, Offset.zero);

      final paint = Paint()
        ..color = bandColors[b]
        ..style = PaintingStyle.fill;
      canvas.drawPath(bandPath, paint);
    }
  }

  void _drawBodyContourLines(
    Canvas canvas, {
    required List<Vector2> positions,
    required int n,
    required double Function(double) sx,
    required double Function(double) sy,
    required double tailA,
    required double headA,
    required double tailWWorld,
    required double headWWorld,
    required Offset Function(int) rightAt,
    required Offset Function(int) leftAt,
  }) {
    final baseStrokeWidth = (3.0 * _paintZ).clamp(1.0, 3.0);
    final baseContourWidth = (baseStrokeWidth * _contourStrokeWidthFrac).clamp(
      0.5,
      1.5,
    );
    final contourT = _contourTValues();
    final contourPaint = Paint()
      ..color = Colors.white.withValues(
        alpha: bodyContourStyle == BodyContourStyle.tubular
            ? (_contourOpacity * 1.2).clamp(0.0, 1.0)
            : _contourOpacity,
      )
      ..style = PaintingStyle.stroke;

    for (var c = 1; c < contourT.length - 1; c++) {
      final t = contourT[c];
      final contourPath = _buildContourPath(
        t,
        positions,
        n,
        sx,
        sy,
        tailA,
        headA,
        tailWWorld,
        headWWorld,
        rightAt,
        leftAt,
      );
      switch (bodyContourStyle) {
        case BodyContourStyle.schematic:
          contourPaint.strokeWidth = baseContourWidth;
          break;
        case BodyContourStyle.tubular:
          // Linear: thin at outline (low t), thick toward spine (high t). No V — center is largest.
          final tubularFrac = (1 + 0.3 * -t);
          contourPaint.strokeWidth = (baseContourWidth * tubularFrac);
          break;
      }
      canvas.drawPath(contourPath, contourPaint);
    }
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
      oldDelegate.lastAteAt != lastAteAt ||
      oldDelegate.blurSigma != blurSigma ||
      oldDelegate.layerOpacity != layerOpacity ||
      oldDelegate.blurLayerBackgroundColor != blurLayerBackgroundColor ||
      oldDelegate.drawEyes != drawEyes ||
      oldDelegate.eyesOnly != eyesOnly ||
      oldDelegate.isBaby != isBaby ||
      oldDelegate.isEpic != isEpic ||
      oldDelegate.bodyContourStyle != bodyContourStyle ||
      oldDelegate.showContourLines != showContourLines ||
      oldDelegate.blurBodyLayers != blurBodyLayers;
}
