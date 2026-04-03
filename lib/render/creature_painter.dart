import 'dart:math' show cos, pi, sin, sqrt;
import 'dart:ui' show ImageFilter;
import 'package:bioism/render/antenna_painter.dart' show drawAntennaAtSegment;
import 'package:bioism/render/eye_painter.dart';
import 'package:bioism/render/pec_painter.dart';
import 'package:flutter/material.dart';
import 'package:bioism/creature.dart';
import 'package:bioism/simulation/angle_util.dart';
import 'package:bioism/simulation/spine.dart';
import 'package:bioism/simulation/vector.dart';
import 'package:bioism/render/mouth_painter.dart';
import 'package:bioism/render/render_utils.dart';
import 'package:bioism/render/tail_painter.dart';
import 'package:bioism/render/view.dart';

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

  /// If true, draw only dorsal fins and eyes (e.g. above inner-body cloud). Mutually exclusive with [eyesOnly].
  final bool dorsalAndEyesOnly;

  /// If true, draw tail, lateral, mouth, body only (no dorsal, no eyes); used so dorsal+eyes can be drawn above cloud.
  final bool skipDorsalAndEyes;

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
    this.dorsalAndEyesOnly = false,
    this.skipDorsalAndEyes = false,
    this.isBaby = false,
    this.isEpic = false,
    this.bodyContourStyle = BodyContourStyle.tubular,
    this.showContourLines = false,
    this.blurBodyLayers = false,
  });

  // Set during paint() for use by _drawTailFin, _drawBody, _drawDorsalFins, _drawConfigEyes.
  late double _paintCenterX;
  late double _paintCenterY;
  late double _paintZ;
  late Color _paintFillColor;
  late List<Vector2> _paintPositions;
  late List<double> _paintSegmentAngles;
  late int _paintN;
  late double _bodyScale;
  double _widthAt(int i) {
    final w = creature.segmentWidths.isEmpty
        ? _fallbackWidth.clamp(Creature.minVertexWidth, Creature.maxVertexWidth)
        : creature.widthAtVertex(i);
    return w * _bodyScale;
  }

  /// Evaluate cubic Bézier at t: (1-t)³P0 + 3(1-t)²t C0 + 3(1-t)t² C1 + t³ P1.
  static Offset _cubicAt(double t, Offset p0, Offset c0, Offset c1, Offset p1) {
    final u = 1.0 - t;
    final u2 = u * u;
    final u3 = u2 * u;
    final t2 = t * t;
    final t3 = t2 * t;
    return Offset(
      u3 * p0.dx + 3 * u2 * t * c0.dx + 3 * u * t2 * c1.dx + t3 * p1.dx,
      u3 * p0.dy + 3 * u2 * t * c0.dy + 3 * u * t2 * c1.dy + t3 * p1.dy,
    );
  }

  /// Appends a cubic Bézier cap from [p0] to [p1] with tangent continuity. [exitDir] at p0 and
  /// [entryDir] at p1 (unnormalized); [radius] scales the control point distance (e.g. cap radius).
  /// Uses k=0.72 so caps bulge smoothly (round ball) without pinching at the tip.
  static void _appendCubicCap(
    Path path,
    Offset p0,
    Offset p1,
    Offset exitDir,
    Offset entryDir,
    double radius,
  ) {
    const k = 0.72; // rounder than 0.55 to avoid pinched ends
    final exitLen = sqrt(exitDir.dx * exitDir.dx + exitDir.dy * exitDir.dy);
    final entryLen = sqrt(
      entryDir.dx * entryDir.dx + entryDir.dy * entryDir.dy,
    );
    final uExit = exitLen >= 1e-6
        ? Offset(exitDir.dx / exitLen, exitDir.dy / exitLen)
        : Offset.zero;
    final uEntry = entryLen >= 1e-6
        ? Offset(entryDir.dx / entryLen, entryDir.dy / entryLen)
        : Offset.zero;
    final c0 = Offset(
      p0.dx + k * radius * uExit.dx,
      p0.dy + k * radius * uExit.dy,
    );
    final c1 = Offset(
      p1.dx - k * radius * uEntry.dx,
      p1.dy - k * radius * uEntry.dy,
    );
    path.cubicTo(c0.dx, c0.dy, c1.dx, c1.dy, p1.dx, p1.dy);
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
        halfOffset[i - 1].dx * prevFrac +
            halfOffset[i].dx * currFrac +
            halfOffset[i + 1].dx * nextFrac,
        halfOffset[i - 1].dy * prevFrac +
            halfOffset[i].dy * currFrac +
            halfOffset[i + 1].dy * nextFrac,
      );
    }
    rightOut.clear();
    leftOut.clear();
    for (var k = 0; k <= n; k++) {
      rightOut.add(
        Offset(spine[k].dx + halfOffset[k].dx, spine[k].dy + halfOffset[k].dy),
      );
      leftOut.add(
        Offset(
          spine[n - k].dx - halfOffset[n - k].dx,
          spine[n - k].dy - halfOffset[n - k].dy,
        ),
      );
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
        return _fallbackWidth.clamp(
          Creature.minVertexWidth,
          Creature.maxVertexWidth,
        );
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
    const tension = 0.2;
    final path = Path();
    final tailCenter = Offset(sx(positions[0].x), sy(positions[0].y));
    final tailLeft = Offset(
      tailCenter.dx + tailWWorld * z * cos(tailA + 3 * pi / 2),
      tailCenter.dy + tailWWorld * z * sin(tailA + 3 * pi / 2),
    );
    path.moveTo(tailLeft.dx, tailLeft.dy);
    final rightSide = <Offset>[for (var i = 0; i <= n; i++) rightAt(i)];
    final leftSide = <Offset>[for (var i = n; i >= 0; i--) leftAt(i)];
    final rightOut = <Offset>[];
    final leftOut = <Offset>[];
    if (rightSide.length >= 5) {
      CreaturePainter._smoothBodyOutlineSymmetric(
        rightSide,
        leftSide,
        rightOut,
        leftOut,
      );
    } else {
      rightOut.addAll(rightSide);
      leftOut.addAll(leftSide);
    }
    final tailRadius = tailWWorld * z;
    final tailTip = Offset(
      tailCenter.dx - tailRadius * cos(tailA),
      tailCenter.dy - tailRadius * sin(tailA),
    );
    final tailLeftTangent = Offset(
      leftOut.last.dx - leftOut[leftOut.length - 2].dx,
      leftOut.last.dy - leftOut[leftOut.length - 2].dy,
    );
    CreaturePainter._appendCubicCap(
      path,
      tailLeft,
      tailTip,
      tailLeftTangent,
      Offset(-sin(tailA), cos(tailA)),
      tailRadius,
    );
    CreaturePainter._appendCubicCap(
      path,
      tailTip,
      rightOut.first,
      Offset(-sin(tailA), cos(tailA)),
      Offset(rightOut[1].dx - rightOut[0].dx, rightOut[1].dy - rightOut[0].dy),
      tailRadius,
    );
    appendSmoothCurve(path, rightOut, tension, closed: false);
    final headRadius = headWWorld * z;
    final headCenter = Offset(sx(positions[n].x), sy(positions[n].y));
    final headTip = Offset(
      headCenter.dx + headRadius * cos(headA),
      headCenter.dy + headRadius * sin(headA),
    );
    final headRightTangent = Offset(
      rightOut.last.dx - rightOut[rightOut.length - 2].dx,
      rightOut.last.dy - rightOut[rightOut.length - 2].dy,
    );
    final headLeftTangent = Offset(
      leftOut[1].dx - leftOut[0].dx,
      leftOut[1].dy - leftOut[0].dy,
    );
    final headTipTangent = Offset(sin(headA), -cos(headA));
    CreaturePainter._appendCubicCap(
      path,
      rightOut.last,
      headTip,
      headRightTangent,
      headTipTangent,
      headRadius,
    );
    CreaturePainter._appendCubicCap(
      path,
      headTip,
      leftOut.first,
      headTipTangent,
      headLeftTangent,
      headRadius,
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

    if (eyesOnly) {
      if (!isBaby) {
        final configEyes = creature.eyes;
        if (configEyes != null && configEyes.isNotEmpty)
          _drawConfigEyes(canvas);
      }
      if (useBlurLayer) canvas.restore();
      return;
    }
    if (dorsalAndEyesOnly) {
      _drawDorsalFins(canvas);
      if (!isBaby) {
        final configEyes = creature.eyes;
        if (configEyes != null && configEyes.isNotEmpty)
          _drawConfigEyes(canvas);
      }
      if (useBlurLayer) canvas.restore();
      return;
    }
    _drawCreature(canvas);

    if (useBlurLayer) canvas.restore();
  }

  /// Draw order (matches player creature levels 1–3 + eyes): tail fin → lateral fins → mouth → body [→ dorsal fins → eyes when !skipDorsalAndEyes and drawEyes].
  void _drawCreature(Canvas canvas) {
    _drawTailFin(canvas);
    _drawAntennae(canvas);
    _drawLateralFins(canvas);
    _drawMouth(canvas);
    _drawBody(canvas);
    if (!skipDorsalAndEyes) {
      if (drawEyes && !isBaby) {
        final configEyes = creature.eyes;
        if (configEyes != null && configEyes.isNotEmpty)
          _drawConfigEyes(canvas);
        // No fallback head eyes: only config eyes are drawn, so editor selection/remove works.
      }
      _drawDorsalFins(canvas);
    }
  }

  /// Draw eyes from [creature.eyes]: full iris (no sclera) + pupil, with bubble-style highlight; single eye when offset < threshold.
  /// Max perpendicular shift as fraction of halfWidth when body bends.
  static const double _eyeBendShiftFrac = .5;

  void _drawConfigEyes(Canvas canvas) {
    final eyes = creature.eyes!;
    final positions = _paintPositions;
    final segmentAngles = spine.segmentAngles;
    if (positions.length < 2 || segmentAngles.isEmpty) return;
    double sx(double wx) => _paintCenterX + (wx - view.cameraX) * _paintZ;
    double sy(double wy) => _paintCenterY + (wy - view.cameraY) * _paintZ;
    const irisFrac = 0.90;
    const primaryHighlightOffset = 0.2;
    const primaryHighlightRadiusFrac = 0.3;
    const secondaryHighlightOffset = 0.26;
    const secondaryHighlightRadiusFrac = 0.2;
    for (var eyeIdx = 0; eyeIdx < eyes.length; eyeIdx++) {
      final eye = eyes[eyeIdx];
      final seg = eye.segment;
      if (seg < 0 || seg >= segmentAngles.length || seg + 1 >= positions.length)
        continue;
      final halfW = _widthAt(seg);
      final cx = (positions[seg].x + positions[seg + 1].x) / 2;
      final cy = (positions[seg].y + positions[seg + 1].y) / 2;
      final a = segmentAngles[seg];
      final rWorld = eye.radius * _bodyScale;
      final rScreen = rWorld * _paintZ;
      final strokeW = (rScreen * 0.12).clamp(1.2, 3.0);
      final isSingle = eye.offsetFromCenter < EyeConfig.singleEyeThreshold;

      // Bend: signed angle difference to adjacent segment. Positive = curving one way, negative = other.
      double bend = 0.0;
      if (!isSingle && segmentAngles.length > 1) {
        if (seg + 1 < segmentAngles.length) {
          bend = segmentAngles[seg + 1] - segmentAngles[seg];
        } else if (seg > 0) {
          bend = segmentAngles[seg] - segmentAngles[seg - 1];
        }
        // Normalise to [-pi, pi].
        while (bend > pi) bend -= 2 * pi;
        while (bend < -pi) bend += 2 * pi;
      }

      // Perpendicular shift: bend pulls eyes toward concave side.
      // perpDir is (-sin(a), cos(a)) — same direction as offset. Positive bend = eyes shift in +perpDir.
      final bendShift = !isSingle
          ? -bend.clamp(-1.0, 1.0) * _eyeBendShiftFrac * halfW
          : 0.0;
      final perpDx = -sin(a) * bendShift;
      final perpDy = cos(a) * bendShift;

      final anchorPairs = <(double, double)>[];
      if (isSingle) {
        anchorPairs.add((cx, cy));
      } else {
        final off = eye.offsetFromCenter * halfW;
        final dx = -sin(a) * off;
        final dy = cos(a) * off;
        anchorPairs.add((cx + dx + perpDx, cy + dy + perpDy));
        anchorPairs.add((cx - dx + perpDx, cy - dy + perpDy));
      }

      final centers = <Offset>[];
      for (final (ax, ay) in anchorPairs) {
        centers.add(Offset(sx(ax), sy(ay)));
      }
      final pupilFrac = eye.pupilFraction;
      for (final center in centers) {
        drawEye(
          canvas: canvas,
          center: center,
          radius: rScreen,
          strokeW: strokeW,
          irisFrac: irisFrac,
          pupilFrac: pupilFrac,
          creatureColor: Color(creature.color),
          finColor: Color(creature.finColor ?? creature.color),
          primaryHighlightOffset: primaryHighlightOffset,
          primaryHighlightRadiusFrac: primaryHighlightRadiusFrac,
          secondaryHighlightOffset: secondaryHighlightOffset,
          secondaryHighlightRadiusFrac: secondaryHighlightRadiusFrac,
        );
      }
    }
  }

  /// Shared head cap curve in world space (right edge → tip → left edge). Uses same body outline
  /// logic as [_drawBody]. [widthAtWorld] = world-space width at vertex index (e.g. creature.widthAtVertex(i) * bodyScale).
  /// Used by both CreaturePainter and editor preview so mouth placement matches actual render.
  static List<Offset>? computeHeadCapFaceCurveWorld({
    required List<Vector2> positions,
    required List<double> segmentAngles,
    required double Function(int) widthAtWorld,
    required double centerX,
    required double centerY,
    required double zoom,
    required double cameraX,
    required double cameraY,
  }) {
    final n = positions.length - 1;
    if (n < 0 || positions.length < 2 || segmentAngles.isEmpty) return null;
    double sx(double wx) => centerX + (wx - cameraX) * zoom;
    double sy(double wy) => centerY + (wy - cameraY) * zoom;
    double wAt(int i) => widthAtWorld(i) * zoom;
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
    if (rightOut.isEmpty || leftOut.isEmpty) return null;
    final headA = segmentAngles[segmentAngles.length - 1];
    final headRadius = widthAtWorld(n) * zoom;
    final headCenter = Offset(sx(positions[n].x), sy(positions[n].y));
    final headTip = Offset(
      headCenter.dx + headRadius * cos(headA),
      headCenter.dy + headRadius * sin(headA),
    );
    final headRightTangent = Offset(
      rightOut.last.dx - rightOut[rightOut.length - 2].dx,
      rightOut.last.dy - rightOut[rightOut.length - 2].dy,
    );
    final headLeftTangent = Offset(
      leftOut[1].dx - leftOut[0].dx,
      leftOut[1].dy - leftOut[0].dy,
    );
    final headTipTangent = Offset(sin(headA), -cos(headA));
    const k = 0.72;
    Offset norm(Offset o) {
      final len = sqrt(o.dx * o.dx + o.dy * o.dy);
      if (len >= 1e-6) return Offset(o.dx / len, o.dy / len);
      return Offset.zero;
    }

    final rLast = rightOut.last;
    final lFirst = leftOut.first;
    final c0Right = Offset(
      rLast.dx + k * headRadius * norm(headRightTangent).dx,
      rLast.dy + k * headRadius * norm(headRightTangent).dy,
    );
    final c1Right = Offset(
      headTip.dx - k * headRadius * norm(headTipTangent).dx,
      headTip.dy - k * headRadius * norm(headTipTangent).dy,
    );
    final c0Tip = Offset(
      headTip.dx + k * headRadius * norm(headTipTangent).dx,
      headTip.dy + k * headRadius * norm(headTipTangent).dy,
    );
    final c1Left = Offset(
      lFirst.dx - k * headRadius * norm(headLeftTangent).dx,
      lFirst.dy - k * headRadius * norm(headLeftTangent).dy,
    );
    final curve = <Offset>[];
    const steps = 11;
    for (var i = 0; i < steps; i++) {
      final t = i / (steps - 1);
      curve.add(_cubicAt(t, rLast, c0Right, c1Right, headTip));
    }
    for (var i = 1; i < steps; i++) {
      final t = i / (steps - 1);
      curve.add(_cubicAt(t, headTip, c0Tip, c1Left, lFirst));
    }
    return curve
        .map(
          (s) => Offset(
            cameraX + (s.dx - centerX) / zoom,
            cameraY + (s.dy - centerY) / zoom,
          ),
        )
        .toList();
  }

  List<Offset>? _computeHeadCapFaceCurveWorld() {
    if (creature.mouth == null) return null;
    return computeHeadCapFaceCurveWorld(
      positions: _paintPositions,
      segmentAngles: _paintSegmentAngles,
      widthAtWorld: _widthAt,
      centerX: _paintCenterX,
      centerY: _paintCenterY,
      zoom: _paintZ,
      cameraX: view.cameraX,
      cameraY: view.cameraY,
    );
  }

  void _drawMouth(Canvas canvas) {
    if (creature.mouth == null) return;
    final n = _paintN;
    final headWidthWorld = creature.segmentWidths.isEmpty
        ? _fallbackWidth
        : creature.widthAtVertex(n);
    final faceCurveWorld = _computeHeadCapFaceCurveWorld();
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
      faceCurveWorld: faceCurveWorld,
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

    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = (2.0 * _paintZ).clamp(1.0, 2.0);
    for (final config in fins) {
      final seg = config.segment;
      if (seg < 0 || seg >= n) continue;
      final len = config.length;
      final wid = config.width;
      final flareRad = config.angleDegrees * pi / 180.0;
      final lenScreen = len * _paintZ;
      final widScreen = wid * _paintZ;
      final aAttach = segmentAngles[seg < segmentAngles.length ? seg : seg - 1];
      final segW = _widthAt(seg);
      final halfW = segW;
      final px = positions[seg].x;
      final py = positions[seg].y;
      final leftCx = px + sin(aAttach) * halfW;
      final leftCy = py - cos(aAttach) * halfW;
      final rightCx = px - sin(aAttach) * halfW;
      final rightCy = py + cos(aAttach) * halfW;

      final fillPaintL = Paint()
        ..shader =
            LinearGradient(
              transform: GradientRotation(pi / 2 - flareRad),
              colors: [finColor, Color(creature.color), Color(creature.color)],
            ).createShader(
              Rect.fromCenter(
                center: Offset.zero,
                width: lenScreen / 2,
                height: lenScreen / 2,
              ),
            )
        ..style = PaintingStyle.fill;
      final fillPaintR = Paint()
        ..shader =
            LinearGradient(
              transform: GradientRotation(-pi / 2 + flareRad),
              colors: [finColor, Color(creature.color), Color(creature.color)],
            ).createShader(
              Rect.fromCenter(
                center: Offset.zero,
                width: lenScreen / 2,
                height: lenScreen / 2,
              ),
            )
        ..style = PaintingStyle.fill;

      final anchors = computeFinAnchors(
        flareRad: flareRad,
        halfWidth: halfW,
        positions: positions,
        segment: seg,
        segmentAngles: segmentAngles,
      );

      drawTransformed(
        canvas,
        Offset(sx(leftCx), sy(leftCy)),
        anchors.leftAngle,
        () {
          drawLateralWing(
            canvas,
            config.wingType,
            lenScreen,
            widScreen,
            fillPaintL,
            strokePaint,
            isLeft: true,
          );
        },
      );

      drawTransformed(
        canvas,
        Offset(sx(rightCx), sy(rightCy)),
        anchors.rightAngle,
        () {
          drawLateralWing(
            canvas,
            config.wingType,
            lenScreen,
            widScreen,
            fillPaintR,
            strokePaint,
            isLeft: false,
          );
        },
      );
    }
  }

  void _drawAntennae(Canvas canvas) {
    final antennae = creature.antennae;
    if (antennae == null || antennae.isEmpty) return;
    final positions = _paintPositions;
    final segmentAngles = _paintSegmentAngles;
    final n = _paintN;
    double sx(double wx) => _paintCenterX + (wx - view.cameraX) * _paintZ;
    double sy(double wy) => _paintCenterY + (wy - view.cameraY) * _paintZ;

    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = (3.0 * _paintZ).clamp(1.0, 3.0);
    for (final config in antennae) {
      final seg = config.segment;
      if (seg < 0 || seg >= n) continue;
      drawAntennaAtSegment(
        canvas,
        seg,
        config.length,
        config.width,
        config.angleDegrees,
        positions,
        segmentAngles,
        _widthAt(seg),
        sx,
        sy,
        _paintZ,
        strokePaint,
      );
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
    const tension = 0.2;
    final path = Path();
    final tailCenter = Offset(sx(positions[0].x), sy(positions[0].y));
    final tailLeft = Offset(
      tailCenter.dx + tailWWorld * _paintZ * cos(tailA + 3 * pi / 2),
      tailCenter.dy + tailWWorld * _paintZ * sin(tailA + 3 * pi / 2),
    );
    path.moveTo(tailLeft.dx, tailLeft.dy);
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
    final tailRadius = tailWWorld * _paintZ;
    final tailTip = Offset(
      tailCenter.dx - tailRadius * cos(tailA),
      tailCenter.dy - tailRadius * sin(tailA),
    );
    // Tail cap: exit at tailLeft from left body tangent (path closes there); tip tangents = (-sin(tailA), cos(tailA)).
    final tailLeftTangent = Offset(
      leftOut.last.dx - leftOut[leftOut.length - 2].dx,
      leftOut.last.dy - leftOut[leftOut.length - 2].dy,
    );
    _appendCubicCap(
      path,
      tailLeft,
      tailTip,
      tailLeftTangent,
      Offset(-sin(tailA), cos(tailA)),
      tailRadius,
    );
    _appendCubicCap(
      path,
      tailTip,
      rightOut.first,
      Offset(-sin(tailA), cos(tailA)),
      Offset(rightOut[1].dx - rightOut[0].dx, rightOut[1].dy - rightOut[0].dy),
      tailRadius,
    );
    appendSmoothCurve(path, rightOut, tension, closed: false);
    // Head cap: tangents at body junctions from body curve (G1 continuity).
    final headRadius = headWWorld * _paintZ;
    final headCenter = Offset(sx(positions[n].x), sy(positions[n].y));
    final headTip = Offset(
      headCenter.dx + headRadius * cos(headA),
      headCenter.dy + headRadius * sin(headA),
    );
    final headRightTangent = Offset(
      rightOut.last.dx - rightOut[rightOut.length - 2].dx,
      rightOut.last.dy - rightOut[rightOut.length - 2].dy,
    );
    final headLeftTangent = Offset(
      leftOut[1].dx - leftOut[0].dx,
      leftOut[1].dy - leftOut[0].dy,
    );
    final headTipTangent = Offset(sin(headA), -cos(headA));
    _appendCubicCap(
      path,
      rightOut.last,
      headTip,
      headRightTangent,
      headTipTangent,
      headRadius,
    );
    _appendCubicCap(
      path,
      headTip,
      leftOut.first,
      headTipTangent,
      headLeftTangent,
      headRadius,
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
    const tension = 0.2;
    final tailRadius = tailWWorld * (1 - t) * _paintZ;
    final headRadius = headWWorld * (1 - t) * _paintZ;
    final tailCenter = Offset(sx(positions[0].x), sy(positions[0].y));
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
    final tailTip = Offset(
      tailCenter.dx - tailRadius * cos(tailA),
      tailCenter.dy - tailRadius * sin(tailA),
    );
    final headCenter = Offset(sx(positions[n].x), sy(positions[n].y));
    final headTip = Offset(
      headCenter.dx + headRadius * cos(headA),
      headCenter.dy + headRadius * sin(headA),
    );
    final path = Path();
    if (!reverse) {
      path.moveTo(tailLeft.dx, tailLeft.dy);
      final tailLeftTan = Offset(
        leftOut.last.dx - leftOut[leftOut.length - 2].dx,
        leftOut.last.dy - leftOut[leftOut.length - 2].dy,
      );
      _appendCubicCap(
        path,
        tailLeft,
        tailTip,
        tailLeftTan,
        Offset(-sin(tailA), cos(tailA)),
        tailRadius,
      );
      _appendCubicCap(
        path,
        tailTip,
        rightOut.first,
        Offset(-sin(tailA), cos(tailA)),
        Offset(
          rightOut[1].dx - rightOut[0].dx,
          rightOut[1].dy - rightOut[0].dy,
        ),
        tailRadius,
      );
      appendSmoothCurve(path, rightOut, tension, closed: false);
      final headRightTan = Offset(
        rightOut.last.dx - rightOut[rightOut.length - 2].dx,
        rightOut.last.dy - rightOut[rightOut.length - 2].dy,
      );
      final headLeftTan = Offset(
        leftOut[1].dx - leftOut[0].dx,
        leftOut[1].dy - leftOut[0].dy,
      );
      final headTipTan = Offset(sin(headA), -cos(headA));
      _appendCubicCap(
        path,
        rightOut.last,
        headTip,
        headRightTan,
        headTipTan,
        headRadius,
      );
      _appendCubicCap(
        path,
        headTip,
        leftOut.first,
        headTipTan,
        headLeftTan,
        headRadius,
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
      // Reverse head cap: body tangents at junctions (left = exit from body, right = entry to body).
      final headLeftTanRev = Offset(
        leftOut[0].dx - leftOut[1].dx,
        leftOut[0].dy - leftOut[1].dy,
      );
      final headRightTanRev = Offset(
        rightOut.last.dx - rightOut[rightOut.length - 2].dx,
        rightOut.last.dy - rightOut[rightOut.length - 2].dy,
      );
      final headTipTanRev = Offset(sin(headA), -cos(headA));
      _appendCubicCap(
        path,
        leftOut.first,
        headTip,
        headLeftTanRev,
        headTipTanRev,
        headRadius,
      );
      _appendCubicCap(
        path,
        headTip,
        rightOut.last,
        headTipTanRev,
        headRightTanRev,
        headRadius,
      );
      appendSmoothCurve(
        path,
        rightOut.reversed.toList(),
        tension,
        closed: false,
      );
      // Reverse tail cap: body tangent at right (exit); at tailLeft use left body tangent (arrive).
      final tailRightTanRev = Offset(
        rightOut[0].dx - rightOut[1].dx,
        rightOut[0].dy - rightOut[1].dy,
      );
      final tailLeftTanRev = Offset(
        leftOut.last.dx - leftOut[leftOut.length - 2].dx,
        leftOut.last.dy - leftOut[leftOut.length - 2].dy,
      );
      _appendCubicCap(
        path,
        rightOut.first,
        tailTip,
        tailRightTanRev,
        Offset(sin(tailA), -cos(tailA)),
        tailRadius,
      );
      _appendCubicCap(
        path,
        tailTip,
        tailLeft,
        Offset(-sin(tailA), cos(tailA)),
        tailLeftTanRev,
        tailRadius,
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
    const tension = 0.2;
    final maxAngle = Spine.maxJointAngleRad;
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
      oldDelegate.dorsalAndEyesOnly != dorsalAndEyesOnly ||
      oldDelegate.skipDorsalAndEyes != skipDorsalAndEyes ||
      oldDelegate.isBaby != isBaby ||
      oldDelegate.isEpic != isEpic ||
      oldDelegate.bodyContourStyle != bodyContourStyle ||
      oldDelegate.showContourLines != showContourLines ||
      oldDelegate.blurBodyLayers != blurBodyLayers;
}
