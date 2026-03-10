/// World coordinate system and chunk grid.
///
/// **Two layers:**
/// - **Chunks** (500 units): base grid. Used for mutable state (food, future: creatures, etc.)
///   that can be culled when far and regenerated when back. Chunk index is stable; chunk *state* varies.
/// - **Biome regions** (10×10 chunks = 5000 units): stable data. One biome per region; never culled.
///   Wraps on a 10×10 grid. Other stable per-region data can be added here.
///
/// All world positions and chunk indices are in the same coordinate system.

/// Chunk size in world units. One chunk = one square cell of the base grid.
const double kChunkSizeWorld = 500.0;

/// Number of chunks per biome region along one axis. One biome region = [kBiomeRegionChunks]×[kBiomeRegionChunks] chunks.
const int kBiomeRegionChunks = 10;

/// Biome region size in world units (= one side of the square region).
const double kBiomeRegionSizeWorld = kChunkSizeWorld * kBiomeRegionChunks;

/// Biome grid size (wrap). 10×10 biome regions that wrap.
const int kBiomeGridSize = 10;

/// Radius (world units) around the camera for chunk load/cull. Chunks within this distance are kept; food and creatures are generated for them.
const double kChunkLoadRadiusWorld = 4000.0;

/// Chunk index for world x (unbounded).
int chunkIndexX(double worldX) => (worldX / kChunkSizeWorld).floor();

/// Chunk index for world y (unbounded).
int chunkIndexY(double worldY) => (worldY / kChunkSizeWorld).floor();

/// Chunk index (cx, cy) for world position (x, y).
(int, int) chunkIndex(double x, double y) =>
    (chunkIndexX(x), chunkIndexY(y));

/// Biome region index (bx, by) from chunk index (cx, cy). One region = 10×10 chunks.
(int, int) biomeRegionFromChunk(int cx, int cy) =>
    (cx ~/ kBiomeRegionChunks, cy ~/ kBiomeRegionChunks);

/// Wrap a biome region index to 0..kBiomeGridSize-1.
int wrapBiomeRegion(int value) {
  final v = value % kBiomeGridSize;
  return v < 0 ? v + kBiomeGridSize : v;
}

/// Wrapped biome region (bx, by) from chunk (cx, cy).
(int, int) wrappedBiomeRegionFromChunk(int cx, int cy) => (
      wrapBiomeRegion(cx ~/ kBiomeRegionChunks),
      wrapBiomeRegion(cy ~/ kBiomeRegionChunks),
    );

/// Stable string key for chunk (cx, cy). Use for sets/maps of generated chunks, etc.
String chunkKey(int cx, int cy) => '$cx,$cy';

/// Squared distance from point (px, py) to AABB [x0,x1]×[y0,y1]. 0 if point inside.
double distSqToAabb(double px, double py, double x0, double x1, double y0, double y1) {
  final dx = px < x0 ? x0 - px : (px > x1 ? px - x1 : 0.0);
  final dy = py < y0 ? y0 - py : (py > y1 ? py - y1 : 0.0);
  return dx * dx + dy * dy;
}

/// True if circle (cx, cy, r) overlaps axis-aligned rect [left, right]×[top, bottom].
bool circleOverlapsRect(
  double cx, double cy, double r,
  double left, double right, double top, double bottom,
) =>
    !(cx + r < left || cx - r > right || cy + r < top || cy - r > bottom);

/// True if AABB [minX, maxX]×[minY, maxY] overlaps rect [left, right]×[top, bottom].
bool aabbOverlapsRect(
  double minX, double maxX, double minY, double maxY,
  double left, double right, double top, double bottom,
) =>
    !(maxX < left || minX > right || maxY < top || minY > bottom);
