import 'world.dart';

import 'food.dart';
import '../controller/background_giant_store.dart';
import '../controller/creature_store.dart';

/// Single source of chunk in-range / out-of-range logic. No per-item distance checks.
/// When a chunk is in range and not yet generated: [onGenerate] → food + creatures + giants.
/// When a chunk goes out of range: [onClear] → clear food, clear creatures, clear giants.
/// Giants use parallax (camera * 0.25), so we keep/generate chunks around both main camera and parallax center.
class ChunkManager {
  ChunkManager({
    required this.foodStore,
    required this.creatureStore,
    this.backgroundGiantStore,
    this.parallaxFactor = 0.25,
  });

  final FoodStore foodStore;
  final CreatureStore creatureStore;
  final BackgroundGiantStore? backgroundGiantStore;
  final double parallaxFactor;

  final Set<String> _generated = {};

  /// Update chunk state from camera (cx, cy) and [radius]. Clears chunks too far from BOTH main and parallax center so giants don't disappear. Generates chunks in range of either.
  void update(double cx, double cy, double radius) {
    if (radius < 1) return;
    final r2 = radius * radius;
    final cellSize = kChunkSizeWorld;
    final px = cx * parallaxFactor;
    final py = cy * parallaxFactor;

    // Clear only when chunk is out of range of BOTH main camera and parallax center (so giants behind us stay)
    for (final key in Set<String>.from(_generated)) {
      final parts = key.split(',');
      if (parts.length != 2) continue;
      final ci = int.tryParse(parts[0]);
      final cj = int.tryParse(parts[1]);
      if (ci == null || cj == null) continue;
      final x0 = ci * cellSize;
      final x1 = (ci + 1) * cellSize;
      final y0 = cj * cellSize;
      final y1 = (cj + 1) * cellSize;
      final farFromMain = distSqToAabb(cx, cy, x0, x1, y0, y1) > r2;
      final farFromParallax = distSqToAabb(px, py, x0, x1, y0, y1) > r2;
      if (farFromMain && farFromParallax) {
        foodStore.clearChunk(ci, cj);
        creatureStore.clearChunk(ci, cj);
        backgroundGiantStore?.clearChunk(ci, cj);
        _generated.remove(key);
      }
    }

    // Generate chunks in range of main camera OR parallax center (so we have giants when travelling)
    final mainIMin = ((cx - radius) / cellSize).floor();
    final mainIMax = ((cx + radius) / cellSize).ceil();
    final mainJMin = ((cy - radius) / cellSize).floor();
    final mainJMax = ((cy + radius) / cellSize).ceil();
    final parIMin = ((px - radius) / cellSize).floor();
    final parIMax = ((px + radius) / cellSize).ceil();
    final parJMin = ((py - radius) / cellSize).floor();
    final parJMax = ((py + radius) / cellSize).ceil();
    final iMin = mainIMin < parIMin ? mainIMin : parIMin;
    final iMax = mainIMax > parIMax ? mainIMax : parIMax;
    final jMin = mainJMin < parJMin ? mainJMin : parJMin;
    final jMax = mainJMax > parJMax ? mainJMax : parJMax;
    for (var i = iMin; i <= iMax; i++) {
      for (var j = jMin; j <= jMax; j++) {
        final key = chunkKey(i, j);
        if (_generated.contains(key)) continue;
        final x0 = i * cellSize;
        final x1 = (i + 1) * cellSize;
        final y0 = j * cellSize;
        final y1 = (j + 1) * cellSize;
        final inRangeMain = distSqToAabb(cx, cy, x0, x1, y0, y1) <= r2;
        final inRangeParallax = distSqToAabb(px, py, x0, x1, y0, y1) <= r2;
        if (!inRangeMain && !inRangeParallax) continue;
        foodStore.generateForChunk(i, j);
        creatureStore.generateForChunk(i, j);
        backgroundGiantStore?.generateForChunk(i, j);
        _generated.add(key);
      }
    }
  }
}
