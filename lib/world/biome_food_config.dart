import 'package:creature_bio_sim/world/biome.dart';

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
        plantPerChunk: 0.5,
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
        animalPerChunk: 0.4,
        bubblePerChunk: 0.1,
      );
  }
}
