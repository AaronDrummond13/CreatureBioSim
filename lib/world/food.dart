/// Cell type for food items. Plant = green hexagon; animal = red circle; bubble = pop-able bubble (same look as background).
enum CellType { plant, animal, bubble }

/// A plant or animal cell (food) in world space. See [FoodPainter].
/// Linked to chunk [chunkCx], [chunkCy] for culling (updated on drift so culling only removes food in that chunk).
class FoodItem {
  FoodItem(
    this.x,
    this.y,
    this.chunkCx,
    this.chunkCy, {
    this.nucleusOffsetX = 0,
    this.nucleusOffsetY = 0,
    this.cellType = CellType.plant,
  });

  final double x;
  final double y;
  final int chunkCx;
  final int chunkCy;
  final double nucleusOffsetX;
  final double nucleusOffsetY;
  final CellType cellType;
}
