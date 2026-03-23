import 'package:flutter/material.dart';

import 'package:bioism/controller/creature_store.dart';
import 'package:bioism/controller/food_store.dart';
import 'package:bioism/controller/mammoth_store.dart';
import 'package:bioism/creature.dart';
import 'package:bioism/render/background_painter.dart'
    show BackgroundPainter, SolidBackgroundPainter;
import 'package:bioism/render/creature_painter.dart';
import 'package:bioism/render/food_painter.dart';
import 'package:bioism/render/inner_body_cloud_painter.dart';
import 'package:bioism/render/mammoth_painter.dart';
import 'package:bioism/simulation/spine.dart';
import 'package:bioism/simulation_view_state.dart';
import 'package:bioism/world/biome_map.dart';
import 'package:bioism/world/world.dart'
    show aabbOverlapsRect, circleOverlapsRect;

/// Player creature render levels (back-to-front). Used to order painter layers.
///
/// 1. Tail fin + lateral fins
/// 2. Body (mouth drawn in same pass before body fill)
/// 3. Digestion cloud (inner-body consumed remnants)
/// 4. Dorsal fin + eyes (drawn together above cloud)
const int playerCreatureLevelCount = 4;

/// Builds the ordered list of paint layers for the play (simulation) screen.
List<Widget> buildSimulationLayers({
  required Size size,
  required SimulationViewState viewState,
  required FoodStore foodStore,
  required CreatureStore creatureStore,
  required MammothStore mammothStore,
  required BiomeMap biomeMap,
  required Creature creature,
  required Spine spine,
  required bool isDead,
  required double? lastAteTimeSeconds,
}) {
  viewState.setViewSize(size);
  final cameraView = viewState.cameraView;
  final bgView = viewState.backgroundCameraView();
  final t = viewState.timeSeconds;
  final bgColor = Color.lerp(
    const Color.fromARGB(255, 28, 30, 54),
    biomeMap.blendedColorAt(viewState.cameraX, viewState.cameraY),
    .4,
  )!;
  final (left, right, top, bottom) = viewState.renderRectWithBuffer(0.15);
  final r = foodStore.radiusWorld;
  final visibleItems = foodStore.items
      .where(
        (i) =>
            !i.isGiant &&
            circleOverlapsRect(i.x, i.y, r, left, right, top, bottom),
      )
      .toList();
  final visibleGiantItems = foodStore.items
      .where(
        (i) =>
            i.isGiant &&
            circleOverlapsRect(
              i.x,
              i.y,
              i.radiusWorld ?? r,
              left,
              right,
              top,
              bottom,
            ),
      )
      .toList();
  const remnantRadius = 220.0;
  final visibleRemnants = foodStore.consumedRemnants
      .where(
        (remnant) => circleOverlapsRect(
          remnant.x,
          remnant.y,
          remnantRadius,
          left,
          right,
          top,
          bottom,
        ),
      )
      .toList();
  const creatureMargin = 50.0;
  final visibleEntities = creatureStore.entities.where((e) {
    final pos = e.spine.positions;
    if (pos.isEmpty) return false;
    var minX = pos[0].x, maxX = pos[0].x, minY = pos[0].y, maxY = pos[0].y;
    for (final p in pos) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }
    return aabbOverlapsRect(
      minX - creatureMargin,
      maxX + creatureMargin,
      minY - creatureMargin,
      maxY + creatureMargin,
      left,
      right,
      top,
      bottom,
    );
  }).toList();
  final babyEntities = visibleEntities.where((e) => e.isBaby).toList();
  final normalEntities = visibleEntities
      .where((e) => !e.isBaby && !e.isEpic)
      .toList();
  final epicEntities = visibleEntities.where((e) => e.isEpic).toList();
  final visibleMammoths = mammothStore.getVisible(
    viewState.cameraX,
    viewState.cameraY,
    viewState.viewWidthWorld,
    viewState.viewHeightWorld,
  );
  return [
    Positioned.fill(
      child: CustomPaint(painter: SolidBackgroundPainter(color: bgColor)),
    ),
    Positioned.fill(
      child: CustomPaint(
        painter: MammothPainter(
          mammoths: visibleMammoths,
          view: bgView,
          timeSeconds: t,
          blurSigma: 5,
        ),
      ),
    ),
    Positioned.fill(
      child: CustomPaint(
        painter: BackgroundPainter(
          view: cameraView,
          timeSeconds: t,
          biomeMap: biomeMap,
          biomeTintFrac: 0.5,
        ),
      ),
    ),
    Positioned.fill(
      child: CustomPaint(
        painter: FoodPainter(
          view: cameraView,
          items: visibleItems,
          consumedRemnants: const [],
          timeSeconds: t,
          foodRadiusWorld: foodStore.radiusWorld,
        ),
      ),
    ),
    ...babyEntities.map(
      (e) => Positioned.fill(
        child: CustomPaint(
          painter: CreaturePainter(
            creature: e.creature,
            spine: e.spine,
            view: cameraView,
            timeSeconds: t,
            isBaby: true,
            isEpic: false,
          ),
        ),
      ),
    ),
    ...normalEntities.map(
      (e) => Positioned.fill(
        child: CustomPaint(
          painter: CreaturePainter(
            creature: e.creature,
            spine: e.spine,
            view: cameraView,
            timeSeconds: t,
            isBaby: false,
            isEpic: false,
          ),
        ),
      ),
    ),
    if (!isDead) ...[
      // Player: tail + lateral, body (+ mouth) only (no dorsal, no eyes).
      Positioned.fill(
        child: CustomPaint(
          painter: CreaturePainter(
            creature: creature,
            spine: spine,
            view: cameraView,
            timeSeconds: t,
            skipDorsalAndEyes: true,
            lastAteAt: lastAteTimeSeconds,
          ),
        ),
      ),
      // Digestion cloud (clipped to body path).
      Positioned.fill(
        child: CustomPaint(
          painter: InnerBodyCloudPainter(
            view: cameraView,
            spine: spine,
            consumedRemnants: visibleRemnants
                .where((remnant) => remnant.consumedByPlayer)
                .toList(),
            timeSeconds: t,
            bodyClipPath: CreaturePainter.buildBodyPath(
              creature,
              spine,
              cameraView,
              size,
            ),
          ),
        ),
      ),
      // Dorsal fin + eyes (drawn together above cloud).
      Positioned.fill(
        child: CustomPaint(
          painter: CreaturePainter(
            creature: creature,
            spine: spine,
            view: cameraView,
            timeSeconds: t,
            dorsalAndEyesOnly: true,
            lastAteAt: lastAteTimeSeconds,
          ),
        ),
      ),
    ],
    ...epicEntities.map(
      (e) => Positioned.fill(
        child: CustomPaint(
          painter: CreaturePainter(
            creature: e.creature,
            spine: e.spine,
            view: cameraView,
            timeSeconds: t,
            isBaby: false,
            isEpic: true,
          ),
        ),
      ),
    ),
    Positioned.fill(
      child: CustomPaint(
        painter: FoodPainter(
          view: cameraView,
          items: visibleGiantItems,
          consumedRemnants: visibleRemnants,
          timeSeconds: t,
          foodRadiusWorld: foodStore.radiusWorld,
        ),
      ),
    ),
  ];
}
