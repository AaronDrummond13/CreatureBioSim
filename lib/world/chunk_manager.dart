import 'world.dart';

import 'food.dart';
import '../controller/creature_store.dart';

/// Single source of chunk in-range / out-of-range logic. No per-item distance checks.
/// When a chunk is in range and not yet generated: [onGenerate] → food + creatures.
/// When a chunk goes out of range: [onClear] → clear food, clear creatures.
class ChunkManager {
  ChunkManager({
    required this.foodStore,
    required this.creatureStore,
  });

  final FoodStore foodStore;
  final CreatureStore creatureStore;

  final Set<String> _generated = {};

  /// Update chunk state from camera (cx, cy) and [radius]. Clears chunks that are too far; generates chunks that are in range.
  void update(double cx, double cy, double radius) {
    if (radius < 1) return;
    final r2 = radius * radius;
    final cellSize = kChunkSizeWorld;

    // Clear chunks that are now out of range
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
      if (distSqToAabb(cx, cy, x0, x1, y0, y1) > r2) {
        foodStore.clearChunk(ci, cj);
        creatureStore.clearChunk(ci, cj);
        _generated.remove(key);
      }
    }

    // Generate chunks that are in range and not yet generated
    final iMin = ((cx - radius) / cellSize).floor();
    final iMax = ((cx + radius) / cellSize).ceil();
    final jMin = ((cy - radius) / cellSize).floor();
    final jMax = ((cy + radius) / cellSize).ceil();
    for (var i = iMin; i <= iMax; i++) {
      for (var j = jMin; j <= jMax; j++) {
        final key = chunkKey(i, j);
        if (_generated.contains(key)) continue;
        final x0 = i * cellSize;
        final x1 = (i + 1) * cellSize;
        final y0 = j * cellSize;
        final y1 = (j + 1) * cellSize;
        if (distSqToAabb(cx, cy, x0, x1, y0, y1) > r2) continue;
        foodStore.generateForChunk(i, j);
        creatureStore.generateForChunk(i, j);
        _generated.add(key);
      }
    }
  }
}
