import 'dart:math' show cos, pi, Random, sin, sqrt;

import 'package:creature_bio_sim/world/biome.dart';
import 'package:creature_bio_sim/world/biome_food_config.dart';
import 'package:creature_bio_sim/world/biome_map.dart';
import 'package:creature_bio_sim/world/consumed_remnant.dart';
import 'package:creature_bio_sim/world/food.dart';
import 'package:creature_bio_sim/world/world.dart';

/// Food items linked to chunks. Generation/clear is driven by [ChunkManager]. Spawn counts per chunk come from [biomeFoodConfig] for the chunk's biome.
class FoodStore {
  FoodStore({this.biomeMap, this.radiusWorld = 20.0, Random? random})
      : _random = random ?? Random();

  /// When set, chunk biome is used to look up [biomeFoodConfig]. When null, uses [Biome.clear] config.
  final BiomeMap? biomeMap;
  final double radiusWorld;
  final Random _random;

  final List<FoodItem> _items = [];
  List<FoodItem> get items => _items;

  final List<ConsumedRemnant> _consumedRemnants = [];
  List<ConsumedRemnant> get consumedRemnants => _consumedRemnants;

  /// Minimum distance between food centres so they don't overlap (default 2× radius).
  double get minSpacing => 2.0 * radiusWorld;

  /// Remove any food whose centre is within [radius] of (headX, headY). If [timeSeconds] is set, adds a [ConsumedRemnant] for rendering burst + fading nucleus.
  /// When [allowedCellTypes] is non-null, only food with [FoodItem.cellType] in the set is consumed (e.g. herbivore = plant only).
  /// Returns the number of items consumed.
  int consumeNear(
    double headX,
    double headY, [
    double? radius,
    double? timeSeconds,
    Set<CellType>? allowedCellTypes,
  ]) {
    final r = radius ?? radiusWorld;
    final r2 = r * r;
    var count = 0;
    for (var i = _items.length - 1; i >= 0; i--) {
      final item = _items[i];
      if (allowedCellTypes != null && !allowedCellTypes.contains(item.cellType)) continue;
      final dx = item.x - headX;
      final dy = item.y - headY;
      if (dx * dx + dy * dy <= r2) {
        if (timeSeconds != null) {
          final n = _random.nextInt(3) + 1;
          final bubbleSizes = List<int>.generate(n, (_) => _random.nextInt(3));
          _consumedRemnants.add(
            ConsumedRemnant(
              x: item.x,
              y: item.y,
              nucleusOffsetX: item.nucleusOffsetX,
              nucleusOffsetY: item.nucleusOffsetY,
              cellType: item.cellType,
              consumedAt: timeSeconds,
              headX: headX,
              headY: headY,
              bubbleSizes: bubbleSizes,
            ),
          );
        }
        _items.removeAt(i);
        count++;
      }
    }
    return count;
  }

  /// Add a consumed remnant at (x, y), e.g. when a baby creature is eaten. Uses [cellType] (default animal) for rendering. [scale] multiplies drawn size (e.g. 4.0 for player death).
  void addConsumedRemnantAt(
    double x,
    double y,
    double consumedAt,
    double headX,
    double headY, {
    CellType cellType = CellType.animal,
    double scale = 1.0,
  }) {
    final n = _random.nextInt(3) + 1;
    final bubbleSizes = List<int>.generate(n, (_) => _random.nextInt(3));
    _consumedRemnants.add(
      ConsumedRemnant(
        x: x,
        y: y,
        nucleusOffsetX: 0,
        nucleusOffsetY: 0,
        cellType: cellType,
        consumedAt: consumedAt,
        headX: headX,
        headY: headY,
        bubbleSizes: bubbleSizes,
        scale: scale,
      ),
    );
  }

  /// Only checks items in the same chunk (ci, cj).
  bool _tooCloseInChunk(int ci, int cj, double x, double y, double minDist) {
    final minDist2 = minDist * minDist;
    for (final item in _items) {
      if (item.chunkCx != ci || item.chunkCy != cj) continue;
      final dx = x - item.x;
      final dy = y - item.y;
      if (dx * dx + dy * dy < minDist2) return true;
    }
    return false;
  }

