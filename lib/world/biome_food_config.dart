import 'package:creature_bio_sim/world/biome.dart';

/// Target counts per chunk per food type. Adjust per biome below.
class BiomeFoodConfig {
  const BiomeFoodConfig({
    this.plantPerChunk = 0.2,
    this.animalPerChunk = 0.2,
    this.bubblePerChunk = 0.2,
    this.giantPlantPerChunk = 0.025,
    this.giantAnimalPerChunk = 0.05,
    this.giantBubblePerChunk = 0.05,
  });
  final double plantPerChunk;
  final double animalPerChunk;
  final double bubblePerChunk;
  final double giantPlantPerChunk;
  final double giantAnimalPerChunk;
  final double giantBubblePerChunk;
}

/// Prefilled per-biome food targets. Edit these to tune spawns (e.g. algae = more plant, clear = more bubbles, poisoned = less plant).
BiomeFoodConfig biomeFoodConfig(Biome biome) {
  switch (biome) {
    case Biome.clear:
      return const BiomeFoodConfig(
        plantPerChunk: 0.2,
        animalPerChunk: 0.1,
        bubblePerChunk: 0.3,
        giantPlantPerChunk: 0.05,
        giantAnimalPerChunk: 0.025,
        giantBubblePerChunk: 0.075,
      );
    case Biome.deep:
      return const BiomeFoodConfig();
    case Biome.algae:
      return const BiomeFoodConfig(
        plantPerChunk: 0.5,
        animalPerChunk: 0.2,
        bubblePerChunk: 0.1,
        giantPlantPerChunk: 0.1,
        giantAnimalPerChunk: 0.05,
        giantBubblePerChunk: 0.025,
      );
    case Biome.poisoned:
      return const BiomeFoodConfig(
        plantPerChunk: 0.1,
        animalPerChunk: 0.2,
        bubblePerChunk: 0.3,
        giantPlantPerChunk: 0.025,
        giantAnimalPerChunk: 0.05,
        giantBubblePerChunk: 0.75,
      );
    case Biome.dirty:
      return const BiomeFoodConfig(
        plantPerChunk: 0.2,
        animalPerChunk: 0.4,
        bubblePerChunk: 0.1,
        giantPlantPerChunk: 0.025,
        giantAnimalPerChunk: 0.075,
        giantBubblePerChunk: 0.025,
      );
    case Biome.wasteland:
      return const BiomeFoodConfig(
        plantPerChunk: 0,
        animalPerChunk: 0,
        bubblePerChunk: 0.2,
        giantBubblePerChunk: 0.075,
      );
  }
}
