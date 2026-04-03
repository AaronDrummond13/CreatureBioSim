import 'package:bioism/ui/edit_button.dart';
import 'package:flutter/material.dart';

import 'package:bioism/creature.dart';
import 'package:bioism/dorsal_fin_rules.dart';
import 'package:bioism/editor/editor_panel/editor_panel.dart';
import 'package:bioism/editor/editor_preview/editor_preview.dart';
import 'package:bioism/editor/editor_style.dart';

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
      onTabChanged: (i) => setState(() {
        _tabIndex = i;
        _selectedDorsalFinIndex = null;
        _selectedLateralFinIndex = null;
        _selectedAntennaeIndex = null;
        _selectedEyeIndex = null;
        _selectedMouth = false;
      }),
      selectedDorsalFinIndex: _selectedDorsalFinIndex,
      onDorsalFinSelected: (i) => setState(() => _selectedDorsalFinIndex = i),
      selectedLateralFinIndex: _selectedLateralFinIndex,
      onLateralRemoved: _onLateralRemovedFromViewport,
      selectedAntennaeIndex: _selectedAntennaeIndex,
      onAntennaeRemoved: _onAntennaeRemovedFromViewport,
    );

    Widget preview = EditorPreview(
      key: ValueKey('preview_$_panelClosed'),
      creature: _creature,
      editTabIndex: _panelClosed ? null : _editorTabIndex,
      panelClosed: _panelClosed,
      selectedDorsalFinIndex: _selectedDorsalFinIndex,
      onDorsalFinSelected: (i) => setState(() {
        _selectedDorsalFinIndex = i;
        if (i != null) _selectedLateralFinIndex = null;
        if (i != null) _selectedMouth = false;
      }),
      selectedLateralFinIndex: _selectedLateralFinIndex,
      selectedAntennaeIndex: _selectedAntennaeIndex,
      onLateralFinSelected: _onLateralFinSelectedFromViewport,
      onLateralLengthChanged: _onLateralLengthChangedFromViewport,
      onLateralWidthChanged: _onLateralWidthChangedFromViewport,
      onLateralAngleChanged: _onLateralAngleChangedFromViewport,
      onAntennaeSelected: _onAntennaeSelectedFromViewport,
      onAntennaeLengthChanged: _onAntennaeLengthChangedFromViewport,
      onAntennaeWidthChanged: _onAntennaeWidthChangedFromViewport,
      onAntennaeAngleChanged: _onAntennaeAngleChangedFromViewport,
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
      onAntennaeToggled: _onAntennaeToggledFromViewport,
      onAntennaeMoved: _onAntennaeMovedFromViewport,
      onAntennaeAdded: _onAntennaeAddedFromViewport,
      onAntennaeRemoved: _onAntennaeRemovedFromViewport,
      onMouthAdded: _onMouthAddedFromViewport,
      onMouthRemoved: _onMouthRemovedFromViewport,
      onMouthLengthChanged: _onMouthLengthChangedFromViewport,
      onMouthCurveChanged: _onMouthCurveChangedFromViewport,
      onMouthWobbleAmplitudeChanged: _onMouthWobbleAmplitudeChangedFromViewport,
      selectedEyeIndex: _selectedEyeIndex,
      onEyeSelected: (i) => setState(() {
        _selectedEyeIndex = i;
        if (i != null) _selectedDorsalFinIndex = null;
        if (i != null) _selectedLateralFinIndex = null;
        if (i != null) _selectedMouth = false;
      }),
      selectedMouth: _selectedMouth,
      onMouthSelected: (selected) => setState(() => _selectedMouth = selected),
      onEyeAdded: _onEyeAddedFromViewport,
      onEyeRemoved: _onEyeRemovedFromViewport,
      onEyeMoved: _onEyeMovedFromViewport,
      onEyeRadiusChanged: _onEyeRadiusChangedFromViewport,
      onEyePupilFractionChanged: _onEyePupilFractionChangedFromViewport,
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
            top: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                EditButton(onTap: () => widget.onPlay(_creature)),
                const SizedBox(height: 16),
                _editorTopButton(
                  label: _panelClosed ? 'Edit' : 'Test',
                  onTap: () => setState(() {
                    _panelClosed = !_panelClosed;
                    if (_panelClosed) {
                      _selectedDorsalFinIndex = null;
                      _selectedLateralFinIndex = null;
                      _selectedEyeIndex = null;
                      _selectedMouth = false;
                    }
                  }),
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
          border: Border.all(
            color: EditorStyle.stroke,
            width: EditorStyle.strokeWidth,
          ),
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
  int? _selectedLateralFinIndex;
  int? _selectedAntennaeIndex;
  int? _selectedEyeIndex;
  bool _selectedMouth = false;

  void _onDorsalRangeFromViewport(int start, int end) {
    final fins = List<(List<int>, double?)>.from(_creature.dorsalFins ?? []);
    if (_selectedDorsalFinIndex == null ||
        _selectedDorsalFinIndex! >= fins.length)
      return;
    final segCount = _creature.segmentCount;
    if (!dorsalFinCanSetRange(
      fins,
      _selectedDorsalFinIndex!,
      start,
      end,
      segCount,
    ))
      return;
    final segs = [for (var i = start; i <= end; i++) i];
    fins[_selectedDorsalFinIndex!] = (segs, fins[_selectedDorsalFinIndex!].$2);
    setState(
      () => _creature = Creature(
        segmentWidths: _creature.segmentWidths,
        color: _creature.color,
        dorsalFins: fins,
        finColor: _creature.finColor,
        tail: _creature.tail,
        lateralFins: _creature.lateralFins,
        antennae: _creature.antennae,
        trophicType: _creature.trophicType,
        mouth: _creature.mouth,
        mouthCount: _creature.mouthCount,
        mouthLength: _creature.mouthLength,
        mouthCurve: _creature.mouthCurve,
        mouthWobbleAmplitude: _creature.mouthWobbleAmplitude,
        eyes: _creature.eyes,
      ),
    );
  }

  void _onDorsalHeightFromViewport(double? height) {
    final fins = List<(List<int>, double?)>.from(_creature.dorsalFins ?? []);
    if (_selectedDorsalFinIndex == null ||
        _selectedDorsalFinIndex! >= fins.length)
      return;
    final f = fins[_selectedDorsalFinIndex!];
    fins[_selectedDorsalFinIndex!] = (f.$1, height);
    setState(
      () => _creature = Creature(
        segmentWidths: _creature.segmentWidths,
        color: _creature.color,
        dorsalFins: fins,
        antennae: _creature.antennae,
        finColor: _creature.finColor,
        tail: _creature.tail,
        lateralFins: _creature.lateralFins,
        trophicType: _creature.trophicType,
        mouth: _creature.mouth,
        eyes: _creature.eyes,
      ),
    );
  }

  void _onDorsalAddedFromViewport(int seg) {
    final segCount = _creature.segmentCount;
    if (segCount < dorsalFinMinSegments) return;
    final fins = List<(List<int>, double?)>.from(_creature.dorsalFins ?? []);
    final len = dorsalFinMinSegments;
    var added = false;
    for (var offset = 0; offset <= len && !added; offset++) {
      final start = (seg - offset).clamp(0, segCount - len);
      final end = start + len - 1;
      if (end < seg || start > seg) continue;
      if (!dorsalFinCanAdd(fins, start, end, segCount)) continue;
      final segs = [for (var i = start; i <= end; i++) i];
      fins.add((segs, kDorsalHeightMedium));
      added = true;
    }
    if (!added) return;
    setState(
      () => _creature = Creature(
        segmentWidths: _creature.segmentWidths,
        color: _creature.color,
        dorsalFins: fins,
        finColor: _creature.finColor,
        tail: _creature.tail,
        lateralFins: _creature.lateralFins,
        antennae: _creature.antennae,
        trophicType: _creature.trophicType,
        mouth: _creature.mouth,
        eyes: _creature.eyes,
      ),
    );
    _selectedDorsalFinIndex = fins.length - 1;
  }

  void _onSegmentCountFromViewport(int newCount) {
    newCount = newCount.clamp(1, Creature.maxSegmentCount);
    final current = _creature.segmentCount;
    if (newCount == current) return;
    var w = List<double>.from(_creature.segmentWidths);
    final delta = newCount - current;
    if (delta > 0) {
      // Add segments at tail so head/eyes/fins stay put; new segments get tail width.
      final tailSegW = w.isEmpty ? 20.0 : w.first;
      final clamped = tailSegW.clamp(
        Creature.minVertexWidth,
        Creature.maxVertexWidth,
      );
      for (var i = current; i < newCount; i++) w.insert(0, clamped);
    } else {
      w = w.sublist(-delta);
    }
    // Offset all segment indices so attachments stay at same spine position.
    List<(List<int>, double?)>? dorsal = _creature.dorsalFins
        ?.map((f) => (f.$1.map((s) => s + delta).toList(), f.$2))
        .toList();
    List<LateralFinConfig>? lateral = _creature.lateralFins
        ?.map((c) => c.copyWith(segment: c.segment + delta))
        .toList();
    List<AntennaeConfig>? antennae = _creature.antennae
        ?.map((c) => c.copyWith(segment: c.segment + delta))
        .toList();
    List<EyeConfig>? eyes = _creature.eyes
        ?.map((e) => e.copyWith(segment: e.segment + delta))
        .toList();
    setState(
      () => _creature = _creatureWith(
        _creature,
        segmentWidths: w,
        newSegmentCount: newCount,
        dorsalFins: dorsal,
        lateralFins: lateral,
        antennae: antennae,
        eyes: eyes,
        filterDorsalLateral: true,
      ),
    );
  }

  void _onSegmentWidthDeltaFromViewport(int seg, double delta) {
    final w = List<double>.from(_creature.segmentWidths);
    if (seg < 0 || seg >= w.length) return;
    final minW = Creature.minVertexWidth;
    final maxW = Creature.maxVertexWidth;
    w[seg] = (w[seg] + delta).clamp(minW, maxW);
    setState(() => _creature = _creatureWith(_creature, segmentWidths: w));
  }

  void _onDorsalRemovedFromViewport(int finIndex) {
    final fins = List<(List<int>, double?)>.from(_creature.dorsalFins ?? []);
    if (finIndex < 0 || finIndex >= fins.length) return;
    fins.removeAt(finIndex);
    setState(() {
      _creature = Creature(
        segmentWidths: _creature.segmentWidths,
        color: _creature.color,
        dorsalFins: fins.isEmpty ? null : fins,
        finColor: _creature.finColor,
        tail: _creature.tail,
        lateralFins: _creature.lateralFins,
        antennae: _creature.antennae,
        trophicType: _creature.trophicType,
        mouth: _creature.mouth,
        mouthCount: _creature.mouthCount,
        mouthLength: _creature.mouthLength,
        mouthCurve: _creature.mouthCurve,
        mouthWobbleAmplitude: _creature.mouthWobbleAmplitude,
        eyes: _creature.eyes,
      );
      _selectedDorsalFinIndex = null;
    });
  }

  void _onTailRootWidthFromViewport(double value) {
    final v = value.clamp(TailConfig.rootWidthMin, TailConfig.rootWidthMax);
    setState(
      () => _creature = Creature(
        segmentWidths: _creature.segmentWidths,
        color: _creature.color,
        dorsalFins: _creature.dorsalFins,
        finColor: _creature.finColor,
        tail: _creature.tail?.copyWith(rootWidth: v),
        lateralFins: _creature.lateralFins,
        antennae: _creature.antennae,
        trophicType: _creature.trophicType,
        mouth: _creature.mouth,
        mouthCount: _creature.mouthCount,
        mouthLength: _creature.mouthLength,
        mouthCurve: _creature.mouthCurve,
        mouthWobbleAmplitude: _creature.mouthWobbleAmplitude,
        eyes: _creature.eyes,
      ),
    );
  }

  void _onTailMaxWidthFromViewport(double value) {
    final v = value.clamp(TailConfig.maxWidthMin, TailConfig.maxWidthMax);
    setState(
      () => _creature = Creature(
        segmentWidths: _creature.segmentWidths,
        color: _creature.color,
        dorsalFins: _creature.dorsalFins,
        finColor: _creature.finColor,
        tail: _creature.tail?.copyWith(maxWidth: v),
        lateralFins: _creature.lateralFins,
        antennae: _creature.antennae,
        trophicType: _creature.trophicType,
        mouth: _creature.mouth,
        mouthCount: _creature.mouthCount,
        mouthLength: _creature.mouthLength,
        mouthCurve: _creature.mouthCurve,
        mouthWobbleAmplitude: _creature.mouthWobbleAmplitude,
        eyes: _creature.eyes,
      ),
    );
  }

  void _onTailLengthFromViewport(double value) {
    final v = value.clamp(TailConfig.lengthMin, TailConfig.lengthMax);
    setState(
      () => _creature = Creature(
        segmentWidths: _creature.segmentWidths,
        color: _creature.color,
        dorsalFins: _creature.dorsalFins,
        finColor: _creature.finColor,
        tail: _creature.tail?.copyWith(length: v),
        lateralFins: _creature.lateralFins,
        antennae: _creature.antennae,
        trophicType: _creature.trophicType,
        mouth: _creature.mouth,
        mouthCount: _creature.mouthCount,
        mouthLength: _creature.mouthLength,
        mouthCurve: _creature.mouthCurve,
        mouthWobbleAmplitude: _creature.mouthWobbleAmplitude,
        eyes: _creature.eyes,
      ),
    );
  }

  void _onTailAddedFromViewport(CaudalFinType? type) {
    setState(
      () => _creature = Creature(
        segmentWidths: _creature.segmentWidths,
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
        antennae: _creature.antennae,
        trophicType: _creature.trophicType,
        mouth: _creature.mouth,
        mouthCount: _creature.mouthCount,
        mouthLength: _creature.mouthLength,
        mouthCurve: _creature.mouthCurve,
        mouthWobbleAmplitude: _creature.mouthWobbleAmplitude,
        eyes: _creature.eyes,
      ),
    );
  }

  void _onTailRemovedFromViewport() {
    setState(
      () => _creature = Creature(
        segmentWidths: _creature.segmentWidths,
        color: _creature.color,
        dorsalFins: _creature.dorsalFins,
        finColor: _creature.finColor,
        tail: null,
        lateralFins: _creature.lateralFins,
        antennae: _creature.antennae,
        trophicType: _creature.trophicType,
        mouth: _creature.mouth,
        mouthCount: _creature.mouthCount,
        mouthLength: _creature.mouthLength,
        mouthCurve: _creature.mouthCurve,
        mouthWobbleAmplitude: _creature.mouthWobbleAmplitude,
        eyes: _creature.eyes,
      ),
    );
  }

  void _onLateralToggledFromViewport(int seg) {
    final list = List<LateralFinConfig>.from(_creature.lateralFins ?? []);
    final idx = list.indexWhere((c) => c.segment == seg);
    if (idx >= 0)
      list.removeAt(idx);
    else
      list.add(LateralFinConfig(seg));
    list.sort((a, b) => a.segment.compareTo(b.segment));
    setState(
      () => _creature = _creatureWith(
        _creature,
        lateralFins: list.isEmpty ? null : list,
      ),
    );
  }

  void _onLateralMovedFromViewport(int fromIndex, int toSeg) {
    final list = List<LateralFinConfig>.from(_creature.lateralFins ?? []);
    if (fromIndex < 0 || fromIndex >= list.length) return;
    final config = list[fromIndex];
    list[fromIndex] = config.copyWith(segment: toSeg);
    list.sort((a, b) => a.segment.compareTo(b.segment));
    setState(() => _creature = _creatureWith(_creature, lateralFins: list));
  }

  void _onLateralAddedFromViewport(int seg, LateralWingType wingType) {
    final list = List<LateralFinConfig>.from(_creature.lateralFins ?? []);
    final existing = list.indexWhere((c) => c.segment == seg);
    if (existing >= 0) {
      list[existing] = list[existing].copyWith(wingType: wingType);
    } else {
      list.add(LateralFinConfig(seg, wingType: wingType));
      list.sort((a, b) => a.segment.compareTo(b.segment));
    }
    setState(() => _creature = _creatureWith(_creature, lateralFins: list));
  }

  void _onLateralRemovedFromViewport(int index) {
    final list = List<LateralFinConfig>.from(_creature.lateralFins ?? []);
    if (index < 0 || index >= list.length) return;
    list.removeAt(index);
    setState(() {
      _creature = _creatureWith(
        _creature,
        lateralFins: list.isEmpty ? <LateralFinConfig>[] : list,
      );
      if (list.isEmpty) {
        _selectedLateralFinIndex = null;
      } else if (_selectedLateralFinIndex != null) {
        if (_selectedLateralFinIndex == index) {
          _selectedLateralFinIndex = null;
        } else if (_selectedLateralFinIndex! > index) {
          _selectedLateralFinIndex = _selectedLateralFinIndex! - 1;
        }
      }
    });
  }

  void _onLateralFinSelectedFromViewport(int? index) {
    setState(() {
      _selectedLateralFinIndex = index;
      if (index != null) {
        _selectedDorsalFinIndex = null;
        _selectedMouth = false;
      }
    });
  }

  void _onLateralLengthChangedFromViewport(int index, double value) {
    final list = List<LateralFinConfig>.from(_creature.lateralFins ?? []);
    if (index < 0 || index >= list.length) return;
    list[index] = list[index].copyWith(length: value);
    setState(() => _creature = _creatureWith(_creature, lateralFins: list));
  }

  void _onLateralWidthChangedFromViewport(int index, double value) {
    final list = List<LateralFinConfig>.from(_creature.lateralFins ?? []);
    if (index < 0 || index >= list.length) return;
    list[index] = list[index].copyWith(width: value);
    setState(() => _creature = _creatureWith(_creature, lateralFins: list));
  }

  void _onLateralAngleChangedFromViewport(int index, double angleDegrees) {
    final list = List<LateralFinConfig>.from(_creature.lateralFins ?? []);
    if (index < 0 || index >= list.length) return;
    list[index] = list[index].copyWith(angleDegrees: angleDegrees);
    setState(() => _creature = _creatureWith(_creature, lateralFins: list));
  }

  //////////////////////////////////////////

  void _onAntennaeToggledFromViewport(int seg) {
    final list = List<AntennaeConfig>.from(_creature.antennae ?? []);
    final idx = list.indexWhere((c) => c.segment == seg);
    if (idx >= 0)
      list.removeAt(idx);
    else
      list.add(AntennaeConfig(seg));
    list.sort((a, b) => a.segment.compareTo(b.segment));
    setState(
      () => _creature = _creatureWith(
        _creature,
        antennae: list.isEmpty ? null : list,
      ),
    );
  }

  void _onAntennaeMovedFromViewport(int fromIndex, int toSeg) {
    final list = List<AntennaeConfig>.from(_creature.antennae ?? []);
    if (fromIndex < 0 || fromIndex >= list.length) return;
    final config = list[fromIndex];
    list[fromIndex] = config.copyWith(segment: toSeg);
    list.sort((a, b) => a.segment.compareTo(b.segment));
    setState(() => _creature = _creatureWith(_creature, antennae: list));
  }

  void _onAntennaeAddedFromViewport(int seg) {
    final list = List<AntennaeConfig>.from(_creature.antennae ?? []);

    list.add(AntennaeConfig(seg));
    list.sort((a, b) => a.segment.compareTo(b.segment));

    setState(() => _creature = _creatureWith(_creature, antennae: list));
  }

  void _onAntennaeRemovedFromViewport(int index) {
    final list = List<AntennaeConfig>.from(_creature.antennae ?? []);
    if (index < 0 || index >= list.length) return;
    list.removeAt(index);
    setState(() {
      _creature = _creatureWith(
        _creature,
        antennae: list.isEmpty ? <AntennaeConfig>[] : list,
      );
      if (list.isEmpty) {
        _selectedAntennaeIndex = null;
      } else if (_selectedAntennaeIndex != null) {
        if (_selectedAntennaeIndex == index) {
          _selectedAntennaeIndex = null;
        } else if (_selectedAntennaeIndex! > index) {
          _selectedAntennaeIndex = _selectedAntennaeIndex! - 1;
        }
      }
    });
  }

  void _onAntennaeSelectedFromViewport(int? index) {
    setState(() {
      _selectedAntennaeIndex = index;
      if (index != null) {
        _selectedDorsalFinIndex = null;
        _selectedMouth = false;
      }
    });
  }

  void _onAntennaeLengthChangedFromViewport(int index, double value) {
    final list = List<AntennaeConfig>.from(_creature.antennae ?? []);
    if (index < 0 || index >= list.length) return;
    list[index] = list[index].copyWith(length: value);
    setState(() => _creature = _creatureWith(_creature, antennae: list));
  }

  void _onAntennaeWidthChangedFromViewport(int index, double value) {
    final list = List<AntennaeConfig>.from(_creature.antennae ?? []);
    if (index < 0 || index >= list.length) return;
    list[index] = list[index].copyWith(width: value);
    setState(() => _creature = _creatureWith(_creature, antennae: list));
  }

  void _onAntennaeAngleChangedFromViewport(int index, double angleDegrees) {
    final list = List<AntennaeConfig>.from(_creature.antennae ?? []);
    if (index < 0 || index >= list.length) return;
    list[index] = list[index].copyWith(angleDegrees: angleDegrees);
    setState(() => _creature = _creatureWith(_creature, antennae: list));
  }

  /////////////////////////////////////////

  void _onMouthAddedFromViewport(MouthType? type, int? mouthCount) {
    final trophicType = type == MouthType.teeth
        ? TrophicType.carnivore
        : (type == MouthType.tentacle
              ? TrophicType.herbivore
              : (type == MouthType.mandible
                    ? TrophicType.omnivore
                    : TrophicType.none));
    final count = type == MouthType.teeth
        ? (mouthCount ?? 4)
        : (type == MouthType.tentacle ? (mouthCount ?? 5) : null);
    setState(
      () => _creature = Creature(
        segmentWidths: _creature.segmentWidths,
        color: _creature.color,
        dorsalFins: _creature.dorsalFins,
        finColor: _creature.finColor,
        tail: _creature.tail,
        lateralFins: _creature.lateralFins,
        antennae: _creature.antennae,
        trophicType: trophicType,
        mouth: type,
        mouthCount: count,
        mouthLength: (type == MouthType.teeth || type == MouthType.tentacle)
            ? MouthParams.lengthDefault
            : null,
        mouthCurve: type == MouthType.teeth ? MouthParams.curveDefault : null,
        mouthWobbleAmplitude: type == MouthType.tentacle
            ? MouthParams.wobbleDefault
            : null,
        eyes: _creature.eyes,
      ),
    );
  }

  void _onMouthRemovedFromViewport() {
    setState(
      () => _creature = Creature(
        segmentWidths: _creature.segmentWidths,
        color: _creature.color,
        dorsalFins: _creature.dorsalFins,
        finColor: _creature.finColor,
        tail: _creature.tail,
        lateralFins: _creature.lateralFins,
        antennae: _creature.antennae,
        trophicType: TrophicType.none,
        mouth: null,
        mouthCount: null,
        mouthLength: null,
        mouthCurve: null,
        mouthWobbleAmplitude: null,
        eyes: _creature.eyes,
      ),
    );
  }

  void _onMouthLengthChangedFromViewport(double length) {
    final v = length.clamp(MouthParams.lengthMin, MouthParams.lengthMax);
    setState(() => _creature = _creatureWith(_creature, mouthLength: v));
  }

  void _onMouthCurveChangedFromViewport(double curve) {
    final v = curve.clamp(MouthParams.curveMin, MouthParams.curveMax);
    setState(() => _creature = _creatureWith(_creature, mouthCurve: v));
  }

  void _onMouthWobbleAmplitudeChangedFromViewport(double wobbleAmplitude) {
    final v = wobbleAmplitude.clamp(
      MouthParams.wobbleMin,
      MouthParams.wobbleMax,
    );
    setState(
      () => _creature = _creatureWith(_creature, mouthWobbleAmplitude: v),
    );
  }

  void _onEyeAddedFromViewport(int segment, double offsetFromCenter) {
    final list = List<EyeConfig>.from(_creature.eyes ?? []);
    list.add(EyeConfig(segment, offset: offsetFromCenter));
    list.sort((a, b) => a.segment.compareTo(b.segment));
    setState(() {
      _creature = Creature(
        segmentWidths: _creature.segmentWidths,
        color: _creature.color,
        dorsalFins: _creature.dorsalFins,
        finColor: _creature.finColor,
        tail: _creature.tail,
        lateralFins: _creature.lateralFins,
        antennae: _creature.antennae,
        trophicType: _creature.trophicType,
        mouth: _creature.mouth,
        mouthCount: _creature.mouthCount,
        mouthLength: _creature.mouthLength,
        mouthCurve: _creature.mouthCurve,
        mouthWobbleAmplitude: _creature.mouthWobbleAmplitude,
        eyes: list,
      );
      _selectedEyeIndex = list.length - 1;
    });
  }

  void _onEyeRemovedFromViewport(int index) {
    final list = List<EyeConfig>.from(_creature.eyes ?? []);
    if (index < 0 || index >= list.length) return;
    list.removeAt(index);
    setState(() {
      _creature = Creature(
        segmentWidths: _creature.segmentWidths,
        color: _creature.color,
        dorsalFins: _creature.dorsalFins,
        finColor: _creature.finColor,
        tail: _creature.tail,
        lateralFins: _creature.lateralFins,
        antennae: _creature.antennae,
        trophicType: _creature.trophicType,
        mouth: _creature.mouth,
        mouthCount: _creature.mouthCount,
        mouthLength: _creature.mouthLength,
        mouthCurve: _creature.mouthCurve,
        mouthWobbleAmplitude: _creature.mouthWobbleAmplitude,
        eyes: list.isEmpty ? null : list,
      );
      if (_selectedEyeIndex == index)
        _selectedEyeIndex = null;
      else if (_selectedEyeIndex != null && _selectedEyeIndex! > index)
        _selectedEyeIndex = _selectedEyeIndex! - 1;
    });
  }

  void _onEyeMovedFromViewport(
    int index,
    int segment,
    double offsetFromCenter,
  ) {
    final list = List<EyeConfig>.from(_creature.eyes ?? []);
    if (index < 0 || index >= list.length) return;
    list[index] = list[index].copyWith(
      segment: segment,
      offsetFromCenter: offsetFromCenter.clamp(
        EyeConfig.offsetMin,
        EyeConfig.offsetMax,
      ),
    );
    list.sort((a, b) => a.segment.compareTo(b.segment));
    setState(() => _creature = _creatureWith(_creature, eyes: list));
  }

  void _onEyeRadiusChangedFromViewport(int index, double value) {
    final list = List<EyeConfig>.from(_creature.eyes ?? []);
    if (index < 0 || index >= list.length) return;
    list[index] = list[index].copyWith(radius: value);
    setState(() => _creature = _creatureWith(_creature, eyes: list));
  }

  void _onEyePupilFractionChangedFromViewport(int index, double pupilFraction) {
    final list = List<EyeConfig>.from(_creature.eyes ?? []);
    if (index < 0 || index >= list.length) return;
    list[index] = list[index].copyWith(pupilFraction: pupilFraction);
    setState(() => _creature = _creatureWith(_creature, eyes: list));
  }
}

Creature _creatureWith(
  Creature creature, {
  List<double>? segmentWidths,
  int? color,
  List<(List<int>, double?)>? dorsalFins,
  List<LateralFinConfig>? lateralFins,
  List<AntennaeConfig>? antennae,
  List<EyeConfig>? eyes,
  MouthType? mouth,
  int? mouthCount,
  double? mouthLength,
  double? mouthCurve,
  double? mouthWobbleAmplitude,
  bool filterDorsalLateral = false,
  int? newSegmentCount,
}) {
  final seg =
      newSegmentCount ??
      (segmentWidths?.length ?? creature.segmentWidths.length);
  List<(List<int>, double?)>? dorsal = dorsalFins ?? creature.dorsalFins;
  List<LateralFinConfig>? lateral = lateralFins ?? creature.lateralFins;
  List<AntennaeConfig>? antennaeList = antennae ?? creature.antennae;
  List<EyeConfig>? eyeList = eyes ?? creature.eyes;
  if (filterDorsalLateral && seg >= 1) {
    dorsal = _filterDorsalForSegmentCount(dorsal, seg);
    lateral = _filterLateralForSegmentCount(lateral, seg);
    antennaeList = _filterAntennaeForSegmentCount(antennae, seg);
    eyeList = _filterEyesForSegmentCount(eyeList, seg);
  }
  return Creature(
    segmentWidths: segmentWidths ?? creature.segmentWidths,
    color: color ?? creature.color,
    dorsalFins: dorsal,
    finColor: creature.finColor,
    tail: creature.tail,
    lateralFins: lateral,
    antennae: antennaeList,
    trophicType: creature.trophicType,
    mouth: mouth ?? creature.mouth,
    mouthCount: mouthCount ?? creature.mouthCount,
    mouthLength: mouthLength ?? creature.mouthLength,
    mouthCurve: mouthCurve ?? creature.mouthCurve,
    mouthWobbleAmplitude: mouthWobbleAmplitude ?? creature.mouthWobbleAmplitude,
    eyes: eyeList,
  );
}

List<(List<int>, double?)>? _filterDorsalForSegmentCount(
  List<(List<int>, double?)>? fins,
  int segCount,
) {
  if (fins == null || fins.isEmpty) return fins;
  final out = <(List<int>, double?)>[];
  for (final f in fins) {
    final list = f.$1.where((s) => s >= 0 && s < segCount).toList();
    if (list.isNotEmpty && list.length == f.$1.length) out.add((list, f.$2));
  }
  return out.isEmpty ? null : out;
}

List<LateralFinConfig>? _filterLateralForSegmentCount(
  List<LateralFinConfig>? configs,
  int segCount,
) {
  if (configs == null) return null;
  final out = configs
      .where((c) => c.segment >= 0 && c.segment < segCount)
      .toList();
  return out.isEmpty ? null : out;
}

List<AntennaeConfig>? _filterAntennaeForSegmentCount(
  List<AntennaeConfig>? configs,
  int segCount,
) {
  if (configs == null) return null;
  final out = configs
      .where((c) => c.segment >= 0 && c.segment < segCount)
      .toList();
  return out.isEmpty ? null : out;
}

List<EyeConfig>? _filterEyesForSegmentCount(
  List<EyeConfig>? configs,
  int segCount,
) {
  if (configs == null) return null;
  final out = configs
      .where((c) => c.segment >= 0 && c.segment < segCount)
      .toList();
  return out.isEmpty ? null : out;
}
