import 'dart:math' show cos, pi, Random, sin, sqrt;

import 'world.dart';

/// Cell type for food items. Plant = green hexagon; animal = red circle.
enum CellType { plant, animal }

/// A plant or animal cell (food) in world space. See [FoodPainter].
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

  /// Minimum distance between food centres so they don't overlap (default 2× radius).
  double get minSpacing => 2.0 * radiusWorld;

  /// Remove any food whose centre is within [radius] of (headX, headY). Call each tick with head position.
  void consumeNear(double headX, double headY, [double? radius]) {
    final r = radius ?? radiusWorld;
    final r2 = r * r;
    for (var i = _items.length - 1; i >= 0; i--) {
      final item = _items[i];
      final dx = item.x - headX;
      final dy = item.y - headY;
      if (dx * dx + dy * dy <= r2) _items.removeAt(i);
    }
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

  /// Update plant cell positions with a slow drift (time-based field). Call each frame with current time in seconds.
  void tick(double timeSeconds) {
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
