import 'dart:math' show pi, sqrt;

import 'package:flutter/material.dart';

import 'package:creature_bio_sim/creature.dart';
import 'package:creature_bio_sim/render/render_utils.dart' show appendJigJag, appendSmoothCurve;
import 'package:creature_bio_sim/render/tail_painter.dart';
import 'package:creature_bio_sim/simulation/vector.dart';
import 'package:creature_bio_sim/editor/editor_shared.dart';
import 'package:creature_bio_sim/editor/editor_style.dart';

/// Left/bottom panel: custom tab row + content (no Material). Play is top-right only.
class EditorPanel extends StatelessWidget {
  const EditorPanel({
    super.key,
    required this.creature,
    required this.onCreatureChanged,
    required this.tabIndex,
    required this.onTabChanged,
    required this.selectedDorsalFinIndex,
    required this.onDorsalFinSelected,
    this.selectedLateralFinIndex,
    this.onLateralRemoved,
  });

  final Creature creature;
  final void Function(Creature) onCreatureChanged;
  final int tabIndex;
  final void Function(int) onTabChanged;
  final int? selectedDorsalFinIndex;
  final void Function(int?) onDorsalFinSelected;
  final int? selectedLateralFinIndex;
  final void Function(int index)? onLateralRemoved;

  static const List<String> _tabs = ['Body', 'Colour', 'Parts'];

