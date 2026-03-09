import 'dart:math' show atan2, cos, pi, sin, sqrt;
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:creature_bio_sim/creature.dart';
import 'package:creature_bio_sim/render/background_painter.dart';
import 'package:creature_bio_sim/render/creature_painter.dart';
import 'package:creature_bio_sim/render/tail_painter.dart';
import 'package:creature_bio_sim/render/view.dart';
import 'package:creature_bio_sim/simulation/angle_util.dart' show relativeAngleDiff;
import 'package:creature_bio_sim/simulation/spine.dart';
import 'package:creature_bio_sim/simulation/vector.dart';
import 'package:creature_bio_sim/editor/editor_shared.dart';
import 'package:creature_bio_sim/editor/editor_style.dart';
/// Draws one lateral fin on the creature at the given segment (for add/move preview). [highlight] = draw in highlight color; [highlightForRemove] = red (will be removed).
class _LateralFinAtSegmentPainter extends CustomPainter {
  _LateralFinAtSegmentPainter({
    required this.segment,
    required this.positions,
    required this.segmentAngles,
    required this.centerX,
    required this.centerY,
    required this.cameraX,
    required this.cameraY,
    required this.zoom,
    required this.segWidth,
    required this.finColor,
    this.highlight = false,
    this.highlightForRemove = false,
  });

  final int segment;
  final List<Vector2> positions;
  final List<double> segmentAngles;
  final double centerX;
  final double centerY;
  final double cameraX;
  final double cameraY;
  final double zoom;
  final double segWidth;
  final Color finColor;
  final bool highlight;
  final bool highlightForRemove;

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.length < 2 || segment < 0 || segment >= positions.length - 1) return;
    if (segment >= segmentAngles.length) return;
    double sx(double wx) => centerX + (wx - cameraX) * zoom;
    double sy(double wy) => centerY + (wy - cameraY) * zoom;
    const flareRad = 45.0 * pi / 180.0;
    final len = segWidth * 1.5;
    final wid = len / 3.0;
    final lenScreen = len * zoom;
    final widScreen = wid * zoom;
    final rect = Rect.fromCenter(center: Offset.zero, width: lenScreen, height: widScreen);
    final aAttach = segmentAngles[segment];
    final segHead = segment + 1 < segmentAngles.length ? segment + 1 : segment;
    final aLock = segmentAngles[segHead];
    final halfW = segWidth;
    final px = positions[segment].x;
    final py = positions[segment].y;
    final leftCx = px + sin(aAttach) * halfW, leftCy = py - cos(aAttach) * halfW;
    final rightCx = px - sin(aAttach) * halfW, rightCy = py + cos(aAttach) * halfW;
    final leftAngle = aLock + flareRad, rightAngle = aLock - flareRad;
    final fillColor = highlightForRemove
        ? Colors.red.withValues(alpha: 0.5)
        : (highlight ? Colors.white.withValues(alpha: 0.6) : finColor.withValues(alpha: 0.9));
    final strokeColor = highlightForRemove ? Colors.red : (highlight ? Colors.amber : Colors.white);
    final fillPaint = Paint()..color = fillColor..style = PaintingStyle.fill;
    final strokePaint = Paint()..color = strokeColor..style = PaintingStyle.stroke..strokeWidth = (2.0 * zoom).clamp(1.0, 2.0);
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

  @override
  bool shouldRepaint(covariant _LateralFinAtSegmentPainter old) =>
      old.segment != segment || old.highlight != highlight || old.highlightForRemove != highlightForRemove;
}

/// Highlights a 3-segment dorsal fin on the creature when dragging + dorsal over the viewport.
class _DorsalDropHighlightPainter extends CustomPainter {
  _DorsalDropHighlightPainter({
    required this.startSeg,
    required this.positions,
    required this.centerX,
    required this.centerY,
    required this.cameraX,
    required this.cameraY,
    required this.zoom,
    required this.finColor,
  });

  final int startSeg;
  final List<Vector2> positions;
  final double centerX;
  final double centerY;
  final double cameraX;
  final double cameraY;
  final double zoom;
  final Color finColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.length < 2 || startSeg < 0) return;
    final endSeg = (startSeg + 2).clamp(startSeg, positions.length - 2);
    double sx(double wx) => centerX + (wx - cameraX) * zoom;
    double sy(double wy) => centerY + (wy - cameraY) * zoom;
    const fullH = 14.0;
    const baseH = fullH * 0.3;
    final topPts = <Offset>[];
    final spinePts = <Offset>[];
    for (var i = startSeg; i <= endSeg + 1 && i < positions.length; i++) {
      final p = Offset(sx(positions[i].x), sy(positions[i].y));
      spinePts.add(p);
      final idx = i - startSeg;
      final isEnd = idx == 0 || idx == (endSeg - startSeg + 1);
      final h = (isEnd ? baseH : fullH * 0.7) * zoom;
      final prev = i > startSeg ? positions[i - 1] : positions[i];
      final dx = positions[i].x - prev.x;
      final dy = positions[i].y - prev.y;
      final perp = (dx * dx + dy * dy) > 0 ? h / sqrt(dx * dx + dy * dy) : 0.0;
      topPts.add(Offset(p.dx - dy * perp, p.dy + dx * perp));
    }
    if (topPts.isEmpty || spinePts.isEmpty) return;
    final path = Path()..moveTo(topPts.first.dx, topPts.first.dy);
    for (var i = 1; i < topPts.length; i++) path.lineTo(topPts[i].dx, topPts[i].dy);
    for (var i = spinePts.length - 1; i >= 0; i--) path.lineTo(spinePts[i].dx, spinePts[i].dy);
    path.close();
    canvas.drawPath(path, Paint()..color = finColor.withValues(alpha: 0.5));
    canvas.drawPath(path, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _DorsalDropHighlightPainter old) =>
      old.startSeg != startSeg;
}

/// Draws a dorsal fin range with highlight (e.g. when dragging to delete).
class _DorsalRangeHighlightPainter extends CustomPainter {
  _DorsalRangeHighlightPainter({
    required this.startSeg,
    required this.endSeg,
    required this.positions,
    required this.centerX,
    required this.centerY,
    required this.cameraX,
    required this.cameraY,
    required this.zoom,
  });

  final int startSeg;
  final int endSeg;
  final List<Vector2> positions;
  final double centerX;
  final double centerY;
  final double cameraX;
  final double cameraY;
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.length < 2 || startSeg < 0 || endSeg < startSeg) return;
    final lastSeg = endSeg.clamp(startSeg, positions.length - 2);
    double sx(double wx) => centerX + (wx - cameraX) * zoom;
    double sy(double wy) => centerY + (wy - cameraY) * zoom;
    const fullH = 14.0;
    const baseH = fullH * 0.3;
    final topPts = <Offset>[];
    final spinePts = <Offset>[];
    for (var i = startSeg; i <= lastSeg + 1 && i < positions.length; i++) {
      final p = Offset(sx(positions[i].x), sy(positions[i].y));
      spinePts.add(p);
      final idx = i - startSeg;
      final isEnd = idx == 0 || idx == (lastSeg - startSeg + 1);
      final h = (isEnd ? baseH : fullH * 0.7) * zoom;
      final prev = i > startSeg ? positions[i - 1] : positions[i];
      final dx = positions[i].x - prev.x;
      final dy = positions[i].y - prev.y;
      final perp = (dx * dx + dy * dy) > 0 ? h / sqrt(dx * dx + dy * dy) : 0.0;
      topPts.add(Offset(p.dx - dy * perp, p.dy + dx * perp));
    }
    if (topPts.isEmpty || spinePts.isEmpty) return;
    final path = Path()..moveTo(topPts.first.dx, topPts.first.dy);
    for (var i = 1; i < topPts.length; i++) path.lineTo(topPts[i].dx, topPts[i].dy);
    for (var i = spinePts.length - 1; i >= 0; i--) path.lineTo(spinePts[i].dx, spinePts[i].dy);
    path.close();
    canvas.drawPath(path, Paint()..color = Colors.red.withValues(alpha: 0.5));
    canvas.drawPath(path, Paint()..color = Colors.red..style = PaintingStyle.stroke..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(covariant _DorsalRangeHighlightPainter old) =>
      old.startSeg != startSeg || old.endSeg != endSeg;
}

