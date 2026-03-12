import 'dart:math' show Random;

import 'package:creature_bio_sim/creature.dart';
import 'package:creature_bio_sim/simulation/spine.dart';
import 'package:creature_bio_sim/world/biome.dart';
import 'package:creature_bio_sim/world/biome_creature_config.dart';
import 'package:creature_bio_sim/world/biome_map.dart';
import 'package:creature_bio_sim/world/world.dart';
import 'package:creature_bio_sim/controller/bot_controller.dart';
import 'package:creature_bio_sim/controller/spawner.dart';

/// A creature plus spine and bot controller, tied to a chunk for culling.
/// [chunkCx]/[chunkCy] track current position chunk so culling only removes creatures actually in that chunk.
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

  int chunkCx;
  int chunkCy;
  final Creature creature;
  final Spine spine;
  final BotController botController;
  final bool isBaby;
  final bool isEpic;
}

/// Creatures linked to chunks. Generation/clear is driven by [ChunkManager].
/// Spawn counts per chunk from [biomeCreatureConfig] (groupsPerChunk, singlesPerChunk, epicsPerChunk).
class CreatureStore {
  CreatureStore({required this.spawner, this.biomeMap, Random? random})
    : _random = random ?? Random();

  final Spawner spawner;
  final BiomeMap? biomeMap;
  final Random _random;

  int _countFromRate(double rate) {
    if (rate <= 0) return 0;
    final floor = rate.floor();
    final frac = rate - floor;
    final extra = frac > 0 && _random.nextDouble() < frac ? 1 : 0;
    return (floor + extra).clamp(0, 0x7FFFFFFF);
  }

  static const double _botWanderRadius = 500.0;
  static const int _botTicksPerNewTarget = 80;

  void _addCreature(
    List<StoredCreature> list,
    int chunkCx,
    int chunkCy,
    Creature creature,
    Spine spine, {
    bool isBaby = false,
    bool isEpic = false,
  }) {
    final pos = spine.positions;
    final homeX = pos.isNotEmpty ? pos.last.x : null;
    final homeY = pos.isNotEmpty ? pos.last.y : null;
    list.add(
      StoredCreature(
        chunkCx: chunkCx,
        chunkCy: chunkCy,
        creature: creature,
        spine: spine,
        botController: BotController(
          spine: spine,
          wanderRadius: _botWanderRadius,
          ticksPerNewTarget: _botTicksPerNewTarget,
          homeX: homeX,
          homeY: homeY,
        ),
        isBaby: isBaby,
        isEpic: isEpic,
      ),
    );
  }

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

    final cellSize = kChunkSizeWorld;
    final x0 = i * cellSize;
    final y0 = j * cellSize;
    final centerX = (i + 0.5) * cellSize;
    final centerY = (j + 0.5) * cellSize;
    final biome = biomeMap != null
        ? biomeMap!.biomeAt(centerX, centerY)
        : Biome.clear;
    final config = biomeCreatureConfig(biome);

    final numGroups = _countFromRate(config.groupsPerChunk);
    final numSingles = _countFromRate(config.singlesPerChunk);
    final numEpics = _countFromRate(config.epicsPerChunk);
    if (numGroups == 0 && numSingles == 0 && numEpics == 0) return;

    final list = <StoredCreature>[];
    const compositions = [
      [false, false], // 2 adults
      [false, false, false], // 3 adults
      [false, false, true], // 2 adults, 1 kid
      [false, true, true, true], // 1 adult, 3 kids
    ];

    for (var g = 0; g < numGroups; g++) {
      final cx = x0 + _random.nextDouble() * cellSize;
      final cy = y0 + _random.nextDouble() * cellSize;
      final babyFlags = compositions[_random.nextInt(4)];
      final (creature, group) = spawner.createGroupAt(
        cx,
        cy,
        babyFlags: babyFlags,
      );
      for (final (spine, isBaby) in group) {
        _addCreature(list, i, j, creature, spine, isBaby: isBaby);
      }
    }
    for (var s = 0; s < numSingles; s++) {
      final cx = x0 + _random.nextDouble() * cellSize;
      final cy = y0 + _random.nextDouble() * cellSize;
      final (creature, spine) = spawner.createRandomAt(cx, cy);
      _addCreature(list, i, j, creature, spine);
    }
    for (var e = 0; e < numEpics; e++) {
      final cx = x0 + _random.nextDouble() * cellSize;
      final cy = y0 + _random.nextDouble() * cellSize;
      final (creature, spine) = spawner.createRandomAt(cx, cy);
      _addCreature(list, i, j, creature, spine, isEpic: true);
    }

    _byChunk[key] = list;
  }

  void tick() {
    final moves = <StoredCreature, (int, int)>{};
    for (final list in _byChunk.values) {
      for (final e in list) {
        e.botController.tick();
        final pos = e.spine.positions;
        if (pos.isEmpty) continue;
        final head = pos.last;
        final cx = chunkIndexX(head.x);
        final cy = chunkIndexY(head.y);
        if (cx != e.chunkCx || cy != e.chunkCy) moves[e] = (cx, cy);
      }
    }
    for (final entry in moves.entries) {
      final e = entry.key;
      final (cx, cy) = entry.value;
      final oldKey = chunkKey(e.chunkCx, e.chunkCy);
      final newKey = chunkKey(cx, cy);
      if (oldKey == newKey) continue;
      final oldList = _byChunk[oldKey];
      if (oldList != null) {
        oldList.remove(e);
        if (oldList.isEmpty) _byChunk.remove(oldKey);
      }
      _byChunk.putIfAbsent(newKey, () => []).add(e);
      e.chunkCx = cx;
      e.chunkCy = cy;
    }
  }

  /// Remove all creature chunk entries whose chunk center is beyond [cullRadius] from (cx, cy).
  /// Called by ChunkManager to clean up chunks created by wandering creatures.
  void cullOutOfRange(double cx, double cy, double cullRadius) {
    final cullR2 = cullRadius * cullRadius;
    final cellSize = kChunkSizeWorld;
    final keysToRemove = <String>[];
    for (final key in _byChunk.keys) {
      final parts = key.split(',');
      if (parts.length != 2) continue;
      final ci = int.tryParse(parts[0]);
      final cj = int.tryParse(parts[1]);
      if (ci == null || cj == null) continue;
      final x0 = ci * cellSize;
      final x1 = (ci + 1) * cellSize;
      final y0 = cj * cellSize;
      final y1 = (cj + 1) * cellSize;
      if (distSqToAabb(cx, cy, x0, x1, y0, y1) > cullR2) {
        keysToRemove.add(key);
      }
    }
    for (final key in keysToRemove) {
      _byChunk.remove(key);
    }
  }
}
