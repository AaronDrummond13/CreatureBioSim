import 'dart:math' show atan2, cos, pi, sin, sqrt;
import 'package:creature_bio_sim/editor/editor_preview/body_node_painter.dart';
import 'package:creature_bio_sim/editor/editor_preview/dorsal_node_painter.dart';
import 'package:creature_bio_sim/editor/editor_preview/dorsal_preview_painter.dart';
import 'package:creature_bio_sim/editor/editor_preview/eye_node_painter.dart';
import 'package:creature_bio_sim/editor/editor_preview/eye_preview_painter.dart';
import 'package:creature_bio_sim/editor/editor_preview/mouth_node_painter.dart';
import 'package:creature_bio_sim/editor/editor_preview/mouth_preview_painter.dart';
import 'package:creature_bio_sim/editor/editor_preview/pec_fin_node_painter.dart';
import 'package:creature_bio_sim/editor/editor_preview/pec_fin_segment_painter.dart';
import 'package:creature_bio_sim/editor/editor_preview/remove_dorsal_painter.dart';
import 'package:creature_bio_sim/editor/editor_preview/remove_mouth_painter.dart';
import 'package:creature_bio_sim/editor/editor_preview/remove_tail_painter.dart';
import 'package:creature_bio_sim/editor/editor_preview/spine_node_painter.dart';
import 'package:creature_bio_sim/editor/editor_preview/tail_node_painter.dart';
import 'package:creature_bio_sim/editor/editor_preview/tail_preview_painter.dart';
import 'package:creature_bio_sim/editor/node_painter.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:creature_bio_sim/creature.dart';
import 'package:creature_bio_sim/render/background_painter.dart';
import 'package:creature_bio_sim/render/creature_painter.dart';
import 'package:creature_bio_sim/render/view.dart';
import 'package:creature_bio_sim/simulation/spine.dart';
import 'package:creature_bio_sim/simulation/vector.dart';
import 'package:creature_bio_sim/simulation_view_state.dart';
import 'package:creature_bio_sim/editor/editor_shared.dart';
import 'package:creature_bio_sim/editor/editor_style.dart';

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
    this.selectedLateralFinIndex,
    this.onLateralRemoved,
    this.onLateralFinSelected,
    this.onLateralLengthChanged,
    this.onLateralWidthChanged,
    this.onLateralAngleChanged,
    this.onMouthAdded,
    this.onMouthRemoved,
    this.onMouthLengthChanged,
    this.onMouthCurveChanged,
    this.onMouthWobbleAmplitudeChanged,
    this.selectedMouth = false,
    this.onMouthSelected,
    this.selectedEyeIndex,
    this.onEyeSelected,
    this.onEyeAdded,
    this.onEyeRemoved,
    this.onEyeMoved,
    this.onEyeRadiusChanged,
    this.onEyePupilFractionChanged,
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
  final void Function(int fromIndex, int toSeg)? onLateralMoved;
  final void Function(int seg, LateralWingType wingType)? onLateralAdded;
  final int? selectedLateralFinIndex;
  final void Function(int index)? onLateralRemoved;
  final void Function(int? index)? onLateralFinSelected;
  final void Function(int index, double value)? onLateralLengthChanged;
  final void Function(int index, double value)? onLateralWidthChanged;
  final void Function(int index, double angleDegrees)? onLateralAngleChanged;
  final void Function(MouthType? type, int? mouthCount)? onMouthAdded;
  final void Function()? onMouthRemoved;
  final void Function(double length)? onMouthLengthChanged;
  final void Function(double curve)? onMouthCurveChanged;
  final void Function(double wobbleAmplitude)? onMouthWobbleAmplitudeChanged;
  final bool selectedMouth;
  final void Function(bool selected)? onMouthSelected;
  final int? selectedEyeIndex;
  final void Function(int? index)? onEyeSelected;
  final void Function(int segment, double offsetFromCenter)? onEyeAdded;
  final void Function(int index)? onEyeRemoved;
  final void Function(int index, int segment, double offsetFromCenter)?
  onEyeMoved;
  final void Function(int index, double value)? onEyeRadiusChanged;
  final void Function(int index, double pupilFraction)?
  onEyePupilFractionChanged;

  @override
  State<EditorPreview> createState() => _EditorPreviewState();
}

