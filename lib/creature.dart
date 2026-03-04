/// Creature definition: identity and appearance, outside engine and renderer.
/// Spine length (segment count) and colour. Engine and renderer use this data.
class Creature {
  /// Number of spine segments (spine length).
  final int segmentCount;

  /// Fill colour as 0xAARRGGBB. Renderer uses this when drawing.
  final int color;

  const Creature({
    this.segmentCount = 20,
    this.color = 0xFF2E7D32,
  });
}
