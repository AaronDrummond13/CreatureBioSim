import 'dart:math' show atan2, cos, pi, sin, sqrt;
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import '../creature.dart';
import '../render/background_painter.dart';
import '../render/creature_painter.dart';
import '../render/tail_painter.dart';
import '../render/view.dart';
import '../simulation/angle_util.dart' show relativeAngleDiff;
import '../simulation/spine.dart';
import '../simulation/vector.dart';

/// Same dark base as play mode (simulation_screen bgColor base).
const Color _kEditorBackground = Color.fromARGB(255, 28, 30, 54);

const double _kFinRemoveMargin = 100.0;
const double _kDorsalGrabRadius = 20.0;
const double _kLateralGrabRadius = 22.0;

/// Shared editor UI: curves and fills to match game aesthetic (no Material).
class _EditorStyle {
  static const Color stroke = Color(0xFF6b8a9e);
  static const Color fill = Color(0xFF2e3d4d);
  static const Color selected = Color(0xFF3d5a6e);
  static const Color text = Color(0xFFe8eef2);
  static const Color textMuted = Color(0xFF8fa3b0);
  static const double radius = 8.0;
  static const double strokeWidth = 1.5;
}

/// Custom slider: track + draggable thumb (no Material).
class _EditorSlider extends StatefulWidget {
  const _EditorSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final void Function(double) onChanged;

  @override
  State<_EditorSlider> createState() => _EditorSliderState();
}

class _EditorSliderState extends State<_EditorSlider> {
  double get _frac => (widget.value - widget.min) / (widget.max - widget.min);

  void _onDrag(DragUpdateDetails d, double width) {
    final frac = (d.localPosition.dx / width).clamp(0.0, 1.0);
    final v = widget.min + frac * (widget.max - widget.min);
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final thumbX = _frac * w;
        return GestureDetector(
          onHorizontalDragUpdate: (d) => _onDrag(d, w),
          onTapDown: (d) => _onDrag(DragUpdateDetails(delta: Offset.zero, localPosition: d.localPosition, globalPosition: d.globalPosition), w),
          child: CustomPaint(
            size: Size(w, 24),
            painter: _SliderPainter(
              thumbX: thumbX,
              trackColor: _EditorStyle.fill,
              strokeColor: _EditorStyle.stroke,
              thumbColor: _EditorStyle.selected,
            ),
          ),
        );
      },
    );
  }
}

class _SliderPainter extends CustomPainter {
  _SliderPainter({required this.thumbX, required this.trackColor, required this.strokeColor, required this.thumbColor});

  final double thumbX;
  final Color trackColor;
  final Color strokeColor;
  final Color thumbColor;

  @override
  void paint(Canvas canvas, Size size) {
    final r = 4.0;
    final track = RRect.fromRectAndRadius(Rect.fromLTWH(0, size.height / 2 - 2, size.width, 4), Radius.circular(r));
    canvas.drawRRect(track, Paint()..color = trackColor);
    canvas.drawRRect(track, Paint()..color = strokeColor..style = PaintingStyle.stroke..strokeWidth = _EditorStyle.strokeWidth);
    canvas.drawCircle(Offset(thumbX, size.height / 2), 10, Paint()..color = thumbColor);
    canvas.drawCircle(Offset(thumbX, size.height / 2), 10, Paint()..color = strokeColor..style = PaintingStyle.stroke..strokeWidth = _EditorStyle.strokeWidth);
  }

  @override
  bool shouldRepaint(covariant _SliderPainter old) => old.thumbX != thumbX;
}

/// Full-screen creature editor: left (or bottom) panel for properties, right (or top) for live preview.
/// Play and Test/Edit buttons are drawn inside the editor (top-right).
class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.initialCreature,
    required this.onPlay,
    required this.panelClosed,
    required this.onTogglePanel,
  });

  final Creature initialCreature;
  final void Function(Creature creature) onPlay;
  final bool panelClosed;
  final VoidCallback onTogglePanel;

  @override
  State<EditorScreen> createState() => EditorScreenState();
}

class EditorScreenState extends State<EditorScreen> {
  late Creature _creature;

  @override
  void initState() {
    super.initState();
    _creature = widget.initialCreature;
  }

