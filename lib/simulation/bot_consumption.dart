import 'package:creature_bio_sim/controller/creature_store.dart';
import 'package:creature_bio_sim/controller/food_store.dart';
import 'package:creature_bio_sim/creature.dart' show TrophicType;
import 'package:creature_bio_sim/simulation/creature_collision.dart';
import 'package:creature_bio_sim/world/food.dart' show CellType;

/// Bot consumption rules: bots eat food (by trophic type), non-herbivore bots eat
/// babies, epic carnivore/omnivore bots eat non-epic creatures.
void runBotConsumption(
  FoodStore foodStore,
  CreatureStore creatureStore,
  double timeSeconds, {
  double headMouthSizeFrac = 0.8,
}) {
  final foodRadius = foodStore.radiusWorld;
  for (final e in creatureStore.entities) {
    if (e.isBaby || e.spine.positions.isEmpty) continue;
    final head = e.spine.positions.last;
    final headR = eaterHeadRadius(e.creature, isEpic: e.isEpic, mouthFrac: headMouthSizeFrac);
    final consumeRadius = foodRadius + headR;
    final allowedFood =
        e.creature.mouth == null || e.creature.trophicType == TrophicType.none
            ? {CellType.bubble}
            : (e.creature.trophicType == TrophicType.herbivore
                ? {CellType.plant, CellType.bubble}
                : (e.creature.trophicType == TrophicType.carnivore
                    ? {CellType.animal, CellType.bubble}
                    : null));
    foodStore.consumeNear(
      head.x,
      head.y,
      consumeRadius,
      timeSeconds,
      allowedFood,
      false,
      e.isEpic,
    );
  }
  // Non-herbivore bots eat babies — check eater head vs baby full body.
  final babiesToRemove = <StoredCreature>[];
  for (final e in creatureStore.entities) {
    if (e.isBaby ||
        e.creature.trophicType == TrophicType.herbivore ||
        e.creature.trophicType == TrophicType.none) continue;
    final pos = e.spine.positions;
    if (pos.isEmpty) continue;
    final head = pos.last;
    final headR = eaterHeadRadius(e.creature, isEpic: e.isEpic, mouthFrac: headMouthSizeFrac);
    for (final other in creatureStore.entities) {
      if (!other.isBaby || identical(e, other)) continue;
      if (pointHitsCreature(
        head.x, head.y,
        other.spine, other.creature,
        attackRadius: headR,
        targetIsBaby: true,
      )) {
        babiesToRemove.add(other);
        break;
      }
    }
  }
  for (final b in babiesToRemove) {
    final pos = b.spine.positions;
    if (pos.isEmpty) continue;
    final bx = pos.last.x;
    final by = pos.last.y;
    foodStore.addConsumedRemnantAt(
      bx, by, timeSeconds, bx, by,
      cellType: CellType.animal,
    );
    creatureStore.removeCreature(b);
  }
  // Epic carnivore/omnivore bots eat non-epic creatures — check epic head vs target full body.
  final nonEpicsToRemove = <StoredCreature>{};
  for (final e in creatureStore.entities) {
    if (!e.isEpic || e.isBaby || e.spine.positions.isEmpty) continue;
    if (e.creature.trophicType != TrophicType.carnivore &&
        e.creature.trophicType != TrophicType.omnivore) continue;
    final head = e.spine.positions.last;
    final headR = eaterHeadRadius(e.creature, isEpic: true, mouthFrac: headMouthSizeFrac);
    for (final other in creatureStore.entities) {
      if (other.isEpic || identical(e, other)) continue;
      if (pointHitsCreature(
        head.x, head.y,
        other.spine, other.creature,
        attackRadius: headR,
      )) {
        nonEpicsToRemove.add(other);
      }
    }
  }
  for (final b in nonEpicsToRemove) {
    final pos = b.spine.positions;
    if (pos.isEmpty) continue;
    final bx = pos.last.x;
    final by = pos.last.y;
    foodStore.addConsumedRemnantAt(
      bx, by, timeSeconds, bx, by,
      cellType: CellType.animal,
    );
    creatureStore.removeCreature(b);
  }
}
