import 'dart:math' show Random;

import 'package:creature_bio_sim/creature.dart';
import 'package:creature_bio_sim/dorsal_fin_rules.dart';
import 'package:creature_bio_sim/simulation/spine.dart';

/// Factory for random creatures and spines. Use with [CreatureStore] for chunk-based spawning.
class Spawner {
  Spawner({int? seed}) : _rng = Random(seed);

  /// Herbivore, carnivore, omnivore only; [TrophicType.none] is valid in editor but not for spawning.
  static const _spawnableTrophic = [
    TrophicType.herbivore,
    TrophicType.carnivore,
    TrophicType.omnivore,
  ];

  final Random _rng;

  /// Creates a random creature and spine positioned at [headX], [headY].
  (Creature, Spine) createRandomAt(double headX, double headY) {
    final creature = _randomCreature();
    final spine = Spine(segmentCount: creature.segmentCount);
    _positionSpineHeadAt(spine, headX, headY);
    return (creature, spine);
  }

  /// Creates one random creature and one spine per [babyFlags] (identical body plan). Each spine is placed near [centerX], [centerY] with small random offset. Returns (creature, list of (spine, isBaby)).
  (Creature, List<(Spine, bool)>) createGroupAt(
    double centerX,
    double centerY, {
    required List<bool> babyFlags,
  }) {
    final creature = _randomCreature();
    const spread = 60.0;
    final list = <(Spine, bool)>[];
    for (var i = 0; i < babyFlags.length; i++) {
      final spine = Spine(segmentCount: creature.segmentCount);
      final x = centerX + (_rng.nextDouble() * 2 - 1) * spread;
      final y = centerY + (_rng.nextDouble() * 2 - 1) * spread;
      _positionSpineHeadAt(spine, x, y);
      list.add((spine, babyFlags[i]));
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
    final segmentCount = 1 + _rng.nextInt(Creature.maxSegmentCount);
    final widths = _smoothSegmentWidths(segmentCount);
    final color = 0xFF000000 | _rng.nextInt(0xFFFFFF);
    final dorsalFins = _randomDorsalFins(segmentCount);
    final tailFin = _randomTailFin();
    final lateralFins = _randomLateralFins(segmentCount);
    final tail = tailFin != null
        ? TailConfig(
            tailFin,
            rootWidth: _inRange(TailConfig.rootWidthMin, TailConfig.rootWidthMax),
            maxWidth: _inRange(TailConfig.maxWidthMin, TailConfig.maxWidthMax),
            length: _inRange(TailConfig.lengthMin, TailConfig.lengthMax),
          )
        : null;
    final trophicType = _spawnableTrophic[_rng.nextInt(_spawnableTrophic.length)];
    final mouth = trophicType == TrophicType.herbivore
        ? MouthType.tentacle
        : (trophicType == TrophicType.carnivore ? MouthType.teeth : MouthType.mandible);
    final mouthCount = mouth == MouthType.teeth
        ? teethCountOptions[_rng.nextInt(teethCountOptions.length)]
        : (mouth == MouthType.tentacle
            ? tentacleCountOptions[_rng.nextInt(tentacleCountOptions.length)]
            : null);
    final eyes = _randomEyes(segmentCount);
    return Creature(
      segmentWidths: widths,
      color: color,
      dorsalFins: (dorsalFins == null || dorsalFins.isEmpty)
          ? null
          : dorsalFins,
      tail: tail,
      lateralFins: (lateralFins == null || lateralFins.isEmpty)
          ? null
          : lateralFins,
      trophicType: trophicType,
      mouth: mouth,
      mouthCount: mouthCount,
      mouthLength: (mouth == MouthType.teeth || mouth == MouthType.tentacle) ? MouthParams.lengthDefault : null,
      mouthCurve: mouth == MouthType.teeth ? MouthParams.curveDefault : null,
      mouthWobbleAmplitude: mouth == MouthType.tentacle ? MouthParams.wobbleDefault : null,
      eyes: (eyes == null || eyes.isEmpty) ? null : eyes,
    );
  }

  /// Random eye count (0–3), segment, offset and radius per eye. Babies still get no eyes at render time.
  List<EyeConfig>? _randomEyes(int segmentCount) {
    if (segmentCount < 1) return null;
    final n = _rng.nextInt(4); // 0 to 3 eyes
    if (n == 0) return null;
    final list = <EyeConfig>[];
    for (var i = 0; i < n; i++) {
      final seg = _rng.nextInt(segmentCount);
      final offset = _rng.nextDouble(); // 0 = single centre, (0,1] = pair
      final radius = _inRange(EyeConfig.radiusMin, EyeConfig.radiusMax);
      list.add(EyeConfig(seg, offsetFromCenter: offset, radius: radius));
    }
    list.sort((a, b) => a.segment.compareTo(b.segment));
    return list;
  }

  double _inRange(double min, double max) => min + _rng.nextDouble() * (max - min);

  /// ~1/6 chance per segment (excluding head) to get a lateral fin with default or random size in range.
  List<LateralFinConfig>? _randomLateralFins(int segmentCount) {
    final n = segmentCount;
    if (n < 1) return null;
    final list = <LateralFinConfig>[];
    for (var seg = 0; seg < n; seg++) {
      if (_rng.nextDouble() < 1 / 6) {
        final length = _inRange(LateralFinConfig.lengthMin, LateralFinConfig.lengthMax);
        final width = _inRange(LateralFinConfig.widthMin, LateralFinConfig.widthMax);
        list.add(LateralFinConfig(seg, length: length, width: width));
      }
    }
    return list.isEmpty ? null : list;
  }

  /// Interpolate between a few random control points so segment widths vary smoothly.
  List<double> _smoothSegmentWidths(int segmentCount) {
    const numKeys = 5;
    if (segmentCount <= numKeys) {
      return List<double>.generate(
        segmentCount,
        (_) =>
            Creature.minVertexWidth +
            _rng.nextDouble() *
                (Creature.maxVertexWidth - Creature.minVertexWidth),
      );
    }
    final keyIndices = <int>[0];
    for (var k = 1; k < numKeys - 1; k++) {
      keyIndices.add((segmentCount * k) ~/ (numKeys - 1));
    }
    keyIndices.add(segmentCount - 1);

    final keyWidths = keyIndices.map((_) {
      return Creature.minVertexWidth +
          _rng.nextDouble() *
              (Creature.maxVertexWidth - Creature.minVertexWidth);
    }).toList();

    final widths = <double>[];
    for (var i = 0; i < segmentCount; i++) {
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

  /// Uses [dorsal_fin_rules]: up to [dorsalFinMaxFinsForSpawner] fins, each at least [dorsalFinMinSegments] segments, no duplicate segments.
  List<(List<int>, double?)>? _randomDorsalFins(int segmentCount) {
    if (segmentCount < dorsalFinMinSegments) return null;
    final numFins = _rng.nextInt(dorsalFinMaxFinsForSpawner + 1);
    if (numFins == 0) return null;

    final fins = <(List<int>, double?)>[];
    final used = <int>{};

    for (var f = 0; f < numFins; f++) {
      final len = dorsalFinMinSegments + _rng.nextInt((segmentCount - dorsalFinMinSegments).clamp(1, 5));
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
