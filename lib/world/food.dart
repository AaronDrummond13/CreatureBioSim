import 'dart:math' show cos, pi, Random, sin, sqrt;

import 'world.dart';

/// Cell type for food items. Plant = green hexagon; animal = red circle.
enum CellType { plant, animal }

/// A plant or animal cell (food) in world space. See [FoodPainter].
/// [nucleusOffsetX] and [nucleusOffsetY] place the nucleus near the centre (random per cell).
class FoodItem {
  FoodItem(this.x, this.y,
      {this.nucleusOffsetX = 0,
      this.nucleusOffsetY = 0,
      this.cellType = CellType.plant});

  final double x;
  final double y;
  final double nucleusOffsetX;
  final double nucleusOffsetY;
  final CellType cellType;
}

/// Mutable chunk state: plant cells (food). Chunk-based generation and culling; uses [World] chunk grid (500 units).
class FoodStore {
  FoodStore({
    this.targetDensity = 1 / 230400.0,
    this.radiusWorld = 14.0,
    Random? random,
  }) : _random = random ?? Random();

  final double targetDensity;
  final double radiusWorld;
  final Random _random;

  final List<FoodItem> _items = [];
  List<FoodItem> get items => _items;

  /// Chunks that currently have generated food (cleared when food is culled so re-entry regenerates).
  final Set<String> _generatedChunks = {};

  double get chunkSizeWorld => kChunkSizeWorld;

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

  static (int, int) _chunkAt(double x, double y) => chunkIndex(x, y);

  bool _tooCloseToExisting(double x, double y, double minDist) {
    final minDist2 = minDist * minDist;
    for (final item in _items) {
      final dx = x - item.x;
      final dy = y - item.y;
      if (dx * dx + dy * dy < minDist2) return true;
    }
    return false;
  }

  /// Fill the circle centered at (cx, cy) with radius [radius].
  /// Call once on start. Marks the camera chunk as generated only if we actually added food.
  /// No-op if [radius] < 1 (avoids division by zero and avoids marking empty as generated).
  void generateInArea(double cx, double cy, double radius) {
    _items.clear();
    _generatedChunks.clear();
    if (radius < 1) return;
    final area = pi * radius * radius;
    final count = (area * targetDensity).round().clamp(0, 0x7FFFFFFF);
    final minDist = minSpacing;
    var attempts = 0;
    const maxAttemptsPerItem = 500;
    while (_items.length < count && attempts < count * maxAttemptsPerItem) {
      final r = sqrt(_random.nextDouble()) * radius;
      final theta = _random.nextDouble() * 2 * pi;
      final x = cx + r * cos(theta);
      final y = cy + r * sin(theta);
      if (!_tooCloseToExisting(x, y, minDist)) {
        final nux = (_random.nextDouble() * 2 - 1) * radiusWorld * 0.12;
        final nuy = (_random.nextDouble() * 2 - 1) * radiusWorld * 0.12;
        final type = _random.nextInt(8) == 0 ? CellType.animal : CellType.plant;
        _items.add(FoodItem(x, y, nucleusOffsetX: nux, nucleusOffsetY: nuy, cellType: type));
      }
      attempts++;
    }
    if (_items.isEmpty) return;
    for (final item in _items) {
      final (i, j) = _chunkAt(item.x, item.y);
      _generatedChunks.add(chunkKey(i, j));
    }
  }