class _EditorPreviewState extends State<EditorPreview>
    with SingleTickerProviderStateMixin {
  late Spine _spine;
  double _dragTargetX = 0;
  double _dragTargetY = 0;
  double _zoom = 2;
  late Ticker _ticker;
  int? _dorsalDragStartSeg;
  bool _dorsalDragFromFin = false;
  int? _dorsalDraggingNode; // 0=start, 1=end, 2=height
  int? _bodyDraggingNode; // 0=tail
  int? _bodyWidthDragSeg;
  double _bodyWidthDragLastPanY = 0;
  int? _tailDraggingNode; // 0=root, 1=max, 2=length
  double _tailDragStartValue = 0;
  bool _tailDragFromCreature = false;
  bool _tailSelected = false;
  Offset? _tailAddDragLocal;
  TailDragPayload? _tailAddDragPayload;
  Offset? _mouthAddDragLocal;
  MouthDragPayload? _mouthAddDragPayload;
  bool _mouthDragFromCreature = false;
  int? _mouthDraggingNode; // 0=length, 1=width
  Offset? _eyeAddDragLocal;
  bool _eyeDragFromCreature = false;
  int? _eyeDraggingNode; // 0 = radius node
  int? _lateralDragFromIndex;
  int? _lateralPanStartIndex;
  int?
  _lateralDraggingNode; // 0=lengthLeft, 1=widthLeft, 2=lengthRight, 3=widthRight
  double _lastPanX = 0;
  double _lastPanY = 0;
  double _panStartX = 0;
  double _panStartY = 0;
  double? _pinchStartZoom;
  Size _lastPreviewSize = Size.zero;
  double _lastCameraX = 0;
  double _lastCameraY = 0;
  double _editorCameraX = 0;
  double _editorCameraY = 0;
  bool _editorCameraInitialized = false;
  double _editorPanOffsetX = 0;
  double _editorPanOffsetY = 0;
  bool _editorPanning = false;
  bool _editorPotentialPan = false;
  static const double _panDragSlop = 10.0;

  /// Test mode (panel closed): store touch so we refresh target from camera each tick (same as play mode).
  Offset? _editorTouchLocal;
  Size? _editorTouchScreenSize;
  bool _editorTouchFrozen = false;
  int _editorPointerCount = 0;
  Offset? _lateralAddDragLocal;
  LateralDragPayload? _lateralAddDragPayload;
  Offset? _dorsalAddDragLocal;
  double _backgroundTimeSeconds = 0.0;
  double? _lastEditorRealTimeSeconds;
  final GlobalKey _previewKey = GlobalKey();
  final GlobalKey _previewContentKey = GlobalKey();

  int _segmentCountFromTailDrag(
    double centerX,
    double centerY,
    double cameraX,
    double cameraY,
    List<Vector2> positions,
  ) {
    final dropWx = (_lastPanX - centerX) / _zoom + cameraX;
    final dropWy = (_lastPanY - centerY) / _zoom + cameraY;
    final headW = positions.last;
    final tailW = positions.first;
    final headToDropX = dropWx - headW.x;
    final headToDropY = dropWy - headW.y;
    final headToTailX = tailW.x - headW.x;
    final headToTailY = tailW.y - headW.y;
    final headToTailLen = sqrt(
      headToTailX * headToTailX + headToTailY * headToTailY,
    );
    const nodeOffset = BodyNodePainter.outsideOffset;
    final projectedDist = headToTailLen > 1e-6
        ? (headToDropX * headToTailX + headToDropY * headToTailY) /
              headToTailLen
        : 0.0;
    final spineLength = projectedDist - nodeOffset;
    return spineLength <= 0
        ? 1
        : (spineLength / _spine.segmentLength).round().clamp(
            1,
            Creature.maxSegmentCount,
          );
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
      if (d2 < bestD2) {
        bestD2 = d2;
        best = i;
      }
    }
    return best.clamp(0, _spine.segmentCount - 1);
  }

  /// Returns (segment, offsetFromCenter 0..offsetMax). 0 = on spine (single eye), (0, offsetMax] = symmetric pair.
  (int, double) _segmentAndOffsetAtLocal(double sx, double sy) {
    if (_lastPreviewSize.width <= 0 || _lastPreviewSize.height <= 0)
      return (0, 0.0);
    final centerX = _lastPreviewSize.width / 2;
    final centerY = _lastPreviewSize.height / 2;
    final positions = _spine.positions;
    final wx = (sx - centerX) / _zoom + _lastCameraX;
    final wy = (sy - centerY) / _zoom + _lastCameraY;
    if (positions.length < 2 || _spine.segmentAngles.isEmpty) return (0, 0.0);
    var bestSeg = 0;
    var bestD2 = 1e20;
    for (var i = 0; i < positions.length - 1; i++) {
      final cx = (positions[i].x + positions[i + 1].x) / 2;
      final cy = (positions[i].y + positions[i + 1].y) / 2;
      final d2 = (wx - cx) * (wx - cx) + (wy - cy) * (wy - cy);
      if (d2 < bestD2) {
        bestD2 = d2;
        bestSeg = i;
      }
    }
    final seg = bestSeg.clamp(0, _spine.segmentCount - 1);
    final cx = (positions[seg].x + positions[seg + 1].x) / 2;
    final cy = (positions[seg].y + positions[seg + 1].y) / 2;
    final a = _spine.segmentAngles[seg];
    final perpDist = -(wx - cx) * sin(a) + (wy - cy) * cos(a);
    final halfW = widget.creature.widthAtVertex(seg);
    if (halfW <= 0) return (seg, 0.0);
    var offset = (perpDist.abs() / halfW).clamp(0.0, EyeConfig.offsetMax);
    if (offset < EyeConfig.singleEyeThreshold) offset = 0.0;
    return (seg, offset);
  }

  static double get _minZoom => SimulationViewState.minZoom;
  static double get _maxZoom => SimulationViewState.maxZoom;
  static const double _zoomStep = 0.15;

  /// Same as SimulationScreen: fixed distance per step so speed is constant.
  static final double _headMoveSpeed = Spine.defaultMoveSpeed;
  static const double _arrivalThreshold = 20.0;

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
    if (_spine.segmentCount != widget.creature.segmentCount) {
      _spine = Spine(segmentCount: widget.creature.segmentCount);
      _positionSpineHeadAtOrigin();
      final head = _spine.positions.isNotEmpty ? _spine.positions.last : null;
      if (head != null) {
        _dragTargetX = head.x;
        _dragTargetY = head.y;
      }
    }
    if (widget.panelClosed && !oldWidget.panelClosed) {
      _editorCameraInitialized = false;
    }
    if (!widget.panelClosed && oldWidget.panelClosed) {
      _editorTouchLocal = null;
      _editorTouchScreenSize = null;
      _editorTouchFrozen = false;
      _editorPointerCount = 0;
      _editorPanOffsetX = 0;
      _editorPanOffsetY = 0;
    }
    if (widget.panelClosed && !oldWidget.panelClosed) {
      _editorPotentialPan = false;
    }
    final newLaterals = widget.creature.lateralFins?.length ?? 0;
    if (_lateralDragFromIndex != null &&
        (newLaterals == 0 || _lateralDragFromIndex! >= newLaterals)) {
      _lateralDragFromIndex = null;
      _lateralPanStartIndex = null;
    }
    if (widget.editTabIndex != oldWidget.editTabIndex) {
      _tailSelected = false;
      _tailDragFromCreature = false;
      _tailDraggingNode = null;
      _mouthDragFromCreature = false;
      _mouthDraggingNode = null;
      _dorsalDragFromFin = false;
      _dorsalDraggingNode = null;
      _eyeDragFromCreature = false;
      _eyeDraggingNode = null;
      _lateralDraggingNode = null;
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
    final realTimeSeconds = d.inMilliseconds / 1000.0;
    _backgroundTimeSeconds = realTimeSeconds;
    _lastEditorRealTimeSeconds ??= realTimeSeconds;
    final realDt = realTimeSeconds - _lastEditorRealTimeSeconds!;
    _lastEditorRealTimeSeconds = realTimeSeconds;
    final isSpineLocked = !widget.panelClosed;
    final steps = (realDt / _kFixedDt).round().clamp(0, _kMaxStepsPerFrame);
    for (var i = 0; i < steps; i++) {
      final head = _spine.positions.isNotEmpty ? _spine.positions.last : null;
      if (isSpineLocked) {
        if (head != null) {
          _dragTargetX = head.x;
          _dragTargetY = head.y;
        }
      } else if (head != null &&
          _editorTouchLocal != null &&
          _editorTouchScreenSize != null &&
          !_editorTouchFrozen) {
        final local = _editorTouchLocal!;
        final size = _editorTouchScreenSize!;
        _dragTargetX = head.x + (local.dx - size.width / 2) / _zoom;
        _dragTargetY = head.y + (local.dy - size.height / 2) / _zoom;
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
        } else {
          _spine.resolve(_dragTargetX, _dragTargetY, speed: _headMoveSpeed);
        }
      }
    }
    if (widget.panelClosed) {
      final pos = _spine.positions;
      if (pos.isNotEmpty) {
        final head = pos.last;
        if (!_editorCameraInitialized) {
          _editorCameraX = head.x;
          _editorCameraY = head.y;
          _editorCameraInitialized = true;
        } else {
          _editorCameraX = head.x;
          _editorCameraY = head.y;
        }
        setState(() {});
      }
    }
    if (steps > 0 && !widget.panelClosed) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final positions = _spine.positions;
    double cameraX = 0.0;
    double cameraY = 0.0;
    if (positions.isNotEmpty) {
      if (widget.panelClosed) {
        cameraX = _editorCameraX;
        cameraY = _editorCameraY;
      } else {
        final mid = positions.length ~/ 2;
        final central = positions[mid];
        cameraX = central.x + _editorPanOffsetX;
        cameraY = central.y + _editorPanOffsetY;
      }
    }
    _lastCameraX = cameraX;
    _lastCameraY = cameraY;
    final view = CameraView(cameraX: cameraX, cameraY: cameraY, zoom: _zoom);

    final editTab = widget.editTabIndex ?? 0;
    final isBodyEdit = editTab == 0 && !widget.panelClosed;
    final isTailEdit = editTab == 1 && !widget.panelClosed;
    final isDorsalEdit =
        editTab == 1 &&
        widget.selectedDorsalFinIndex != null &&
        !widget.panelClosed;
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
            if (d2 < bestD2) {
              bestD2 = d2;
              best = i;
            }
          }
          return best.clamp(0, _spine.segmentCount - 1);
        }

        double widthAtSegment(int seg) {
          final v = widget.creature.segmentWidths;
          if (seg < 0 || seg >= v.length) return 20.0;
          return v[seg];
        }

        /// Half-width at vertex (matches CreaturePainter / widthAtVertex for lateral fin attachment).
        double widthAtVertex(int vertexIndex) =>
            widget.creature.widthAtVertex(vertexIndex);

        Rect creatureScreenBounds() {
          final pos = _spine.positions;
          if (pos.isEmpty)
            return Rect.fromLTWH(centerX - 20, centerY - 20, 40, 40);
          var minX = double.infinity,
              minY = double.infinity,
              maxX = -double.infinity,
              maxY = -double.infinity;
          for (final p in pos) {
            final sx = centerX + (p.x - cameraX) * _zoom;
            final sy = centerY + (p.y - cameraY) * _zoom;
            if (sx < minX) minX = sx;
            if (sy < minY) minY = sy;
            if (sx > maxX) maxX = sx;
            if (sy > maxY) maxY = sy;
          }
          const margin = 40.0;
          return Rect.fromLTRB(
            minX - margin,
            minY - margin,
            maxX + margin,
            maxY + margin,
          );
        }

        Rect finRemoveBounds() =>
            creatureScreenBounds().inflate(kFinRemoveMargin);

        int? dorsalFinIndexAtScreen(double px, double py) {
          final fins = widget.creature.dorsalFins ?? [];
          if (fins.isEmpty || positions.length < 2) return null;
          final r2 = kDorsalGrabRadius * kDorsalGrabRadius;
          for (var i = 0; i < fins.length; i++) {
            final range = fins[i].$1;
            if (range.isEmpty) continue;
            for (
              var seg = range.first;
              seg <= range.last && seg < positions.length - 1;
              seg++
            ) {
              final cx = (positions[seg].x + positions[seg + 1].x) / 2;
              final cy = (positions[seg].y + positions[seg + 1].y) / 2;
              final sx = centerX + (cx - cameraX) * _zoom;
              final sy = centerY + (cy - cameraY) * _zoom;
              if ((px - sx) * (px - sx) + (py - sy) * (py - sy) <= r2) return i;
            }
          }
          return null;
        }

        /// Point-in-ellipse: (px,py) in screen space, ellipse center (cx,cy), angle, semi-axes a,b in screen space.
        bool pointInEllipseScreen(
          double px,
          double py,
          double cx,
          double cy,
          double angle,
          double a,
          double b,
        ) {
          final dx = px - cx;
          final dy = py - cy;
          final cosA = cos(angle);
          final sinA = sin(angle);
          final localX = dx * cosA + dy * sinA;
          final localY = -dx * sinA + dy * cosA;
          if (a <= 0 || b <= 0) return false;
          return (localX / a) * (localX / a) + (localY / b) * (localY / b) <=
              1.0;
        }

        int? lateralIndexNearScreen(double px, double py) {
          final laterals = widget.creature.lateralFins ?? [];
          if (laterals.isEmpty || positions.length < 2) return null;
          final segAngles = _spine.segmentAngles;
          if (segAngles.isEmpty) return null;
          double sx(double wx) => centerX + (wx - cameraX) * _zoom;
          double sy(double wy) => centerY + (wy - cameraY) * _zoom;
          for (var i = 0; i < laterals.length; i++) {
            final config = laterals[i];
            final seg = config.segment;
            if (seg < 0 ||
                seg >= positions.length - 1 ||
                seg >= segAngles.length)
              continue;
            final flareRad = config.angleDegrees * pi / 180.0;
            final halfW = widthAtVertex(seg);
            final aAttach = segAngles[seg];
            final segHead = seg + 1 < segAngles.length ? seg + 1 : seg;
            final aLock = segAngles[segHead];
            final leftAngle = aLock + flareRad;
            final rightAngle = aLock - flareRad;
            final lenScreen = config.length * _zoom;
            final widScreen = config.width * _zoom;
            final aScreen = lenScreen / 2;
            final bScreen = widScreen / 2;
            final pxW = positions[seg].x, pyW = positions[seg].y;
            final leftCx = pxW + sin(aAttach) * halfW;
            final leftCy = pyW - cos(aAttach) * halfW;
            final rightCx = pxW - sin(aAttach) * halfW;
            final rightCy = pyW + cos(aAttach) * halfW;
            final leftSx = sx(leftCx);
            final leftSy = sy(leftCy);
            final rightSx = sx(rightCx);
            final rightSy = sy(rightCy);
            if (pointInEllipseScreen(
              px,
              py,
              leftSx,
              leftSy,
              leftAngle,
              aScreen,
              bScreen,
            ))
              return i;
            if (pointInEllipseScreen(
              px,
              py,
              rightSx,
              rightSy,
              rightAngle,
              aScreen,
              bScreen,
            ))
              return i;
          }
          return null;
        }

        bool isPointOnMouth(double px, double py) {
          if (widget.creature.mouth == null || positions.length < 2)
            return false;
          final head = positions.last;
          final headSeg = (positions.length - 2).clamp(0, positions.length - 1);
          final headW = widthAtSegment(headSeg) * _zoom * 1.4;
          final sx = centerX + (head.x - cameraX) * _zoom;
          final sy = centerY + (head.y - cameraY) * _zoom;
          return (px - sx) * (px - sx) + (py - sy) * (py - sy) <= headW * headW;
        }

        const double mouthNodeRadius = 14.0;

        /// Match mouth_painter: headSizeRef 30, sizeScale = headW/30; spikes extend length*sizeScale in world.
        const double mouthHeadSizeRef = 30.0;

        /// Extra forward offset so nodes sit clearly in front of the drawn spikes (world units).
        const double mouthNodeForwardOffset = 14.0;

        /// Two nodes when creature has teeth or tentacle: [length, width]. Length = end of spikes + offset; width = middle + offset.
        List<Offset>? mouthNodePositions() {
          if (positions.length < 2 || _spine.segmentAngles.isEmpty) return null;
          final mouth = widget.creature.mouth;
          if (mouth != MouthType.teeth && mouth != MouthType.tentacle)
            return null;
          double sx(double wx) => centerX + (wx - cameraX) * _zoom;
          double sy(double wy) => centerY + (wy - cameraY) * _zoom;
          final head = positions.last;
          final headA = _spine.segmentAngles.last;
          final forwardX = cos(headA);
          final forwardY = sin(headA);
          final perpX = -sin(headA);
          final perpY = cos(headA);
          final headSeg = (positions.length - 2).clamp(0, positions.length - 1);
          final headW = widthAtSegment(headSeg);
          final sizeScale = headW / mouthHeadSizeRef;
          final length =
              widget.creature.mouthLength ?? MouthParams.lengthDefault;
          final spikeLengthWorld = length * sizeScale;
          final lengthNodeX =
              head.x + forwardX * (spikeLengthWorld + mouthNodeForwardOffset);
          final lengthNodeY =
              head.y + forwardY * (spikeLengthWorld + mouthNodeForwardOffset);
          final midForward = spikeLengthWorld * 0.5 + mouthNodeForwardOffset;
          final widthNodeX =
              head.x + forwardX * midForward + perpX * (headW * 0.6);
          final widthNodeY =
              head.y + forwardY * midForward + perpY * (headW * 0.6);
          return [
            Offset(sx(lengthNodeX), sy(lengthNodeY)),
            Offset(sx(widthNodeX), sy(widthNodeY)),
          ];
        }

        int? hitMouthNode(double px, double py) {
          final nodes = mouthNodePositions();
          if (nodes == null) return null;
          final r2 = mouthNodeRadius * mouthNodeRadius;
          for (var i = 0; i < nodes.length; i++) {
            final o = nodes[i];
            if ((px - o.dx) * (px - o.dx) + (py - o.dy) * (py - o.dy) <= r2)
              return i;
          }
          return null;
        }

        const double eyeGrabRadius = 18.0;
        const double eyeNodeRadius = 14.0;

        /// Screen positions for one eye config (1 or 2 circles).
        List<Offset> eyeScreenPositions(EyeConfig eye) {
          if (positions.length < 2 || _spine.segmentAngles.isEmpty) return [];
          double sx(double wx) => centerX + (wx - cameraX) * _zoom;
          double sy(double wy) => centerY + (wy - cameraY) * _zoom;
          final seg = eye.segment.clamp(0, positions.length - 2);
          final cx = (positions[seg].x + positions[seg + 1].x) / 2;
          final cy = (positions[seg].y + positions[seg + 1].y) / 2;
          final a = _spine.segmentAngles[seg];
          final halfW = widthAtVertex(seg);
          final isSingle = eye.offsetFromCenter < EyeConfig.singleEyeThreshold;
          if (isSingle) return [Offset(sx(cx), sy(cy))];
          final off = eye.offsetFromCenter * halfW;
          final dx = -sin(a) * off;
          final dy = cos(a) * off;
          return [
            Offset(sx(cx + dx), sy(cy + dy)),
            Offset(sx(cx - dx), sy(cy - dy)),
          ];
        }

        int? eyeIndexAtScreen(double px, double py) {
          final eyes = widget.creature.eyes ?? [];
          final r2 = eyeGrabRadius * eyeGrabRadius;
          for (var i = 0; i < eyes.length; i++) {
            for (final pos in eyeScreenPositions(eyes[i])) {
              if ((px - pos.dx) * (px - pos.dx) +
                      (py - pos.dy) * (py - pos.dy) <=
                  r2)
                return i;
            }
          }
          return null;
        }

        /// Radius and pupil handles. Pupil node is at 90° to radius node. Single: [radius, pupil]. Pair: [leftRadius, rightRadius, leftPupil, rightPupil].
        List<Offset>? eyeNodePositions() {
          final eyes = widget.creature.eyes ?? [];
          final idx = widget.selectedEyeIndex;
          if (idx == null ||
              idx >= eyes.length ||
              positions.length < 2 ||
              _spine.segmentAngles.isEmpty)
            return null;
          final eye = eyes[idx];
          final seg = eye.segment.clamp(0, positions.length - 2);
          final cx = (positions[seg].x + positions[seg + 1].x) / 2;
          final cy = (positions[seg].y + positions[seg + 1].y) / 2;
          final a = _spine.segmentAngles[seg];
          final halfW = widthAtVertex(seg);
          double sx(double wx) => centerX + (wx - cameraX) * _zoom;
          double sy(double wy) => centerY + (wy - cameraY) * _zoom;
          final isSingle = eye.offsetFromCenter < EyeConfig.singleEyeThreshold;
          final pupilDist = eye.radius * eye.pupilFraction;
          // Radius direction (-sin(a), cos(a)); perpendicular (cos(a), sin(a)).
          if (isSingle) {
            final radiusX = cx + (-sin(a)) * eye.radius;
            final radiusY = cy + cos(a) * eye.radius;
            final pupilX = cx + cos(a) * pupilDist;
            final pupilY = cy + sin(a) * pupilDist;
            return [
              Offset(sx(radiusX), sy(radiusY)),
              Offset(sx(pupilX), sy(pupilY)),
            ];
          }
          final off = eye.offsetFromCenter * halfW;
          final dx = -sin(a) * off;
          final dy = cos(a) * off;
          final leftCx = cx + dx;
          final leftCy = cy + dy;
          final rightCx = cx - dx;
          final rightCy = cy - dy;
          return [
            Offset(
              sx(leftCx + (-sin(a)) * eye.radius),
              sy(leftCy + cos(a) * eye.radius),
            ),
            Offset(
              sx(rightCx + sin(a) * eye.radius),
              sy(rightCy + (-cos(a)) * eye.radius),
            ),
            Offset(
              sx(leftCx + cos(a) * pupilDist),
              sy(leftCy + sin(a) * pupilDist),
            ),
            Offset(
              sx(rightCx + cos(a) * pupilDist),
              sy(rightCy + sin(a) * pupilDist),
            ),
          ];
        }

        int? hitEyeNode(double px, double py) {
          final positions = eyeNodePositions();
          if (positions == null) return null;
          final r2 = eyeNodeRadius * eyeNodeRadius;
          for (var i = 0; i < positions.length; i++) {
            final o = positions[i];
            if ((px - o.dx) * (px - o.dx) + (py - o.dy) * (py - o.dy) <= r2)
              return i;
          }
          return null;
        }

        const double dorsalNodeRadius = 14.0;
        List<Offset>? dorsalNodePositions() {
          final fins = widget.creature.dorsalFins ?? [];
          final idx = widget.selectedDorsalFinIndex;
          if (idx == null || idx >= fins.length || positions.length < 2)
            return null;
          final range = fins[idx].$1;
          if (range.isEmpty) return null;
          final startSeg = range.first.clamp(0, positions.length - 2);
          final endSeg = range.last.clamp(0, positions.length - 2);
          double sx(double wx) => centerX + (wx - cameraX) * _zoom;
          double sy(double wy) => centerY + (wy - cameraY) * _zoom;
          final startCx =
              (positions[startSeg].x + positions[startSeg + 1].x) / 2;
          final startCy =
              (positions[startSeg].y + positions[startSeg + 1].y) / 2;
          final endCx = (positions[endSeg].x + positions[endSeg + 1].x) / 2;
          final endCy = (positions[endSeg].y + positions[endSeg + 1].y) / 2;
          final midSeg = (startSeg + endSeg) ~/ 2;
          final midCx = midSeg + 1 < positions.length
              ? (positions[midSeg].x + positions[midSeg + 1].x) / 2
              : (positions[midSeg].x + positions[endSeg].x) / 2;
          final midCy = midSeg + 1 < positions.length
              ? (positions[midSeg].y + positions[midSeg + 1].y) / 2
              : (positions[midSeg].y + positions[endSeg].y) / 2;
          return [
            Offset(sx(startCx), sy(startCy)),
            Offset(sx(endCx), sy(endCy)),
            Offset(sx(midCx), sy(midCy) - 24),
          ];
        }

        int? hitDorsalNode(double px, double py) {
          final nodes = dorsalNodePositions();
          if (nodes == null) return null;
          for (var i = 0; i < nodes.length; i++) {
            final o = nodes[i];
            if ((px - o.dx) * (px - o.dx) + (py - o.dy) * (py - o.dy) <=
                dorsalNodeRadius * dorsalNodeRadius)
              return i;
          }
          return null;
        }

        const double lateralNodeRadius = 14.0;

        /// Returns 4 positions: [lengthLeft, widthLeft, lengthRight, widthRight]. Index 0,2 = length; 1,3 = width.
        List<Offset>? lateralNodePositions() {
          final laterals = widget.creature.lateralFins ?? [];
          final idx = widget.selectedLateralFinIndex;
          if (idx == null || idx >= laterals.length || positions.length < 2)
            return null;
          final segAngles = _spine.segmentAngles;
          if (segAngles.isEmpty) return null;
          final config = laterals[idx];
          final seg = config.segment;
          if (seg < 0 || seg >= positions.length - 1 || seg >= segAngles.length)
            return null;
          double sx(double wx) => centerX + (wx - cameraX) * _zoom;
          double sy(double wy) => centerY + (wy - cameraY) * _zoom;
          final flareRad = config.angleDegrees * pi / 180.0;
          final halfW = widthAtVertex(seg);
          final aAttach = segAngles[seg];
          final segHead = seg + 1 < segAngles.length ? seg + 1 : seg;
          final aLock = segAngles[segHead];
          final leftAngle = aLock + flareRad;
          final rightAngle = aLock - flareRad;
          final pxW = positions[seg].x, pyW = positions[seg].y;
          final leftCx = pxW + sin(aAttach) * halfW;
          final leftCy = pyW - cos(aAttach) * halfW;
          final rightCx = pxW - sin(aAttach) * halfW;
          final rightCy = pyW + cos(aAttach) * halfW;
          // Length node on the outside of each fin; width node perpendicular.
          final lengthLeftX = leftCx - (config.length / 2) * cos(leftAngle);
          final lengthLeftY = leftCy - (config.length / 2) * sin(leftAngle);
          final widthLeftX = leftCx - (config.width / 2) * sin(leftAngle);
          final widthLeftY = leftCy + (config.width / 2) * cos(leftAngle);
          final lengthRightX = rightCx - (config.length / 2) * cos(rightAngle);
          final lengthRightY = rightCy - (config.length / 2) * sin(rightAngle);
          final widthRightX = rightCx - (config.width / 2) * sin(rightAngle);
          final widthRightY = rightCy + (config.width / 2) * cos(rightAngle);
          // Angle node: same direction as length node, further out (next to length node).
          final angleDist = config.length;
          final angleLeftX = leftCx - angleDist * cos(leftAngle);
          final angleLeftY = leftCy - angleDist * sin(leftAngle);
          final angleRightX = rightCx - angleDist * cos(rightAngle);
          final angleRightY = rightCy - angleDist * sin(rightAngle);
          return [
            Offset(sx(lengthLeftX), sy(lengthLeftY)),
            Offset(sx(widthLeftX), sy(widthLeftY)),
            Offset(sx(lengthRightX), sy(lengthRightY)),
            Offset(sx(widthRightX), sy(widthRightY)),
            Offset(sx(angleLeftX), sy(angleLeftY)),
            Offset(sx(angleRightX), sy(angleRightY)),
          ];
        }

        /// Returns 0 or 2 = length node (left/right), 1 or 3 = width node (left/right). Caller maps to logical 0=length, 1=width.
        int? hitLateralNode(double px, double py) {
          final nodes = lateralNodePositions();
          if (nodes == null) return null;
          final r2 = lateralNodeRadius * lateralNodeRadius;
          for (var i = 0; i < nodes.length; i++) {
            final o = nodes[i];
            if ((px - o.dx) * (px - o.dx) + (py - o.dy) * (py - o.dy) <= r2)
              return i;
          }
          return null;
        }

        const double bodyNodeRadius = 24.0;
        int? hitSegmentWidthNode(double px, double py) {
          if (positions.length < 2 || widget.onSegmentWidthDelta == null)
            return null;
          final r2 = nodeRadius * nodeRadius;
          final n = positions.length - 1;
          for (var seg = 0; seg < n; seg++) {
            final cx = (positions[seg].x + positions[seg + 1].x) / 2;
            final cy = (positions[seg].y + positions[seg + 1].y) / 2;
            final sx = centerX + (cx - cameraX) * _zoom;
            final sy = centerY + (cy - cameraY) * _zoom;
            if ((px - sx) * (px - sx) + (py - sy) * (py - sy) <= r2) return seg;
          }
          return null;
        }

        int? hitBodyNode(double px, double py) {
          if (positions.length < 2) return null;
          const out = BodyNodePainter.outsideOffset;
          final tail = positions.first;
          final second = positions[1];
          double dx = tail.x - second.x, dy = tail.y - second.y;
          var len = sqrt(dx * dx + dy * dy);
          if (len < 1e-6) len = 1.0;
          final tailOutX = tail.x + dx / len * out,
              tailOutY = tail.y + dy / len * out;
          final sx0 = centerX + (tailOutX - cameraX) * _zoom;
          final sy0 = centerY + (tailOutY - cameraY) * _zoom;
          final r2 = bodyNodeRadius * bodyNodeRadius;
          if ((px - sx0) * (px - sx0) + (py - sy0) * (py - sy0) <= r2) return 0;
          return null;
        }

        bool showTailNodes() =>
            isTailEdit &&
            _tailSelected &&
            widget.creature.tail != null &&
            positions.isNotEmpty &&
            _spine.segmentAngles.isNotEmpty;
        double effectiveTailRoot() {
          final v = widget.creature.segmentWidths;
          final derived = v.isEmpty ? 20.0 : v.reduce((a, b) => a < b ? a : b);
          return widget.creature.tail?.rootWidth ?? derived;
        }

        double effectiveTailMax() {
          final v = widget.creature.segmentWidths;
          final derived = v.isEmpty
              ? 10.0
              : v.reduce((a, b) => a > b ? a : b) / 2;
          return widget.creature.tail?.maxWidth ?? derived;
        }

        double effectiveTailLen() {
          final segW = widthAtSegment(0);
          final derived = segW * 3.0;
          return widget.creature.tail?.length ?? derived;
        }

        int? hitTailNode(double px, double py) {
          if (!showTailNodes()) return null;
          final tail = positions.first;
          final tailA = _spine.segmentAngles[0];
          final back = tailA + pi;
          final leftDirX = sin(tailA);
          final leftDirY = -cos(tailA);
          final backDirX = cos(back);
          final backDirY = sin(back);
          final rootW = effectiveTailRoot();
          final maxW = effectiveTailMax();
          final len = effectiveTailLen();
          double sx(double wx) => centerX + (wx - cameraX) * _zoom;
          double sy(double wy) => centerY + (wy - cameraY) * _zoom;
          final r2 = nodeRadius * nodeRadius;
          final rootPx = tail.x + leftDirX * rootW,
              rootPy = tail.y + leftDirY * rootW;
          if ((px - sx(rootPx)) * (px - sx(rootPx)) +
                  (py - sy(rootPy)) * (py - sy(rootPy)) <=
              r2)
            return 0;
          final maxPx = tail.x + backDirX * len * 0.7 + leftDirX * maxW,
              maxPy = tail.y + backDirY * len * 0.7 + leftDirY * maxW;
          if ((px - sx(maxPx)) * (px - sx(maxPx)) +
                  (py - sy(maxPy)) * (py - sy(maxPy)) <=
              r2)
            return 1;
          final tipPx = tail.x + backDirX * len,
              tipPy = tail.y + backDirY * len;
          if ((px - sx(tipPx)) * (px - sx(tipPx)) +
                  (py - sy(tipPy)) * (py - sy(tipPy)) <=
              r2)
            return 2;
          return null;
        }

        const double tailGrabRadius = 36.0;
        double dist2ToSegment(
          double px,
          double py,
          double x0,
          double y0,
          double x1,
          double y1,
        ) {
          final dx = x1 - x0, dy = y1 - y0;
          final len2 = dx * dx + dy * dy;
          if (len2 < 1e-10)
            return (px - x0) * (px - x0) + (py - y0) * (py - y0);
          var t = ((px - x0) * dx + (py - y0) * dy) / len2;
          t = t.clamp(0.0, 1.0);
          final nx = x0 + t * dx, ny = y0 + t * dy;
          return (px - nx) * (px - nx) + (py - ny) * (py - ny);
        }

        bool isPointOnTail(double px, double py) {
          if (widget.creature.tail == null ||
              positions.isEmpty ||
              _spine.segmentAngles.isEmpty)
            return false;
          final tail = positions.first;
          final tailA = _spine.segmentAngles[0];
          final back = tailA + pi;
          final len = effectiveTailLen();
          final tipX = tail.x + cos(back) * len;
          final tipY = tail.y + sin(back) * len;
          double sx(double wx) => centerX + (wx - cameraX) * _zoom;
          double sy(double wy) => centerY + (wy - cameraY) * _zoom;
          final s0x = sx(tail.x),
              s0y = sy(tail.y),
              s1x = sx(tipX),
              s1y = sy(tipY);
          final d2 = dist2ToSegment(px, py, s0x, s0y, s1x, s1y);
          return d2 <= tailGrabRadius * tailGrabRadius;
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
                painter: BackgroundPainter(
                  view: view,
                  timeSeconds: _backgroundTimeSeconds,
                ),
                size: Size(w, h),
              ),
            ),
            SizedBox(
              key: _previewContentKey,
              width: w,
              height: h,
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) {
                  _editorPointerCount++;
                },
                onPointerUp: (_) {
                  _editorPointerCount = (_editorPointerCount - 1).clamp(0, 10);
                  if (_editorPointerCount == 0 && widget.panelClosed) {
                    _editorTouchLocal = null;
                    _editorTouchScreenSize = null;
                    _editorTouchFrozen = false;
                    setState(() {});
                  }
                },
                onPointerCancel: (_) {
                  _editorPointerCount = (_editorPointerCount - 1).clamp(0, 10);
                  if (_editorPointerCount == 0 && widget.panelClosed) {
                    _editorTouchLocal = null;
                    _editorTouchScreenSize = null;
                    _editorTouchFrozen = false;
                    setState(() {});
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: (d) {
                    final lx = d.localFocalPoint.dx;
                    final ly = d.localFocalPoint.dy;
                    if (d.pointerCount >= 2) {
                      _pinchStartZoom = _zoom;
                      if (widget.panelClosed) {
                        final pos = _spine.positions;
                        if (pos.isNotEmpty) {
                          final head = pos.last;
                          _dragTargetX = head.x;
                          _dragTargetY = head.y;
                        }
                        _editorTouchFrozen = true;
                        _editorTouchLocal = null;
                        _editorTouchScreenSize = null;
                        setState(() {});
                      }
                    } else {
                      _panStartX = lx;
                      _panStartY = ly;
                      _lastPanX = lx;
                      _lastPanY = ly;
                      if (widget.panelClosed) {
                        _editorTouchLocal = Offset(lx, ly);
                        _editorTouchScreenSize = Size(w, h);
                        _editorTouchFrozen = false;
                      }
                      if (isBodyEdit) {
                        final node = hitBodyNode(lx, ly);
                        final segNode = hitSegmentWidthNode(lx, ly);
                        if (node != null &&
                            widget.onSegmentCountChanged != null) {
                          _bodyDraggingNode = node;
                        } else if (segNode != null &&
                            widget.onSegmentWidthDelta != null) {
                          _bodyWidthDragSeg = segNode;
                          _bodyWidthDragLastPanY = ly;
                        } else {
                          if (widget.panelClosed) {
                            final worldX = (lx - centerX) / _zoom + cameraX;
                            final worldY = (ly - centerY) / _zoom + cameraY;
                            setState(() {
                              _dragTargetX = worldX;
                              _dragTargetY = worldY;
                            });
                          } else {
                            setState(() => _editorPotentialPan = true);
                          }
                        }
                      } else if (editTab == 1 && !widget.panelClosed) {
                        // Parts tab: dorsal (body then node) -> lateral -> tail -> target (same one-drag-to-remove as tail)
                        final dorsalIdx = dorsalFinIndexAtScreen(lx, ly);
                        final dorsalNode = hitDorsalNode(lx, ly);
                        if (dorsalIdx != null && dorsalNode == null) {
                          setState(() {
                            _tailSelected = false;
                            _dorsalDragFromFin = true;
                          });
                          widget.onDorsalFinSelected?.call(dorsalIdx);
                        } else if (widget.selectedDorsalFinIndex != null &&
                            dorsalNode != null) {
                          _dorsalDraggingNode = dorsalNode;
                        } else {
                          final eyeNodeHit = hitEyeNode(lx, ly);
                          final eyeIdx = eyeIndexAtScreen(lx, ly);
                          if (eyeNodeHit != null &&
                              widget.selectedEyeIndex != null &&
                              widget.onEyeRadiusChanged != null) {
                            _eyeDraggingNode = eyeNodeHit;
                          } else if (eyeIdx != null) {
                            widget.onDorsalFinSelected?.call(null);
                            widget.onLateralFinSelected?.call(null);
                            widget.onEyeSelected?.call(eyeIdx);
                            setState(() {
                              _tailSelected = false;
                              _eyeDragFromCreature = true;
                            });
                          } else {
                            // Prioritise lateral nodes (when a lateral is selected) then lateral fin body over pan.
                            final lateralNodeHit =
                                widget.selectedLateralFinIndex != null
                                ? hitLateralNode(lx, ly)
                                : null;
                            if (lateralNodeHit != null &&
                                ((lateralNodeHit <= 3 &&
                                        widget.onLateralLengthChanged != null &&
                                        widget.onLateralWidthChanged != null) ||
                                    (lateralNodeHit >= 4 &&
                                        widget.onLateralAngleChanged !=
                                            null))) {
                              _lateralDraggingNode = lateralNodeHit;
                            } else {
                              final lateralIdx = lateralIndexNearScreen(lx, ly);
                              if (lateralIdx != null) {
                                _lateralPanStartIndex = lateralIdx;
                              } else {
                                final mouthNodeHit = widget.selectedMouth
                                    ? hitMouthNode(lx, ly)
                                    : null;
                                if (mouthNodeHit != null &&
                                    (mouthNodeHit == 0 &&
                                            widget.onMouthLengthChanged !=
                                                null ||
                                        mouthNodeHit == 1 &&
                                            (widget.onMouthCurveChanged !=
                                                    null ||
                                                widget.onMouthWobbleAmplitudeChanged !=
                                                    null))) {
                                  setState(
                                    () => _mouthDraggingNode = mouthNodeHit,
                                  );
                                } else if (isPointOnMouth(lx, ly) &&
                                    widget.creature.mouth != null &&
                                    widget.onMouthRemoved != null) {
                                  widget.onDorsalFinSelected?.call(null);
                                  widget.onLateralFinSelected?.call(null);
                                  widget.onEyeSelected?.call(null);
                                  widget.onMouthSelected?.call(true);
                                  setState(() {
                                    _tailSelected = false;
                                    _mouthDragFromCreature = true;
                                  });
                                } else {
                                  final tailNode = hitTailNode(lx, ly);
                                  if (tailNode != null &&
                                      _tailSelected &&
                                      (widget.onTailRootWidthChanged != null ||
                                          widget.onTailMaxWidthChanged !=
                                              null ||
                                          widget.onTailLengthChanged != null)) {
                                    _tailDraggingNode = tailNode;
                                    _tailDragStartValue = tailNode == 0
                                        ? effectiveTailRoot()
                                        : (tailNode == 1
                                              ? effectiveTailMax()
                                              : effectiveTailLen());
                                  } else if (tailNode == null &&
                                      isPointOnTail(lx, ly) &&
                                      widget.creature.tail != null &&
                                      widget.onTailRemoved != null) {
                                    widget.onDorsalFinSelected?.call(null);
                                    widget.onLateralFinSelected?.call(null);
                                    widget.onEyeSelected?.call(null);
                                    widget.onMouthSelected?.call(false);
                                    setState(() {
                                      _tailSelected = true;
                                      _tailDragFromCreature = true;
                                    });
                                  } else if (widget.panelClosed) {
                                    final worldX =
                                        (lx - centerX) / _zoom + cameraX;
                                    final worldY =
                                        (ly - centerY) / _zoom + cameraY;
                                    widget.onMouthSelected?.call(false);
                                    setState(() {
                                      _dragTargetX = worldX;
                                      _dragTargetY = worldY;
                                    });
                                  } else {
                                    widget.onMouthSelected?.call(false);
                                    setState(() => _editorPotentialPan = true);
                                  }
                                }
                              }
                            }
                          }
                        }
                      } else if (widget.panelClosed) {
                        final worldX = (lx - centerX) / _zoom + cameraX;
                        final worldY = (ly - centerY) / _zoom + cameraY;
                        widget.onMouthSelected?.call(false);
                        setState(() {
                          _dragTargetX = worldX;
                          _dragTargetY = worldY;
                        });
                      } else {
                        widget.onMouthSelected?.call(false);
                        setState(() => _editorPotentialPan = true);
                      }
                    }
                  },
                  onScaleUpdate: (d) {
                    final lx = d.localFocalPoint.dx;
                    final ly = d.localFocalPoint.dy;
                    if (_pinchStartZoom != null && d.pointerCount >= 2) {
                      setState(() {
                        _zoom = (_pinchStartZoom! * d.scale).clamp(
                          _minZoom,
                          _maxZoom,
                        );
                      });
                      return;
                    }
                    if (widget.panelClosed &&
                        d.pointerCount == 1 &&
                        !_editorTouchFrozen) {
                      _editorTouchLocal = Offset(lx, ly);
                    }
                    if (_editorPotentialPan) {
                      final dx = lx - _panStartX;
                      final dy = ly - _panStartY;
                      if (dx * dx + dy * dy > _panDragSlop * _panDragSlop) {
                        setState(() {
                          _editorPotentialPan = false;
                          _editorPanning = true;
                          _lastPanX = lx;
                          _lastPanY = ly;
                        });
                        return;
                      }
                      return;
                    }
                    if (_editorPanning) {
                      setState(() {
                        _editorPanOffsetX += (_lastPanX - lx) / _zoom;
                        _editorPanOffsetY += (_lastPanY - ly) / _zoom;
                        _lastPanX = lx;
                        _lastPanY = ly;
                      });
                      return;
                    }
                    if (_lateralPanStartIndex != null &&
                        _lateralDragFromIndex == null) {
                      final dx = lx - _panStartX;
                      final dy = ly - _panStartY;
                      if (dx * dx + dy * dy >
                          _EditorPreviewState._panDragSlop *
                              _EditorPreviewState._panDragSlop) {
                        setState(
                          () => _lateralDragFromIndex = _lateralPanStartIndex,
                        );
                      }
                    }
                    if (_lateralDraggingNode != null &&
                        widget.selectedLateralFinIndex != null) {
                      const scale = 0.2;
                      final idx = widget.selectedLateralFinIndex!;
                      final rawDelta = (ly - _lastPanY) * scale;
                      // Only left length node (0) has inverted drag; negate delta for that node only.
                      final delta = _lateralDraggingNode! == 0
                          ? -rawDelta
                          : rawDelta;
                      final laterals = widget.creature.lateralFins!;
                      if (idx < laterals.length) {
                        if ((_lateralDraggingNode == 0 ||
                                _lateralDraggingNode == 2) &&
                            widget.onLateralLengthChanged != null) {
                          final v = (laterals[idx].length + delta).clamp(
                            LateralFinConfig.lengthMin,
                            LateralFinConfig.lengthMax,
                          );
                          widget.onLateralLengthChanged!(idx, v);
                        } else if ((_lateralDraggingNode == 1 ||
                                _lateralDraggingNode == 3) &&
                            widget.onLateralWidthChanged != null) {
                          final v = (laterals[idx].width + delta).clamp(
                            LateralFinConfig.widthMin,
                            LateralFinConfig.widthMax,
                          );
                          widget.onLateralWidthChanged!(idx, v);
                        } else if ((_lateralDraggingNode == 4 ||
                                _lateralDraggingNode == 5) &&
                            widget.onLateralAngleChanged != null) {
                          final config = laterals[idx];
                          final seg = config.segment.clamp(
                            0,
                            positions.length - 1,
                          );
                          if (seg < _spine.segmentAngles.length) {
                            final aAttach = _spine.segmentAngles[seg];
                            final segHead =
                                seg + 1 < _spine.segmentAngles.length
                                ? seg + 1
                                : seg;
                            final aLock = _spine.segmentAngles[segHead];
                            final halfW = widthAtVertex(seg);
                            final pxW = positions[seg].x;
                            final pyW = positions[seg].y;
                            final leftCx = pxW + sin(aAttach) * halfW;
                            final leftCy = pyW - cos(aAttach) * halfW;
                            final rightCx = pxW - sin(aAttach) * halfW;
                            final rightCy = pyW + cos(aAttach) * halfW;
                            final wx = (lx - centerX) / _zoom + cameraX;
                            final wy = (ly - centerY) / _zoom + cameraY;
                            final cx = _lateralDraggingNode == 4
                                ? leftCx
                                : rightCx;
                            final cy = _lateralDraggingNode == 4
                                ? leftCy
                                : rightCy;
                            final ptrAngle = atan2(wy - cy, wx - cx);
                            // Mirror across spine + 180° so drag sensor is in same quadrant as fin (was 180° off).
                            final effectivePtr = 2.0 * aLock - ptrAngle + pi;
                            var flareRad = _lateralDraggingNode == 4
                                ? -effectivePtr -
                                      aLock // left: aLock + flare = -ptr
                                : effectivePtr +
                                      aLock; // right: aLock - flare = -ptr
                            while (flareRad > pi) flareRad -= 2 * pi;
                            while (flareRad < -pi) flareRad += 2 * pi;
                            final flareDeg = (flareRad * 180.0 / pi).clamp(
                              LateralFinConfig.angleDegreesMin,
                              LateralFinConfig.angleDegreesMax,
                            );
                            widget.onLateralAngleChanged!(idx, flareDeg);
                          }
                        }
                      }
                      _lastPanX = lx;
                      _lastPanY = ly;
                      setState(() {});
                      return;
                    }
                    if (_mouthDraggingNode != null) {
                      final head = positions.last;
                      if (_mouthDraggingNode == 0 &&
                          widget.onMouthLengthChanged != null) {
                        final worldX = (lx - centerX) / _zoom + cameraX;
                        final worldY = (ly - centerY) / _zoom + cameraY;
                        final headA = _spine.segmentAngles.last;
                        final forwardX = cos(headA);
                        final forwardY = sin(headA);
                        final signedDist =
                            (worldX - head.x) * forwardX +
                            (worldY - head.y) * forwardY;
                        final headSeg = (positions.length - 2).clamp(
                          0,
                          positions.length - 1,
                        );
                        final headW = widthAtSegment(headSeg);
                        final sizeScale = (headW / mouthHeadSizeRef).clamp(
                          0.1,
                          10.0,
                        );
                        final logicalLength = signedDist / sizeScale;
                        final v = logicalLength.clamp(
                          MouthParams.lengthMin,
                          MouthParams.lengthMax,
                        );
                        widget.onMouthLengthChanged!(v);
                      } else if (_mouthDraggingNode == 1) {
                        const sense = 0.025;
                        final delta = (ly - _lastPanY) * sense;
                        if (widget.creature.mouth == MouthType.teeth &&
                            widget.onMouthCurveChanged != null) {
                          final cur =
                              widget.creature.mouthCurve ??
                              MouthParams.curveDefault;
                          final v = (cur + delta).clamp(
                            MouthParams.curveMin,
                            MouthParams.curveMax,
                          );
                          widget.onMouthCurveChanged!(v);
                        } else if (widget.creature.mouth ==
                                MouthType.tentacle &&
                            widget.onMouthWobbleAmplitudeChanged != null) {
                          final cur =
                              widget.creature.mouthWobbleAmplitude ??
                              MouthParams.wobbleDefault;
                          final v = (cur + delta).clamp(
                            MouthParams.wobbleMin,
                            MouthParams.wobbleMax,
                          );
                          widget.onMouthWobbleAmplitudeChanged!(v);
                        }
                      }
                      _lastPanX = lx;
                      _lastPanY = ly;
                      setState(() {});
                      return;
                    }
                    _lastPanX = lx;
                    _lastPanY = ly;
                    if (_tailDragFromCreature ||
                        _mouthDragFromCreature ||
                        _eyeDragFromCreature) {
                      setState(() {});
                      return;
                    }
                    if (_bodyDraggingNode != null &&
                        widget.onSegmentCountChanged != null) {
                      widget.onSegmentCountChanged!(
                        _segmentCountFromTailDrag(
                          centerX,
                          centerY,
                          cameraX,
                          cameraY,
                          positions,
                        ),
                      );
                      setState(() {});
                      return;
                    }
                    if (_tailDraggingNode != null &&
                        positions.isNotEmpty &&
                        _spine.segmentAngles.isNotEmpty) {
                      final tailA = _spine.segmentAngles[0];
                      final back = tailA + pi;
                      final leftDirX = sin(tailA);
                      final leftDirY = -cos(tailA);
                      final backDirX = cos(back);
                      final backDirY = sin(back);
                      final dx = (_lastPanX - _panStartX) / _zoom;
                      final dy = (_lastPanY - _panStartY) / _zoom;
                      if (_tailDraggingNode == 0 &&
                          widget.onTailRootWidthChanged != null) {
                        final delta = dx * leftDirX + dy * leftDirY;
                        final v = (_tailDragStartValue + delta).clamp(
                          TailConfig.rootWidthMin,
                          TailConfig.rootWidthMax,
                        );
                        widget.onTailRootWidthChanged!(v);
                      } else if (_tailDraggingNode == 1 &&
                          widget.onTailMaxWidthChanged != null) {
                        final delta = dx * leftDirX + dy * leftDirY;
                        final v = (_tailDragStartValue + delta).clamp(
                          TailConfig.maxWidthMin,
                          TailConfig.maxWidthMax,
                        );
                        widget.onTailMaxWidthChanged!(v);
                      } else if (_tailDraggingNode == 2 &&
                          widget.onTailLengthChanged != null) {
                        final delta = dx * backDirX + dy * backDirY;
                        final v = (_tailDragStartValue + delta).clamp(
                          TailConfig.lengthMin,
                          TailConfig.lengthMax,
                        );
                        widget.onTailLengthChanged!(v);
                      }
                      setState(() {});
                      return;
                    }
                    if (_dorsalDraggingNode != null) {
                      final fins = widget.creature.dorsalFins ?? [];
                      final idx = widget.selectedDorsalFinIndex;
                      if (idx != null &&
                          idx < fins.length &&
                          widget.onDorsalRangeChanged != null) {
                        final range = fins[idx].$1;
                        if (range.isNotEmpty) {
                          final seg = segmentAtScreen(
                            _lastPanX,
                            _lastPanY,
                          ).clamp(0, _spine.segmentCount - 1);
                          if (_dorsalDraggingNode == 0) {
                            widget.onDorsalRangeChanged!(
                              seg.clamp(0, range.last),
                              range.last,
                            );
                          } else if (_dorsalDraggingNode == 1) {
                            widget.onDorsalRangeChanged!(
                              range.first,
                              seg.clamp(range.first, _spine.segmentCount - 1),
                            );
                          }
                        }
                      }
                      if (_dorsalDraggingNode == 2 &&
                          widget.onDorsalHeightChanged != null) {
                        final frac = (1.0 - _lastPanY / h).clamp(0.0, 1.0);
                        final height = frac < 0.33
                            ? kDorsalHeightSmall
                            : (frac < 0.66
                                  ? kDorsalHeightMedium
                                  : kDorsalHeightLarge);
                        widget.onDorsalHeightChanged!(height);
                      }
                      setState(() {});
                      return;
                    }
                    if (_bodyWidthDragSeg != null &&
                        widget.onSegmentWidthDelta != null) {
                      const scale = 0.2;
                      final seg = _bodyWidthDragSeg!;
                      final delta = (_bodyWidthDragLastPanY - ly) * scale;
                      widget.onSegmentWidthDelta!(seg, delta);
                      _bodyWidthDragLastPanY = ly;
                      setState(() {});
                      return;
                    }
                    if (_bodyDraggingNode != null ||
                        _dorsalDragFromFin ||
                        _dorsalDragStartSeg != null ||
                        _lateralDragFromIndex != null ||
                        _lateralDraggingNode != null ||
                        _lateralPanStartIndex != null ||
                        _mouthDragFromCreature ||
                        _eyeDragFromCreature)
                      return;
                    if (_eyeDraggingNode != null &&
                        widget.selectedEyeIndex != null &&
                        positions.length >= 2 &&
                        _spine.segmentAngles.isNotEmpty) {
                      final eyes = widget.creature.eyes ?? [];
                      final idx = widget.selectedEyeIndex!;
                      final nodeIndex = _eyeDraggingNode!;
                      if (idx < eyes.length) {
                        final eye = eyes[idx];
                        final seg = eye.segment.clamp(0, positions.length - 2);
                        final cx =
                            (positions[seg].x + positions[seg + 1].x) / 2;
                        final cy =
                            (positions[seg].y + positions[seg + 1].y) / 2;
                        final a = _spine.segmentAngles[seg];
                        final halfW = widthAtVertex(seg);
                        final isSingle =
                            eye.offsetFromCenter < EyeConfig.singleEyeThreshold;
                        final isRadiusNode = isSingle
                            ? (nodeIndex == 0)
                            : (nodeIndex < 2);
                        final isPupilNode = isSingle
                            ? (nodeIndex == 1)
                            : (nodeIndex >= 2);
                        if (isRadiusNode && widget.onEyeRadiusChanged != null) {
                          final nodeSide = isSingle ? 0 : nodeIndex;
                          final off = isSingle
                              ? 0.0
                              : eye.offsetFromCenter * halfW;
                          final dx = -sin(a) * off;
                          final dy = cos(a) * off;
                          final eyeCenterWx = isSingle
                              ? cx
                              : (nodeSide == 0 ? cx + dx : cx - dx);
                          final eyeCenterWy = isSingle
                              ? cy
                              : (nodeSide == 0 ? cy + dy : cy - dy);
                          final wx = (lx - centerX) / _zoom + cameraX;
                          final wy = (ly - centerY) / _zoom + cameraY;
                          final dist = sqrt(
                            (wx - eyeCenterWx) * (wx - eyeCenterWx) +
                                (wy - eyeCenterWy) * (wy - eyeCenterWy),
                          );
                          final r = dist.clamp(
                            EyeConfig.radiusMin,
                            EyeConfig.radiusMax,
                          );
                          final atMin = eye.radius <= EyeConfig.radiusMin;
                          final wouldGrow = r > EyeConfig.radiusMin;
                          final outX = nodeSide == 0 ? -sin(a) : sin(a);
                          final outY = nodeSide == 0 ? cos(a) : -cos(a);
                          final correctSide =
                              (wx - eyeCenterWx) * outX +
                                  (wy - eyeCenterWy) * outY >
                              0;
                          final rToApply = (atMin && wouldGrow && !correctSide)
                              ? EyeConfig.radiusMin
                              : r;
                          widget.onEyeRadiusChanged!(idx, rToApply);
                        } else if (isPupilNode &&
                            widget.onEyePupilFractionChanged != null) {
                          final off = isSingle
                              ? 0.0
                              : eye.offsetFromCenter * halfW;
                          final dx = -sin(a) * off;
                          final dy = cos(a) * off;
                          final eyeCenterWx = isSingle
                              ? cx
                              : (nodeIndex == 2 ? cx + dx : cx - dx);
                          final eyeCenterWy = isSingle
                              ? cy
                              : (nodeIndex == 2 ? cy + dy : cy - dy);
                          final wx = (lx - centerX) / _zoom + cameraX;
                          final wy = (ly - centerY) / _zoom + cameraY;
                          final dist = sqrt(
                            (wx - eyeCenterWx) * (wx - eyeCenterWx) +
                                (wy - eyeCenterWy) * (wy - eyeCenterWy),
                          );
                          final rawFrac = (dist / eye.radius).clamp(
                            EyeConfig.pupilFractionMin,
                            EyeConfig.pupilFractionMax,
                          );
                          final atMin =
                              eye.pupilFraction <= EyeConfig.pupilFractionMin;
                          final wouldGrow =
                              rawFrac > EyeConfig.pupilFractionMin;
                          // Outward from center toward pupil node = (cos(a), sin(a)); only allow growing if drag is on that side.
                          final outX = cos(a);
                          final outY = sin(a);
                          final correctSide =
                              (wx - eyeCenterWx) * outX +
                                  (wy - eyeCenterWy) * outY >
                              0;
                          final pupilFrac = (atMin && wouldGrow && !correctSide)
                              ? EyeConfig.pupilFractionMin
                              : rawFrac;
                          widget.onEyePupilFractionChanged!(idx, pupilFrac);
                        }
                      }
                      setState(() {});
                      return;
                    }
                    if (isSpineLocked) return;
                    if (widget.panelClosed) return;
                    final worldX = (lx - centerX) / _zoom + cameraX;
                    final worldY = (ly - centerY) / _zoom + cameraY;
                    setState(() {
                      _dragTargetX = worldX;
                      _dragTargetY = worldY;
                    });
                  },
                  onScaleEnd: (_) {
                    if (_editorPanning) {
                      setState(() => _editorPanning = false);
                      return;
                    }
                    if (_editorPotentialPan) {
                      setState(() {
                        _editorPotentialPan = false;
                        _tailSelected = false;
                      });
                      widget.onDorsalFinSelected?.call(null);
                      widget.onLateralFinSelected?.call(null);
                      widget.onEyeSelected?.call(null);
                      return;
                    }
                    _pinchStartZoom = null;
                    if (widget.panelClosed) {
                      _editorTouchLocal = null;
                      _editorTouchScreenSize = null;
                      _editorTouchFrozen = false;
                    }
                    if (_eyeDragFromCreature &&
                        widget.selectedEyeIndex != null) {
                      final inside = finRemoveBounds().contains(
                        Offset(_lastPanX, _lastPanY),
                      );
                      if (inside && widget.onEyeMoved != null) {
                        final (seg, offset) = _segmentAndOffsetAtLocal(
                          _lastPanX,
                          _lastPanY,
                        );
                        widget.onEyeMoved!(
                          widget.selectedEyeIndex!,
                          seg,
                          offset,
                        );
                      } else if (!inside && widget.onEyeRemoved != null) {
                        widget.onEyeRemoved!(widget.selectedEyeIndex!);
                      }
                      setState(() {
                        _eyeDragFromCreature = false;
                        _eyeDraggingNode = null;
                      });
                      return;
                    } else if (_tailDragFromCreature) {
                      if (!finRemoveBounds().contains(
                            Offset(_lastPanX, _lastPanY),
                          ) &&
                          widget.onTailRemoved != null) {
                        widget.onTailRemoved!();
                      }
                      setState(() => _tailDragFromCreature = false);
                      return;
                    }
                    if (_mouthDragFromCreature) {
                      if (!finRemoveBounds().contains(
                            Offset(_lastPanX, _lastPanY),
                          ) &&
                          widget.onMouthRemoved != null) {
                        widget.onMouthRemoved!();
                      }
                      setState(() => _mouthDragFromCreature = false);
                      return;
                    }
                    if (_eyeDragFromCreature || _eyeDraggingNode != null) {
                      setState(() {
                        _eyeDragFromCreature = false;
                        _eyeDraggingNode = null;
                      });
                      return;
                    }
                    if (_tailDraggingNode != null) {
                      setState(() => _tailDraggingNode = null);
                      return;
                    }
                    if (_mouthDraggingNode != null) {
                      setState(() => _mouthDraggingNode = null);
                      return;
                    }
                    if (_bodyWidthDragSeg != null) {
                      setState(() => _bodyWidthDragSeg = null);
                      return;
                    }
                    if (_bodyDraggingNode != null &&
                        widget.onSegmentCountChanged != null) {
                      widget.onSegmentCountChanged!(
                        _segmentCountFromTailDrag(
                          centerX,
                          centerY,
                          cameraX,
                          cameraY,
                          positions,
                        ),
                      );
                      setState(() => _bodyDraggingNode = null);
                      return;
                    }
                    if (_dorsalDraggingNode != null) {
                      setState(() => _dorsalDraggingNode = null);
                      return;
                    }
                    if (_dorsalDragFromFin &&
                        widget.onDorsalRemoved != null &&
                        widget.selectedDorsalFinIndex != null) {
                      if (!finRemoveBounds().contains(
                        Offset(_lastPanX, _lastPanY),
                      )) {
                        widget.onDorsalRemoved!(widget.selectedDorsalFinIndex!);
                      }
                      setState(() => _dorsalDragFromFin = false);
                      return;
                    }
                    if (_dorsalDragStartSeg != null &&
                        widget.onDorsalRangeChanged != null) {
                      final seg = segmentAtScreen(_lastPanX, _lastPanY);
                      final a = _dorsalDragStartSeg!;
                      widget.onDorsalRangeChanged!(
                        a < seg ? a : seg,
                        a < seg ? seg : a,
                      );
                      setState(() => _dorsalDragStartSeg = null);
                      return;
                    }
                    if (_lateralDragFromIndex != null) {
                      final releaseInBounds = finRemoveBounds().contains(
                        Offset(_lastPanX, _lastPanY),
                      );
                      if (!releaseInBounds && widget.onLateralRemoved != null) {
                        widget.onLateralRemoved!(_lateralDragFromIndex!);
                      } else if (releaseInBounds &&
                          widget.onLateralMoved != null) {
                        final seg = segmentAtScreen(_lastPanX, _lastPanY);
                        widget.onLateralMoved!(_lateralDragFromIndex!, seg);
                      }
                      setState(() {
                        _lateralDragFromIndex = null;
                        _lateralPanStartIndex = null;
                      });
                      return;
                    }
                    if (_lateralDraggingNode != null) {
                      setState(() => _lateralDraggingNode = null);
                      return;
                    }
                    if (_lateralPanStartIndex != null) {
                      final dist2 =
                          (_lastPanX - _panStartX) * (_lastPanX - _panStartX) +
                          (_lastPanY - _panStartY) * (_lastPanY - _panStartY);
                      if (dist2 < 100) {
                        widget.onLateralFinSelected?.call(
                          _lateralPanStartIndex,
                        );
                        setState(() {
                          _tailSelected = false;
                          _lateralPanStartIndex = null;
                        });
                      } else {
                        setState(() => _lateralPanStartIndex = null);
                      }
                      return;
                    }
                    if (editTab == 1 && widget.onDorsalFinSelected != null) {
                      final dist2 =
                          (_lastPanX - _panStartX) * (_lastPanX - _panStartX) +
                          (_lastPanY - _panStartY) * (_lastPanY - _panStartY);
                      if (dist2 < 100) {
                        final dorsalFound = dorsalFinIndexAtScreen(
                          _lastPanX,
                          _lastPanY,
                        );
                        if (dorsalFound != null) {
                          setState(() => _tailSelected = false);
                          widget.onDorsalFinSelected!(dorsalFound);
                          setState(() {});
                          return;
                        }
                        // Tap elsewhere: deselect dorsal so user can interact with tail, laterals or empty space.
                        if (widget.selectedDorsalFinIndex != null &&
                            hitDorsalNode(_lastPanX, _lastPanY) == null) {
                          widget.onDorsalFinSelected!(null);
                          setState(() {});
                        }
                      }
                    }
                    final tapDist2 =
                        (_lastPanX - _panStartX) * (_lastPanX - _panStartX) +
                        (_lastPanY - _panStartY) * (_lastPanY - _panStartY);
                    if (tapDist2 < 100 &&
                        !isPointOnTail(_lastPanX, _lastPanY)) {
                      setState(() => _tailSelected = false);
                    }
                    if (!widget.panelClosed) {
                      final pos = _spine.positions;
                      if (pos.isNotEmpty) {
                        final head = pos.last;
                        setState(() {
                          _dragTargetX = head.x;
                          _dragTargetY = head.y;
                        });
                      }
                    }
                  },
                  child: CustomPaint(
                    size: Size(w, h),
                    painter: CreaturePainter(
                      creature: widget.creature,
                      spine: _spine,
                      view: view,
                      showContourLines: true,
                      blurBodyLayers: false,
                    ),
                  ),
                ),
              ),
            ),
            if (isBodyEdit && widget.onSegmentCountChanged != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: BodyNodePainter(
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
            if (isBodyEdit && widget.onSegmentWidthDelta != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: SpineNodePainter(
                      positions: positions,
                      centerX: centerX,
                      centerY: centerY,
                      cameraX: cameraX,
                      cameraY: cameraY,
                      zoom: _zoom,
                      activeSegment: _bodyWidthDragSeg,
                    ),
                    size: Size(w, h),
                  ),
                ),
              ),
            if (widget.selectedLateralFinIndex != null &&
                lateralNodePositions() != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: PecFinNodePainter(
                      positions: lateralNodePositions()!,
                      activeNode: _lateralDraggingNode,
                    ),
                    size: Size(w, h),
                  ),
                ),
              ),
            if (widget.selectedMouth && mouthNodePositions() != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: MouthNodePainter(
                      positions: mouthNodePositions()!,
                      activeNode: _mouthDraggingNode,
                    ),
                    size: Size(w, h),
                  ),
                ),
              ),
            if (widget.selectedEyeIndex != null && eyeNodePositions() != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: EyeNodePainter(
                      nodePositions: eyeNodePositions()!,
                      activeNodeIndex: _eyeDraggingNode,
                    ),
                    size: Size(w, h),
                  ),
                ),
              ),
            if (showTailNodes())
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: TailNodePainter(
                      tailX: positions.first.x,
                      tailY: positions.first.y,
                      tailA: _spine.segmentAngles[0],
                      rootW: effectiveTailRoot(),
                      maxW: effectiveTailMax(),
                      len: effectiveTailLen(),
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
                widget.creature.tail != null &&
                !finRemoveBounds().contains(Offset(_lastPanX, _lastPanY)))
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: RemoveTailPainter(
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
            if (_mouthDragFromCreature &&
                widget.creature.mouth != null &&
                !finRemoveBounds().contains(Offset(_lastPanX, _lastPanY)) &&
                positions.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: RemoveMouthPainter(
                      headSx: centerX + (positions.last.x - cameraX) * _zoom,
                      headSy: centerY + (positions.last.y - cameraY) * _zoom,
                      radius:
                          widthAtSegment(
                            (positions.length - 2).clamp(
                              0,
                              positions.length - 1,
                            ),
                          ) *
                          _zoom *
                          1.2,
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
                    painter: TailPreviewPainter(
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
            if (_mouthAddDragLocal != null &&
                _mouthAddDragPayload != null &&
                creatureScreenBounds()
                    .inflate(80)
                    .contains(_mouthAddDragLocal!) &&
                positions.length >= 2 &&
                _spine.segmentAngles.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: MouthPreviewPainter(
                      creature: widget.creature,
                      previewMouthType: _mouthAddDragPayload!.mouthType,
                      positions: positions,
                      segmentAngles: _spine.segmentAngles,
                      centerX: centerX,
                      centerY: centerY,
                      cameraX: cameraX,
                      cameraY: cameraY,
                      zoom: _zoom,
                      headWidthWorld: widthAtSegment(
                        (positions.length - 2).clamp(0, positions.length - 1),
                      ),
                      bodyColor: Color(widget.creature.color),
                      faceCurveWorld:
                          CreaturePainter.computeHeadCapFaceCurveWorld(
                            positions: positions,
                            segmentAngles: _spine.segmentAngles,
                            widthAtWorld: (i) =>
                                widget.creature.widthAtVertex(i),
                            centerX: centerX,
                            centerY: centerY,
                            zoom: _zoom,
                            cameraX: cameraX,
                            cameraY: cameraY,
                          ),
                      previewMouthCount: _mouthAddDragPayload?.mouthCount,
                    ),
                    size: Size(w, h),
                  ),
                ),
              ),
            if (_eyeAddDragLocal != null &&
                creatureScreenBounds()
                    .inflate(40)
                    .contains(_eyeAddDragLocal!) &&
                positions.length >= 2 &&
                _spine.segmentAngles.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: Builder(
                    builder: (_) {
                      final (seg, offset) = _segmentAndOffsetAtLocal(
                        _eyeAddDragLocal!.dx,
                        _eyeAddDragLocal!.dy,
                      );
                      return CustomPaint(
                        painter: EyePreviewPainter(
                          segment: seg,
                          offsetFromCenter: offset,
                          positions: positions,
                          segmentAngles: _spine.segmentAngles,
                          centerX: centerX,
                          centerY: centerY,
                          cameraX: cameraX,
                          cameraY: cameraY,
                          zoom: _zoom,
                          widthAtVertex: (i) => widthAtVertex(i),
                          creatureColor: Color(widget.creature.color),
                          creatureFinColor: widget.creature.finColor != null
                              ? Color(widget.creature.finColor!)
                              : null,
                        ),
                        size: Size(w, h),
                      );
                    },
                  ),
                ),
              ),
            if (_eyeDragFromCreature &&
                widget.selectedEyeIndex != null &&
                positions.length >= 2 &&
                _spine.segmentAngles.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: Builder(
                    builder: (_) {
                      final (seg, offset) = _segmentAndOffsetAtLocal(
                        _lastPanX,
                        _lastPanY,
                      );
                      final eyes = widget.creature.eyes ?? [];
                      final idx = widget.selectedEyeIndex!;
                      final eye = idx < eyes.length ? eyes[idx] : null;
                      final radiusWorld = eye?.radius;
                      final pupilFraction =
                          eye?.pupilFraction ?? EyeConfig.pupilFractionDefault;
                      return CustomPaint(
                        painter: EyePreviewPainter(
                          segment: seg,
                          offsetFromCenter: offset,
                          positions: positions,
                          segmentAngles: _spine.segmentAngles,
                          centerX: centerX,
                          centerY: centerY,
                          cameraX: cameraX,
                          cameraY: cameraY,
                          zoom: _zoom,
                          widthAtVertex: (i) => widthAtVertex(i),
                          creatureColor: Color(widget.creature.color),
                          creatureFinColor: widget.creature.finColor != null
                              ? Color(widget.creature.finColor!)
                              : null,
                          pupilFraction: pupilFraction,
                          radiusWorld: radiusWorld,
                        ),
                        size: Size(w, h),
                      );
                    },
                  ),
                ),
              ),
            if (_dorsalDragFromFin &&
                widget.selectedDorsalFinIndex != null &&
                !finRemoveBounds().contains(Offset(_lastPanX, _lastPanY))) ...[
              Builder(
                builder: (_) {
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
                        painter: RemoveDorsalPainter(
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
                },
              ),
            ],
            if (isDorsalEdit && widget.selectedDorsalFinIndex != null) ...[
              Builder(
                builder: (context) {
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
                        painter: DorsalNodePainter(
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
                },
              ),
            ],
            if (_dorsalAddDragLocal != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: DorsalPreviewPainter(
                      startSeg: _segmentAtLocal(
                        _dorsalAddDragLocal!.dx,
                        _dorsalAddDragLocal!.dy,
                      ).clamp(0, (positions.length - 4).clamp(0, 999)),
                      positions: positions,
                      centerX: centerX,
                      centerY: centerY,
                      cameraX: cameraX,
                      cameraY: cameraY,
                      zoom: _zoom,
                      finColor: widget.creature.finColor != null
                          ? Color(widget.creature.finColor!)
                          : Color.lerp(
                              Color(widget.creature.color),
                              Colors.white,
                              0.15,
                            )!,
                    ),
                    size: Size(w, h),
                  ),
                ),
              ),
            if (_lateralAddDragLocal != null) ...[
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: PecFinSegmentPainter(
                      segment: segmentAtScreen(
                        _lateralAddDragLocal!.dx,
                        _lateralAddDragLocal!.dy,
                      ),
                      length: LateralFinConfig.lengthDefault,
                      width: LateralFinConfig.widthDefault,
                      wingType:
                          _lateralAddDragPayload?.wingType ??
                          LateralWingType.ellipse,
                      positions: positions,
                      segmentAngles: _spine.segmentAngles,
                      centerX: centerX,
                      centerY: centerY,
                      cameraX: cameraX,
                      cameraY: cameraY,
                      zoom: _zoom,
                      segWidth: widthAtVertex(
                        segmentAtScreen(
                          _lateralAddDragLocal!.dx,
                          _lateralAddDragLocal!.dy,
                        ),
                      ),
                      finColor: widget.creature.finColor != null
                          ? Color(widget.creature.finColor!)
                          : Color.lerp(
                              Color(widget.creature.color),
                              Colors.white,
                              0.15,
                            )!,
                      highlight: false,
                    ),
                    size: Size(w, h),
                  ),
                ),
              ),
            ],
            if (_lateralDragFromIndex != null &&
                widget.creature.lateralFins != null &&
                _lateralDragFromIndex! <
                    widget.creature.lateralFins!.length) ...[
              if (finRemoveBounds().contains(Offset(_lastPanX, _lastPanY)))
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: PecFinSegmentPainter(
                        segment: segmentAtScreen(
                          _lastPanX,
                          _lastPanY,
                        ).clamp(0, positions.length - 2),
                        length:
                            _lateralDragFromIndex! <
                                (widget.creature.lateralFins?.length ?? 0)
                            ? widget
                                  .creature
                                  .lateralFins![_lateralDragFromIndex!]
                                  .length
                            : LateralFinConfig.lengthDefault,
                        width:
                            _lateralDragFromIndex! <
                                (widget.creature.lateralFins?.length ?? 0)
                            ? widget
                                  .creature
                                  .lateralFins![_lateralDragFromIndex!]
                                  .width
                            : LateralFinConfig.widthDefault,
                        angleDegrees:
                            _lateralDragFromIndex! <
                                (widget.creature.lateralFins?.length ?? 0)
                            ? widget
                                  .creature
                                  .lateralFins![_lateralDragFromIndex!]
                                  .angleDegrees
                            : LateralFinConfig.angleDegreesDefault,
                        wingType:
                            _lateralDragFromIndex! <
                                (widget.creature.lateralFins?.length ?? 0)
                            ? widget
                                  .creature
                                  .lateralFins![_lateralDragFromIndex!]
                                  .wingType
                            : LateralWingType.ellipse,
                        positions: positions,
                        segmentAngles: _spine.segmentAngles,
                        centerX: centerX,
                        centerY: centerY,
                        cameraX: cameraX,
                        cameraY: cameraY,
                        zoom: _zoom,
                        segWidth: widthAtVertex(
                          segmentAtScreen(
                            _lastPanX,
                            _lastPanY,
                          ).clamp(0, positions.length - 2),
                        ),
                        finColor: widget.creature.finColor != null
                            ? Color(widget.creature.finColor!)
                            : Color.lerp(
                                Color(widget.creature.color),
                                Colors.white,
                                0.15,
                              )!,
                        highlight: false,
                      ),
                      size: Size(w, h),
                    ),
                  ),
                ),
              if (!finRemoveBounds().contains(Offset(_lastPanX, _lastPanY)))
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: PecFinSegmentPainter(
                        segment:
                            _lateralDragFromIndex! <
                                (widget.creature.lateralFins?.length ?? 0)
                            ? widget
                                  .creature
                                  .lateralFins![_lateralDragFromIndex!]
                                  .segment
                            : 0,
                        length:
                            _lateralDragFromIndex! <
                                (widget.creature.lateralFins?.length ?? 0)
                            ? widget
                                  .creature
                                  .lateralFins![_lateralDragFromIndex!]
                                  .length
                            : LateralFinConfig.lengthDefault,
                        width:
                            _lateralDragFromIndex! <
                                (widget.creature.lateralFins?.length ?? 0)
                            ? widget
                                  .creature
                                  .lateralFins![_lateralDragFromIndex!]
                                  .width
                            : LateralFinConfig.widthDefault,
                        angleDegrees:
                            _lateralDragFromIndex! <
                                (widget.creature.lateralFins?.length ?? 0)
                            ? widget
                                  .creature
                                  .lateralFins![_lateralDragFromIndex!]
                                  .angleDegrees
                            : LateralFinConfig.angleDegreesDefault,
                        wingType:
                            _lateralDragFromIndex! <
                                (widget.creature.lateralFins?.length ?? 0)
                            ? widget
                                  .creature
                                  .lateralFins![_lateralDragFromIndex!]
                                  .wingType
                            : LateralWingType.ellipse,
                        positions: positions,
                        segmentAngles: _spine.segmentAngles,
                        centerX: centerX,
                        centerY: centerY,
                        cameraX: cameraX,
                        cameraY: cameraY,
                        zoom: _zoom,
                        segWidth: widthAtVertex(
                          _lateralDragFromIndex! <
                                  (widget.creature.lateralFins?.length ?? 0)
                              ? widget
                                    .creature
                                    .lateralFins![_lateralDragFromIndex!]
                                    .segment
                              : 0,
                        ),
                        finColor: widget.creature.finColor != null
                            ? Color(widget.creature.finColor!)
                            : Color.lerp(
                                Color(widget.creature.color),
                                Colors.white,
                                0.15,
                              )!,
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
                      _zoomBtn(
                        () => setState(
                          () => _zoom = (_zoom - _zoomStep).clamp(
                            _minZoom,
                            _maxZoom,
                          ),
                        ),
                        '−',
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '${(_zoom * 100).round()}%',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      _zoomBtn(
                        () => setState(
                          () => _zoom = (_zoom + _zoomStep).clamp(
                            _minZoom,
                            _maxZoom,
                          ),
                        ),
                        '+',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
        Widget inner = stackContent;
        if (editTab == 1 && widget.onTailAdded != null) {
          final child = inner;
          inner = DragTarget<TailDragPayload>(
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (d) {
              final box =
                  _previewContentKey.currentContext?.findRenderObject()
                      as RenderBox?;
              if (box != null && box.hasSize) {
                final local = box.globalToLocal(d.offset);
                if (creatureScreenBounds().inflate(80).contains(local)) {
                  widget.onTailAdded!(d.data.tailFin);
                }
              }
              setState(() {
                _tailAddDragLocal = null;
                _tailAddDragPayload = null;
              });
            },
            onMove: (d) {
              final box =
                  _previewContentKey.currentContext?.findRenderObject()
                      as RenderBox?;
              if (box != null && box.hasSize) {
                setState(() {
                  _tailAddDragLocal = box.globalToLocal(d.offset);
                  _tailAddDragPayload = d.data;
                });
              }
            },
            onLeave: (_) => setState(() {
              _tailAddDragLocal = null;
              _tailAddDragPayload = null;
            }),
            builder: (context, candidateData, rejectedData) => child,
          );
        }
        if (editTab == 1 && widget.onEyeAdded != null) {
          final child = inner;
          inner = DragTarget<EyeDragPayload>(
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (d) {
              final box =
                  _previewContentKey.currentContext?.findRenderObject()
                      as RenderBox?;
              if (box != null && box.hasSize) {
                final local = box.globalToLocal(d.offset);
                if (creatureScreenBounds().inflate(40).contains(local)) {
                  final (seg, offset) = _segmentAndOffsetAtLocal(
                    local.dx,
                    local.dy,
                  );
                  widget.onEyeAdded!(seg, offset);
                }
              }
              setState(() => _eyeAddDragLocal = null);
            },
            onMove: (d) {
              final box =
                  _previewContentKey.currentContext?.findRenderObject()
                      as RenderBox?;
              if (box != null && box.hasSize) {
                setState(() => _eyeAddDragLocal = box.globalToLocal(d.offset));
              }
            },
            onLeave: (_) => setState(() => _eyeAddDragLocal = null),
            builder: (context, candidateData, rejectedData) => child,
          );
        }
        if (editTab == 1 && widget.onLateralAdded != null) {
          final child = inner;
          inner = DragTarget<LateralDragPayload>(
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (d) {
              final box =
                  _previewContentKey.currentContext?.findRenderObject()
                      as RenderBox?;
              if (box != null && box.hasSize) {
                final local = box.globalToLocal(d.offset);
                final seg = _segmentAtLocal(local.dx, local.dy);
                final wingType = d.data.wingType;
                widget.onLateralAdded!(seg, wingType);
              }
              setState(() {
                _lateralAddDragLocal = null;
                _lateralAddDragPayload = null;
              });
            },
            onMove: (d) {
              final box =
                  _previewContentKey.currentContext?.findRenderObject()
                      as RenderBox?;
              if (box != null && box.hasSize) {
                setState(() {
                  _lateralAddDragLocal = box.globalToLocal(d.offset);
                  _lateralAddDragPayload = d.data;
                });
              }
            },
            onLeave: (_) => setState(() {
              _lateralAddDragLocal = null;
              _lateralAddDragPayload = null;
            }),
            builder: (context, candidateData, rejectedData) => child,
          );
        }
        if (editTab == 1 && widget.onMouthAdded != null) {
          final child = inner;
          inner = DragTarget<MouthDragPayload>(
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (d) {
              final box =
                  _previewContentKey.currentContext?.findRenderObject()
                      as RenderBox?;
              if (box != null && box.hasSize) {
                final local = box.globalToLocal(d.offset);
                if (creatureScreenBounds().inflate(80).contains(local)) {
                  widget.onMouthAdded!(d.data.mouthType, d.data.mouthCount);
                }
              }
              setState(() {
                _mouthAddDragLocal = null;
                _mouthAddDragPayload = null;
              });
            },
            onMove: (d) {
              final box =
                  _previewContentKey.currentContext?.findRenderObject()
                      as RenderBox?;
              if (box != null && box.hasSize) {
                setState(() {
                  _mouthAddDragLocal = box.globalToLocal(d.offset);
                  _mouthAddDragPayload = d.data;
                });
              }
            },
            onLeave: (_) => setState(() {
              _mouthAddDragLocal = null;
              _mouthAddDragPayload = null;
            }),
            builder: (context, candidateData, rejectedData) => child,
          );
        }
        if (editTab == 1 && widget.onDorsalAdded != null) {
          final child = inner;
          return DragTarget<DorsalDragPayload>(
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (d) {
              final box =
                  _previewContentKey.currentContext?.findRenderObject()
                      as RenderBox?;
              if (box != null && box.hasSize) {
                final local = box.globalToLocal(d.offset);
                widget.onDorsalAdded!(_segmentAtLocal(local.dx, local.dy));
              }
              setState(() => _dorsalAddDragLocal = null);
            },
            onMove: (d) {
              final box =
                  _previewContentKey.currentContext?.findRenderObject()
                      as RenderBox?;
              if (box != null && box.hasSize) {
                setState(
                  () => _dorsalAddDragLocal = box.globalToLocal(d.offset),
                );
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
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }
}
