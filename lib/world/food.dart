import 'dart:math' show cos, pi, Random, sin, sqrt;

import 'world.dart';

/// Cell type for food items. Plant = green hexagon; animal = red circle.
enum CellType { plant, animal }

/// A plant or animal cell (food) in world space. See [FoodPainter].
/// Remnant after consumption: nucleus stays, drifts away from [headX, headY], and fades over 5s; body "burst" drawn for ~0.3s.
class ConsumedRemnant {
  ConsumedRemnant({
    required this.x,
    required this.y,
    required this.nucleusOffsetX,
    required this.nucleusOffsetY,
    required this.cellType,
    required this.consumedAt,
    required this.headX,
    required this.headY,
    required this.bubbleSizes,
  });
  final double x, y, nucleusOffsetX, nucleusOffsetY;
  final CellType cellType;
  final double consumedAt;
  final double headX, headY;
  /// One entry per bubble (1–3). Each value 0=small, 1=medium, 2=large.
  final List<int> bubbleSizes;
}

/// Linked to chunk [chunkCx], [chunkCy] for culling (stays linked even if it drifts out of chunk).
class FoodItem {
  FoodItem(this.x, this.y, this.chunkCx, this.chunkCy,
      {this.nucleusOffsetX = 0,
      this.nucleusOffsetY = 0,
      this.cellType = CellType.plant});

  final double x;
  final double y;
  final int chunkCx;
  final int chunkCy;
  final double nucleusOffsetX;
  final double nucleusOffsetY;
  final CellType cellType;
}

/// Food items linked to chunks. Generation/clear is driven by [ChunkManager]; no distance-based add/remove.
class FoodStore {
  FoodStore({
    this.targetDensity = 1 / 230400.0,
    this.radiusWorld = 14.0,
    this.chunkSpawnChance = 0.25,
    Random? random,
  }) : _random = random ?? Random();

  final double targetDensity;
  final double radiusWorld;
  final double chunkSpawnChance;
  final Random _random;

  final List<FoodItem> _items = [];
  List<FoodItem> get items => _items;

  final List<ConsumedRemnant> _consumedRemnants = [];
  List<ConsumedRemnant> get consumedRemnants => _consumedRemnants;

  /// Minimum distance between food centres so they don't overlap (default 2× radius).
  double get minSpacing => 2.0 * radiusWorld;

  /// Remove any food whose centre is within [radius] of (headX, headY). If [timeSeconds] is set, adds a [ConsumedRemnant] for rendering burst + fading nucleus.
  void consumeNear(double headX, double headY, [double? radius, double? timeSeconds]) {
    final r = radius ?? radiusWorld;
    final r2 = r * r;
    for (var i = _items.length - 1; i >= 0; i--) {
      final item = _items[i];
      final dx = item.x - headX;
      final dy = item.y - headY;
      if (dx * dx + dy * dy <= r2) {
        if (timeSeconds != null) {
          final n = _random.nextInt(3) + 1;
          final bubbleSizes = List<int>.generate(n, (_) => _random.nextInt(3));
          _consumedRemnants.add(ConsumedRemnant(
            x: item.x,
            y: item.y,
            nucleusOffsetX: item.nucleusOffsetX,
            nucleusOffsetY: item.nucleusOffsetY,
            cellType: item.cellType,
            consumedAt: timeSeconds,
            headX: headX,
            headY: headY,
            bubbleSizes: bubbleSizes,
          ));
        }
        _items.removeAt(i);
      }
    }
  }

  /// Add a consumed remnant at (x, y), e.g. when a baby creature is eaten. Uses [cellType] (default animal) for rendering.
  void addConsumedRemnantAt(
    double x,
    double y,
    double consumedAt,
    double headX,
    double headY, {
    CellType cellType = CellType.animal,
  }) {
    final n = _random.nextInt(3) + 1;
    final bubbleSizes = List<int>.generate(n, (_) => _random.nextInt(3));
    _consumedRemnants.add(ConsumedRemnant(
      x: x,
      y: y,
      nucleusOffsetX: 0,
      nucleusOffsetY: 0,
      cellType: cellType,
      consumedAt: consumedAt,
      headX: headX,
      headY: headY,
      bubbleSizes: bubbleSizes,
    ));
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
      if (_items[i].chunkCx == ci && _items[i].chunkCy == cj) _items.removeAt(i);
    }
  }

  /// Generate food for chunk (i, j). Called by [ChunkManager] when chunk comes into range.
  void generateForChunk(int i, int j) {
    if (chunkSpawnChance < 1.0 && _random.nextDouble() >= chunkSpawnChance) return;
    final cellSize = kChunkSizeWorld;
    final centerX = (i + 0.5) * cellSize;
    final centerY = (j + 0.5) * cellSize;
    final fillRadius = cellSize / 2;
    final area = pi * fillRadius * fillRadius;
    final count = (area * targetDensity).round().clamp(0, 0x7FFFFFFF);
    final minDist = minSpacing;
    final r2 = fillRadius * fillRadius;
    var attempts = 0;
    const maxAttemptsPerItem = 500;
    var added = 0;
    while (added < count && attempts < count * maxAttemptsPerItem) {
      final r = sqrt(_random.nextDouble()) * fillRadius;
      final theta = _random.nextDouble() * 2 * pi;
      final x = centerX + r * cos(theta);
      final y = centerY + r * sin(theta);
      if ((x - centerX) * (x - centerX) + (y - centerY) * (y - centerY) <= r2 &&
          !_tooCloseInChunk(i, j, x, y, minDist)) {
        final nux = (_random.nextDouble() * 2 - 1) * radiusWorld * 0.12;
        final nuy = (_random.nextDouble() * 2 - 1) * radiusWorld * 0.12;
        final type = _random.nextInt(8) == 0 ? CellType.animal : CellType.plant;
        _items.add(FoodItem(x, y, i, j, nucleusOffsetX: nux, nucleusOffsetY: nuy, cellType: type));
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
    _consumedRemnants.removeWhere((r) => timeSeconds - r.consumedAt > remnantLifetimeSeconds);
    if (_items.isEmpty) return;
    var dt = timeSeconds - _lastTimeSeconds;
    _lastTimeSeconds = timeSeconds;
    if (dt <= 0 || dt > 0.1) dt = 1 / 60.0;
    final t = timeSeconds;
    final newItems = _items.map((item) {
      final dx = driftSpeed * (sin(t * 0.3) + 0.4 * sin(t + item.x * 0.015)) * dt;
      final dy = driftSpeed * (cos(t * 0.4) + 0.4 * cos(t + item.y * 0.015)) * dt;
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
