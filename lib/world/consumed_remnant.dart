import 'package:creature_bio_sim/world/food.dart';

/// Remnant after consumption: nucleus stays, drifts away from [headX, headY], and fades over 5s; body "burst" drawn for ~0.3s. See [FoodPainter].
/// When [consumedByPlayer] is true, the inner-body cloud (InnerBodyCloudPainter) is drawn for this remnant; otherwise only the top-layer burst/nucleus is drawn.
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
    this.consumedByPlayer = false,
  });
  final double x, y, nucleusOffsetX, nucleusOffsetY;
  final CellType cellType;
  final double consumedAt;
  final double headX, headY;

  /// One entry per bubble (1–3). Each value 0=small, 1=medium, 2=large.
  final List<int> bubbleSizes;

  /// Scale for drawing (e.g. 4.0 for player death remains).
  final double scale;

  /// True when the player consumed this; only these remnants drive the red/green cloud inside the player's body.
  final bool consumedByPlayer;
}
