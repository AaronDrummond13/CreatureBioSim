/// Creature definition: identity and appearance, outside engine and renderer.
/// Spine length is implied by [vertexWidths] (segmentCount = vertexWidths.length - 1).
class Creature {
  static const double minVertexWidth = 10.0;
  static const double maxVertexWidth = 50.0;

  /// Fill colour as 0xAARRGGBB. Renderer uses this when drawing.
  final int color;

  /// Per-vertex half-widths (spine to outline). Length = segmentCount + 1. Each value clamped to [minVertexWidth, maxVertexWidth].
  final List<double> vertexWidths;

  /// Dorsal fins: (segment indices, optional height). Height in world units; null uses renderer default.
  final List<(List<int>, double?)>? dorsalFins;

  /// Fin colour as 0xAARRGGBB. When null, a lighter tint of body color is used.
  final int? finColor;

  /// Number of spine segments (vertexWidths.length - 1).
  int get segmentCount => vertexWidths.length - 1;

  Creature({
    required List<double> vertexWidths,
    this.dorsalFins,
    this.finColor,
    this.color = 0xFF2E7D32,
  }) : vertexWidths = vertexWidths.map((w) => w.clamp(minVertexWidth, maxVertexWidth)).toList();

  /// Creature with [segmentCount] segments and uniform width (clamped to min/max).
  factory Creature.withSegments(
    int segmentCount, {
    int color = 0xFF2E7D32,
    double width = 30.0,
    List<(List<int>, double?)>? dorsalFins,
    int? finColor,
  }) {
    final w = width.clamp(minVertexWidth, maxVertexWidth);
    return Creature(
      vertexWidths: List.filled(segmentCount + 1, w),
      dorsalFins: dorsalFins,
      finColor: finColor,
      color: color,
    );
  }
}
