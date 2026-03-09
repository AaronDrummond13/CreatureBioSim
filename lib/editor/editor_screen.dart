import 'package:flutter/material.dart';

import 'package:creature_bio_sim/creature.dart';
import 'package:creature_bio_sim/editor/editor_panel.dart';
import 'package:creature_bio_sim/editor/editor_preview.dart';
import 'package:creature_bio_sim/editor/editor_style.dart';

/// Full-screen creature editor: left (or bottom) panel for properties, right (or top) for live preview.
/// Play and Test/Edit buttons are drawn inside the editor (top-right).
class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.initialCreature,
    required this.onPlay,
  });

  final Creature initialCreature;
  final void Function(Creature creature) onPlay;

  @override
  State<EditorScreen> createState() => EditorScreenState();
}

class EditorScreenState extends State<EditorScreen> {
  late Creature _creature;
  bool _panelClosed = false;

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
    final panelSize = isPortrait
        ? size.height * 0.42
        : (size.width > 600 ? 320.0 : size.width * 0.38);

    Widget panel = EditorPanel(
      creature: _creature,
      onCreatureChanged: _updateCreature,
      tabIndex: _tabIndex,
      onTabChanged: (i) => setState(() => _tabIndex = i),
      selectedDorsalFinIndex: _selectedDorsalFinIndex,
      onDorsalFinSelected: (i) => setState(() => _selectedDorsalFinIndex = i),
    );

    Widget preview = EditorPreview(
      key: ValueKey('preview_$_panelClosed'),
      creature: _creature,
      editTabIndex: _panelClosed ? null : _editorTabIndex,
      panelClosed: _panelClosed,
      selectedDorsalFinIndex: _selectedDorsalFinIndex,
      onDorsalFinSelected: (i) => setState(() => _selectedDorsalFinIndex = i),
      onDorsalRangeChanged: _onDorsalRangeFromViewport,
      onDorsalHeightChanged: _onDorsalHeightFromViewport,
      onDorsalAdded: _onDorsalAddedFromViewport,
      onDorsalRemoved: _onDorsalRemovedFromViewport,
      onSegmentCountChanged: _onSegmentCountFromViewport,
      onSegmentWidthDelta: _onSegmentWidthDeltaFromViewport,
      onTailRootWidthChanged: _onTailRootWidthFromViewport,
      onTailMaxWidthChanged: _onTailMaxWidthFromViewport,
      onTailLengthChanged: _onTailLengthFromViewport,
      onTailAdded: _onTailAddedFromViewport,
      onTailRemoved: _onTailRemovedFromViewport,
      onLateralToggled: _onLateralToggledFromViewport,
      onLateralMoved: _onLateralMovedFromViewport,
      onLateralAdded: _onLateralAddedFromViewport,
      onLateralRemoved: _onLateralRemovedFromViewport,
    );

    Widget content;
    if (_panelClosed) {
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
                  label: _panelClosed ? 'Edit' : 'Test',
                  onTap: () => setState(() => _panelClosed = !_panelClosed),
                  selected: !_panelClosed,
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
          color: selected ? EditorStyle.selected : EditorStyle.fill,
          borderRadius: BorderRadius.circular(EditorStyle.radius),
          border: Border.all(color: EditorStyle.stroke, width: EditorStyle.strokeWidth),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: EditorStyle.text,
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
      tail: _creature.tail,
      lateralFins: _creature.lateralFins,
      trophicType: _creature.trophicType,
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
      tail: _creature.tail,
      lateralFins: _creature.lateralFins,
      trophicType: _creature.trophicType,
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
      tail: _creature.tail,
      lateralFins: _creature.lateralFins,
      trophicType: _creature.trophicType,
    ));
    _selectedDorsalFinIndex = fins.length - 1;
  }

  void _onSegmentCountFromViewport(int newCount) {
    newCount = newCount.clamp(1, Creature.maxSegmentCount);
    final current = _creature.segmentCount;
    if (newCount == current) return;
    var w = List<double>.from(_creature.vertexWidths);
    if (newCount > current) {
      final tailW = w.isEmpty ? 20.0 : w.first;
      final clamped = tailW.clamp(Creature.minVertexWidth, Creature.maxVertexWidth);
      for (var i = current; i < newCount; i++) w.insert(0, clamped);
    } else {
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
        tail: _creature.tail,
        lateralFins: _creature.lateralFins,
        trophicType: _creature.trophicType,
      );
      _selectedDorsalFinIndex = null;
    });
  }

  void _onTailRootWidthFromViewport(double value) {
    final v = value.clamp(TailConfig.rootWidthMin, TailConfig.rootWidthMax);
    setState(() => _creature = Creature(
      vertexWidths: _creature.vertexWidths,
      color: _creature.color,
      dorsalFins: _creature.dorsalFins,
      finColor: _creature.finColor,
      tail: _creature.tail?.copyWith(rootWidth: v),
      lateralFins: _creature.lateralFins,
      trophicType: _creature.trophicType,
    ));
  }

  void _onTailMaxWidthFromViewport(double value) {
    final v = value.clamp(TailConfig.maxWidthMin, TailConfig.maxWidthMax);
    setState(() => _creature = Creature(
      vertexWidths: _creature.vertexWidths,
      color: _creature.color,
      dorsalFins: _creature.dorsalFins,
      finColor: _creature.finColor,
      tail: _creature.tail?.copyWith(maxWidth: v),
      lateralFins: _creature.lateralFins,
      trophicType: _creature.trophicType,
    ));
  }

  void _onTailLengthFromViewport(double value) {
    final v = value.clamp(TailConfig.lengthMin, TailConfig.lengthMax);
    setState(() => _creature = Creature(
      vertexWidths: _creature.vertexWidths,
      color: _creature.color,
      dorsalFins: _creature.dorsalFins,
      finColor: _creature.finColor,
      tail: _creature.tail?.copyWith(length: v),
      lateralFins: _creature.lateralFins,
      trophicType: _creature.trophicType,
    ));
  }

  void _onTailAddedFromViewport(CaudalFinType? type) {
    setState(() => _creature = Creature(
      vertexWidths: _creature.vertexWidths,
      color: _creature.color,
      dorsalFins: _creature.dorsalFins,
      finColor: _creature.finColor,
      tail: type != null
          ? TailConfig(
              type,
              rootWidth: _creature.tail?.rootWidth ?? 12.0,
              maxWidth: _creature.tail?.maxWidth ?? 20.0,
              length: _creature.tail?.length ?? 90.0,
            )
          : null,
      lateralFins: _creature.lateralFins,
      trophicType: _creature.trophicType,
    ));
  }

  void _onTailRemovedFromViewport() {
    setState(() => _creature = Creature(
      vertexWidths: _creature.vertexWidths,
      color: _creature.color,
      dorsalFins: _creature.dorsalFins,
      finColor: _creature.finColor,
      tail: null,
      lateralFins: _creature.lateralFins,
      trophicType: _creature.trophicType,
    ));
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
      tail: _creature.tail,
      lateralFins: list.isEmpty ? null : list,
      trophicType: _creature.trophicType,
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
      tail: _creature.tail,
      lateralFins: list,
      trophicType: _creature.trophicType,
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
      tail: _creature.tail,
      lateralFins: list,
      trophicType: _creature.trophicType,
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
      tail: _creature.tail,
      lateralFins: list.isEmpty ? null : list,
      trophicType: _creature.trophicType,
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
    tail: creature.tail,
    lateralFins: lateral,
    trophicType: creature.trophicType,
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
