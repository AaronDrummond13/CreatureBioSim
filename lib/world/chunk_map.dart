import 'package:flutter/material.dart';

import 'biome.dart';

/// Deterministic 10×10 grid of chunks; world position maps with wrapping.
/// Chunk biome from hash of (cx, cy). Blended colour at (x,y) from 4 neighbouring chunks.
class ChunkMap {
  ChunkMap({
    this.chunkSize = 5000.0,
    this.gridSize = 10,
  });

  final double chunkSize;
  final int gridSize;

  int _wrap(int value) {
    final v = value % gridSize;
    return v < 0 ? v + gridSize : v;
  }

  /// Chunk index for world x (wraps 0..gridSize-1).
  int chunkX(double worldX) => _wrap((worldX / chunkSize).floor());

  /// Chunk index for world y (wraps 0..gridSize-1).
  int chunkY(double worldY) => _wrap((worldY / chunkSize).floor());

  /// Deterministic biome for chunk (cx, cy). Hash-based.
  Biome biomeAtChunk(int cx, int cy) {
    final wrappedCx = _wrap(cx);
    final wrappedCy = _wrap(cy);
    final h = (wrappedCx * 31 + wrappedCy).hashCode;
    final index = (h % Biome.values.length).abs();
    return Biome.values[index];
  }

  /// Blended colour at world (x, y). Weights from distance to chunk boundaries (bilinear).
  Color blendedColorAt(double x, double y) {
    final cx = (x / chunkSize).floor();
    final cy = (y / chunkSize).floor();
    final fx = (x - cx * chunkSize) / chunkSize;
    final fy = (y - cy * chunkSize) / chunkSize;
    // Clamp to [0,1] for edge case when exactly on boundary
    final u = fx.clamp(0.0, 1.0);
    final v = fy.clamp(0.0, 1.0);

    final c00 = biomeAtChunk(cx, cy).color;
    final c10 = biomeAtChunk(cx + 1, cy).color;
    final c01 = biomeAtChunk(cx, cy + 1).color;
    final c11 = biomeAtChunk(cx + 1, cy + 1).color;

    return Color.lerp(
      Color.lerp(c00, c10, u)!,
      Color.lerp(c01, c11, u)!,
      v,
    )!;
  }
}