  static const double _panelMargin = 12.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(_panelMargin),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(EditorStyle.radius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          _tabRow(context),
          Expanded(
            child: _tabContent(creature, onCreatureChanged),
          ),
        ],
      ),
    );
  }

  Widget _tabRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_tabs.length, (i) {
                  final selected = i == tabIndex;
                  return GestureDetector(
                    onTap: () => onTabChanged(i),
                    child: Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? EditorStyle.selected : EditorStyle.fill,
                        borderRadius: BorderRadius.circular(EditorStyle.radius),
                        border: Border.all(color: EditorStyle.stroke, width: EditorStyle.strokeWidth),
                      ),
                      child: Text(
                        _tabs[i],
                        style: TextStyle(
                          color: EditorStyle.text,
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabContent(Creature creature, void Function(Creature) onCreatureChanged) {
    switch (tabIndex) {
      case 0:
        return _BodyTab(creature: creature, onCreatureChanged: onCreatureChanged);
      case 1:
        return _ColourTab(creature: creature, onCreatureChanged: onCreatureChanged);
      case 2:
        return _FinsTab(
          creature: creature,
          onCreatureChanged: onCreatureChanged,
          selectedDorsalFinIndex: selectedDorsalFinIndex,
          onDorsalFinSelected: onDorsalFinSelected,
          selectedLateralFinIndex: selectedLateralFinIndex,
          onLateralRemoved: onLateralRemoved,
        );
      default:
        return const SizedBox();
    }
  }
}

/// Body: segment count via viewport head/tail nodes; tail (caudal) fin picker.
class _BodyTab extends StatelessWidget {
  const _BodyTab({
    required this.creature,
    required this.onCreatureChanged,
  });

  final Creature creature;
  final void Function(Creature) onCreatureChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('Body length', style: TextStyle(color: EditorStyle.text, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('Drag the tail node in the view to change segment count.', style: TextStyle(fontSize: 12, color: EditorStyle.textMuted)),
      ],
    );
  }
}

/// Shared helper for draggable tail box (used from Parts tab).
Widget _draggableTailBox(Creature c, CaudalFinType tailFin) {
  const boxW = 52.0;
  const boxH = 36.0;
  final box = _TailBox(creature: c, tailFin: tailFin);
  return Draggable<TailDragPayload>(
    data: TailDragPayload(tailFin),
    dragAnchorStrategy: pointerDragAnchorStrategy,
    feedbackOffset: const Offset(-boxW / 2, -boxH / 2),
    feedback: Material(
      elevation: 0,
      color: Colors.transparent,
      child: SizedBox(
        width: boxW,
        height: boxH,
        child: CustomPaint(
          painter: _TailPreviewPainter(creature: c, tailFin: tailFin),
          size: const Size(boxW, boxH),
        ),
      ),
    ),
    childWhenDragging: Opacity(opacity: 0.5, child: box),
    child: box,
  );
}

/// Colour tab: one picker, select Body or Fin to colour. No scroll.
class _ColourTab extends StatefulWidget {
  const _ColourTab({
    required this.creature,
    required this.onCreatureChanged,
  });

  final Creature creature;
  final void Function(Creature) onCreatureChanged;

  @override
  State<_ColourTab> createState() => _ColourTabState();
}

class _ColourTabState extends State<_ColourTab> {
  bool _editingFin = false;

  @override
  Widget build(BuildContext context) {
    final creature = widget.creature;
    final color = _editingFin
        ? (creature.finColor != null ? Color(creature.finColor!) : Color(creature.color))
        : Color(creature.color);
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _editingFin = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !_editingFin ? EditorStyle.selected : EditorStyle.fill,
                        borderRadius: BorderRadius.circular(EditorStyle.radius),
                        border: Border.all(color: EditorStyle.stroke, width: EditorStyle.strokeWidth),
                      ),
                      child: Center(child: Text('Body', style: TextStyle(color: EditorStyle.text, fontSize: 13))),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _editingFin = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _editingFin ? EditorStyle.selected : EditorStyle.fill,
                        borderRadius: BorderRadius.circular(EditorStyle.radius),
                        border: Border.all(color: EditorStyle.stroke, width: EditorStyle.strokeWidth),
                      ),
                      child: Center(child: Text('Fin', style: TextStyle(color: EditorStyle.text, fontSize: 13))),
                    ),
                  ),
                ),
              ],
            ),
            if (_editingFin && creature.finColor == null) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => widget.onCreatureChanged(Creature(
                  segmentWidths: creature.segmentWidths,
                  color: creature.color,
                  dorsalFins: creature.dorsalFins,
                  finColor: creature.color,
                  tail: creature.tail,
                  lateralFins: creature.lateralFins,
                  trophicType: creature.trophicType,
                  mouth: creature.mouth,
                  mouthCount: creature.mouthCount,
                  mouthLength: creature.mouthLength,
                  mouthCurve: creature.mouthCurve,
                  mouthWobbleAmplitude: creature.mouthWobbleAmplitude,
                  eyes: creature.eyes,
                )),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: EditorStyle.fill,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: EditorStyle.stroke),
                  ),
                  child: Center(child: Text('Use custom fin colour', style: TextStyle(color: EditorStyle.textMuted, fontSize: 12))),
                ),
              ),
            ],
            const SizedBox(height: 12),
            _HSVPicker(
              color: color,
              onChanged: (c) {
                final value = 0xFF000000 | (c.value & 0xFFFFFF);
                widget.onCreatureChanged(Creature(
                  segmentWidths: creature.segmentWidths,
                  color: _editingFin ? creature.color : value,
                  dorsalFins: creature.dorsalFins,
                  finColor: _editingFin ? value : creature.finColor,
                  tail: creature.tail,
                  lateralFins: creature.lateralFins,
                  trophicType: creature.trophicType,
                  mouth: creature.mouth,
                  mouthCount: creature.mouthCount,
                  mouthLength: creature.mouthLength,
                  mouthCurve: creature.mouthCurve,
                  mouthWobbleAmplitude: creature.mouthWobbleAmplitude,
                  eyes: creature.eyes,
                ));
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple HSV picker: hue strip + saturation/value square. Custom drawn.
class _HSVPicker extends StatefulWidget {
  const _HSVPicker({required this.color, required this.onChanged});

  final Color color;
  final void Function(Color) onChanged;

  @override
  State<_HSVPicker> createState() => _HSVPickerState();
}

class _HSVPickerState extends State<_HSVPicker> {
  late double _hue;
  late double _saturation;
  late double _value;
  final GlobalKey _hueKey = GlobalKey();
  final GlobalKey _svKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _syncFromColor();
  }

  @override
  void didUpdateWidget(covariant _HSVPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.color.value != widget.color.value) _syncFromColor();
  }

  void _syncFromColor() {
    final hsv = HSVColor.fromColor(widget.color);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
  }

  void _emit() {
    widget.onChanged(HSVColor.fromAHSV(1, _hue, _saturation, _value).toColor());
  }

  void _handleHuePointer(PointerEvent e) {
    final box = _hueKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final local = box.globalToLocal(e.position);
    final w = box.size.width;
    final dx = local.dx.clamp(0.0, w);
    _hue = (dx / w) * 360;
    setState(() {});
    _emit();
  }

  void _handleSVPointer(PointerEvent e) {
    final box = _svKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final local = box.globalToLocal(e.position);
    final w = box.size.width;
    final h = box.size.height;
    final dx = local.dx.clamp(0.0, w);
    final dy = local.dy.clamp(0.0, h);
    _saturation = dx / w;
    _value = 1 - (dy / h);
    setState(() {});
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth > 0 ? c.maxWidth : 200.0;
            final h = 20.0;
            return SizedBox(
              key: _hueKey,
              width: w,
              height: h,
              child: Listener(
                onPointerDown: _handleHuePointer,
                onPointerMove: _handleHuePointer,
                child: CustomPaint(
                  painter: _HueStripPainter(),
                  size: Size(w, h),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, c) {
            final side = (c.maxWidth > 0 && c.maxHeight > 0)
                ? (c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight).clamp(80.0, 200.0)
                : 160.0;
            return SizedBox(
              key: _svKey,
              width: side,
              height: side,
              child: Listener(
                onPointerDown: _handleSVPointer,
                onPointerMove: _handleSVPointer,
                child: CustomPaint(
                  painter: _SVSquarePainter(hue: _hue, s: _saturation, v: _value),
                  size: Size(side, side),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _HueStripPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(4));
    final shader = const LinearGradient(
      colors: [
        Color(0xFFFF0000),
        Color(0xFFFFFF00),
        Color(0xFF00FF00),
        Color(0xFF00FFFF),
        Color(0xFF0000FF),
        Color(0xFFFF00FF),
        Color(0xFFFF0000),
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRRect(rect, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _SVSquarePainter extends CustomPainter {
  _SVSquarePainter({required this.hue, required this.s, required this.v});

  final double hue;
  final double s;
  final double v;

  @override
  void paint(Canvas canvas, Size size) {
    for (var py = 0; py < size.height; py += 4) {
      for (var px = 0; px < size.width; px += 4) {
        final sx = px / size.width;
        final vy = 1 - py / size.height;
        final c = HSVColor.fromAHSV(1, hue, sx, vy).toColor();
        canvas.drawRect(Rect.fromLTWH(px.toDouble(), py.toDouble(), 4, 4), Paint()..color = c);
      }
    }
    final thumbX = s * size.width;
    final thumbY = (1 - v) * size.height;
    canvas.drawCircle(Offset(thumbX, thumbY), 6, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _SVSquarePainter old) => old.hue != hue || old.s != s || old.v != v;
}

/// One tail option: real tail via [paintTailFin] with creature colours and minimal spine. Wrapped in Draggable by caller.
class _TailBox extends StatelessWidget {
  const _TailBox({required this.creature, required this.tailFin});

  final Creature creature;
  final CaudalFinType tailFin;

  static const double _boxW = 52;
  static const double _boxH = 36;
  static const double _tailWorldLeft = -25.0;
  static const double _tailLength = 60.0;
  static const double _zoom = 0.87;
  static double get _tailCenterWorld => _tailWorldLeft - _tailLength / 2;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _boxW,
      height: _boxH,
      decoration: BoxDecoration(
        color: EditorStyle.fill,
        borderRadius: BorderRadius.circular(EditorStyle.radius),
        border: Border.all(color: EditorStyle.stroke, width: EditorStyle.strokeWidth),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(EditorStyle.radius),
        child: CustomPaint(
          painter: _TailPreviewPainter(
            creature: creature,
            tailFin: tailFin,
          ),
          size: const Size(_boxW, _boxH),
        ),
      ),
    );
  }
}

/// Paints tail using shared [paintTailFin]; horizontal in box, centered.
class _TailPreviewPainter extends CustomPainter {
  _TailPreviewPainter({required this.creature, required this.tailFin});

  final Creature creature;
  final CaudalFinType? tailFin;

  @override
  void paint(Canvas canvas, Size size) {
    final bodyColor = Color(creature.color);
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    if (tailFin == null) {
      canvas.drawCircle(Offset(centerX, centerY), 8, Paint()..color = bodyColor);
      canvas.drawCircle(Offset(centerX, centerY), 8, Paint()..color = EditorStyle.stroke..style = PaintingStyle.stroke..strokeWidth = 1);
      return;
    }
    final minimal = Creature(
      segmentWidths: [20.0, 25.0],
      color: creature.color,
      finColor: creature.finColor,
      tail: TailConfig(tailFin!),
    );
    final positions = [
      Vector2(_TailBox._tailWorldLeft, 0),
      Vector2(_TailBox._tailWorldLeft + 10, 0),
      Vector2(_TailBox._tailWorldLeft + 20, 0),
    ];
    const segmentAngles = [0.0, 0.0];
    double widthAt(int i) => minimal.widthAtVertex(i);
    paintTailFin(
      canvas,
      minimal,
      positions,
      segmentAngles,
      centerX,
      centerY,
      _TailBox._zoom,
      _TailBox._tailCenterWorld,
      0,
      1.0,
      bodyColor,
      widthAt,
    );
  }

  @override
  bool shouldRepaint(covariant _TailPreviewPainter old) =>
      old.creature.color != creature.color || old.creature.finColor != creature.finColor || old.tailFin != tailFin;
}

/// Paints a single mouth type in a small box (head at center, mouth forward).
class _MouthPreviewPainter extends CustomPainter {
  _MouthPreviewPainter({required this.creature, required this.mouthType});

  final Creature creature;
  final MouthType mouthType;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final bodyColor = Color(creature.color);
    final fillColor = creature.finColor != null
        ? Color(creature.finColor!)
        : Color.lerp(bodyColor, Colors.white, 0.15)!;

    switch (mouthType) {
      case MouthType.teeth:
        _paintSingleToothIcon(canvas, cx, cy, fillColor);
        break;
      case MouthType.tentacle:
        _paintSingleTentacleIcon(canvas, cx, cy, fillColor);
        break;
      case MouthType.mandible:
        _paintSingleMandibleIcon(canvas, cx, cy, fillColor);
        break;
    }
  }

  static void _iconPaints(Color fillColor, Paint fill, Paint stroke) {
    fill
      ..color = fillColor
      ..style = PaintingStyle.fill;
    stroke
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
  }

  /// Single tooth: spike pointing forward (right).
  void _paintSingleToothIcon(Canvas canvas, double cx, double cy, Color fillColor) {
    const scale = 1.2;
    final fill = Paint();
    final stroke = Paint();
    _iconPaints(fillColor, fill, stroke);

    final baseL = Offset(cx - 6 * scale, cy + 2.2 * scale);
    final baseR = Offset(cx - 6 * scale, cy - 2.2 * scale);
    final tip = Offset(cx + 10 * scale, cy);

    final path = Path()
      ..moveTo(baseL.dx, baseL.dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(baseR.dx, baseR.dy)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  /// Single tentacle: one wiggly feeler, base at back, tip forward, icicle-shaped.
  void _paintSingleTentacleIcon(Canvas canvas, double cx, double cy, Color fillColor) {
    const scale = 1.1;
    final fill = Paint();
    final stroke = Paint();
    _iconPaints(fillColor, fill, stroke);

    final spine = [
      Offset(cx - 5 * scale, cy),
      Offset(cx, cy + 1.5 * scale),
      Offset(cx + 4 * scale, cy - 1.2 * scale),
      Offset(cx + 10 * scale, cy),
    ];
    const halfW = 2.0;
    double segLen(int i) {
      if (i <= 0) return 1.0;
      final p = spine[i];
      final prev = spine[i - 1];
      final dx = p.dx - prev.dx;
      final dy = p.dy - prev.dy;
      final l2 = dx * dx + dy * dy;
      return l2 > 1e-10 ? sqrt(l2) : 1.0;
    }

    final leftPts = spine.asMap().entries.map((e) {
      final i = e.key;
      final p = e.value;
      final w = halfW * (1.0 - i / (spine.length - 1) * 0.85);
      final prev = i > 0 ? spine[i - 1] : spine[0];
      final dx = p.dx - prev.dx;
      final dy = p.dy - prev.dy;
      final len = segLen(i);
      final nx = -dy / len;
      final ny = dx / len;
      return Offset(p.dx + nx * w * scale, p.dy + ny * w * scale);
    }).toList();
    final rightPts = spine.asMap().entries.map((e) {
      final i = e.key;
      final p = e.value;
      final w = halfW * (1.0 - i / (spine.length - 1) * 0.85);
      final prev = i > 0 ? spine[i - 1] : spine[0];
      final dx = p.dx - prev.dx;
      final dy = p.dy - prev.dy;
      final len = segLen(i);
      final nx = -dy / len;
      final ny = dx / len;
      return Offset(p.dx - nx * w * scale, p.dy - ny * w * scale);
    }).toList();
    final outline = <Offset>[...leftPts, ...rightPts.reversed.skip(1)];
    final path = Path()..moveTo(outline[0].dx, outline[0].dy);
    appendSmoothCurve(path, outline, 1.0 / 6.0, closed: true);
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  /// Single mandible: one curved jaw with jagged inner edge.
  void _paintSingleMandibleIcon(Canvas canvas, double cx, double cy, Color fillColor) {
    const scale = 1.15;
    const jagAmplitude = 1.3;
    const jagTeeth = 5;
    final fill = Paint();
    final stroke = Paint();
    _iconPaints(fillColor, fill, stroke);

    double x(double v) => cx + v * scale;
    double y(double v) => cy + v * scale;

    const rootX = -5.5;
    const rootY = 2.0;
    const tipX = 11.0;
    const tipY = 4.2;
    const innerRootY = 1.2;
    const innerTipY = 3.5;

    final rootOuter = Offset(x(rootX), y(rootY));
    final tipOuter = Offset(x(tipX), y(tipY));
    final outerArc = [
      rootOuter,
      Offset(x(rootX + 4), y(rootY + 1.2)),
      Offset(x(tipX - 3), y(tipY - 0.5)),
      tipOuter,
    ];
    final rootInner = Offset(x(rootX + 0.8), y(innerRootY));
    final tipInner = Offset(x(tipX - 0.8), y(innerTipY));

    final path = Path();
    path.moveTo(rootInner.dx, rootInner.dy);
    path.lineTo(rootOuter.dx, rootOuter.dy);
    appendSmoothCurve(path, outerArc, 1.0 / 6.0, closed: false);
    path.lineTo(tipInner.dx, tipInner.dy);
    appendJigJag(path, tipInner, rootInner, jagTeeth, jagAmplitude);
    path.close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _MouthPreviewPainter old) =>
      old.creature.color != creature.color || old.creature.finColor != creature.finColor || old.mouthType != mouthType;
}

/// Small dorsal fin preview for the + dorsal button (approximate render).
class _DorsalPreviewPainter extends CustomPainter {
  _DorsalPreviewPainter({required this.bodyColor, this.finColor});

  final Color bodyColor;
  final Color? finColor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.width / 2;
    final cy = size.height / 2;
    final fin = finColor ?? Color.lerp(bodyColor, Colors.white, 0.15)!;
    final path = Path();
    path.moveTo(c - 12, cy + 4);
    path.quadraticBezierTo(c - 4, cy - 10, c, cy - 12);
    path.quadraticBezierTo(c + 4, cy - 10, c + 12, cy + 4);
    path.close();
    canvas.drawPath(path, Paint()..color = fin);
    canvas.drawPath(path, Paint()..color = EditorStyle.stroke..style = PaintingStyle.stroke..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(covariant _DorsalPreviewPainter old) =>
      old.bodyColor != bodyColor || old.finColor != finColor;
}

/// Small lateral fin preview for panel buttons. [wingType] = ellipse (two ovals) or shark (two triangles).
class _LateralPreviewPainter extends CustomPainter {
  _LateralPreviewPainter({required this.bodyColor, this.finColor, this.wingType = LateralWingType.ellipse});

  final Color bodyColor;
  final Color? finColor;
  final LateralWingType wingType;

  @override
  void paint(Canvas canvas, Size size) {
    final color = finColor ?? Color.lerp(bodyColor, Colors.white, 0.15)!;
    final fill = Paint()..color = color..style = PaintingStyle.fill;
    final stroke = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.2;
    const flareRad = 45.0 * pi / 180.0;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final len = size.width * 0.22;
    final wid = len / 3.0;
    final offset = size.width * 0.18;
    void drawOne(Canvas c, double dx) {
      c.save();
      c.translate(cx + dx, cy);
      c.rotate(dx < 0 ? flareRad : -flareRad);
      if (wingType == LateralWingType.sharkWing) {
        final hLen = len / 2, hWid = wid / 2;
        final path = Path()
          ..moveTo(hLen, -hWid)
          ..quadraticBezierTo(0.0, -hWid, -hLen, 0.0)
          ..quadraticBezierTo(0.0, hWid, hLen, hWid)
          ..close();
        c.drawPath(path, fill);
        c.drawPath(path, stroke);
      } else if (wingType == LateralWingType.sharkConcave) {
        final hLen = len / 2, hWid = wid / 2;
        final isLeft = dx < 0;
        final path = Path();
        if (isLeft) {
          path
            ..moveTo(hLen, -hWid)
            ..quadraticBezierTo(0.0, -hWid, -hLen, 0.0)
            ..quadraticBezierTo(0.0, 0.0, hLen, hWid)
            ..close();
        } else {
          path
            ..moveTo(hLen, -hWid)
            ..quadraticBezierTo(0.0, 0.0, -hLen, 0.0)
            ..quadraticBezierTo(0.0, hWid, hLen, hWid)
            ..close();
        }
        c.drawPath(path, fill);
        c.drawPath(path, stroke);
      } else if (wingType == LateralWingType.paddle) {
        final hLen = len / 2, hWid = wid / 2;
        final path = Path()
          ..moveTo(-hLen, -hWid)
          ..quadraticBezierTo(0.0, -hWid, hLen, 0.0)
          ..quadraticBezierTo(0.0, hWid, -hLen, hWid)
          ..close();
        c.drawPath(path, fill);
        c.drawPath(path, stroke);
      } else if (wingType == LateralWingType.paddleConcave) {
        final hLen = len / 2, hWid = wid / 2;
        final isLeft = dx < 0;
        final path = Path();
        if (isLeft) {
          path
            ..moveTo(-hLen, -hWid)
            ..quadraticBezierTo(0.0, -hWid, hLen, 0.0)
            ..quadraticBezierTo(0.0, 0.0, -hLen, hWid)
            ..close();
        } else {
          path
            ..moveTo(-hLen, -hWid)
            ..quadraticBezierTo(0.0, 0.0, hLen, 0.0)
            ..quadraticBezierTo(0.0, hWid, -hLen, hWid)
            ..close();
        }
        c.drawPath(path, fill);
        c.drawPath(path, stroke);
      } else {
        final rect = Rect.fromCenter(center: Offset.zero, width: len, height: wid);
        c.drawOval(rect, fill);
        c.drawOval(rect, stroke);
      }
      c.restore();
    }
    drawOne(canvas, -offset);
    drawOne(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _LateralPreviewPainter old) =>
      old.bodyColor != bodyColor || old.finColor != finColor || old.wingType != wingType;
}

/// Horizontal strip of segment nodes; drag start/end thumbs to set range.
class _DorsalSpineStrip extends StatefulWidget {
  const _DorsalSpineStrip({
    required this.segmentCount,
    required this.start,
    required this.end,
    required this.onRangeChanged,
  });

  final int segmentCount;
  final int start;
  final int end;
  final void Function(int start, int end) onRangeChanged;

  @override
  State<_DorsalSpineStrip> createState() => _DorsalSpineStripState();
}

class _DorsalSpineStripState extends State<_DorsalSpineStrip> {
  int? _dragging; // 0 = start, 1 = end

  int _segmentAt(double x, double width) {
    if (widget.segmentCount <= 0) return 0;
    final frac = (x / width).clamp(0.0, 1.0);
    return (frac * (widget.segmentCount - 1)).round().clamp(0, widget.segmentCount - 1);
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.segmentCount;
    if (n <= 0) return const SizedBox(height: 32);
    final start = widget.start.clamp(0, n - 1);
    final end = widget.end.clamp(start, n - 1);

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        return SizedBox(
          height: 36,
          child: GestureDetector(
            onPanStart: (d) {
              final seg = _segmentAt(d.localPosition.dx, w);
              final distStart = (seg - start).abs();
              final distEnd = (seg - end).abs();
              setState(() => _dragging = distStart <= distEnd ? 0 : 1);
            },
            onPanUpdate: (d) {
              final seg = _segmentAt(d.localPosition.dx, w);
              if (_dragging == 0) {
                widget.onRangeChanged(seg.clamp(0, end), end);
              } else if (_dragging == 1) {
                widget.onRangeChanged(start, seg.clamp(start, n - 1));
              }
            },
            onPanEnd: (_) => setState(() => _dragging = null),
            child: CustomPaint(
              painter: _DorsalStripPainter(
                segmentCount: n,
                start: start,
                end: end,
                strokeColor: EditorStyle.stroke,
                fillColor: EditorStyle.fill,
                selectedColor: EditorStyle.selected,
              ),
              size: Size(w, 36),
            ),
          ),
        );
      },
    );
  }
}

class _DorsalStripPainter extends CustomPainter {
  _DorsalStripPainter({
    required this.segmentCount,
    required this.start,
    required this.end,
    required this.strokeColor,
    required this.fillColor,
    required this.selectedColor,
  });

  final int segmentCount;
  final int start;
  final int end;
  final Color strokeColor;
  final Color fillColor;
  final Color selectedColor;

  @override
  void paint(Canvas canvas, Size size) {
    final n = segmentCount;
    if (n <= 0) return;
    final segW = size.width / n;
    final cy = size.height / 2;
    final r = 6.0;

    for (var i = 0; i < n; i++) {
      final cx = (i + 0.5) * segW;
      final inRange = i >= start && i <= end;
      canvas.drawCircle(Offset(cx, cy), r, Paint()..color = inRange ? selectedColor : fillColor);
      canvas.drawCircle(Offset(cx, cy), r, Paint()..color = strokeColor..style = PaintingStyle.stroke..strokeWidth = 1.5);
      if (i == start || i == end) {
        canvas.drawCircle(Offset(cx, cy), 3, Paint()..color = strokeColor);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DorsalStripPainter old) =>
      old.segmentCount != segmentCount || old.start != start || old.end != end;
}

/// Parts tab: Head (mouth types) and Fins (tail, dorsal, pectoral). Drag to add; tap in view to select or edit.
class _FinsTab extends StatelessWidget {
  const _FinsTab({
    required this.creature,
    required this.onCreatureChanged,
    required this.selectedDorsalFinIndex,
    required this.onDorsalFinSelected,
    this.selectedLateralFinIndex,
    this.onLateralRemoved,
  });

  final Creature creature;
  final void Function(Creature) onCreatureChanged;
  final int? selectedDorsalFinIndex;
  final void Function(int?)? onDorsalFinSelected;
  final int? selectedLateralFinIndex;
  final void Function(int index)? onLateralRemoved;

  static const double _boxW = 52;
  static const double _boxH = 36;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('Parts', style: TextStyle(color: EditorStyle.text, fontWeight: FontWeight.w600, fontSize: 12)),
        Text('Drag to add; tap in view to select or edit.', style: TextStyle(fontSize: 11, color: EditorStyle.textMuted)),
        const SizedBox(height: 14),
        Text('Eyes', style: TextStyle(color: EditorStyle.text, fontWeight: FontWeight.w600, fontSize: 12)),
        Text('Drag onto creature to add. Tap in view to select; drag node to resize; drag off to remove.', style: TextStyle(fontSize: 11, color: EditorStyle.textMuted)),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Draggable<EyeDragPayload>(
              data: EyeDragPayload(),
              dragAnchorStrategy: pointerDragAnchorStrategy,
              feedbackOffset: const Offset(-16, -16),
              feedback: Material(
                elevation: 0,
                color: Colors.transparent,
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: Center(
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: EditorStyle.stroke, width: 1),
                      ),
                    ),
                  ),
                ),
              ),
              childWhenDragging: Opacity(opacity: 0.5, child: _eyeBox()),
              child: _eyeBox(),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text('Head', style: TextStyle(color: EditorStyle.text, fontWeight: FontWeight.w600, fontSize: 12)),
        Text('Drag onto creature to add or replace. Drag off in view to remove.', style: TextStyle(fontSize: 11, color: EditorStyle.textMuted)),
        const SizedBox(height: 8),
        _mouthGroupLabel('Herbivore'),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _mouthButton(creature, MouthType.tentacle, 3, 'Shrimp'),
            _mouthButton(creature, MouthType.tentacle, 5, 'Squid'),
            _mouthButton(creature, MouthType.tentacle, 7, 'Octopus'),
          ],
        ),
        const SizedBox(height: 8),
        _mouthGroupLabel('Carnivore'),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _mouthButton(creature, MouthType.teeth, 2, 'Fangs'),
            _mouthButton(creature, MouthType.teeth, 4, 'Biter'),
            _mouthButton(creature, MouthType.teeth, 6, 'Teeth'),
          ],
        ),
        const SizedBox(height: 8),
        _mouthGroupLabel('Omnivore'),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _mouthButton(creature, MouthType.mandible, null, 'Mandible'),
          ],
        ),
        const SizedBox(height: 14),
        Text('Fins', style: TextStyle(color: EditorStyle.text, fontWeight: FontWeight.w600, fontSize: 12)),
        Text('Drag to creature to add. Tap in view to select; drag off to remove.', style: TextStyle(fontSize: 11, color: EditorStyle.textMuted)),
        const SizedBox(height: 6),
        Text('Tail Fin', style: TextStyle(color: EditorStyle.text, fontSize: 11)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: CaudalFinType.values.map((e) => _draggableTailBox(creature, e)).toList(),
        ),
        const SizedBox(height: 8),
        Text('Dorsal Fin', style: TextStyle(color: EditorStyle.text, fontSize: 11)),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Draggable<DorsalDragPayload>(
              data: DorsalDragPayload(),
              dragAnchorStrategy: pointerDragAnchorStrategy,
              feedbackOffset: const Offset(-16, -16),
              feedback: Material(
                elevation: 0,
                color: Colors.transparent,
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: Center(
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: EditorStyle.selected.withValues(alpha: 0.9),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.5,
                child: _dorsalBox(),
              ),
              child: _dorsalBox(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Pectoral Fin', style: TextStyle(color: EditorStyle.text, fontSize: 11)),
        Text('Drag Ellipse or Shark to add or replace. Tap in view to select; drag off to remove.', style: TextStyle(fontSize: 11, color: EditorStyle.textMuted)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _draggableLateralBox(creature, LateralWingType.ellipse),
            _draggableLateralBox(creature, LateralWingType.sharkWing),
            _draggableLateralBox(creature, LateralWingType.sharkConcave),
            _draggableLateralBox(creature, LateralWingType.paddle),
            _draggableLateralBox(creature, LateralWingType.paddleConcave),
            if (selectedLateralFinIndex != null &&
                creature.lateralFins != null &&
                selectedLateralFinIndex! < creature.lateralFins!.length &&
                onLateralRemoved != null)
              GestureDetector(
                onTap: () => onLateralRemoved!(selectedLateralFinIndex!),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: EditorStyle.fill,
                    borderRadius: BorderRadius.circular(EditorStyle.radius),
                    border: Border.all(color: EditorStyle.stroke, width: EditorStyle.strokeWidth),
                  ),
                  child: Text('Remove', style: TextStyle(fontSize: 11, color: EditorStyle.text)),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _mouthGroupLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: EditorStyle.textMuted)),
    );
  }

  Widget _mouthButton(Creature creature, MouthType mouthType, int? mouthCount, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _draggableMouthBox(creature, mouthType, mouthCount),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 9, color: EditorStyle.textMuted)),
      ],
    );
  }

  Widget _draggableMouthBox(Creature creature, MouthType mouthType, [int? mouthCount]) {
    Widget mouthBox() => Container(
      width: _boxW,
      height: _boxH,
      decoration: BoxDecoration(
        color: EditorStyle.fill,
        borderRadius: BorderRadius.circular(EditorStyle.radius),
        border: Border.all(color: EditorStyle.stroke, width: EditorStyle.strokeWidth),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(EditorStyle.radius),
        child: CustomPaint(
          painter: _MouthPreviewPainter(creature: creature, mouthType: mouthType),
          size: const Size(_boxW, _boxH),
        ),
      ),
    );
    return Draggable<MouthDragPayload>(
      data: MouthDragPayload(mouthType, mouthCount),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedbackOffset: const Offset(-26, -18),
      feedback: Material(
        elevation: 0,
        color: Colors.transparent,
        child: SizedBox(
          width: _boxW,
          height: _boxH,
          child: CustomPaint(
            painter: _MouthPreviewPainter(creature: creature, mouthType: mouthType),
            size: const Size(_boxW, _boxH),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.5, child: mouthBox()),
      child: mouthBox(),
    );
  }

  Widget _dorsalBox() {
    return Container(
      width: _boxW,
      height: _boxH,
      decoration: BoxDecoration(
        color: EditorStyle.fill,
        borderRadius: BorderRadius.circular(EditorStyle.radius),
        border: Border.all(color: EditorStyle.stroke, width: EditorStyle.strokeWidth),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(EditorStyle.radius),
        child: CustomPaint(
          painter: _DorsalPreviewPainter(
            bodyColor: Color(creature.color),
            finColor: creature.finColor != null ? Color(creature.finColor!) : null,
          ),
          size: const Size(_boxW, _boxH),
        ),
      ),
    );
  }

  Widget _eyeBox() {
    return Container(
      width: _boxW,
      height: _boxH,
      decoration: BoxDecoration(
        color: EditorStyle.fill,
        borderRadius: BorderRadius.circular(EditorStyle.radius),
        border: Border.all(color: EditorStyle.stroke, width: EditorStyle.strokeWidth),
      ),
      child: Center(
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: EditorStyle.stroke, width: 1),
          ),
        ),
      ),
    );
  }

  Widget _lateralBox(LateralWingType wingType) {
    return Container(
      width: _boxW,
      height: _boxH,
      decoration: BoxDecoration(
        color: EditorStyle.fill,
        borderRadius: BorderRadius.circular(EditorStyle.radius),
        border: Border.all(color: EditorStyle.stroke, width: EditorStyle.strokeWidth),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(EditorStyle.radius),
        child: CustomPaint(
          painter: _LateralPreviewPainter(
            bodyColor: Color(creature.color),
            finColor: creature.finColor != null ? Color(creature.finColor!) : null,
            wingType: wingType,
          ),
          size: const Size(_boxW, _boxH),
        ),
      ),
    );
  }

  Widget _draggableLateralBox(Creature creature, LateralWingType wingType) {
    return Draggable<LateralDragPayload>(
      data: LateralDragPayload(wingType: wingType),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedbackOffset: const Offset(-26, -18),
      feedback: Material(
        elevation: 0,
        color: Colors.transparent,
        child: SizedBox(
          width: _boxW,
          height: _boxH,
          child: CustomPaint(
            painter: _LateralPreviewPainter(
              bodyColor: Color(creature.color),
              finColor: creature.finColor != null ? Color(creature.finColor!) : null,
              wingType: wingType,
            ),
            size: const Size(_boxW, _boxH),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.5, child: _lateralBox(wingType)),
      child: _lateralBox(wingType),
    );
  }
}