/// Draws 3 dorsal adjust nodes (start, end, height) when a fin is selected.
class _DorsalNodesOverlayPainter extends CustomPainter {
  _DorsalNodesOverlayPainter({
    required this.positions,
    required this.startSeg,
    required this.endSeg,
    required this.centerX,
    required this.centerY,
    required this.cameraX,
    required this.cameraY,
    required this.zoom,
    this.activeNode,
  });

  final List<Vector2> positions;
  final int startSeg;
  final int endSeg;
  final double centerX;
  final double centerY;
  final double cameraX;
  final double cameraY;
  final double zoom;
  final int? activeNode;

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.length < 2 || startSeg < 0 || endSeg >= positions.length) return;
    double sx(double wx) => centerX + (wx - cameraX) * zoom;
    double sy(double wy) => centerY + (wy - cameraY) * zoom;
    final startCx = (positions[startSeg].x + positions[startSeg + 1].x) / 2;
    final startCy = (positions[startSeg].y + positions[startSeg + 1].y) / 2;
    final endCx = (positions[endSeg].x + positions[endSeg + 1].x) / 2;
    final endCy = (positions[endSeg].y + positions[endSeg + 1].y) / 2;
    final midSeg = (startSeg + endSeg) ~/ 2;
    final midCx = midSeg + 1 < positions.length
        ? (positions[midSeg].x + positions[midSeg + 1].x) / 2
        : (positions[midSeg].x + positions[endSeg].x) / 2;
    final midCy = midSeg + 1 < positions.length
        ? (positions[midSeg].y + positions[midSeg + 1].y) / 2
        : (positions[midSeg].y + positions[endSeg].y) / 2;
    final sx0 = sx(startCx);
    final sy0 = sy(startCy);
    final sx1 = sx(endCx);
    final sy1 = sy(endCy);
    final sx2 = sx(midCx);
    final sy2 = sy(midCy) - 24;

    final points = [Offset(sx0, sy0), Offset(sx1, sy1), Offset(sx2, sy2)];
    for (var i = 0; i < points.length; i++) {
      final active = activeNode == i;
      final stroke = Paint()
        ..color = Colors.white.withValues(alpha: active ? 1.0 : 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final fill = Paint()..color = Colors.white.withValues(alpha: active ? 0.5 : 0.15);
      canvas.drawCircle(points[i], 14, fill);
      canvas.drawCircle(points[i], 14, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _DorsalNodesOverlayPainter old) =>
      old.startSeg != startSeg || old.endSeg != endSeg || old.activeNode != activeNode;
}

/// Three nodes for tail sizing: root width, max width, length (when creature has tailFin).
class _TailNodesOverlayPainter extends CustomPainter {
  _TailNodesOverlayPainter({
    required this.tailX,
    required this.tailY,
    required this.tailA,
    required this.rootW,
    required this.maxW,
    required this.len,
    required this.centerX,
    required this.centerY,
    required this.cameraX,
    required this.cameraY,
    required this.zoom,
    this.activeNode,
  });

  final double tailX;
  final double tailY;
  final double tailA;
  final double rootW;
  final double maxW;
  final double len;
  final double centerX;
  final double centerY;
  final double cameraX;
  final double cameraY;
  final double zoom;
  /// 0=root, 1=max, 2=length; null=none active.
  final int? activeNode;

  static const double _nodeRadius = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    double sx(double wx) => centerX + (wx - cameraX) * zoom;
    double sy(double wy) => centerY + (wy - cameraY) * zoom;
    final back = tailA + pi;
    final leftDirX = sin(tailA);
    final leftDirY = -cos(tailA);
    final backDirX = cos(back);
    final backDirY = sin(back);
    final rootPx = tailX + leftDirX * rootW;
    final rootPy = tailY + leftDirY * rootW;
    final maxPx = tailX + backDirX * len * 0.7 + leftDirX * maxW;
    final maxPy = tailY + backDirY * len * 0.7 + leftDirY * maxW;
    final tipPx = tailX + backDirX * len;
    final tipPy = tailY + backDirY * len;
    final points = [
      Offset(sx(rootPx), sy(rootPy)),
      Offset(sx(maxPx), sy(maxPy)),
      Offset(sx(tipPx), sy(tipPy)),
    ];
    for (var i = 0; i < 3; i++) {
      final active = activeNode == i;
      final stroke = Paint()
        ..color = Colors.white.withValues(alpha: active ? 1.0 : 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      final fill = Paint()..color = Colors.white.withValues(alpha: active ? 0.5 : 0.15);
      canvas.drawCircle(points[i], _nodeRadius, fill);
      canvas.drawCircle(points[i], _nodeRadius, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _TailNodesOverlayPainter old) =>
      old.rootW != rootW || old.maxW != maxW || old.len != len || old.activeNode != activeNode;
}

/// Draws the tail fin in red when dragging to remove (outside bounds).
class _TailRemoveHighlightPainter extends CustomPainter {
  _TailRemoveHighlightPainter({
    required this.creature,
    required this.positions,
    required this.segmentAngles,
    required this.centerX,
    required this.centerY,
    required this.cameraX,
    required this.cameraY,
    required this.zoom,
    required this.bodyColor,
    required this.widthAt,
  });

  final Creature creature;
  final List<Vector2> positions;
  final List<double> segmentAngles;
  final double centerX;
  final double centerY;
  final double cameraX;
  final double cameraY;
  final double zoom;
  final Color bodyColor;
  final double Function(int i) widthAt;

  @override
  void paint(Canvas canvas, Size size) {
    paintTailFin(
      canvas,
      creature,
      positions,
      segmentAngles,
      centerX,
      centerY,
      zoom,
      cameraX,
      cameraY,
      1.0,
      bodyColor,
      widthAt,
      overrideFinColor: Colors.red.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(covariant _TailRemoveHighlightPainter old) => false;
}

/// Draws the tail fin as preview when dragging a new tail type onto the creature.
class _TailAddPreviewPainter extends CustomPainter {
  _TailAddPreviewPainter({
    required this.creature,
    required this.previewTailFin,
    required this.positions,
    required this.segmentAngles,
    required this.centerX,
    required this.centerY,
    required this.cameraX,
    required this.cameraY,
    required this.zoom,
    required this.bodyColor,
    required this.widthAt,
  });

  final Creature creature;
  final CaudalFinType previewTailFin;
  final List<Vector2> positions;
  final List<double> segmentAngles;
  final double centerX;
  final double centerY;
  final double cameraX;
  final double cameraY;
  final double zoom;
  final Color bodyColor;
  final double Function(int i) widthAt;

  @override
  void paint(Canvas canvas, Size size) {
    final previewCreature = Creature(
      vertexWidths: creature.vertexWidths,
      color: creature.color,
      dorsalFins: creature.dorsalFins,
      finColor: creature.finColor,
      tailFin: previewTailFin,
      lateralFins: creature.lateralFins,
      tailRootWidth: creature.tailRootWidth ?? 12.0,
      tailMaxWidth: creature.tailMaxWidth ?? 20.0,
      tailLength: creature.tailLength ?? 90.0,
    );
    paintTailFin(
      canvas,
      previewCreature,
      positions,
      segmentAngles,
      centerX,
      centerY,
      zoom,
      cameraX,
      cameraY,
      1.0,
      bodyColor,
      widthAt,
      overrideFinColor: Colors.white.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant _TailAddPreviewPainter old) =>
      old.previewTailFin != previewTailFin;
}

/// Tail node OUTSIDE creature (after tail) for extend/contract.
class _BodyNodesOverlayPainter extends CustomPainter {
  _BodyNodesOverlayPainter({
    required this.positions,
    required this.centerX,
    required this.centerY,
    required this.cameraX,
    required this.cameraY,
    required this.zoom,
    this.activeNode,
  });

  final List<Vector2> positions;
  final double centerX;
  final double centerY;
  final double cameraX;
  final double cameraY;
  final double zoom;
  /// 0 = tail; null = none active (inactive look).
  final int? activeNode;

  static const double _outsideOffset = 88.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.length < 2) return;
    final tail = positions.first;
    final second = positions[1];
    double dx = tail.x - second.x;
    double dy = tail.y - second.y;
    var len = sqrt(dx * dx + dy * dy);
    if (len < 1e-6) len = 1.0;
    final tailOutX = tail.x + dx / len * _outsideOffset;
    final tailOutY = tail.y + dy / len * _outsideOffset;
    final sx0 = centerX + (tailOutX - cameraX) * zoom;
    final sy0 = centerY + (tailOutY - cameraY) * zoom;
    const r = 24.0;
    final active = activeNode == 0;
    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: active ? 1.0 : 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final fill = Paint()..color = Colors.white.withValues(alpha: active ? 0.5 : 0.15);
    canvas.drawCircle(Offset(sx0, sy0), r, fill);
    canvas.drawCircle(Offset(sx0, sy0), r, stroke);
  }

  @override
  bool shouldRepaint(covariant _BodyNodesOverlayPainter old) =>
      old.activeNode != activeNode;
}

/// Preview: creature centered, draggable target, zoom. Optional viewport fin editing.
class EditorPreview extends StatefulWidget {
  const EditorPreview({
    super.key,
    required this.creature,
    this.editTabIndex = 0,
    this.panelClosed = false,
    this.selectedDorsalFinIndex,
    this.onDorsalFinSelected,
    this.onDorsalRangeChanged,
    this.onDorsalHeightChanged,
    this.onDorsalAdded,
    this.onDorsalRemoved,
    this.onSegmentCountChanged,
    this.onSegmentWidthDelta,
    this.onTailRootWidthChanged,
    this.onTailMaxWidthChanged,
    this.onTailLengthChanged,
    this.onTailAdded,
    this.onTailRemoved,
    this.onLateralToggled,
    this.onLateralMoved,
    this.onLateralAdded,
    this.onLateralRemoved,
  });

  final Creature creature;
  final int? editTabIndex;
  final bool panelClosed;
  final int? selectedDorsalFinIndex;
  final void Function(int? finIndex)? onDorsalFinSelected;
  final void Function(int start, int end)? onDorsalRangeChanged;
  final void Function(double? height)? onDorsalHeightChanged;
  final void Function(int seg)? onDorsalAdded;
  final void Function(int finIndex)? onDorsalRemoved;
  final void Function(int count)? onSegmentCountChanged;
  final void Function(int seg, double delta)? onSegmentWidthDelta;
  final void Function(double value)? onTailRootWidthChanged;
  final void Function(double value)? onTailMaxWidthChanged;
  final void Function(double value)? onTailLengthChanged;
  final void Function(CaudalFinType? type)? onTailAdded;
  final void Function()? onTailRemoved;
  final void Function(int seg)? onLateralToggled;
  final void Function(int fromSeg, int toSeg)? onLateralMoved;
  final void Function(int seg)? onLateralAdded;
  final void Function(int seg)? onLateralRemoved;

  @override
  State<EditorPreview> createState() => _EditorPreviewState();
}

class _EditorPreviewState extends State<EditorPreview> with SingleTickerProviderStateMixin {
  late Spine _spine;
  double _dragTargetX = 0;
  double _dragTargetY = 0;
  double _zoom = 1.0;
  late Ticker _ticker;
  int? _dorsalDragStartSeg;
  bool _dorsalDragFromFin = false;
  int? _dorsalDraggingNode; // 0=start, 1=end, 2=height
  int? _bodyDraggingNode; // 0=tail
  int? _bodyWidthDragSeg;
  double _bodyWidthDragLastDist = 0;
  int? _tailDraggingNode; // 0=root, 1=max, 2=length
  double _tailDragStartValue = 0;
  bool _tailDragFromCreature = false;
  bool _tailSelected = false;
  Offset? _tailAddDragLocal;
  TailDragPayload? _tailAddDragPayload;
  int? _lateralDragFromSeg;
  int? _lateralPanStartSeg;
  double _lastPanX = 0;
  double _lastPanY = 0;
  double _panStartX = 0;
  double _panStartY = 0;
  double? _pinchStartZoom;
  Size _lastPreviewSize = Size.zero;
  double _lastCameraX = 0;
  double _lastCameraY = 0;
  Offset? _lateralAddDragLocal;
  Offset? _dorsalAddDragLocal;
  double _backgroundTimeSeconds = 0.0;
  double _editorSimTimeSeconds = 0.0;
  final GlobalKey _previewKey = GlobalKey();
  final GlobalKey _previewContentKey = GlobalKey();

  int _segmentCountFromTailDrag(double centerX, double centerY, double cameraX, double cameraY, List<Vector2> positions) {
    final dropWx = (_lastPanX - centerX) / _zoom + cameraX;
    final dropWy = (_lastPanY - centerY) / _zoom + cameraY;
    final headW = positions.last;
    final tailW = positions.first;
    final headToDropX = dropWx - headW.x;
    final headToDropY = dropWy - headW.y;
    final headToTailX = tailW.x - headW.x;
    final headToTailY = tailW.y - headW.y;
    final headToTailLen = sqrt(headToTailX * headToTailX + headToTailY * headToTailY);
    const nodeOffset = _BodyNodesOverlayPainter._outsideOffset;
    final projectedDist = headToTailLen > 1e-6
        ? (headToDropX * headToTailX + headToDropY * headToTailY) / headToTailLen
        : 0.0;
    final spineLength = projectedDist - nodeOffset;
    return spineLength <= 0 ? 1 : (spineLength / _spine.segmentLength).round().clamp(1, Creature.maxSegmentCount);
  }

  int _segmentAtLocal(double sx, double sy) {
    if (_lastPreviewSize.width <= 0 || _lastPreviewSize.height <= 0) return 0;
    final centerX = _lastPreviewSize.width / 2;
    final centerY = _lastPreviewSize.height / 2;
    final positions = _spine.positions;
    final wx = (sx - centerX) / _zoom + _lastCameraX;
    final wy = (sy - centerY) / _zoom + _lastCameraY;
    if (positions.length < 2) return 0;
    var best = 0;
    var bestD2 = 1e20;
    for (var i = 0; i < positions.length - 1; i++) {
      final cx = (positions[i].x + positions[i + 1].x) / 2;
      final cy = (positions[i].y + positions[i + 1].y) / 2;
      final d2 = (wx - cx) * (wx - cx) + (wy - cy) * (wy - cy);
      if (d2 < bestD2) { bestD2 = d2; best = i; }
    }
    return best.clamp(0, _spine.segmentCount - 1);
  }

  static const double _minZoom = 0.4;
  static const double _maxZoom = 2.5;
  static const double _zoomStep = 0.15;
  /// Same as SimulationScreen: fixed distance per step so speed is constant.
  static const double _headMoveSpeed = 6.0;
  static const double _arrivalThreshold = 10.0;
  static const double _kGlobalTurnNudge = 0.02;
  /// Fixed sim step so editor movement matches play mode speed (60 steps/sec).
  static const double _kFixedDt = 1 / 60.0;
  static const int _kMaxStepsPerFrame = 5;

  @override
  void initState() {
    super.initState();
    _spine = Spine(segmentCount: widget.creature.segmentCount);
    _positionSpineHeadAtOrigin();
    final head = _spine.positions.isNotEmpty ? _spine.positions.last : null;
    if (head != null) {
      _dragTargetX = head.x;
      _dragTargetY = head.y;
    }
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(covariant EditorPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.creature.segmentCount != widget.creature.segmentCount) {
      _spine = Spine(segmentCount: widget.creature.segmentCount);
      _positionSpineHeadAtOrigin();
      final head = _spine.positions.isNotEmpty ? _spine.positions.last : null;
      if (head != null) {
        _dragTargetX = head.x;
        _dragTargetY = head.y;
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _positionSpineHeadAtOrigin() {
    final n = _spine.headIndex;
    final len = _spine.segmentLength;
    for (var i = 0; i <= n; i++) {
      _spine.nodes[i].position.x = (i - n) * len;
      _spine.nodes[i].position.y = 0;
    }
  }

  void _onTick(Duration d) {
    if (!mounted) return;
    final realElapsed = d.inMilliseconds / 1000.0;
    _backgroundTimeSeconds = realElapsed;
    final isSpineLocked = !widget.panelClosed;
    final steps = ((realElapsed - _editorSimTimeSeconds) / _kFixedDt)
        .floor()
        .clamp(0, _kMaxStepsPerFrame);
    for (var i = 0; i < steps; i++) {
      final head = _spine.positions.isNotEmpty ? _spine.positions.last : null;
      if (isSpineLocked) {
        if (head != null) {
          _dragTargetX = head.x;
          _dragTargetY = head.y;
        }
      }
      if (head != null) {
        final dx = _dragTargetX - head.x;
        final dy = _dragTargetY - head.y;
        final len = sqrt(dx * dx + dy * dy);
        if (len <= _arrivalThreshold) {
          _spine.resolve(
            head.x,
            head.y,
            intendedTargetX: _dragTargetX,
            intendedTargetY: _dragTargetY,
          );
          // No global nudge when arrived — avoids spazzing from rotating in place.
        } else {
          final step = _headMoveSpeed / len;
          final nx = head.x + dx * step;
          final ny = head.y + dy * step;
          _spine.resolve(
            nx,
            ny,
            intendedTargetX: _dragTargetX,
            intendedTargetY: _dragTargetY,
          );
          if (_spine.segmentCount >= 2) {
            final headPos = _spine.positions.last;
            final headDir = _spine.segmentAngles.last;
            final towardTouch = atan2(_dragTargetY - headPos.y, _dragTargetX - headPos.x);
            final turn = relativeAngleDiff(headDir, towardTouch);
            if (turn.abs() > _spine.maxJointAngleRad) {
              final nudge = turn.abs() < _kGlobalTurnNudge
                  ? turn
                  : (turn > 0 ? _kGlobalTurnNudge : -_kGlobalTurnNudge);
              _spine.rotateAroundBase(nudge);
            }
          }
        }
      }
    }
    _editorSimTimeSeconds += steps * _kFixedDt;
    if (steps > 0) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final positions = _spine.positions;
    double cameraX = 0.0;
    double cameraY = 0.0;
    if (positions.isNotEmpty) {
      for (final p in positions) {
        cameraX += p.x;
        cameraY += p.y;
      }
      cameraX /= positions.length;
      cameraY /= positions.length;
    }
    _lastCameraX = cameraX;
    _lastCameraY = cameraY;
    final view = CameraView(cameraX: cameraX, cameraY: cameraY, zoom: _zoom);

    final editTab = widget.editTabIndex ?? 0;
    final isBodyEdit = editTab == 0 && !widget.panelClosed;
    final isTailEdit = editTab == 2 && !widget.panelClosed;
    final isDorsalEdit = editTab == 2 && widget.selectedDorsalFinIndex != null && !widget.panelClosed;
    final isLateralEdit = editTab == 2 && !widget.panelClosed;
    final isSpineLocked = !widget.panelClosed;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        _lastPreviewSize = Size(w, h);
        final centerX = w / 2;
        final centerY = h / 2;
        final positions = _spine.positions;

        int segmentAtScreen(double sx, double sy) {
          final wx = (sx - centerX) / _zoom + cameraX;
          final wy = (sy - centerY) / _zoom + cameraY;
          if (positions.length < 2) return 0;
          var best = 0;
          var bestD2 = 1e20;
          for (var i = 0; i < positions.length - 1; i++) {
            final cx = (positions[i].x + positions[i + 1].x) / 2;
            final cy = (positions[i].y + positions[i + 1].y) / 2;
            final d2 = (wx - cx) * (wx - cx) + (wy - cy) * (wy - cy);
            if (d2 < bestD2) { bestD2 = d2; best = i; }
          }
          return best.clamp(0, _spine.segmentCount - 1);
        }

        double widthAtSegment(int seg) {
          final v = widget.creature.vertexWidths;
          if (seg < 0 || seg >= v.length - 1) return 20.0;
          return (v[seg] + v[seg + 1]) / 2;
        }

        Rect creatureScreenBounds() {
          final pos = _spine.positions;
          if (pos.isEmpty) return Rect.fromLTWH(centerX - 20, centerY - 20, 40, 40);
          var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
          for (final p in pos) {
            final sx = centerX + (p.x - cameraX) * _zoom;
            final sy = centerY + (p.y - cameraY) * _zoom;
            if (sx < minX) minX = sx;
            if (sy < minY) minY = sy;
            if (sx > maxX) maxX = sx;
            if (sy > maxY) maxY = sy;
          }
          const margin = 40.0;
          return Rect.fromLTRB(minX - margin, minY - margin, maxX + margin, maxY + margin);
        }

        Rect _finRemoveBounds() => creatureScreenBounds().inflate(kFinRemoveMargin);

        int? _dorsalFinIndexAtScreen(double px, double py) {
          final fins = widget.creature.dorsalFins ?? [];
          if (fins.isEmpty || positions.length < 2) return null;
          final r2 = kDorsalGrabRadius * kDorsalGrabRadius;
          for (var i = 0; i < fins.length; i++) {
            final range = fins[i].$1;
            if (range.isEmpty) continue;
            for (var seg = range.first; seg <= range.last && seg < positions.length - 1; seg++) {
              final cx = (positions[seg].x + positions[seg + 1].x) / 2;
              final cy = (positions[seg].y + positions[seg + 1].y) / 2;
              final sx = centerX + (cx - cameraX) * _zoom;
              final sy = centerY + (cy - cameraY) * _zoom;
              if ((px - sx) * (px - sx) + (py - sy) * (py - sy) <= r2) return i;
            }
          }
          return null;
        }

        int? _lateralSegNearScreen(double px, double py) {
          final laterals = widget.creature.lateralFins ?? [];
          if (laterals.isEmpty || positions.length < 2) return null;
          final segAngles = _spine.segmentAngles;
          if (segAngles.isEmpty) return null;
          final r2 = kLateralGrabRadius * kLateralGrabRadius;
          double sx(double wx) => centerX + (wx - cameraX) * _zoom;
          double sy(double wy) => centerY + (wy - cameraY) * _zoom;
          for (final seg in laterals) {
            if (seg < 0 || seg >= positions.length - 1 || seg >= segAngles.length) continue;
            final halfW = widthAtSegment(seg);
            final aAttach = segAngles[seg];
            final pxW = positions[seg].x, pyW = positions[seg].y;
            final leftCx = pxW + sin(aAttach) * halfW, leftCy = pyW - cos(aAttach) * halfW;
            final rightCx = pxW - sin(aAttach) * halfW, rightCy = pyW + cos(aAttach) * halfW;
            final leftSx = sx(leftCx), leftSy = sy(leftCy);
            final rightSx = sx(rightCx), rightSy = sy(rightCy);
            if ((px - leftSx) * (px - leftSx) + (py - leftSy) * (py - leftSy) <= r2) return seg;
            if ((px - rightSx) * (px - rightSx) + (py - rightSy) * (py - rightSy) <= r2) return seg;
          }
          return null;
        }

        const double _dorsalNodeRadius = 14.0;
        List<Offset>? _dorsalNodePositions() {
          final fins = widget.creature.dorsalFins ?? [];
          final idx = widget.selectedDorsalFinIndex;
          if (idx == null || idx >= fins.length || positions.length < 2) return null;
          final range = fins[idx].$1;
          if (range.isEmpty) return null;
          final startSeg = range.first.clamp(0, positions.length - 2);
          final endSeg = range.last.clamp(0, positions.length - 2);
          double sx(double wx) => centerX + (wx - cameraX) * _zoom;
          double sy(double wy) => centerY + (wy - cameraY) * _zoom;
          final startCx = (positions[startSeg].x + positions[startSeg + 1].x) / 2;
          final startCy = (positions[startSeg].y + positions[startSeg + 1].y) / 2;
          final endCx = (positions[endSeg].x + positions[endSeg + 1].x) / 2;
          final endCy = (positions[endSeg].y + positions[endSeg + 1].y) / 2;
          final midSeg = (startSeg + endSeg) ~/ 2;
          final midCx = midSeg + 1 < positions.length ? (positions[midSeg].x + positions[midSeg + 1].x) / 2 : (positions[midSeg].x + positions[endSeg].x) / 2;
          final midCy = midSeg + 1 < positions.length ? (positions[midSeg].y + positions[midSeg + 1].y) / 2 : (positions[midSeg].y + positions[endSeg].y) / 2;
          return [Offset(sx(startCx), sy(startCy)), Offset(sx(endCx), sy(endCy)), Offset(sx(midCx), sy(midCy) - 24)];
        }

        int? _hitDorsalNode(double px, double py) {
          final nodes = _dorsalNodePositions();
          if (nodes == null) return null;
          for (var i = 0; i < nodes.length; i++) {
            final o = nodes[i];
            if ((px - o.dx) * (px - o.dx) + (py - o.dy) * (py - o.dy) <= _dorsalNodeRadius * _dorsalNodeRadius) return i;
          }
          return null;
        }

        const double _bodyNodeRadius = 24.0;
        int? _hitBodyNode(double px, double py) {
          if (positions.length < 2) return null;
          const out = _BodyNodesOverlayPainter._outsideOffset;
          final tail = positions.first;
          final second = positions[1];
          double dx = tail.x - second.x, dy = tail.y - second.y;
          var len = sqrt(dx * dx + dy * dy);
          if (len < 1e-6) len = 1.0;
          final tailOutX = tail.x + dx / len * out, tailOutY = tail.y + dy / len * out;
          final sx0 = centerX + (tailOutX - cameraX) * _zoom;
          final sy0 = centerY + (tailOutY - cameraY) * _zoom;
          final r2 = _bodyNodeRadius * _bodyNodeRadius;
          if ((px - sx0) * (px - sx0) + (py - sy0) * (py - sy0) <= r2) return 0;
          return null;
        }

        bool _showTailNodes() =>
            isTailEdit && _tailSelected && widget.creature.tailFin != null && positions.length >= 1 && _spine.segmentAngles.isNotEmpty;
        double _effectiveTailRoot() {
          final v = widget.creature.vertexWidths;
          final derived = v.isEmpty ? 20.0 : v.reduce((a, b) => a < b ? a : b);
          return widget.creature.tailRootWidth ?? derived;
        }
        double _effectiveTailMax() {
          final v = widget.creature.vertexWidths;
          final derived = v.isEmpty ? 10.0 : v.reduce((a, b) => a > b ? a : b) / 2;
          return widget.creature.tailMaxWidth ?? derived;
        }
        double _effectiveTailLen() {
          final segW = widthAtSegment(0);
          final derived = segW * 3.0;
          return widget.creature.tailLength ?? derived;
        }
        int? _hitTailNode(double px, double py) {
          if (!_showTailNodes()) return null;
          final tail = positions.first;
          final tailA = _spine.segmentAngles[0];
          final back = tailA + pi;
          final leftDirX = sin(tailA);
          final leftDirY = -cos(tailA);
          final backDirX = cos(back);
          final backDirY = sin(back);
          final rootW = _effectiveTailRoot();
          final maxW = _effectiveTailMax();
          final len = _effectiveTailLen();
          double sx(double wx) => centerX + (wx - cameraX) * _zoom;
          double sy(double wy) => centerY + (wy - cameraY) * _zoom;
          final r2 = _TailNodesOverlayPainter._nodeRadius * _TailNodesOverlayPainter._nodeRadius;
          final rootPx = tail.x + leftDirX * rootW, rootPy = tail.y + leftDirY * rootW;
          if ((px - sx(rootPx)) * (px - sx(rootPx)) + (py - sy(rootPy)) * (py - sy(rootPy)) <= r2) return 0;
          final maxPx = tail.x + backDirX * len * 0.7 + leftDirX * maxW, maxPy = tail.y + backDirY * len * 0.7 + leftDirY * maxW;
          if ((px - sx(maxPx)) * (px - sx(maxPx)) + (py - sy(maxPy)) * (py - sy(maxPy)) <= r2) return 1;
          final tipPx = tail.x + backDirX * len, tipPy = tail.y + backDirY * len;
          if ((px - sx(tipPx)) * (px - sx(tipPx)) + (py - sy(tipPy)) * (py - sy(tipPy)) <= r2) return 2;
          return null;
        }

        const double _tailGrabRadius = 36.0;
        double _dist2ToSegment(double px, double py, double x0, double y0, double x1, double y1) {
          final dx = x1 - x0, dy = y1 - y0;
          final len2 = dx * dx + dy * dy;
          if (len2 < 1e-10) return (px - x0) * (px - x0) + (py - y0) * (py - y0);
          var t = ((px - x0) * dx + (py - y0) * dy) / len2;
          t = t.clamp(0.0, 1.0);
          final nx = x0 + t * dx, ny = y0 + t * dy;
          return (px - nx) * (px - nx) + (py - ny) * (py - ny);
        }
        bool _isPointOnTail(double px, double py) {
          if (widget.creature.tailFin == null || positions.isEmpty || _spine.segmentAngles.isEmpty) return false;
          final tail = positions.first;
          final tailA = _spine.segmentAngles[0];
          final back = tailA + pi;
          final len = _effectiveTailLen();
          final tipX = tail.x + cos(back) * len;
          final tipY = tail.y + sin(back) * len;
          double sx(double wx) => centerX + (wx - cameraX) * _zoom;
          double sy(double wy) => centerY + (wy - cameraY) * _zoom;
          final s0x = sx(tail.x), s0y = sy(tail.y), s1x = sx(tipX), s1y = sy(tipY);
          final d2 = _dist2ToSegment(px, py, s0x, s0y, s1x, s1y);
          return d2 <= _tailGrabRadius * _tailGrabRadius;
        }

        Widget stackContent = Stack(
          key: _previewKey,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: SolidBackgroundPainter(color: kEditorBackground),
                size: Size(w, h),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: BackgroundPainter(view: view, timeSeconds: _backgroundTimeSeconds),
                size: Size(w, h),
              ),
            ),
            SizedBox(
              key: _previewContentKey,
              width: w,
              height: h,
              child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                onScaleStart: (d) {
                  final lx = d.localFocalPoint.dx;
                  final ly = d.localFocalPoint.dy;
                  if (d.pointerCount >= 2) {
                    _pinchStartZoom = _zoom;
                  } else {
                    _panStartX = lx;
                    _panStartY = ly;
                    _lastPanX = lx;
                    _lastPanY = ly;
                    if (isBodyEdit) {
                      final node = _hitBodyNode(lx, ly);
                      if (node != null && widget.onSegmentCountChanged != null) {
                        _bodyDraggingNode = node;
                      } else if (node == null && widget.onSegmentWidthDelta != null) {
                        _bodyWidthDragSeg = segmentAtScreen(lx, ly).clamp(0, _spine.segmentCount - 1);
                        final seg = _bodyWidthDragSeg!;
                        final pos = _spine.positions;
                        if (seg < pos.length - 1) {
                          final cx = (pos[seg].x + pos[seg + 1].x) / 2;
                          final cy = (pos[seg].y + pos[seg + 1].y) / 2;
                          final sx = centerX + (cx - cameraX) * _zoom;
                          final sy = centerY + (cy - cameraY) * _zoom;
                          _bodyWidthDragLastDist = sqrt((lx - sx) * (lx - sx) + (ly - sy) * (ly - sy));
                        }
                      } else if (node == null) {
                        final worldX = (lx - centerX) / _zoom + cameraX;
                        final worldY = (ly - centerY) / _zoom + cameraY;
                        setState(() { _dragTargetX = worldX; _dragTargetY = worldY; });
                      }
                    } else if (editTab == 2 && !widget.panelClosed) {
                      // Fins tab: dorsal (body then node) -> lateral -> tail -> target (same one-drag-to-remove as tail)
                      final dorsalIdx = _dorsalFinIndexAtScreen(lx, ly);
                      final dorsalNode = _hitDorsalNode(lx, ly);
                      if (dorsalIdx != null && dorsalNode == null) {
                        setState(() {
                          _tailSelected = false;
                          _dorsalDragFromFin = true;
                        });
                        widget.onDorsalFinSelected?.call(dorsalIdx);
                      } else if (widget.selectedDorsalFinIndex != null && dorsalNode != null) {
                        _dorsalDraggingNode = dorsalNode;
                      } else {
                        final lateralSeg = _lateralSegNearScreen(lx, ly);
                        if (lateralSeg != null) {
                          _lateralPanStartSeg = lateralSeg;
                          if (widget.onLateralMoved != null) _lateralDragFromSeg = lateralSeg;
                        } else {
                          final tailNode = _hitTailNode(lx, ly);
                          if (tailNode != null &&
                              _tailSelected &&
                              (widget.onTailRootWidthChanged != null ||
                                  widget.onTailMaxWidthChanged != null ||
                                  widget.onTailLengthChanged != null)) {
                            _tailDraggingNode = tailNode;
                            _tailDragStartValue = tailNode == 0
                                ? _effectiveTailRoot()
                                : (tailNode == 1 ? _effectiveTailMax() : _effectiveTailLen());
                          } else if (tailNode == null &&
                              _isPointOnTail(lx, ly) &&
                              widget.creature.tailFin != null &&
                              widget.onTailRemoved != null) {
                            widget.onDorsalFinSelected?.call(null);
                            setState(() {
                              _tailSelected = true;
                              _tailDragFromCreature = true;
                            });
                          } else if (!isSpineLocked) {
                            final worldX = (lx - centerX) / _zoom + cameraX;
                            final worldY = (ly - centerY) / _zoom + cameraY;
                            setState(() { _dragTargetX = worldX; _dragTargetY = worldY; });
                          }
                        }
                      }
                    } else if (!isSpineLocked) {
                      final worldX = (lx - centerX) / _zoom + cameraX;
                      final worldY = (ly - centerY) / _zoom + cameraY;
                      setState(() { _dragTargetX = worldX; _dragTargetY = worldY; });
                    }
                  }
                },
                onScaleUpdate: (d) {
                  final lx = d.localFocalPoint.dx;
                  final ly = d.localFocalPoint.dy;
                  if (_pinchStartZoom != null && d.pointerCount >= 2) {
                    setState(() {
                      _zoom = (_pinchStartZoom! * d.scale).clamp(_minZoom, _maxZoom);
                    });
                    return;
                  }
                  _lastPanX = lx;
                  _lastPanY = ly;
                  if (_tailDragFromCreature) {
                    setState(() {});
                    return;
                  }
                  if (_bodyDraggingNode != null && widget.onSegmentCountChanged != null) {
                    widget.onSegmentCountChanged!(_segmentCountFromTailDrag(centerX, centerY, cameraX, cameraY, positions));
                    setState(() {});
                    return;
                  }
                  if (_tailDraggingNode != null && positions.isNotEmpty && _spine.segmentAngles.isNotEmpty) {
                    final tailA = _spine.segmentAngles[0];
                    final back = tailA + pi;
                    final leftDirX = sin(tailA);
                    final leftDirY = -cos(tailA);
                    final backDirX = cos(back);
                    final backDirY = sin(back);
                    final dx = (_lastPanX - _panStartX) / _zoom;
                    final dy = (_lastPanY - _panStartY) / _zoom;
                    if (_tailDraggingNode == 0 && widget.onTailRootWidthChanged != null) {
                      final delta = dx * leftDirX + dy * leftDirY;
                      final v = (_tailDragStartValue + delta).clamp(Creature.tailRootWidthMin, Creature.tailRootWidthMax);
                      widget.onTailRootWidthChanged!(v);
                    } else if (_tailDraggingNode == 1 && widget.onTailMaxWidthChanged != null) {
                      final delta = dx * leftDirX + dy * leftDirY;
                      final v = (_tailDragStartValue + delta).clamp(Creature.tailMaxWidthMin, Creature.tailMaxWidthMax);
                      widget.onTailMaxWidthChanged!(v);
                    } else if (_tailDraggingNode == 2 && widget.onTailLengthChanged != null) {
                      final delta = dx * backDirX + dy * backDirY;
                      final v = (_tailDragStartValue + delta).clamp(Creature.tailLengthMin, Creature.tailLengthMax);
                      widget.onTailLengthChanged!(v);
                    }
                    setState(() {});
                    return;
                  }
                  if (_dorsalDraggingNode != null) {
                    final fins = widget.creature.dorsalFins ?? [];
                    final idx = widget.selectedDorsalFinIndex;
                    if (idx != null && idx < fins.length && widget.onDorsalRangeChanged != null) {
                      final range = fins[idx].$1;
                      if (range.isNotEmpty) {
                        final seg = segmentAtScreen(_lastPanX, _lastPanY).clamp(0, _spine.segmentCount - 1);
                        if (_dorsalDraggingNode == 0) {
                          widget.onDorsalRangeChanged!(seg.clamp(0, range.last), range.last);
                        } else if (_dorsalDraggingNode == 1) {
                          widget.onDorsalRangeChanged!(range.first, seg.clamp(range.first, _spine.segmentCount - 1));
                        }
                      }
                    }
                    if (_dorsalDraggingNode == 2 && widget.onDorsalHeightChanged != null) {
                      final frac = (1.0 - _lastPanY / h).clamp(0.0, 1.0);
                      final height = frac < 0.33 ? kDorsalHeightSmall : (frac < 0.66 ? kDorsalHeightMedium : kDorsalHeightLarge);
                      widget.onDorsalHeightChanged!(height);
                    }
                    setState(() {});
                    return;
                  }
                  if (_bodyWidthDragSeg != null && widget.onSegmentWidthDelta != null) {
                    const scale = 0.15;
                    final seg = _bodyWidthDragSeg!;
                    final pos = positions;
                    if (seg < pos.length - 1) {
                      final cx = (pos[seg].x + pos[seg + 1].x) / 2;
                      final cy = (pos[seg].y + pos[seg + 1].y) / 2;
                      final sx = centerX + (cx - cameraX) * _zoom;
                      final sy = centerY + (cy - cameraY) * _zoom;
                      final currentDist = sqrt((_lastPanX - sx) * (_lastPanX - sx) + (_lastPanY - sy) * (_lastPanY - sy));
                      final delta = (currentDist - _bodyWidthDragLastDist) * scale;
                      widget.onSegmentWidthDelta!(seg, delta);
                      _bodyWidthDragLastDist = currentDist;
                    }
                    setState(() {});
                    return;
                  }
                  if (_bodyDraggingNode != null || _dorsalDragFromFin || _dorsalDragStartSeg != null || _lateralDragFromSeg != null) return;
                  if (isSpineLocked) return;
                  final worldX = (lx - centerX) / _zoom + cameraX;
                  final worldY = (ly - centerY) / _zoom + cameraY;
                  setState(() {
                    _dragTargetX = worldX;
                    _dragTargetY = worldY;
                  });
                },
                onScaleEnd: (_) {
                  _pinchStartZoom = null;
                  if (_tailDragFromCreature) {
                    if (!_finRemoveBounds().contains(Offset(_lastPanX, _lastPanY)) && widget.onTailRemoved != null) {
                      widget.onTailRemoved!();
                    }
                    setState(() => _tailDragFromCreature = false);
                    return;
                  }
                  if (_tailDraggingNode != null) {
                    setState(() => _tailDraggingNode = null);
                    return;
                  }
                  if (_bodyWidthDragSeg != null) {
                    setState(() => _bodyWidthDragSeg = null);
                    return;
                  }
                  if (_bodyDraggingNode != null && widget.onSegmentCountChanged != null) {
                    widget.onSegmentCountChanged!(_segmentCountFromTailDrag(centerX, centerY, cameraX, cameraY, positions));
                    setState(() => _bodyDraggingNode = null);
                    return;
                  }
                  if (_dorsalDraggingNode != null) {
                    setState(() => _dorsalDraggingNode = null);
                    return;
                  }
                  if (_dorsalDragFromFin && widget.onDorsalRemoved != null && widget.selectedDorsalFinIndex != null) {
                    if (!_finRemoveBounds().contains(Offset(_lastPanX, _lastPanY))) {
                      widget.onDorsalRemoved!(widget.selectedDorsalFinIndex!);
                    }
                    setState(() => _dorsalDragFromFin = false);
                    return;
                  }
                  if (_dorsalDragStartSeg != null && widget.onDorsalRangeChanged != null) {
                    final seg = segmentAtScreen(_lastPanX, _lastPanY);
                    final a = _dorsalDragStartSeg!;
                    widget.onDorsalRangeChanged!(a < seg ? a : seg, a < seg ? seg : a);
                    setState(() => _dorsalDragStartSeg = null);
                    return;
                  }
                  if (_lateralDragFromSeg != null) {
                    final releaseInBounds = _finRemoveBounds().contains(Offset(_lastPanX, _lastPanY));
                    if (!releaseInBounds && widget.onLateralRemoved != null) {
                      widget.onLateralRemoved!(_lateralDragFromSeg!);
                    } else if (releaseInBounds && widget.onLateralMoved != null) {
                      final seg = segmentAtScreen(_lastPanX, _lastPanY);
                      widget.onLateralMoved!(_lateralDragFromSeg!, seg);
                    }
                    setState(() { _lateralDragFromSeg = null; _lateralPanStartSeg = null; });
                    return;
                  }
                  if (editTab == 2 && widget.onDorsalFinSelected != null) {
                    final dist2 = (_lastPanX - _panStartX) * (_lastPanX - _panStartX) + (_lastPanY - _panStartY) * (_lastPanY - _panStartY);
                    if (dist2 < 100) {
                      final dorsalFound = _dorsalFinIndexAtScreen(_lastPanX, _lastPanY);
                      if (dorsalFound != null) {
                        setState(() => _tailSelected = false);
                        widget.onDorsalFinSelected!(dorsalFound);
                        setState(() {});
                        return;
                      }
                      // Tap elsewhere: deselect dorsal so user can interact with tail, laterals or empty space.
                      if (widget.selectedDorsalFinIndex != null &&
                          _hitDorsalNode(_lastPanX, _lastPanY) == null) {
                        widget.onDorsalFinSelected!(null);
                        setState(() {});
                      }
                    }
                  }
                  if (isLateralEdit && _lateralPanStartSeg != null) {
                    final dist2 = (_lastPanX - _panStartX) * (_lastPanX - _panStartX) + (_lastPanY - _panStartY) * (_lastPanY - _panStartY);
                    if (dist2 < 100) {
                      final laterals = widget.creature.lateralFins ?? [];
                      if (laterals.contains(_lateralPanStartSeg!) && widget.onLateralRemoved != null) {
                        widget.onLateralRemoved!(_lateralPanStartSeg!);
                      }
                    }
                    setState(() => _lateralPanStartSeg = null);
                    return;
                  }
                  final tapDist2 = (_lastPanX - _panStartX) * (_lastPanX - _panStartX) + (_lastPanY - _panStartY) * (_lastPanY - _panStartY);
                  if (tapDist2 < 100 && !_isPointOnTail(_lastPanX, _lastPanY)) {
                    setState(() => _tailSelected = false);
                  }
                  final pos = _spine.positions;
                  if (pos.isNotEmpty) {
                    final head = pos.last;
                    setState(() {
                      _dragTargetX = head.x;
                      _dragTargetY = head.y;
                    });
                  }
                },
                  child: CustomPaint(
                    size: Size(w, h),
                    painter: CreaturePainter(
                      creature: widget.creature,
                      spine: _spine,
                      view: view,
                    ),
                  ),
                ),
              ),
            if (isBodyEdit && widget.onSegmentCountChanged != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _BodyNodesOverlayPainter(
                      positions: positions,
                      centerX: centerX,
                      centerY: centerY,
                      cameraX: cameraX,
                      cameraY: cameraY,
                      zoom: _zoom,
                      activeNode: _bodyDraggingNode,
                    ),
                    size: Size(w, h),
                  ),
                ),
              ),
            if (_showTailNodes())
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _TailNodesOverlayPainter(
                      tailX: positions.first.x,
                      tailY: positions.first.y,
                      tailA: _spine.segmentAngles[0],
                      rootW: _effectiveTailRoot(),
                      maxW: _effectiveTailMax(),
                      len: _effectiveTailLen(),
                      centerX: centerX,
                      centerY: centerY,
                      cameraX: cameraX,
                      cameraY: cameraY,
                      zoom: _zoom,
                      activeNode: _tailDraggingNode,
                    ),
                    size: Size(w, h),
                  ),
                ),
              ),
            if (_tailDragFromCreature &&
                widget.creature.tailFin != null &&
                !_finRemoveBounds().contains(Offset(_lastPanX, _lastPanY)))
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _TailRemoveHighlightPainter(
                      creature: widget.creature,
                      positions: positions,
                      segmentAngles: _spine.segmentAngles,
                      centerX: centerX,
                      centerY: centerY,
                      cameraX: cameraX,
                      cameraY: cameraY,
                      zoom: _zoom,
                      bodyColor: Color(widget.creature.color),
                      widthAt: (i) => widthAtSegment(i),
                    ),
                    size: Size(w, h),
                  ),
                ),
              ),
            if (_tailAddDragLocal != null &&
                _tailAddDragPayload?.tailFin != null &&
                creatureScreenBounds().inflate(80).contains(_tailAddDragLocal!))
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _TailAddPreviewPainter(
                      creature: widget.creature,
                      previewTailFin: _tailAddDragPayload!.tailFin!,
                      positions: positions,
                      segmentAngles: _spine.segmentAngles,
                      centerX: centerX,
                      centerY: centerY,
                      cameraX: cameraX,
                      cameraY: cameraY,
                      zoom: _zoom,
                      bodyColor: Color(widget.creature.color),
                      widthAt: (i) => widthAtSegment(i),
                    ),
                    size: Size(w, h),
                  ),
                ),
              ),
            if (_dorsalDragFromFin && widget.selectedDorsalFinIndex != null && !_finRemoveBounds().contains(Offset(_lastPanX, _lastPanY))) ...[
              Builder(builder: (_) {
                final fins = widget.creature.dorsalFins ?? [];
                final idx = widget.selectedDorsalFinIndex!;
                if (idx >= fins.length) return const SizedBox.shrink();
                final range = fins[idx].$1;
                if (range.isEmpty) return const SizedBox.shrink();
                final startSeg = range.first.clamp(0, positions.length - 2);
                final endSeg = range.last.clamp(0, positions.length - 2);
                return Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _DorsalRangeHighlightPainter(
                        startSeg: startSeg,
                        endSeg: endSeg,
                        positions: positions,
                        centerX: centerX,
                        centerY: centerY,
                        cameraX: cameraX,
                        cameraY: cameraY,
                        zoom: _zoom,
                      ),
                      size: Size(w, h),
                    ),
                  ),
                );
              }),
            ],
            if (isDorsalEdit && widget.selectedDorsalFinIndex != null) ...[
              Builder(builder: (context) {
                final fins = widget.creature.dorsalFins ?? [];
                final idx = widget.selectedDorsalFinIndex!;
                if (idx >= fins.length) return const SizedBox.shrink();
                final range = fins[idx].$1;
                if (range.isEmpty) return const SizedBox.shrink();
                final startSeg = range.first.clamp(0, positions.length - 2);
                final endSeg = range.last.clamp(0, positions.length - 2);
                return Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _DorsalNodesOverlayPainter(
                        positions: positions,
                        startSeg: startSeg,
                        endSeg: endSeg,
                        centerX: centerX,
                        centerY: centerY,
                        cameraX: cameraX,
                        cameraY: cameraY,
                        zoom: _zoom,
                        activeNode: _dorsalDraggingNode,
                      ),
                      size: Size(w, h),
                    ),
                  ),
                );
              }),
            ],
            if (_dorsalAddDragLocal != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _DorsalDropHighlightPainter(
                      startSeg: _segmentAtLocal(_dorsalAddDragLocal!.dx, _dorsalAddDragLocal!.dy).clamp(0, (positions.length - 4).clamp(0, 999)),
                      positions: positions,
                      centerX: centerX,
                      centerY: centerY,
                      cameraX: cameraX,
                      cameraY: cameraY,
                      zoom: _zoom,
                      finColor: widget.creature.finColor != null ? Color(widget.creature.finColor!) : Color.lerp(Color(widget.creature.color), Colors.white, 0.15)!,
                    ),
                    size: Size(w, h),
                  ),
                ),
              ),
            if (_lateralAddDragLocal != null) ...[
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _LateralFinAtSegmentPainter(
                      segment: segmentAtScreen(_lateralAddDragLocal!.dx, _lateralAddDragLocal!.dy),
                      positions: positions,
                      segmentAngles: _spine.segmentAngles,
                      centerX: centerX,
                      centerY: centerY,
                      cameraX: cameraX,
                      cameraY: cameraY,
                      zoom: _zoom,
                      segWidth: widthAtSegment(segmentAtScreen(_lateralAddDragLocal!.dx, _lateralAddDragLocal!.dy)),
                      finColor: widget.creature.finColor != null ? Color(widget.creature.finColor!) : Color.lerp(Color(widget.creature.color), Colors.white, 0.15)!,
                      highlight: false,
                    ),
                    size: Size(w, h),
                  ),
                ),
              ),
            ],
            if (_lateralDragFromSeg != null) ...[
              if (_finRemoveBounds().contains(Offset(_lastPanX, _lastPanY)))
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _LateralFinAtSegmentPainter(
                        segment: segmentAtScreen(_lastPanX, _lastPanY).clamp(0, positions.length - 2),
                        positions: positions,
                        segmentAngles: _spine.segmentAngles,
                        centerX: centerX,
                        centerY: centerY,
                        cameraX: cameraX,
                        cameraY: cameraY,
                        zoom: _zoom,
                        segWidth: widthAtSegment(segmentAtScreen(_lastPanX, _lastPanY).clamp(0, positions.length - 2)),
                        finColor: widget.creature.finColor != null ? Color(widget.creature.finColor!) : Color.lerp(Color(widget.creature.color), Colors.white, 0.15)!,
                        highlight: false,
                      ),
                      size: Size(w, h),
                    ),
                  ),
                ),
              if (!_finRemoveBounds().contains(Offset(_lastPanX, _lastPanY)))
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _LateralFinAtSegmentPainter(
                        segment: _lateralDragFromSeg!,
                        positions: positions,
                        segmentAngles: _spine.segmentAngles,
                        centerX: centerX,
                        centerY: centerY,
                        cameraX: cameraX,
                        cameraY: cameraY,
                        zoom: _zoom,
                        segWidth: widthAtSegment(_lateralDragFromSeg!),
                        finColor: widget.creature.finColor != null ? Color(widget.creature.finColor!) : Color.lerp(Color(widget.creature.color), Colors.white, 0.15)!,
                        highlight: false,
                        highlightForRemove: true,
                      ),
                      size: Size(w, h),
                    ),
                  ),
                ),
            ],
            Positioned(
              left: 12,
              bottom: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _zoomBtn(() => setState(() => _zoom = (_zoom - _zoomStep).clamp(_minZoom, _maxZoom)), '−'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('${(_zoom * 100).round()}%', style: const TextStyle(color: Colors.white)),
                      ),
                      _zoomBtn(() => setState(() => _zoom = (_zoom + _zoomStep).clamp(_minZoom, _maxZoom)), '+'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
        Widget inner = stackContent;
        if (editTab == 2 && widget.onTailAdded != null) {
          final child = inner;
          inner = DragTarget<TailDragPayload>(
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (d) {
              final box = _previewContentKey.currentContext?.findRenderObject() as RenderBox?;
              if (box != null && box.hasSize) {
                final local = box.globalToLocal(d.offset);
                if (creatureScreenBounds().inflate(80).contains(local)) {
                  widget.onTailAdded!(d.data.tailFin);
                }
              }
              setState(() { _tailAddDragLocal = null; _tailAddDragPayload = null; });
            },
            onMove: (d) {
              final box = _previewContentKey.currentContext?.findRenderObject() as RenderBox?;
              if (box != null && box.hasSize) {
                setState(() {
                  _tailAddDragLocal = box.globalToLocal(d.offset);
                  _tailAddDragPayload = d.data;
                });
              }
            },
            onLeave: (_) => setState(() { _tailAddDragLocal = null; _tailAddDragPayload = null; }),
            builder: (context, candidateData, rejectedData) => child,
          );
        }
        if (editTab == 2 && widget.onLateralAdded != null) {
          final child = inner;
          inner = DragTarget<LateralDragPayload>(
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (d) {
              final box = _previewContentKey.currentContext?.findRenderObject() as RenderBox?;
              if (box != null && box.hasSize) {
                final local = box.globalToLocal(d.offset);
                widget.onLateralAdded!(_segmentAtLocal(local.dx, local.dy));
              }
              setState(() => _lateralAddDragLocal = null);
            },
            onMove: (d) {
              final box = _previewContentKey.currentContext?.findRenderObject() as RenderBox?;
              if (box != null && box.hasSize) {
                setState(() => _lateralAddDragLocal = box.globalToLocal(d.offset));
              }
            },
            onLeave: (_) => setState(() => _lateralAddDragLocal = null),
            builder: (context, candidateData, rejectedData) => child,
          );
        }
        if (editTab == 2 && widget.onDorsalAdded != null) {
          final child = inner;
          return DragTarget<DorsalDragPayload>(
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (d) {
              final box = _previewContentKey.currentContext?.findRenderObject() as RenderBox?;
              if (box != null && box.hasSize) {
                final local = box.globalToLocal(d.offset);
                widget.onDorsalAdded!(_segmentAtLocal(local.dx, local.dy));
              }
              setState(() => _dorsalAddDragLocal = null);
            },
            onMove: (d) {
              final box = _previewContentKey.currentContext?.findRenderObject() as RenderBox?;
              if (box != null && box.hasSize) {
                setState(() => _dorsalAddDragLocal = box.globalToLocal(d.offset));
              }
            },
            onLeave: (_) => setState(() => _dorsalAddDragLocal = null),
            builder: (context, candidateData, rejectedData) => child,
          );
        }
        return inner;
      },
    );
  }

  Widget _zoomBtn(VoidCallback onTap, String label) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        ),
        alignment: Alignment.center,
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 18)),
      ),
    );
  }
}