  /// Remove food outside [radius], clear generated chunks that no longer overlap the circle,
  /// and drop any generated chunk that has no food left (so it can be regenerated when revisited).
  void deleteFar(double cx, double cy, double radius) {
    if (radius < 1) return;
    final r2 = radius * radius;
    final cellSize = kChunkSizeWorld;
    for (var i = _items.length - 1; i >= 0; i--) {
      final item = _items[i];
      final dx = item.x - cx;
      final dy = item.y - cy;
      if (dx * dx + dy * dy > r2) _items.removeAt(i);
    }
    for (final key in List<String>.from(_generatedChunks)) {
      final parts = key.split(',');
      if (parts.length != 2) continue;
      final ci = int.tryParse(parts[0]);
      final cj = int.tryParse(parts[1]);
      if (ci == null || cj == null) continue;
      final x0 = ci * cellSize;
      final x1 = (ci + 1) * cellSize;
      final y0 = cj * cellSize;
      final y1 = (cj + 1) * cellSize;
      final dx = cx < x0 ? x0 - cx : (cx > x1 ? cx - x1 : 0.0);
      final dy = cy < y0 ? y0 - cy : (cy > y1 ? cy - y1 : 0.0);
      if (dx * dx + dy * dy > r2) {
        for (var i = _items.length - 1; i >= 0; i--) {
        final (ii, jj) = _chunkAt(_items[i].x, _items[i].y);
        if (ii == ci && jj == cj) _items.removeAt(i);
        }
        _generatedChunks.remove(key);
      }
    }
    // Allow empty (eaten) chunks to be regenerated only when they are far from camera (outer part of view).
    // So eaten areas stay empty while nearby; when we leave and chunk is far, we clear it so revisiting refills.
    final allowRegenDist2 = (radius * 0.6) * (radius * 0.6);
    for (final key in List<String>.from(_generatedChunks)) {
      final parts = key.split(',');
      if (parts.length != 2) continue;
      final ci = int.tryParse(parts[0]);
      final cj = int.tryParse(parts[1]);
      if (ci == null || cj == null) continue;
      final hasFood = _items.any((item) {
        final (ii, jj) = _chunkAt(item.x, item.y);
        return ii == ci && jj == cj;
      });
      if (hasFood) continue;
      final chunkCx = (ci + 0.5) * cellSize;
      final chunkCy = (cj + 0.5) * cellSize;
      final dcx = cx - chunkCx;
      final dcy = cy - chunkCy;
      if (dcx * dcx + dcy * dcy > allowRegenDist2) _generatedChunks.remove(key);
    }
  }

  void _generateForChunk(int i, int j) {
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
          !_tooCloseToExisting(x, y, minDist)) {
        final nux = (_random.nextDouble() * 2 - 1) * radiusWorld * 0.12;
        final nuy = (_random.nextDouble() * 2 - 1) * radiusWorld * 0.12;
        final type = _random.nextInt(8) == 0 ? CellType.animal : CellType.plant;
        _items.add(FoodItem(x, y, nucleusOffsetX: nux, nucleusOffsetY: nuy, cellType: type));
        added++;
      }
      attempts++;
    }
    if (added > 0) _generatedChunks.add(chunkKey(i, j));
  }

  /// Distance squared from point (px, py) to AABB [x0,x1] x [y0,y1]. 0 if inside.
  static double _distSqToAabb(double px, double py, double x0, double x1, double y0, double y1) {
    final dx = px < x0 ? x0 - px : (px > x1 ? px - x1 : 0.0);
    final dy = py < y0 ? y0 - py : (py > y1 ? py - y1 : 0.0);
    return dx * dx + dy * dy;
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
        nucleusOffsetX: item.nucleusOffsetX,
        nucleusOffsetY: item.nucleusOffsetY,
        cellType: item.cellType,
      );
    }).toList();
    _items
      ..clear()
      ..addAll(newItems);
  }

  /// Ensure every chunk that overlaps the circle of [radius] around (cx, cy) has food generated.
  /// Uses same overlap test as clearing: chunk AABB within [radius] of (cx, cy).
  void ensureChunkGenerated(double cx, double cy, double radius) {
    if (radius < 1) return;
    final r2 = radius * radius;
    final cellSize = kChunkSizeWorld;
    final iMin = ((cx - radius) / cellSize).floor();
    final iMax = ((cx + radius) / cellSize).ceil();
    final jMin = ((cy - radius) / cellSize).floor();
    final jMax = ((cy + radius) / cellSize).ceil();
    for (var i = iMin; i <= iMax; i++) {
      for (var j = jMin; j <= jMax; j++) {
        if (_generatedChunks.contains(chunkKey(i, j))) continue;
        final x0 = i * cellSize;
        final x1 = (i + 1) * cellSize;
        final y0 = j * cellSize;
        final y1 = (j + 1) * cellSize;
        if (_distSqToAabb(cx, cy, x0, x1, y0, y1) <= r2) {
          _generateForChunk(i, j);
        }
      }
    }
  }
}
