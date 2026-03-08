import 'dart:math' show Random;

import '../creature.dart';
import '../simulation/spine.dart';
import 'bot_controller.dart';
import 'spawner.dart';
import '../world/world.dart';

/// A creature plus spine and bot controller, tied to a chunk for culling.
class StoredCreature {
  StoredCreature({
    required this.chunkCx,
    required this.chunkCy,
    required this.creature,
    required this.spine,
    required this.botController,
    this.isBaby = false,
    this.isEpic = false,
  });

  final int chunkCx;
  final int chunkCy;
  final Creature creature;
  final Spine spine;
  final BotController botController;
  final bool isBaby;
  final bool isEpic;
}

/// Creatures linked to chunks. Generation/clear is driven by [ChunkManager].
/// Supports single spawn or group spawn (5 identical, some babies).
class CreatureStore {
  CreatureStore({
    required this.spawner,
    this.spawnChanceOneIn = 10,
    this.groupSpawnChanceOneIn = 2,
    this.epicSpawnChanceOneIn = 10,
    Random? random,
  }) : _random = random ?? Random();

  final Spawner spawner;
  final int spawnChanceOneIn;
  final int groupSpawnChanceOneIn;
  final int epicSpawnChanceOneIn;
  final Random _random;

  final Map<String, List<StoredCreature>> _byChunk = {};

  List<StoredCreature> get entities =>
      _byChunk.values.expand((list) => list).toList();

  void clearChunk(int ci, int cj) {
    _byChunk.remove(chunkKey(ci, cj));
  }

  void removeCreature(StoredCreature e) {
    for (final entry in _byChunk.entries) {
      if (entry.value.remove(e)) {
        if (entry.value.isEmpty) _byChunk.remove(entry.key);
        return;
      }
    }
  }

  void generateForChunk(int i, int j) {
    final key = chunkKey(i, j);
    if (_byChunk.containsKey(key)) return;
    if (_random.nextInt(spawnChanceOneIn) != 0) return;

    final cellSize = kChunkSizeWorld;
    final x0 = i * cellSize;
    final y0 = j * cellSize;
    final centerX = x0 + _random.nextDouble() * cellSize;
    final centerY = y0 + _random.nextDouble() * cellSize;

    final list = <StoredCreature>[];

    final doGroup = _random.nextInt(groupSpawnChanceOneIn) == 0;
    if (doGroup) {
      final (creature, group) = spawner.createGroupAt(
        centerX,
        centerY,
        count: 5,
        babyChance: 0.4,
      );
      for (final (spine, isBaby) in group) {
        final botController = BotController(
          spine: spine,
          wanderRadius: 400.0 + _random.nextDouble() * 400.0,
          ticksPerNewTarget: 60 + _random.nextInt(80),
        );
        list.add(
          StoredCreature(
            chunkCx: i,
            chunkCy: j,
            creature: creature,
            spine: spine,
            botController: botController,
            isBaby: isBaby,
          ),
        );
      }
    } else {
      final (creature, spine) = spawner.createRandomAt(centerX, centerY);
      final botController = BotController(
        spine: spine,
        wanderRadius: 600.0 + _random.nextDouble() * 800.0,
        ticksPerNewTarget: 80 + _random.nextInt(120),
      );
      final isEpic = _random.nextInt(epicSpawnChanceOneIn) == 0;
      list.add(
        StoredCreature(
          chunkCx: i,
          chunkCy: j,
          creature: creature,
          spine: spine,
          botController: botController,
          isEpic: isEpic,
        ),
      );
    }

    _byChunk[key] = list;
  }

  void tick() {
    for (final list in _byChunk.values) {
      for (final e in list) {
        e.botController.tick();
      }
    }
  }
}