  @override
  void didUpdateWidget(covariant EditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCreature != widget.initialCreature) {
      _creature = widget.initialCreature;
    }
  }

  /// Called by shell overlay "Play" to apply and exit with current creature.
  void applyPlay() {
    widget.onPlay(_creature);
  }

  void _updateCreature(Creature c) {
    setState(() => _creature = c);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isPortrait = size.height > size.width;
    // Portrait: stack vertical (preview top, panel bottom). Landscape: row (panel left, preview right).
    // On larger/square devices prioritize view: smaller panel.
    final panelSize = isPortrait
        ? size.height * 0.42
        : (size.width > 600 ? 320.0 : size.width * 0.38);

    final panelClosed = widget.panelClosed;

    Widget panel = _EditorPanel(
      creature: _creature,
      onCreatureChanged: _updateCreature,
      tabIndex: _tabIndex,
      onTabChanged: (i) => setState(() => _tabIndex = i),
      selectedDorsalFinIndex: _selectedDorsalFinIndex,
      onDorsalFinSelected: (i) => setState(() => _selectedDorsalFinIndex = i),
    );

    Widget preview = _EditorPreview(
      key: ValueKey('preview_$panelClosed'),
      creature: _creature,
      editTabIndex: panelClosed ? null : _editorTabIndex,
      panelClosed: panelClosed,
      selectedDorsalFinIndex: _selectedDorsalFinIndex,
      onDorsalFinSelected: (i) => setState(() => _selectedDorsalFinIndex = i),
      onDorsalRangeChanged: _onDorsalRangeFromViewport,
      onDorsalHeightChanged: _onDorsalHeightFromViewport,
      onDorsalAdded: _onDorsalAddedFromViewport,
      onDorsalRemoved: _onDorsalRemovedFromViewport,
      onSegmentCountChanged: _onSegmentCountFromViewport,
      onSegmentWidthDelta: _onSegmentWidthDeltaFromViewport,
      onLateralToggled: _onLateralToggledFromViewport,
      onLateralMoved: _onLateralMovedFromViewport,
      onLateralAdded: _onLateralAddedFromViewport,
      onLateralRemoved: _onLateralRemovedFromViewport,
    );

    Widget content;
    if (panelClosed) {
      content = Stack(
        fit: StackFit.expand,
        children: [Positioned.fill(child: preview)],
      );
    } else {
      content = isPortrait
          ? Column(
              children: [
                Expanded(child: preview),
                SizedBox(height: panelSize, child: panel),
              ],
            )
          : Row(
              children: [
                SizedBox(width: panelSize, child: panel),
                Expanded(child: preview),
              ],
            );
    }

    return SafeArea(
      top: !panelClosed,
      bottom: !panelClosed,
      left: !panelClosed,
      right: !panelClosed,
      child: Stack(
        fit: StackFit.expand,
        children: [
          content,
          Positioned(
            top: 10,
            right: 10,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _editorTopButton(label: 'Play', onTap: () => widget.onPlay(_creature)),
                const SizedBox(height: 8),
                _editorTopButton(
                  label: panelClosed ? 'Edit' : 'Test',
                  onTap: widget.onTogglePanel,
                  selected: !panelClosed,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _editorTopButton({
    required String label,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _EditorStyle.selected : _EditorStyle.fill,
          borderRadius: BorderRadius.circular(_EditorStyle.radius),
          border: Border.all(color: _EditorStyle.stroke, width: _EditorStyle.strokeWidth),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: _EditorStyle.text,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  int get _tabIndex => _editorTabIndex;
  set _tabIndex(int v) => _editorTabIndex = v;
  int _editorTabIndex = 0;
  int? _selectedDorsalFinIndex;

  void _onDorsalRangeFromViewport(int start, int end) {
    final fins = List<(List<int>, double?)>.from(_creature.dorsalFins ?? []);
    if (_selectedDorsalFinIndex == null || _selectedDorsalFinIndex! >= fins.length) return;
    final segs = [for (var i = start; i <= end; i++) i];
    fins[_selectedDorsalFinIndex!] = (segs, fins[_selectedDorsalFinIndex!].$2);
    setState(() => _creature = Creature(
      vertexWidths: _creature.vertexWidths,
      color: _creature.color,
      dorsalFins: fins,
      finColor: _creature.finColor,
      tailFin: _creature.tailFin,
      lateralFins: _creature.lateralFins,
    ));
  }

  void _onDorsalHeightFromViewport(double? height) {
    final fins = List<(List<int>, double?)>.from(_creature.dorsalFins ?? []);
    if (_selectedDorsalFinIndex == null || _selectedDorsalFinIndex! >= fins.length) return;
    final f = fins[_selectedDorsalFinIndex!];
    fins[_selectedDorsalFinIndex!] = (f.$1, height);
    setState(() => _creature = Creature(
      vertexWidths: _creature.vertexWidths,
      color: _creature.color,
      dorsalFins: fins,
      finColor: _creature.finColor,
      tailFin: _creature.tailFin,
      lateralFins: _creature.lateralFins,
    ));
  }

  void _onDorsalAddedFromViewport(int seg) {
    final segCount = _creature.segmentCount;
    if (segCount < 3) return;
    final start = (seg + 2 <= segCount - 1) ? seg : (segCount - 3).clamp(0, segCount - 1);
    final segs = [start, start + 1, start + 2];
    final fins = List<(List<int>, double?)>.from(_creature.dorsalFins ?? []);
    fins.add((segs, kDorsalHeightMedium));
    setState(() => _creature = Creature(
      vertexWidths: _creature.vertexWidths,
      color: _creature.color,
      dorsalFins: fins,
      finColor: _creature.finColor,
      tailFin: _creature.tailFin,
      lateralFins: _creature.lateralFins,
    ));
    _selectedDorsalFinIndex = fins.length - 1;
  }

  void _onSegmentCountFromViewport(int newCount) {
    newCount = newCount.clamp(1, Creature.maxSegmentCount);
    final current = _creature.segmentCount;
    if (newCount == current) return;
    var w = List<double>.from(_creature.vertexWidths);
    if (newCount > current) {
      // Add segments at tail: insert new vertex width at start (tail end of list)
      final tailW = w.isEmpty ? 20.0 : w.first;
      final clamped = tailW.clamp(Creature.minVertexWidth, Creature.maxVertexWidth);
      for (var i = current; i < newCount; i++) w.insert(0, clamped);
    } else {
      // Remove segments from tail: drop first (current - newCount) vertices
      w = w.sublist(current - newCount);
    }
    setState(() => _creature = _creatureWith(_creature, vertexWidths: w, newSegmentCount: newCount, filterDorsalLateral: true));
  }

  void _onSegmentWidthDeltaFromViewport(int seg, double delta) {
    final w = List<double>.from(_creature.vertexWidths);
    if (seg < 0 || seg >= w.length - 1) return;
    final minW = Creature.minVertexWidth;
    final maxW = Creature.maxVertexWidth;
    w[seg] = (w[seg] + delta).clamp(minW, maxW);
    w[seg + 1] = (w[seg + 1] + delta).clamp(minW, maxW);
    setState(() => _creature = _creatureWith(_creature, vertexWidths: w));
  }

  void _onDorsalRemovedFromViewport(int finIndex) {
    final fins = List<(List<int>, double?)>.from(_creature.dorsalFins ?? []);
    if (finIndex < 0 || finIndex >= fins.length) return;
    fins.removeAt(finIndex);
    setState(() {
      _creature = Creature(
        vertexWidths: _creature.vertexWidths,
        color: _creature.color,
        dorsalFins: fins.isEmpty ? null : fins,
        finColor: _creature.finColor,
        tailFin: _creature.tailFin,
        lateralFins: _creature.lateralFins,
      );
      _selectedDorsalFinIndex = null;
    });
  }

  void _onLateralToggledFromViewport(int seg) {
    final list = List<int>.from(_creature.lateralFins ?? []);
    if (list.contains(seg)) list.remove(seg); else list.add(seg);
    list.sort();
    setState(() => _creature = Creature(
      vertexWidths: _creature.vertexWidths,
      color: _creature.color,
      dorsalFins: _creature.dorsalFins,
      finColor: _creature.finColor,
      tailFin: _creature.tailFin,
      lateralFins: list.isEmpty ? null : list,
    ));
  }

  void _onLateralMovedFromViewport(int fromSeg, int toSeg) {
    final list = List<int>.from(_creature.lateralFins ?? []);
    final idx = list.indexOf(fromSeg);
    if (idx < 0) return;
    list[idx] = toSeg;
    list.sort();
    setState(() => _creature = Creature(
      vertexWidths: _creature.vertexWidths,
      color: _creature.color,
      dorsalFins: _creature.dorsalFins,
      finColor: _creature.finColor,
      tailFin: _creature.tailFin,
      lateralFins: list,
    ));
  }

  void _onLateralAddedFromViewport(int seg) {
    final list = List<int>.from(_creature.lateralFins ?? []);
    if (list.contains(seg)) return;
    list.add(seg);
    list.sort();
    setState(() => _creature = Creature(
      vertexWidths: _creature.vertexWidths,
      color: _creature.color,
      dorsalFins: _creature.dorsalFins,
      finColor: _creature.finColor,
      tailFin: _creature.tailFin,
      lateralFins: list,
    ));
  }

  void _onLateralRemovedFromViewport(int seg) {
    final list = List<int>.from(_creature.lateralFins ?? []);
    list.remove(seg);
    setState(() => _creature = Creature(
      vertexWidths: _creature.vertexWidths,
      color: _creature.color,
      dorsalFins: _creature.dorsalFins,
      finColor: _creature.finColor,
      tailFin: _creature.tailFin,
      lateralFins: list.isEmpty ? null : list,
    ));
  }
}

/// Left/bottom panel: custom tab row + content (no Material). Play is top-right only.
class _EditorPanel extends StatelessWidget {
  const _EditorPanel({
    required this.creature,
    required this.onCreatureChanged,
    required this.tabIndex,
    required this.onTabChanged,
    required this.selectedDorsalFinIndex,
    required this.onDorsalFinSelected,
  });

  final Creature creature;
  final void Function(Creature) onCreatureChanged;
  final int tabIndex;
  final void Function(int) onTabChanged;
  final int? selectedDorsalFinIndex;
  final void Function(int?) onDorsalFinSelected;

  static const List<String> _tabs = ['Body', 'Colour', 'Fins'];

  static const double _panelMargin = 12.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(_panelMargin),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(_EditorStyle.radius),
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
                        color: selected ? _EditorStyle.selected : _EditorStyle.fill,
                        borderRadius: BorderRadius.circular(_EditorStyle.radius),
                        border: Border.all(color: _EditorStyle.stroke, width: _EditorStyle.strokeWidth),
                      ),
                      child: Text(
                        _tabs[i],
                        style: TextStyle(
                          color: _EditorStyle.text,
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
    final current = creature.tailFin;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('Body length', style: TextStyle(color: _EditorStyle.text, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('Drag the tail node in the view to change segment count.', style: TextStyle(fontSize: 12, color: _EditorStyle.textMuted)),
        const SizedBox(height: 16),
        Text('Tail (caudal) fin — tap to select', style: TextStyle(color: _EditorStyle.text, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _TailBox(
              creature: creature,
              tailFin: null,
              selected: current == null,
              onTap: () => _setTail(creature, null),
            ),
            ...CaudalFinType.values.map((e) => _TailBox(
              creature: creature,
              tailFin: e,
              selected: current == e,
              onTap: () => _setTail(creature, e),
            )),
          ],
        ),
      ],
    );
  }

  void _setTail(Creature c, CaudalFinType? v) {
    onCreatureChanged(Creature(
      vertexWidths: c.vertexWidths,
      color: c.color,
      dorsalFins: c.dorsalFins,
      finColor: c.finColor,
      tailFin: v,
      lateralFins: c.lateralFins,
    ));
  }
}

Creature _creatureWith(Creature creature, {
  List<double>? vertexWidths,
  int? color,
  bool filterDorsalLateral = false,
  int? newSegmentCount,
}) {
  final seg = newSegmentCount ?? (vertexWidths?.length ?? creature.vertexWidths.length) - 1;
  List<(List<int>, double?)>? dorsal = creature.dorsalFins;
  List<int>? lateral = creature.lateralFins;
  if (filterDorsalLateral && seg >= 1) {
    dorsal = _filterDorsalForSegmentCount(creature.dorsalFins, seg);
    lateral = _filterLateralForSegmentCount(creature.lateralFins, seg);
  }
  return Creature(
    vertexWidths: vertexWidths ?? creature.vertexWidths,
    color: color ?? creature.color,
    dorsalFins: dorsal,
    finColor: creature.finColor,
    tailFin: creature.tailFin,
    lateralFins: lateral,
  );
}

List<(List<int>, double?)>? _filterDorsalForSegmentCount(List<(List<int>, double?)>? fins, int segCount) {
  if (fins == null || fins.isEmpty) return fins;
  final out = <(List<int>, double?)>[];
  for (final f in fins) {
    final list = f.$1.where((s) => s >= 0 && s < segCount).toList();
    if (list.isNotEmpty && list.length == f.$1.length) out.add((list, f.$2));
  }
  return out.isEmpty ? null : out;
}

List<int>? _filterLateralForSegmentCount(List<int>? indices, int segCount) {
  if (indices == null) return null;
  final out = indices.where((i) => i >= 0 && i < segCount).toList();
  return out.isEmpty ? null : out;
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
                        color: !_editingFin ? _EditorStyle.selected : _EditorStyle.fill,
                        borderRadius: BorderRadius.circular(_EditorStyle.radius),
                        border: Border.all(color: _EditorStyle.stroke, width: _EditorStyle.strokeWidth),
                      ),
                      child: Center(child: Text('Body', style: TextStyle(color: _EditorStyle.text, fontSize: 13))),
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
                        color: _editingFin ? _EditorStyle.selected : _EditorStyle.fill,
                        borderRadius: BorderRadius.circular(_EditorStyle.radius),
                        border: Border.all(color: _EditorStyle.stroke, width: _EditorStyle.strokeWidth),
                      ),
                      child: Center(child: Text('Fin', style: TextStyle(color: _EditorStyle.text, fontSize: 13))),
                    ),
                  ),
                ),
              ],
            ),
            if (_editingFin && creature.finColor == null) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => widget.onCreatureChanged(Creature(
                  vertexWidths: creature.vertexWidths,
                  color: creature.color,
                  dorsalFins: creature.dorsalFins,
                  finColor: creature.color,
                  tailFin: creature.tailFin,
                  lateralFins: creature.lateralFins,
                )),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _EditorStyle.fill,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _EditorStyle.stroke),
                  ),
                  child: Center(child: Text('Use custom fin colour', style: TextStyle(color: _EditorStyle.textMuted, fontSize: 12))),
                ),
              ),
            ],
            const SizedBox(height: 12),
            _HSVPicker(
              color: color,
              onChanged: (c) {
                final value = 0xFF000000 | (c.value & 0xFFFFFF);
                widget.onCreatureChanged(Creature(
                  vertexWidths: creature.vertexWidths,
                  color: _editingFin ? creature.color : value,
                  dorsalFins: creature.dorsalFins,
                  finColor: _editingFin ? value : creature.finColor,
                  tailFin: creature.tailFin,
                  lateralFins: creature.lateralFins,
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

/// One tail option: real tail via [paintTailFin] with creature colours and minimal spine.
class _TailBox extends StatelessWidget {
  const _TailBox({required this.creature, required this.tailFin, required this.selected, required this.onTap});

  final Creature creature;
  final CaudalFinType? tailFin;
  final bool selected;
  final void Function() onTap;

  static const double _boxW = 52;
  static const double _boxH = 36;
  static const double _tailWorldLeft = -25.0;
  static const double _tailLength = 60.0;
  static const double _zoom = 0.87;
  static double get _tailCenterWorld => _tailWorldLeft - _tailLength / 2;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _boxW,
        height: _boxH,
        decoration: BoxDecoration(
          color: _EditorStyle.fill,
          borderRadius: BorderRadius.circular(_EditorStyle.radius),
          border: Border.all(
            color: selected ? _EditorStyle.text : _EditorStyle.stroke,
            width: selected ? 2 : _EditorStyle.strokeWidth,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_EditorStyle.radius),
          child: CustomPaint(
            painter: _TailPreviewPainter(
              creature: creature,
              tailFin: tailFin,
            ),
            size: const Size(_boxW, _boxH),
          ),
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
      canvas.drawCircle(Offset(centerX, centerY), 8, Paint()..color = _EditorStyle.stroke..style = PaintingStyle.stroke..strokeWidth = 1);
      return;
    }
    final minimal = Creature(
      vertexWidths: [20.0, 25.0],
      color: creature.color,
      finColor: creature.finColor,
      tailFin: tailFin,
    );
    final positions = [
      Vector2(_TailBox._tailWorldLeft, 0),
      Vector2(_TailBox._tailWorldLeft + 10, 0),
      Vector2(_TailBox._tailWorldLeft + 20, 0),
    ];
    const segmentAngles = [0.0, 0.0];
    double widthAt(int i) {
      if (i < minimal.vertexWidths.length) return minimal.vertexWidths[i].clamp(Creature.minVertexWidth, Creature.maxVertexWidth);
      return 20.0;
    }
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

/// Dorsal height presets (world units). null = renderer default.
const double? kDorsalHeightDefault = null;
const double kDorsalHeightSmall = 8.0;
const double kDorsalHeightMedium = 14.0;
const double kDorsalHeightLarge = 22.0;

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
    canvas.drawPath(path, Paint()..color = _EditorStyle.stroke..style = PaintingStyle.stroke..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(covariant _DorsalPreviewPainter old) =>
      old.bodyColor != bodyColor || old.finColor != finColor;
}

/// Small lateral fin preview (two ellipses) for the + lat button.
class _LateralPreviewPainter extends CustomPainter {
  _LateralPreviewPainter({required this.bodyColor, this.finColor});

  final Color bodyColor;
  final Color? finColor;

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
    final rect = Rect.fromCenter(center: Offset.zero, width: len, height: wid);
    final offset = size.width * 0.18;
    canvas.save();
    canvas.translate(cx - offset, cy);
    canvas.rotate(flareRad);
    canvas.drawOval(rect, fill);
    canvas.drawOval(rect, stroke);
    canvas.restore();
    canvas.save();
    canvas.translate(cx + offset, cy);
    canvas.rotate(-flareRad);
    canvas.drawOval(rect, fill);
    canvas.drawOval(rect, stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LateralPreviewPainter old) =>
      old.bodyColor != bodyColor || old.finColor != finColor;
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
                strokeColor: _EditorStyle.stroke,
                fillColor: _EditorStyle.fill,
                selectedColor: _EditorStyle.selected,
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

/// Fins tab: dorsal and lateral add buttons (small, like tail); both on one page.
class _FinsTab extends StatelessWidget {
  const _FinsTab({
    required this.creature,
    required this.onCreatureChanged,
    required this.selectedDorsalFinIndex,
    required this.onDorsalFinSelected,
  });

  final Creature creature;
  final void Function(Creature) onCreatureChanged;
  final int? selectedDorsalFinIndex;
  final void Function(int?)? onDorsalFinSelected;

  static const double _boxW = 52;
  static const double _boxH = 36;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('Fins — drag to add; tap in view to select or edit.', style: TextStyle(color: _EditorStyle.text, fontWeight: FontWeight.w600, fontSize: 12)),
        const SizedBox(height: 12),
        Text('Dorsal', style: TextStyle(color: _EditorStyle.text, fontWeight: FontWeight.w600, fontSize: 12)),
        Text('Drag to creature to add. Tap a fin in view to select; drag nodes to adjust or drag fin off to remove.', style: TextStyle(fontSize: 11, color: _EditorStyle.textMuted)),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Draggable<_DorsalDragPayload>(
              data: _DorsalDragPayload(),
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
                        color: _EditorStyle.selected.withValues(alpha: 0.9),
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
        const SizedBox(height: 16),
        Text('Lateral', style: TextStyle(color: _EditorStyle.text, fontWeight: FontWeight.w600, fontSize: 12)),
        Text('Drag to creature to add. Drag a fin in view to move; drag off creature to remove.', style: TextStyle(fontSize: 11, color: _EditorStyle.textMuted)),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Draggable<_LateralDragPayload>(
              data: _LateralDragPayload(),
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
                    ),
                    size: const Size(_boxW, _boxH),
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.5,
                child: _lateralBox(),
              ),
              child: _lateralBox(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _dorsalBox() {
    return Container(
      width: _boxW,
      height: _boxH,
      decoration: BoxDecoration(
        color: _EditorStyle.fill,
        borderRadius: BorderRadius.circular(_EditorStyle.radius),
        border: Border.all(color: _EditorStyle.stroke, width: _EditorStyle.strokeWidth),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_EditorStyle.radius),
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

  Widget _lateralBox() {
    return Container(
      width: _boxW,
      height: _boxH,
      decoration: BoxDecoration(
        color: _EditorStyle.fill,
        borderRadius: BorderRadius.circular(_EditorStyle.radius),
        border: Border.all(color: _EditorStyle.stroke, width: _EditorStyle.strokeWidth),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_EditorStyle.radius),
        child: CustomPaint(
          painter: _LateralPreviewPainter(
            bodyColor: Color(creature.color),
            finColor: creature.finColor != null ? Color(creature.finColor!) : null,
          ),
          size: const Size(_boxW, _boxH),
        ),
      ),
    );
  }
}

class _LateralDragPayload {}
class _DorsalDragPayload {}

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
class _EditorPreview extends StatefulWidget {
  const _EditorPreview({
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
  final void Function(int seg)? onLateralToggled;
  final void Function(int fromSeg, int toSeg)? onLateralMoved;
  final void Function(int seg)? onLateralAdded;
  final void Function(int seg)? onLateralRemoved;

  @override
  State<_EditorPreview> createState() => _EditorPreviewState();
}

class _EditorPreviewState extends State<_EditorPreview> with SingleTickerProviderStateMixin {
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
  void didUpdateWidget(covariant _EditorPreview oldWidget) {
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

        Rect _finRemoveBounds() => creatureScreenBounds().inflate(_kFinRemoveMargin);

        bool _isTapOnDorsalFin(double px, double py) {
          final fins = widget.creature.dorsalFins ?? [];
          final sel = widget.selectedDorsalFinIndex;
          if (sel == null || sel >= fins.length || positions.length < 2) return false;
          final range = fins[sel].$1;
          if (range.isEmpty) return false;
          final r2 = _kDorsalGrabRadius * _kDorsalGrabRadius;
          for (var seg = range.first; seg <= range.last && seg < positions.length - 1; seg++) {
            final cx = (positions[seg].x + positions[seg + 1].x) / 2;
            final cy = (positions[seg].y + positions[seg + 1].y) / 2;
            final sx = centerX + (cx - cameraX) * _zoom;
            final sy = centerY + (cy - cameraY) * _zoom;
            if ((px - sx) * (px - sx) + (py - sy) * (py - sy) <= r2) return true;
          }
          return false;
        }

        int? _dorsalFinIndexAtScreen(double px, double py) {
          final fins = widget.creature.dorsalFins ?? [];
          if (fins.isEmpty || positions.length < 2) return null;
          final r2 = _kDorsalGrabRadius * _kDorsalGrabRadius;
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
          final r2 = _kLateralGrabRadius * _kLateralGrabRadius;
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

        Widget stackContent = Stack(
          key: _previewKey,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: SolidBackgroundPainter(color: _kEditorBackground),
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
                    } else if (isDorsalEdit && widget.selectedDorsalFinIndex != null) {
                      final node = _hitDorsalNode(lx, ly);
                      if (node != null) {
                        _dorsalDraggingNode = node;
                      } else if (_isTapOnDorsalFin(lx, ly)) {
                        _dorsalDragFromFin = true;
                      }
                    } else if (isLateralEdit) {
                      final seg = segmentAtScreen(lx, ly);
                      final lateralSeg = _lateralSegNearScreen(lx, ly);
                      _lateralPanStartSeg = lateralSeg ?? seg;
                      if (widget.onLateralMoved != null && lateralSeg != null) _lateralDragFromSeg = lateralSeg;
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
                  if (_bodyDraggingNode != null && widget.onSegmentCountChanged != null) {
                    widget.onSegmentCountChanged!(_segmentCountFromTailDrag(centerX, centerY, cameraX, cameraY, positions));
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
                        widget.onDorsalFinSelected!(dorsalFound);
                        setState(() {});
                        return;
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
        Widget finContent = stackContent;
        if (editTab == 2 && widget.onLateralAdded != null) {
          finContent = DragTarget<_LateralDragPayload>(
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
            builder: (context, candidateData, rejectedData) => stackContent,
          );
        }
        if (editTab == 2 && widget.onDorsalAdded != null) {
          return DragTarget<_DorsalDragPayload>(
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
            builder: (context, candidateData, rejectedData) => finContent,
          );
        }
        if (isLateralEdit && widget.onLateralAdded != null) {
          return DragTarget<_LateralDragPayload>(
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
            builder: (context, candidateData, rejectedData) => stackContent,
          );
        }
        return stackContent;
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
