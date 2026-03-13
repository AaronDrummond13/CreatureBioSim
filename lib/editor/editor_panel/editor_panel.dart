import 'package:creature_bio_sim/editor/editor_panel/body_tab.dart';
import 'package:creature_bio_sim/editor/editor_panel/features_tab.dart';
import 'package:flutter/material.dart';
import 'package:creature_bio_sim/creature.dart';
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

  static const List<String> _tabs = ['Body', 'Parts', 'Colour'];

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
          Expanded(child: _tabContent(creature, onCreatureChanged)),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? EditorStyle.selected
                            : EditorStyle.fill,
                        borderRadius: BorderRadius.circular(EditorStyle.radius),
                        border: Border.all(
                          color: EditorStyle.stroke,
                          width: EditorStyle.strokeWidth,
                        ),
                      ),
                      child: Text(
                        _tabs[i],
                        style: TextStyle(
                          color: EditorStyle.text,
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
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

  Widget _tabContent(
    Creature creature,
    void Function(Creature) onCreatureChanged,
  ) {
    switch (tabIndex) {
      case 0:
        return BodyTab(
          creature: creature,
          onCreatureChanged: onCreatureChanged,
        );
      case 1:
        return FeaturesTab(
          creature: creature,
          onCreatureChanged: onCreatureChanged,
          selectedDorsalFinIndex: selectedDorsalFinIndex,
          onDorsalFinSelected: onDorsalFinSelected,
          selectedLateralFinIndex: selectedLateralFinIndex,
          onLateralRemoved: onLateralRemoved,
        );
      case 2:
        return _ColourTab(
          creature: creature,
          onCreatureChanged: onCreatureChanged,
        );
      default:
        return const SizedBox();
    }
  }
}

/// Colour tab: one picker, select Body or Fin to colour. No scroll.
class _ColourTab extends StatefulWidget {
  const _ColourTab({required this.creature, required this.onCreatureChanged});

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
        ? (creature.finColor != null
              ? Color(creature.finColor!)
              : Color(creature.color))
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
                        color: !_editingFin
                            ? EditorStyle.selected
                            : EditorStyle.fill,
                        borderRadius: BorderRadius.circular(EditorStyle.radius),
                        border: Border.all(
                          color: EditorStyle.stroke,
                          width: EditorStyle.strokeWidth,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Body',
                          style: TextStyle(
                            color: EditorStyle.text,
                            fontSize: 13,
                          ),
                        ),
                      ),
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
                        color: _editingFin
                            ? EditorStyle.selected
                            : EditorStyle.fill,
                        borderRadius: BorderRadius.circular(EditorStyle.radius),
                        border: Border.all(
                          color: EditorStyle.stroke,
                          width: EditorStyle.strokeWidth,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Fin',
                          style: TextStyle(
                            color: EditorStyle.text,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_editingFin && creature.finColor == null) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => widget.onCreatureChanged(
                  Creature(
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
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: EditorStyle.fill,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: EditorStyle.stroke),
                  ),
                  child: Center(
                    child: Text(
                      'Use custom fin colour',
                      style: TextStyle(
                        color: EditorStyle.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            _HSVPicker(
              color: color,
              onChanged: (c) {
                final value = 0xFF000000 | (c.value & 0xFFFFFF);
                widget.onCreatureChanged(
                  Creature(
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
                  ),
                );
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
                ? (c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight).clamp(
                    80.0,
                    200.0,
                  )
                : 160.0;
            return SizedBox(
              key: _svKey,
              width: side,
              height: side,
              child: Listener(
                onPointerDown: _handleSVPointer,
                onPointerMove: _handleSVPointer,
                child: CustomPaint(
                  painter: _SVSquarePainter(
                    hue: _hue,
                    s: _saturation,
                    v: _value,
                  ),
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
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(4),
    );
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
        canvas.drawRect(
          Rect.fromLTWH(px.toDouble(), py.toDouble(), 4, 4),
          Paint()..color = c,
        );
      }
    }
    final thumbX = s * size.width;
    final thumbY = (1 - v) * size.height;
    canvas.drawCircle(Offset(thumbX, thumbY), 6, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _SVSquarePainter old) =>
      old.hue != hue || old.s != s || old.v != v;
}
