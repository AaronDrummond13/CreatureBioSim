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

/// Tail (caudal) fin config: type and optional dimensions. Null dimension = derive in renderer.
class TailConfig {
  static const double rootWidthMin = 1.0;
  static const double rootWidthMax = 25.0;
  static const double maxWidthMin = 10.0;
  static const double maxWidthMax = 40.0;
  static const double lengthMin = 50.0;
  static const double lengthMax = 150.0;

  TailConfig(this.type, {double? rootWidth, double? maxWidth, double? length})
    : rootWidth = rootWidth?.clamp(rootWidthMin, rootWidthMax),
      maxWidth = maxWidth?.clamp(maxWidthMin, maxWidthMax),
      length = length?.clamp(lengthMin, lengthMax);

  final CaudalFinType type;
  final double? rootWidth;
  final double? maxWidth;
  final double? length;

  TailConfig copyWith({
    CaudalFinType? type,
    double? rootWidth,
    double? maxWidth,
    double? length,
  }) => TailConfig(
    type ?? this.type,
    rootWidth: rootWidth ?? this.rootWidth,
    maxWidth: maxWidth ?? this.maxWidth,
    length: length ?? this.length,
  );
}

/// What a creature can eat. None = no mouth, bubbles only; herbivore = plant + bubbles; carnivore = animal + bubbles + babies; omnivore = all (balance TBD).
enum TrophicType { none, herbivore, carnivore, omnivore }

/// Mouth style. Null = no mouth. Tentacle = shrimp/herbivore (wiggly). Teeth = carnivore (rigid spikes). Mandible = omnivore (ant-like, open/close).
enum MouthType { tentacle, teeth, mandible }

/// Creature definition: identity and appearance, outside engine and renderer.
/// Spine length is implied by [segmentWidths] (segmentCount = segmentWidths.length). Capped at [maxSegmentCount].
class Creature {
  static const double minVertexWidth = 10.0;
  static const double maxVertexWidth = 50.0;
  static const int maxSegmentCount = 15;

  /// Fill colour as 0xAARRGGBB. Renderer uses this when drawing.
  final int color;

  /// Per-segment half-widths (spine to outline). Length = segmentCount. segmentWidths[seg] = width of segment from vertex seg to vertex seg+1.
  final List<double> segmentWidths;

  /// Dorsal fins: (segment indices, optional height). Height in world units; null uses renderer default.
  final List<(List<int>, double?)>? dorsalFins;

  /// Fin colour as 0xAARRGGBB. When null, a lighter tint of body color is used.
  final int? finColor;

  /// Tail (caudal) fin. Null = no tail. Rendered under the body; null dimensions in config are derived.
  final TailConfig? tail;

  /// Lateral fins (pectoral, pelvic, anal, etc.): segment indices where a fin is attached.
  /// Rendered under the body as rotated ellipses. Only indices < segmentCount are valid.
  final List<int>? lateralFins;

  /// Diet: herbivore (plant only), carnivore (animal + babies), omnivore (all).
  final TrophicType trophicType;

  /// Mouth style. Null = no mouth drawn. Default tentacle (shrimp/herbivore feelers).
  final MouthType? mouth;

  /// Number of spine segments (segmentWidths.length), capped at [maxSegmentCount].
  int get segmentCount => segmentWidths.length;

  /// Effective half-width at vertex [vertexIndex] (0 = tail, segmentCount = head). Derived from segment widths.
  double widthAtVertex(int vertexIndex) {
    if (segmentWidths.isEmpty) return maxVertexWidth;
    final n = segmentWidths.length;
    if (vertexIndex <= 0) return segmentWidths[0].clamp(minVertexWidth, maxVertexWidth);
    if (vertexIndex >= n) return segmentWidths[n - 1].clamp(minVertexWidth, maxVertexWidth);
    final a = segmentWidths[vertexIndex - 1].clamp(minVertexWidth, maxVertexWidth);
    final b = segmentWidths[vertexIndex].clamp(minVertexWidth, maxVertexWidth);
    return (a + b) / 2;
  }

  Creature({
    required List<double> segmentWidths,
    this.dorsalFins,
    this.finColor,
    this.tail,
    this.lateralFins,
    this.trophicType = TrophicType.herbivore,
    this.mouth,
    this.color = 0xFF2E7D32,
  }) : segmentWidths = segmentWidths
           .take(maxSegmentCount)
           .map((w) => w.clamp(minVertexWidth, maxVertexWidth))
           .toList();
}
