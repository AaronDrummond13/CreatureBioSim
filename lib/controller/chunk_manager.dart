import 'package:creature_bio_sim/world/world.dart';

import 'package:creature_bio_sim/controller/food_store.dart';
import 'package:creature_bio_sim/controller/creature_store.dart';

/// Chunk lifecycle for main world only (food + creatures). One center, one radius.
/// Mammoths use their own parallax universe and are not managed here.
class ChunkManager {
  ChunkManager({
    required this.foodStore,
    required this.creatureStore,
  });

  final FoodStore foodStore;
  final CreatureStore creatureStore;

  final Set<String> _generated = {};

  void update(double cx, double cy, double radius) {
    if (radius < 1) return;
    final r2 = radius * radius;
    final cellSize = kChunkSizeWorld;

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

    final iMin = ((cx - radius) / cellSize).floor();
    final iMax = ((cx + radius) / cellSize).ceil();
    final jMin = ((cy - radius) / cellSize).floor();
    final jMax = ((cy + radius) / cellSize).ceil();
    for (var i = iMin; i <= iMax; i++) {
      for (var j = jMin; j <= jMax; j++) {
        final x0 = i * cellSize;
        final x1 = (i + 1) * cellSize;
        final y0 = j * cellSize;
        final y1 = (j + 1) * cellSize;
        if (distSqToAabb(cx, cy, x0, x1, y0, y1) > r2) continue;
        final key = chunkKey(i, j);
        if (_generated.contains(key)) continue;
        foodStore.generateForChunk(i, j);
        creatureStore.generateForChunk(i, j);
        _generated.add(key);
      }
    }
  }
}
