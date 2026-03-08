import 'biome.dart';

/// Per-chunk creature spawn targets per biome. Edit values to tune (fractional = chance, e.g. 0.3 = 30% of 1).
class BiomeCreatureConfig {
  const BiomeCreatureConfig({
    this.groupsPerChunk = 0.07,
    this.singlesPerChunk = 0.03,
    this.epicsPerChunk = 0.005,
  });
  final double groupsPerChunk;
  final double singlesPerChunk;
  final double epicsPerChunk;
}

/// Creature rates per biome. For now all biomes use default; add switch later for per-biome tuning.
BiomeCreatureConfig biomeCreatureConfig(Biome biome) {
  return const BiomeCreatureConfig();
}
