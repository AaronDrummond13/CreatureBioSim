/// Cell type for food items. Plant = green hexagon; animal = red circle; bubble = pop-able bubble (same look as background).
enum CellType { plant, animal, bubble }

/// A plant or animal cell (food) in world space. See [FoodPainter].
/// Linked to chunk [chunkCx], [chunkCy] for culling (updated on drift so culling only removes food in that chunk).
/// When [isGiant] is true, cannot be eaten; [radiusWorld] is its size; renders on top layer as cover.
/// [attachedOffsets] on a giant: relative (dx, dy) for edible normal plant cells at the corners; consumed ones are removed from the list.
class FoodItem {
  FoodItem(
    this.x,
    this.y,
    this.chunkCx,
    this.chunkCy, {
    this.nucleusOffsetX = 0,
    this.nucleusOffsetY = 0,
    this.cellType = CellType.plant,
    this.isGiant = false,
    this.radiusWorld,
    this.attachedOffsets,
    this.rotationSign = 1.0,
  });

  final double x;
  final double y;
  final int chunkCx;
  final int chunkCy;
  final double nucleusOffsetX;
  final double nucleusOffsetY;
  final CellType cellType;
  final bool isGiant;
  final double? radiusWorld;
  /// 1.0 = clockwise, -1.0 = anticlockwise (when multiplied by time for rotation).
  final double rotationSign;

  /// Mutable: remove an element when that corner cell is eaten.
  final List<(double, double)>? attachedOffsets;
}
