import 'package:creature_bio_sim/world/food.dart';

/// Remnant after consumption: nucleus stays, drifts away from [headX, headY], and fades over 5s; body "burst" drawn for ~0.3s. See [FoodPainter].
class ConsumedRemnant {
  ConsumedRemnant({
    required this.x,
    required this.y,
    required this.nucleusOffsetX,
    required this.nucleusOffsetY,
    required this.cellType,
    required this.consumedAt,
    required this.headX,
    required this.headY,
    required this.bubbleSizes,
    this.scale = 1.0,
  });
  final double x, y, nucleusOffsetX, nucleusOffsetY;
  final CellType cellType;
  final double consumedAt;
  final double headX, headY;

  /// One entry per bubble (1–3). Each value 0=small, 1=medium, 2=large.
  final List<int> bubbleSizes;

  /// Scale for drawing (e.g. 4.0 for player death remains).
  final double scale;
}
