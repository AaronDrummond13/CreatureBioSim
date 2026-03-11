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

/// Eye placement: segment index, offset from spine (0 = single centre eye, (0,1] = symmetric pair at that fraction of half-width), radius in world units.
class EyeConfig {
  static const double offsetMin = 0.0;
  static const double offsetMax = 1.0;
  static const double radiusMin = 2.0;
  static const double radiusMax = 18.0;
  static const double radiusDefault = 6.0;
  /// When offsetFromCenter < this, draw a single eye on the spine; otherwise symmetric pair.
  static const double singleEyeThreshold = 0.08;

  EyeConfig(this.segment, {double? offsetFromCenter, double? radius})
    : offsetFromCenter = (offsetFromCenter ?? 0.0).clamp(offsetMin, offsetMax),
      radius = (radius ?? radiusDefault).clamp(radiusMin, radiusMax);

  final int segment;
  final double offsetFromCenter;
  final double radius;

  EyeConfig copyWith({int? segment, double? offsetFromCenter, double? radius}) =>
      EyeConfig(
        segment ?? this.segment,
        offsetFromCenter: offsetFromCenter ?? this.offsetFromCenter,
        radius: radius ?? this.radius,
      );
}

/// Lateral (pectoral) fin wing shape.
enum LateralWingType {
  /// Ellipse (default).
  ellipse,
  /// Shark-style: triangle with two curved (hook) edges.
  sharkWing,
  /// Shark-style with concave rear curve.
  sharkConcave,
  /// Paddle: same shape as shark wing.
  paddle,
  /// Paddle with concave rear curve.
  paddleConcave,
}

/// Pectoral/lateral fin: segment index, size, flare angle, and wing shape.
class LateralFinConfig {
  static const double lengthMin = 12.0;
  static const double lengthMax = 60.0;
  static const double lengthDefault = 30.0;
  static const double widthMin = 6.0;
  static const double widthMax = 20.0;
  static const double widthDefault = 10.0;
  static const double angleDegreesMin = 10.0;
  static const double angleDegreesMax = 80.0;
  static const double angleDegreesDefault = 45.0;

  LateralFinConfig(this.segment, {double? length, double? width, double? angleDegrees, LateralWingType? wingType})
    : length = (length ?? lengthDefault).clamp(lengthMin, lengthMax),
      width = (width ?? widthDefault).clamp(widthMin, widthMax),
      angleDegrees = (angleDegrees ?? angleDegreesDefault).clamp(angleDegreesMin, angleDegreesMax),
      wingType = wingType ?? LateralWingType.ellipse;

  final int segment;
  final double length;
  final double width;
  /// Flare angle in degrees (10–80). Left fin: spineAngle + this; right: spineAngle - this.
  final double angleDegrees;
  final LateralWingType wingType;

  LateralFinConfig copyWith({int? segment, double? length, double? width, double? angleDegrees, LateralWingType? wingType}) =>
      LateralFinConfig(
        segment ?? this.segment,
        length: length ?? this.length,
        width: width ?? this.width,
        angleDegrees: angleDegrees ?? this.angleDegrees,
        wingType: wingType ?? this.wingType,
      );
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

  /// Lateral (pectoral) fins: segment and size per fin. Rendered under the body as rotated ellipses.
  final List<LateralFinConfig>? lateralFins;

  /// Diet: herbivore (plant only), carnivore (animal + babies), omnivore (all).
  final TrophicType trophicType;

  /// Mouth style. Null = no mouth drawn. Default tentacle (shrimp/herbivore feelers).
  final MouthType? mouth;

  /// Optional eye placements (segment, offset, radius). When null or empty, renderer may use default head eyes for non-babies.
  final List<EyeConfig>? eyes;

  /// Number of spine segments (segmentWidths.length), capped at [maxSegmentCount].
  int get segmentCount => segmentWidths.length;

  /// Effective half-width at vertex [vertexIndex] (0 = tail, segmentCount = head). Derived from segment widths.
  double widthAtVertex(int vertexIndex) {
    if (segmentWidths.isEmpty) return maxVertexWidth;
    final n = segmentWidths.length;
    if (vertexIndex <= 0)
      return segmentWidths[0].clamp(minVertexWidth, maxVertexWidth);
    if (vertexIndex >= n)
      return segmentWidths[n - 1].clamp(minVertexWidth, maxVertexWidth);
    final a = segmentWidths[vertexIndex - 1].clamp(
      minVertexWidth,
      maxVertexWidth,
    );
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
    this.eyes,
    this.color = 0xFF2E7D32,
  }) : segmentWidths = segmentWidths
           .take(maxSegmentCount)
           .map((w) => w.clamp(minVertexWidth, maxVertexWidth))
           .toList();
}
