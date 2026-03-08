import 'package:flutter/material.dart';

import 'package:creature_bio_sim/world/biome.dart';
import 'package:creature_bio_sim/world/world.dart';

/// Stable biome layer. One biome per region; regions are 10×10 chunks (5000×5000 world units).
/// 10×10 grid of regions that wraps. Never culled; same region always returns same biome.
class BiomeMap {
  BiomeMap();

  /// Deterministic biome for region (bx, by). [bx], [by] should be wrapped 0..kBiomeGridSize-1.
  Biome biomeAtRegion(int bx, int by) {
    final h = (bx * 31 + by).hashCode;
    final index = (h % Biome.values.length).abs();
    return Biome.values[index];
  }

  /// Biome at world (x, y) — single region (no blending).
  Biome biomeAt(double x, double y) {
    final bx = wrapBiomeRegion((x / kBiomeRegionSizeWorld).floor());
    final by = wrapBiomeRegion((y / kBiomeRegionSizeWorld).floor());
    return biomeAtRegion(bx, by);
  }

  /// Blended colour at world (x, y). Bilinear blend of the 4 neighbouring region corners.
  Color blendedColorAt(double x, double y) {
    final regionSize = kBiomeRegionSizeWorld;
    final cx = (x / regionSize).floor();
    final cy = (y / regionSize).floor();
    final fx = (x - cx * regionSize) / regionSize;
    final fy = (y - cy * regionSize) / regionSize;
    final u = fx.clamp(0.0, 1.0);
    final v = fy.clamp(0.0, 1.0);

    final c00 = biomeAtRegion(wrapBiomeRegion(cx), wrapBiomeRegion(cy)).color;
    final c10 =
        biomeAtRegion(wrapBiomeRegion(cx + 1), wrapBiomeRegion(cy)).color;
    final c01 =
        biomeAtRegion(wrapBiomeRegion(cx), wrapBiomeRegion(cy + 1)).color;
    final c11 =
        biomeAtRegion(wrapBiomeRegion(cx + 1), wrapBiomeRegion(cy + 1)).color;

    return Color.lerp(
      Color.lerp(c00, c10, u)!,
      Color.lerp(c01, c11, u)!,
      v,
    )!;
  }
}
