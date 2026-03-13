import 'dart:math' show atan2, cos, sin, sqrt;

import 'package:creature_bio_sim/controller/chunk_manager.dart';
import 'package:creature_bio_sim/controller/creature_store.dart';
import 'package:creature_bio_sim/controller/food_store.dart';
import 'package:creature_bio_sim/controller/mammoth_store.dart';
import 'package:creature_bio_sim/creature.dart' show Creature, TrophicType;
import 'package:creature_bio_sim/simulation/bot_consumption.dart';
import 'package:creature_bio_sim/simulation/creature_collision.dart';
import 'package:creature_bio_sim/simulation/spine.dart';
import 'package:creature_bio_sim/simulation_view_state.dart';
import 'package:creature_bio_sim/world/food.dart' show CellType;
import 'package:creature_bio_sim/world/world.dart' show kChunkLoadRadiusWorld, kChunkCullRadiusWorld;

/// Mutable output from [runPlayStep]: death flag and last ate time.
class PlayStepOutput {
  bool isDead = false;
  double? lastAteTimeSeconds;
}

/// Runs one simulation step: joystick target, death check, player move/consume,
/// world tick, bot consumption.
void runPlayStep(
  SimulationViewState viewState,
  Spine spine,
  Creature creature,
  CreatureStore creatureStore,
  FoodStore foodStore,
  MammothStore mammothStore,
  ChunkManager chunkManager,
  PlayStepOutput output, {
  double headMoveSpeed = Spine.defaultMoveSpeed,
  double arrivalThreshold = 20.0,
  double headMouthSizeFrac = 0.8,
  double joystickTargetDistance = 120.0,
}) {
  viewState.refreshTouchFromStoredLocal();
  final positions = spine.positions;
  if (positions.isNotEmpty &&
      viewState.isJoystickActive &&
      viewState.joystickOffset != null) {
    final head = positions.last;
    final off = viewState.joystickOffset!;
    final len = off.distance;
    if (len > 1e-6) {
      final angle = atan2(off.dy, off.dx);
      viewState.touchX = head.x + joystickTargetDistance * cos(angle);
      viewState.touchY = head.y + joystickTargetDistance * sin(angle);
    } else {
      viewState.touchX = head.x;
      viewState.touchY = head.y;
    }
  }
  if (positions.isNotEmpty && !output.isDead) {
    final head = positions.last;
    final headSize = creature.segmentWidths.isNotEmpty
        ? creature.segmentWidths.last
        : foodStore.radiusWorld;
    final headCollision = headSize * headMouthSizeFrac;
    for (final e in creatureStore.entities) {
      if (!e.isEpic) continue;
      if (e.creature.trophicType == TrophicType.herbivore) continue;
      final ep = e.spine.positions;
      if (ep.isEmpty) continue;
      final epicHeadR = eaterHeadRadius(e.creature, isEpic: true, mouthFrac: headMouthSizeFrac);
      if (pointHitsCreature(
        ep.last.x, ep.last.y,
        spine, creature,
        attackRadius: epicHeadR,
      )) {
        output.isDead = true;
        foodStore.addConsumedRemnantAt(
          head.x,
          head.y,
          viewState.timeSeconds,
          head.x,
          head.y,
          cellType: CellType.animal,
          scale: 4.0,
        );
        break;
      }
    }
    if (!output.isDead) {
      final dx = viewState.touchX - head.x;
      final dy = viewState.touchY - head.y;
      final len = sqrt(dx * dx + dy * dy);
      if (len <= arrivalThreshold) {
        spine.resolve(
          head.x,
          head.y,
          intendedTargetX: viewState.touchX,
          intendedTargetY: viewState.touchY,
        );
      } else {
        final step = headMoveSpeed / len;
        final nx = head.x + dx * step;
        final ny = head.y + dy * step;
        spine.resolve(
          nx,
          ny,
          intendedTargetX: viewState.touchX,
          intendedTargetY: viewState.touchY,
        );
      }
      final headAfter = spine.positions.last;
      final consumeRadius = foodStore.radiusWorld + headCollision;
      final allowedFood =
          creature.mouth == null || creature.trophicType == TrophicType.none
              ? {CellType.bubble}
              : (creature.trophicType == TrophicType.herbivore
                  ? {CellType.plant, CellType.bubble}
                  : (creature.trophicType == TrophicType.carnivore
                      ? {CellType.animal, CellType.bubble}
                      : null));
      final consumed = foodStore.consumeNear(
        headAfter.x,
        headAfter.y,
        consumeRadius,
        viewState.timeSeconds,
        allowedFood,
        true,
      );
      if (consumed > 0) output.lastAteTimeSeconds = viewState.timeSeconds;
      if (creature.trophicType != TrophicType.herbivore &&
          creature.trophicType != TrophicType.none) {
        for (final e in creatureStore.entities) {
          if (!e.isBaby) continue;
          final pos = e.spine.positions;
          if (pos.isEmpty) continue;
          final bx = pos.last.x;
          final by = pos.last.y;
          final bdx = headAfter.x - bx;
          final bdy = headAfter.y - by;
          if (bdx * bdx + bdy * bdy <= consumeRadius * consumeRadius) {
            foodStore.addConsumedRemnantAt(
              bx,
              by,
              viewState.timeSeconds,
              headAfter.x,
              headAfter.y,
              cellType: CellType.animal,
              consumedByPlayer: true,
            );
            creatureStore.removeCreature(e);
            output.lastAteTimeSeconds = viewState.timeSeconds;
          }
        }
      }
    }
  }
  mammothStore.tick();
  if (viewState.viewWidthWorld > 0 && viewState.viewHeightWorld > 0) {
    mammothStore.update(viewState.cameraX, viewState.cameraY);
    chunkManager.update(
      viewState.cameraX,
      viewState.cameraY,
      kChunkLoadRadiusWorld,
      kChunkCullRadiusWorld,
    );
    creatureStore.tick();
    runBotConsumption(
      foodStore,
      creatureStore,
      viewState.timeSeconds,
      headMouthSizeFrac: headMouthSizeFrac,
    );
  }
  foodStore.tick(viewState.timeSeconds);
}
