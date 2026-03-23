import 'package:bioism/world/world.dart';

import 'package:bioism/controller/food_store.dart';
import 'package:bioism/controller/creature_store.dart';

/// Chunk lifecycle for main world only (food + creatures). One center, two radii:
/// spawn radius (inner) for generation, cull radius (outer) for removal.
/// Mammoths use their own parallax universe and are not managed here.
class ChunkManager {
  ChunkManager({required this.foodStore, required this.creatureStore});

  final FoodStore foodStore;
  final CreatureStore creatureStore;

  final Set<String> _generated = {};

  void update(double cx, double cy, double spawnRadius, double cullRadius) {
    if (spawnRadius < 1) return;
    final cullR2 = cullRadius * cullRadius;
    final spawnR2 = spawnRadius * spawnRadius;
    final cellSize = kChunkSizeWorld;

    // Cull generated chunks beyond cull radius.
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
      if (distSqToAabb(cx, cy, x0, x1, y0, y1) > cullR2) {
        foodStore.clearChunk(ci, cj);
        creatureStore.clearChunk(ci, cj);
        _generated.remove(key);
      }
    }

    // Cull any items that drifted/wandered outside cull radius (escaped their original chunk key).
    foodStore.cullOutOfRange(cx, cy, cullRadius);
    creatureStore.cullOutOfRange(cx, cy, cullRadius);

    // Generate new chunks within spawn radius.
    final iMin = ((cx - spawnRadius) / cellSize).floor();
    final iMax = ((cx + spawnRadius) / cellSize).ceil();
    final jMin = ((cy - spawnRadius) / cellSize).floor();
    final jMax = ((cy + spawnRadius) / cellSize).ceil();
    for (var i = iMin; i <= iMax; i++) {
      for (var j = jMin; j <= jMax; j++) {
        final x0 = i * cellSize;
        final x1 = (i + 1) * cellSize;
        final y0 = j * cellSize;
        final y1 = (j + 1) * cellSize;
        if (distSqToAabb(cx, cy, x0, x1, y0, y1) > spawnR2) continue;
        final key = chunkKey(i, j);
        if (_generated.contains(key)) continue;
        foodStore.generateForChunk(i, j);
        creatureStore.generateForChunk(i, j);
        _generated.add(key);
      }
    }
  }
}
