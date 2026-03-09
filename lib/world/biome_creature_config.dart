import 'package:creature_bio_sim/world/biome.dart';

/// Per-chunk creature spawn targets per biome. Edit values to tune (fractional = chance, e.g. 0.3 = 30% of 1).
class BiomeCreatureConfig {
  const BiomeCreatureConfig({
    this.groupsPerChunk = 0.08,
    this.singlesPerChunk = 0.02,
    this.epicsPerChunk = 0.007,
  });
  final double groupsPerChunk;
  final double singlesPerChunk;
  final double epicsPerChunk;
}

/// Creature rates per biome.
BiomeCreatureConfig biomeCreatureConfig(Biome biome) {
  switch (biome) {
    case Biome.wasteland:
      return const BiomeCreatureConfig(
        groupsPerChunk: 0,
        singlesPerChunk: 0,
        epicsPerChunk: 0,
      );
    default:
      return const BiomeCreatureConfig();
  }
}
