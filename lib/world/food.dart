import 'biome.dart';

/// Target counts per chunk per food type. Adjust per biome below.
class BiomeFoodConfig {
  const BiomeFoodConfig({
    this.plantPerChunk = 0.2,
    this.animalPerChunk = 0.2,
    this.bubblePerChunk = 0.2,
  });
  final double plantPerChunk;
  final double animalPerChunk;
  final double bubblePerChunk;
}

/// Prefilled per-biome food targets. Edit these to tune spawns (e.g. algae = more plant, clear = more bubbles, poisoned = less plant).
BiomeFoodConfig biomeFoodConfig(Biome biome) {
  switch (biome) {
    case Biome.clear:
      return const BiomeFoodConfig(
        plantPerChunk: 0.2,
        animalPerChunk: 0.1,
        bubblePerChunk: 0.3,
      );
    case Biome.deep:
      return const BiomeFoodConfig();
    case Biome.algae:
      return const BiomeFoodConfig(
        plantPerChunk: 0.3,
        animalPerChunk: 0.2,
        bubblePerChunk: 0.1,
      );
    case Biome.poisoned:
      return const BiomeFoodConfig(
        plantPerChunk: 0.1,
        animalPerChunk: 0.2,
        bubblePerChunk: 0.3,
      );
    case Biome.dirty:
      return const BiomeFoodConfig(
        plantPerChunk: 0.2,
        animalPerChunk: 0.3,
        bubblePerChunk: 0.1,
      );
  }
}

/// Cell type for food items. Plant = green hexagon; animal = red circle; bubble = pop-able bubble (same look as background).
enum CellType { plant, animal, bubble }

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
    this.scale = 1.0,
  });
  final double x, y, nucleusOffsetX, nucleusOffsetY;
  final CellType cellType;
  final double consumedAt;
  final double headX, headY;

  /// One entry per bubble (1–3). Each value 0=small, 1=medium, 2=large.
  final List<int> bubbleSizes;

  /// Scale for drawing (e.g. 4.0 for player death remains).
  final double scale;
}

/// Linked to chunk [chunkCx], [chunkCy] for culling (stays linked even if it drifts out of chunk).
class FoodItem {
  FoodItem(
    this.x,
    this.y,
    this.chunkCx,
    this.chunkCy, {
    this.nucleusOffsetX = 0,
    this.nucleusOffsetY = 0,
    this.cellType = CellType.plant,
  });

  final double x;
  final double y;
  final int chunkCx;
  final int chunkCy;
  final double nucleusOffsetX;
  final double nucleusOffsetY;
  final CellType cellType;
}
