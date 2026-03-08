import 'dart:math' show Random;

import '../creature.dart';
import '../simulation/spine.dart';

/// Factory for random creatures and spines. Use with [CreatureStore] for chunk-based spawning.
class Spawner {
  Spawner({int? seed}) : _rng = Random(seed);

  final Random _rng;

  /// Creates a random creature and spine positioned at [headX], [headY].
  (Creature, Spine) createRandomAt(double headX, double headY) {
    final creature = _randomCreature();
    final spine = Spine(segmentCount: creature.segmentCount);
    _positionSpineHeadAt(spine, headX, headY);
    return (creature, spine);
  }

  /// Creates one random creature and [count] spines (identical body plan). Each spine is placed near [centerX], [centerY] with small random offset. Returns (creature, list of (spine, isBaby)).
  (Creature, List<(Spine, bool)>) createGroupAt(
    double centerX,
    double centerY, {
    int count = 5,
    double babyChance = 0.4,
  }) {
    final creature = _randomCreature();
    const spread = 60.0;
    final list = <(Spine, bool)>[];
    for (var i = 0; i < count; i++) {
      final spine = Spine(segmentCount: creature.segmentCount);
      final x = centerX + (_rng.nextDouble() * 2 - 1) * spread;
      final y = centerY + (_rng.nextDouble() * 2 - 1) * spread;
      _positionSpineHeadAt(spine, x, y);
      final isBaby = _rng.nextDouble() < babyChance;
      list.add((spine, isBaby));
    }
    return (creature, list);
  }

  /// 1/8 chance for each tail type including none.
  CaudalFinType? _randomTailFin() {
    switch (_rng.nextInt(8)) {
      case 0:
        return null;
      case 1:
        return CaudalFinType.truncate;
      case 2:
        return CaudalFinType.rounded;
      case 3:
        return CaudalFinType.emarginate;
      case 4:
        return CaudalFinType.lunate;
      case 5:
        return CaudalFinType.forked;
      case 6:
        return CaudalFinType.pointed;
      case 7:
        return CaudalFinType.rhomboid;
      default:
        return null;
    }
  }

  Creature _randomCreature() {
    final segmentCount = 1 + _rng.nextInt(14);
    final vertexCount = segmentCount + 1;
    final widths = _smoothVertexWidths(vertexCount);
    final color = 0xFF000000 | _rng.nextInt(0xFFFFFF);
    final dorsalFins = _randomDorsalFins(segmentCount);
    final tailFin = _randomTailFin();
    final lateralFins = _randomLateralFins(segmentCount);
    return Creature(
      vertexWidths: widths,
      color: color,
      dorsalFins: (dorsalFins == null || dorsalFins.isEmpty)
          ? null
          : dorsalFins,
      tailFin: tailFin,
      lateralFins: (lateralFins == null || lateralFins.isEmpty)
          ? null
          : lateralFins,
    );
  }

  /// ~1/6 chance per segment (excluding head) to get a lateral fin.
  List<int>? _randomLateralFins(int segmentCount) {
    final n = segmentCount;
    if (n < 1) return null;
    final list = <int>[];
    for (var seg = 0; seg < n; seg++) {
      if (_rng.nextDouble() < 1 / 6) list.add(seg);
    }
    return list.isEmpty ? null : list;
  }

  /// Interpolate between a few random control points so widths vary smoothly.
  List<double> _smoothVertexWidths(int vertexCount) {
    const numKeys = 5;
    if (vertexCount <= numKeys) {
      return List<double>.generate(
        vertexCount,
        (_) =>
            Creature.minVertexWidth +
            _rng.nextDouble() *
                (Creature.maxVertexWidth - Creature.minVertexWidth),
      );
    }
    final keyIndices = <int>[0];
    for (var k = 1; k < numKeys - 1; k++) {
      keyIndices.add((vertexCount * k) ~/ (numKeys - 1));
    }
    keyIndices.add(vertexCount - 1);

    final keyWidths = keyIndices.map((_) {
      return Creature.minVertexWidth +
          _rng.nextDouble() *
              (Creature.maxVertexWidth - Creature.minVertexWidth);
    }).toList();

    final widths = <double>[];
    for (var i = 0; i < vertexCount; i++) {
      var k = 0;
      while (k < keyIndices.length - 1 && keyIndices[k + 1] <= i) k++;
      if (k >= keyIndices.length - 1) {
        widths.add(keyWidths.last);
      } else {
        final a = keyIndices[k];
        final b = keyIndices[k + 1];
        final t = (i - a) / (b - a);
        widths.add(keyWidths[k] + (keyWidths[k + 1] - keyWidths[k]) * t);
      }
    }
    return widths;
  }

  /// Up to 2 fins, each at least 3 segments, non-overlapping and not connected (gap of ≥1 segment).
  List<(List<int>, double?)>? _randomDorsalFins(int segmentCount) {
    if (segmentCount < 3) return null;
    const minFinSegments = 3;
    const maxFins = 2;
    final numFins = _rng.nextInt(maxFins + 1);
    if (numFins == 0) return null;

    final fins = <(List<int>, double?)>[];
    final used = <int>{};

    for (var f = 0; f < numFins; f++) {
      final len = minFinSegments + _rng.nextInt(4);
      if (len > segmentCount) break;
      final candidates = <int>[];
      for (var start = 0; start <= segmentCount - len; start++) {
        var overlap = false;
        for (var j = start; j < start + len; j++) {
          if (used.contains(j)) {
            overlap = true;
            break;
          }
        }
        if (!overlap) candidates.add(start);
      }
      if (candidates.isEmpty) break;
      final start = candidates[_rng.nextInt(candidates.length)];
      for (var j = start; j < start + len; j++) used.add(j);
      if (start > 0) used.add(start - 1);
      if (start + len < segmentCount) used.add(start + len);
      final segments = List<int>.generate(len, (i) => start + i);
      final height = _rng.nextBool() ? 12.0 + _rng.nextDouble() * 14.0 : null;
      fins.add((segments, height));
    }

    return fins.isEmpty ? null : fins;
  }

  void _positionSpineHeadAt(Spine spine, double headX, double headY) {
    final n = spine.headIndex;
    final len = spine.segmentLength;
    for (var i = 0; i <= n; i++) {
      spine.nodes[i].position.x = headX + (i - n) * len;
      spine.nodes[i].position.y = headY;
    }
  }
}
