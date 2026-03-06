/// Tail (caudal) fin shape. Rendered under the body, flaring out behind the tail.
enum CaudalFinType {
  /// Straight trailing edge, paddle-like (tip at ~80% length).
  truncate,
  /// Rounded trailing edge (extra nodes at tip/arc and taper).
  rounded,
  /// Slightly notched trailing edge; tip inset (e.g. ~65% length).
  emarginate,
  /// Crescent-shaped; narrow at base, broad lobes (lunate = moon-shaped).
  lunate,
  /// Deeply notched; two long lobes, tip well inset (~35% length).
  forked,
  /// Single point at full length; no notch or lobes.
  pointed,
  /// Diamond-shaped; pointed tip at full length with angled sides.
  rhomboid,
}

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

  /// Caudal (tail) fin type. Null = no tail fin. Rendered under the body.
  final CaudalFinType? tailFin;

  /// Lateral fins (pectoral, pelvic, anal, etc.): vertex indices where a fin is attached.
  /// Rendered under the body as rotated ellipses. Only indices < segmentCount (not head) are valid.
  final List<int>? lateralFins;

  /// Number of spine segments (vertexWidths.length - 1).
  int get segmentCount => vertexWidths.length - 1;

  Creature({
    required List<double> vertexWidths,
    this.dorsalFins,
    this.finColor,
    this.tailFin,
    this.lateralFins,
    this.color = 0xFF2E7D32,
  }) : vertexWidths = vertexWidths.map((w) => w.clamp(minVertexWidth, maxVertexWidth)).toList();
}
