import 'dart:math' show Random;

import '../creature.dart';
import '../simulation/spine.dart';
import 'bot_controller.dart';
import 'spawner.dart';
import '../world/world.dart';

/// A background giant: creature + spine + controller, tied to a chunk for culling.
class StoredBackgroundGiant {
  StoredBackgroundGiant({
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

/// Chunk-based store for background giants (blurred, slow, parallax).
/// One giant per chunk with [spawnChanceOneIn] chance; slow wander.
class BackgroundGiantStore {
  BackgroundGiantStore({
    required this.spawner,
    this.spawnChanceOneIn = 28,
    Random? random,
  }) : _random = random ?? Random();

  final Spawner spawner;
  final int spawnChanceOneIn;
  final Random _random;

  final Map<String, StoredBackgroundGiant> _byChunk = {};
  List<StoredBackgroundGiant> get entities => _byChunk.values.toList();

  void clearChunk(int ci, int cj) {
    _byChunk.remove(chunkKey(ci, cj));
  }

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
      wanderRadius: 1400.0 + _random.nextDouble() * 600.0,
      ticksPerNewTarget: 350 + _random.nextInt(140),
      speed: 0.9,
    );
    _byChunk[key] = StoredBackgroundGiant(
      chunkCx: i,
      chunkCy: j,
      creature: creature,
      spine: spine,
      botController: botController,
    );
  }

  void tick() {
    for (final g in _byChunk.values) {
      g.botController.tick();
    }
  }
}
