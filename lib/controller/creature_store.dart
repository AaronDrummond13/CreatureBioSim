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
  });

  final int chunkCx;
  final int chunkCy;
  final Creature creature;
  final Spine spine;
  final BotController botController;
}

/// Creatures linked to chunks. Generation/clear is driven by [ChunkManager]; no distance-based add/remove.
class CreatureStore {
  CreatureStore({
    required this.spawner,
    this.spawnChanceOneIn = 10,
    Random? random,
  }) : _random = random ?? Random();

  final Spawner spawner;
  final int spawnChanceOneIn;
  final Random _random;

  final Map<String, StoredCreature> _byChunk = {};
  List<StoredCreature> get entities => _byChunk.values.toList();

  /// Remove creature for chunk (ci, cj). Called by [ChunkManager] when chunk goes out of range.
  void clearChunk(int ci, int cj) {
    _byChunk.remove(chunkKey(ci, cj));
  }

  /// Generate creature for chunk (i, j) with 1 in [spawnChanceOneIn] chance. Called by [ChunkManager] when chunk comes into range.
  void generateForChunk(int i, int j) {
    final key = chunkKey(i, j);
    if (_byChunk.containsKey(key)) return;
    if (_random.nextInt(spawnChanceOneIn) != 0) return;
    final cellSize = kChunkSizeWorld;
    final x0 = i * cellSize;
    final y0 = j * cellSize;
    final spawnX = x0 + _random.nextDouble() * cellSize;
    final spawnY = y0 + _random.nextDouble() * cellSize;
    final (creature, spine) = spawner.createRandomAt(spawnX, spawnY);
    final botController = BotController(
      spine: spine,
      wanderRadius: 600.0 + _random.nextDouble() * 800.0,
      ticksPerNewTarget: 80 + _random.nextInt(120),
    );
    _byChunk[key] = StoredCreature(
      chunkCx: i,
      chunkCy: j,
      creature: creature,
      spine: spine,
      botController: botController,
    );
  }

  void tick() {
    for (final e in _byChunk.values) {
      e.botController.tick();
    }
  }
}
