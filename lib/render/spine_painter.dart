import 'dart:math' show cos, pi, sin;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../creature.dart';
import '../simulation/angle_util.dart';
import '../simulation/spine.dart';
import '../simulation/vector.dart';
import 'render_utils.dart';
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
  });

  // Set during paint() for use by _drawTailFin, _drawBody, _drawDorsalFins, _drawEyes.
  late double _paintCenterX;
  late double _paintCenterY;
  late double _paintZ;
  late Color _paintFillColor;
  late List<Vector2> _paintPositions;
  late List<double> _paintSegmentAngles;
  late int _paintN;

  double _widthAt(int i) {
    final vw = creature.vertexWidths;
    if (i < vw.length) {
      return vw[i].clamp(Creature.minVertexWidth, Creature.maxVertexWidth);
    }
    return _fallbackWidth.clamp(Creature.minVertexWidth, Creature.maxVertexWidth);
  }

  /// Builds the creature body outline path in screen coordinates for clipping (e.g. consumption effects).
  static Path buildBodyPath(Creature creature, Spine spine, CameraView view, Size size) {
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
      return _fallbackWidth.clamp(Creature.minVertexWidth, Creature.maxVertexWidth);
    }
    double wAt(int i) => widthAt(i) * z;
    Offset rightAt(int i) {
      final a = segmentAngles[i < segmentAngles.length ? i : segmentAngles.length - 1];
      final w = wAt(i);
      return Offset(sx(positions[i].x) - sin(a) * w, sy(positions[i].y) + cos(a) * w);
    }
    Offset leftAt(int i) {
      final a = segmentAngles[i < segmentAngles.length ? i : segmentAngles.length - 1];
      final w = wAt(i);
      return Offset(sx(positions[i].x) + sin(a) * w, sy(positions[i].y) - cos(a) * w);
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
      curve.add(Offset(sx(positions[0].x + tailWWorld * cos(a)), sy(positions[0].y + tailWWorld * sin(a))));
    }
    for (var i = 0; i <= n; i++) curve.add(rightAt(i));
    for (var i = 0; i < capSegments; i++) {
      final t = i / (capSegments - 1);
      final a = headA + pi / 3 - t * (2 * pi / 3);
      curve.add(Offset(sx(positions[n].x + headWWorld * cos(a)), sy(positions[n].y + headWWorld * sin(a))));
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
    _paintPositions = positions;
    _paintSegmentAngles = segmentAngles;
    _paintN = positions.length - 1;

    if (eyesOnly) {
      _drawEyes(canvas);
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
    if (drawEyes) _drawEyes(canvas);
  }

  void _drawTailFin(Canvas canvas) {
    if (creature.tailFin == null) return;
    final tailFinType = creature.tailFin!;
    final positions = _paintPositions;
    final segmentAngles = _paintSegmentAngles;
    double sx(double wx) => _paintCenterX + (wx - view.cameraX) * _paintZ;
    double sy(double wy) => _paintCenterY + (wy - view.cameraY) * _paintZ;
    final tailX = positions[0].x;
    final tailY = positions[0].y;
    final tailA = segmentAngles[0];
    final tailBend = segmentAngles.length >= 2
        ? relativeAngleDiff(segmentAngles[1], segmentAngles[0])
        : 0.0;
    final maxAngle = spine.maxJointAngleRad;
    var sumAbsBend = 0.0;
    var count = 0;
    for (var i = 1; i < segmentAngles.length; i++) {
      sumAbsBend += relativeAngleDiff(
        segmentAngles[i],
        segmentAngles[i - 1],
      ).abs();
      count++;
    }
    final avgBend = count > 0 ? sumAbsBend / count : 0.0;
    final ratio = (avgBend / maxAngle).clamp(0.0, 1.0);
    final innerScale = caudalFinBaseFrac + (1.0 - caudalFinBaseFrac) * ratio;
    final outerScale = caudalFinBaseFrac;
    final vws = creature.vertexWidths
        .map((w) => w.clamp(Creature.minVertexWidth, Creature.maxVertexWidth))
        .toList();
    final rootW = vws.isEmpty
        ? _widthAt(0)
        : vws.reduce((a, b) => a < b ? a : b);
    final tailSegmentWidth = _widthAt(0);
    final maxW = vws.isEmpty
        ? rootW / 2
        : vws.reduce((a, b) => a > b ? a : b) / 2;

    final back = tailA + pi;
    final len = tailSegmentWidth * 3.0;
    final t = (maxAngle > 1e-6)
        ? (tailBend / maxAngle * 0.5 + 0.5).clamp(0.0, 1.0)
        : 0.5;
    final leftScale = outerScale + (innerScale - outerScale) * t;
    final rightScale = outerScale + (innerScale - outerScale) * (1.0 - t);
    final rootScale = caudalFinBaseFrac + (1.0 - caudalFinBaseFrac) * ratio;
    final rootHalfW = rootW * rootScale;
    final lo = rootHalfW < maxW ? rootHalfW : maxW;
    final hi = rootHalfW > maxW ? rootHalfW : maxW;
    final leftMax = (maxW * leftScale).clamp(lo, hi);
    final rightMax = (maxW * rightScale).clamp(lo, hi);

    final leftDirX = sin(tailA);
    final leftDirY = -cos(tailA);
    final rightDirX = -sin(tailA);
    final rightDirY = cos(tailA);
    final leftTailX = tailX + leftDirX * rootHalfW;
    final leftTailY = tailY + leftDirY * rootHalfW;
    final rightTailX = tailX + rightDirX * rootHalfW;
    final rightTailY = tailY + rightDirY * rootHalfW;
    final tipCx = tailX + cos(back) * len;
    final tipCy = tailY + sin(back) * len;

    final pts = <Offset>[];
    pts.add(Offset(sx(leftTailX), sy(leftTailY)));
    if (tailFinType == CaudalFinType.rounded) {
      pts.add(
        Offset(
          sx(leftTailX + cos(back) * len * 0.3 + leftDirX * leftMax * 0.8),
          sy(leftTailY + sin(back) * len * 0.3 + leftDirY * leftMax * 0.8),
        ),
      );
    }
    if (tailFinType != CaudalFinType.pointed) {
      pts.add(
        Offset(
          sx(leftTailX + cos(back) * len * 0.7 + leftDirX * leftMax),
          sy(leftTailY + sin(back) * len * 0.7 + leftDirY * leftMax),
        ),
      );
    }
    if (tailFinType == CaudalFinType.lunate) {
      pts.add(
        Offset(
          sx(leftTailX + cos(back) * len * 0.6 + leftDirX * leftMax * 0.7),
          sy(leftTailY + sin(back) * len * 0.6 + leftDirY * leftMax * 0.7),
        ),
      );
    }
    if (tailFinType == CaudalFinType.pointed ||
        tailFinType == CaudalFinType.rhomboid) {
      pts.add(Offset(sx(tipCx), sy(tipCy)));
    } else if (tailFinType == CaudalFinType.rounded) {
      pts.add(
        Offset(
          sx(tailX + cos(back) * len * 0.9),
          sy(tailY + sin(back) * len * 0.9),
        ),
      );
    } else if (tailFinType == CaudalFinType.forked) {
      pts.add(
        Offset(
          sx(tailX + cos(back) * len * 0.35),
          sy(tailY + sin(back) * len * 0.35),
        ),
      );
    } else if (tailFinType == CaudalFinType.lunate) {
      pts.add(
        Offset(
          sx(tailX + cos(back) * len * 0.45),
          sy(tailY + sin(back) * len * 0.45),
        ),
      );
    } else if (tailFinType == CaudalFinType.emarginate) {
      pts.add(
        Offset(
          sx(tailX + cos(back) * len * 0.65),
          sy(tailY + sin(back) * len * 0.65),
        ),
      );
    } else if (tailFinType == CaudalFinType.truncate) {
      pts.add(
        Offset(
          sx(tailX + cos(back) * len * 0.8),
          sy(tailY + sin(back) * len * 0.8),
        ),
      );
    }
    if (tailFinType == CaudalFinType.lunate) {
      pts.add(
        Offset(
          sx(rightTailX + cos(back) * len * 0.6 + rightDirX * rightMax * 0.7),
          sy(rightTailY + sin(back) * len * 0.6 + rightDirY * rightMax * 0.7),
        ),
      );
    }
    if (tailFinType != CaudalFinType.pointed) {
      pts.add(
        Offset(
          sx(rightTailX + cos(back) * len * 0.7 + rightDirX * rightMax),
          sy(rightTailY + sin(back) * len * 0.7 + rightDirY * rightMax),
        ),
      );
    }
    if (tailFinType == CaudalFinType.rounded) {
      pts.add(
        Offset(
          sx(rightTailX + cos(back) * len * 0.3 + rightDirX * rightMax * 0.8),
          sy(rightTailY + sin(back) * len * 0.3 + rightDirY * rightMax * 0.8),
        ),
      );
    }
    pts.add(Offset(sx(rightTailX), sy(rightTailY)));

    final path = Path();
    path.moveTo(pts[0].dx, pts[0].dy);
    appendSmoothCurve(path, pts, 1.0 / 6.0);
    path.close();
    final finColor = creature.finColor != null
        ? Color(creature.finColor!)
        : Color.lerp(_paintFillColor, Colors.white, 0.12)!;
    final finPaint = Paint()
      ..color = finColor
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = (2.0 * _paintZ).clamp(1.0, 2.0);
    canvas.drawPath(path, finPaint);
    canvas.drawPath(path, strokePaint);
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
    const flareRad = 35.0 * pi / 180.0; // 35° from inline when neutral
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
      final fullH = fin.$2 ?? dorsalFinHeight;
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
    final eyeRadius = headW * 0.24;
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
      oldDelegate.eyesOnly != eyesOnly;
}