  /// Remove all food linked to chunk (ci, cj). Called by [ChunkManager] when chunk goes out of range.
  void clearChunk(int ci, int cj) {
    for (var i = _items.length - 1; i >= 0; i--) {
      if (_items[i].chunkCx == ci && _items[i].chunkCy == cj)
        _items.removeAt(i);
    }
  }

  /// Fractional value → int: floor + chance for one more (e.g. 0.5 → 0 or 1 with 50% chance).
  int _countFromRate(double rate) {
    if (rate <= 0) return 0;
    final floor = rate.floor();
    final frac = rate - floor;
    final extra = frac > 0 && _random.nextDouble() < frac ? 1 : 0;
    return (floor + extra).clamp(0, 0x7FFFFFFF);
  }

  /// Generate food for chunk (i, j). Called by [ChunkManager] when chunk comes into range.
  /// Uses [biomeFoodConfig] for the chunk's biome; builds plant/animal/bubble counts, shuffles, places at random positions.
  /// Fractional rates (e.g. 0.5) give a chance of 1 item so low densities still spawn food.
  void generateForChunk(int i, int j) {
    final cellSize = kChunkSizeWorld;
    final centerX = (i + 0.5) * cellSize;
    final centerY = (j + 0.5) * cellSize;
    final biome = biomeMap != null
        ? biomeMap!.biomeAt(centerX, centerY)
        : Biome.clear;
    final config = biomeFoodConfig(biome);
    final plantCount = _countFromRate(config.plantPerChunk);
    final animalCount = _countFromRate(config.animalPerChunk);
    final bubbleCount = _countFromRate(config.bubblePerChunk);
    final types = <CellType>[
      ...List.filled(plantCount, CellType.plant),
      ...List.filled(animalCount, CellType.animal),
      ...List.filled(bubbleCount, CellType.bubble),
    ];
    if (types.isEmpty) return;
    types.shuffle(_random);
    final count = types.length;
    final fillRadius = cellSize / 2;
    final minDist = minSpacing;
    final r2 = fillRadius * fillRadius;
    var attempts = 0;
    const maxAttemptsPerItem = 500;
    var added = 0;
    while (added < count && attempts < count * maxAttemptsPerItem) {
      final dist = sqrt(_random.nextDouble()) * fillRadius;
      final theta = _random.nextDouble() * 2 * pi;
      final x = centerX + dist * cos(theta);
      final y = centerY + dist * sin(theta);
      if ((x - centerX) * (x - centerX) + (y - centerY) * (y - centerY) <= r2 &&
          !_tooCloseInChunk(i, j, x, y, minDist)) {
        final nux = (_random.nextDouble() * 2 - 1) * radiusWorld * 0.12;
        final nuy = (_random.nextDouble() * 2 - 1) * radiusWorld * 0.12;
        _items.add(
          FoodItem(
            x,
            y,
            i,
            j,
            nucleusOffsetX: nux,
            nucleusOffsetY: nuy,
            cellType: types[added],
          ),
        );
        added++;
      }
      attempts++;
    }
  }

  /// Drift speed in world units per second. Applied in [tick].
  static const double driftSpeed = 18.0;

  double _lastTimeSeconds = 0;

  static const double remnantLifetimeSeconds = 7.5;

  /// Update plant cell positions with a slow drift; prune consumed remnants older than [remnantLifetimeSeconds].
  void tick(double timeSeconds) {
    _consumedRemnants.removeWhere(
      (r) => timeSeconds - r.consumedAt > remnantLifetimeSeconds,
    );
    if (_items.isEmpty) return;
    var dt = timeSeconds - _lastTimeSeconds;
    _lastTimeSeconds = timeSeconds;
    if (dt <= 0 || dt > 0.1) dt = 1 / 60.0;
    final t = timeSeconds;
    final newItems = _items.map((item) {
      final dx =
          driftSpeed * (sin(t * 0.3) + 0.4 * sin(t + item.x * 0.015)) * dt;
      final dy =
          driftSpeed * (cos(t * 0.4) + 0.4 * cos(t + item.y * 0.015)) * dt;
      return FoodItem(
        item.x + dx,
        item.y + dy,
        item.chunkCx,
        item.chunkCy,
        nucleusOffsetX: item.nucleusOffsetX,
        nucleusOffsetY: item.nucleusOffsetY,
        cellType: item.cellType,
      );
    }).toList();
    _items
      ..clear()
      ..addAll(newItems);
  }
}
