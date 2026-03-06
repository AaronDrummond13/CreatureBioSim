import 'dart:math' show Random;

import '../creature.dart';
import '../simulation/spine.dart';
import 'bot_controller.dart';

/// A creature plus its spine and bot controller, spawned off-screen.
class SpawnedEntity {
  SpawnedEntity({
    required this.creature,
    required this.spine,
    required this.botController,
  });

  final Creature creature;
  final Spine spine;
  final BotController botController;
}

/// Spawns random creatures just off the visible view every [spawnInterval] seconds.
class Spawner {
  Spawner({
    this.spawnInterval = 10.0,
    this.offScreenMargin = 80.0,
    this.maxEntities = 20,
    int? seed,
  }) : _rng = Random(seed);

  final double spawnInterval;
  final double offScreenMargin;
  final int maxEntities;

  final Random _rng;
  double _lastSpawnTime = -999.0;
  final List<SpawnedEntity> _entities = [];

  List<SpawnedEntity> get entities => _entities;

  /// Call each tick. Spawns a new creature when interval has elapsed.
  void tick(
    double timeSeconds,
    double cameraX,
    double cameraY,
    double viewWidthWorld,
    double viewHeightWorld,
  ) {
    if (_lastSpawnTime < 0) _lastSpawnTime = timeSeconds;
    if (timeSeconds - _lastSpawnTime < spawnInterval) return;
    if (_entities.length >= maxEntities) return;
    _lastSpawnTime = timeSeconds;

    final viewLeft = cameraX - viewWidthWorld / 2;
    final viewRight = cameraX + viewWidthWorld / 2;
    final viewTop = cameraY - viewHeightWorld / 2;
    final viewBottom = cameraY + viewHeightWorld / 2;

    final side = _rng.nextInt(4);
    double spawnX;
    double spawnY;
    switch (side) {
      case 0:
        spawnX = viewLeft - offScreenMargin;
        spawnY = viewTop + _rng.nextDouble() * viewHeightWorld;
        break;
      case 1:
        spawnX = viewRight + offScreenMargin;
        spawnY = viewTop + _rng.nextDouble() * viewHeightWorld;
        break;
      case 2:
        spawnX = viewLeft + _rng.nextDouble() * viewWidthWorld;
        spawnY = viewTop - offScreenMargin;
        break;
      default:
        spawnX = viewLeft + _rng.nextDouble() * viewWidthWorld;
        spawnY = viewBottom + offScreenMargin;
    }

    final creature = _randomCreature();
    final spine = Spine(segmentCount: creature.segmentCount);
    _positionSpineHeadAt(spine, spawnX, spawnY);

    final botController = BotController(
      spine: spine,
      wanderRadius: 800.0 + _rng.nextDouble() * 1200.0,
      ticksPerNewTarget: 80 + _rng.nextInt(100),
    );

    _entities.add(SpawnedEntity(
      creature: creature,
      spine: spine,
      botController: botController,
    ));
  }

  /// Creates a random creature and spine positioned at [headX], [headY]. Does not add to entities.
  (Creature, Spine) createRandomAt(double headX, double headY) {
    final creature = _randomCreature();
    final spine = Spine(segmentCount: creature.segmentCount);
    _positionSpineHeadAt(spine, headX, headY);
    return (creature, spine);
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
    final segmentCount = 5 + _rng.nextInt(14);
    final vertexCount = segmentCount + 1;
    final widths = _smoothVertexWidths(vertexCount);
    final color = 0xFF000000 | _rng.nextInt(0xFFFFFF);
    final dorsalFins = _randomDorsalFins(segmentCount);
    final tailFin = _randomTailFin();
    final lateralFins = _randomLateralFins(segmentCount);
    return Creature(
      vertexWidths: widths,
      color: color,
      dorsalFins: (dorsalFins == null || dorsalFins.isEmpty) ? null : dorsalFins,
      tailFin: tailFin,
      lateralFins: (lateralFins == null || lateralFins.isEmpty) ? null : lateralFins,
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
        (_) => Creature.minVertexWidth +
            _rng.nextDouble() * (Creature.maxVertexWidth - Creature.minVertexWidth),
      );
    }
    final keyIndices = <int>[0];
    for (var k = 1; k < numKeys - 1; k++) {
      keyIndices.add((vertexCount * k) ~/ (numKeys - 1));
    }
    keyIndices.add(vertexCount - 1);

    final keyWidths = keyIndices.map((_) {
      return Creature.minVertexWidth +
          _rng.nextDouble() * (Creature.maxVertexWidth - Creature.minVertexWidth);
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
