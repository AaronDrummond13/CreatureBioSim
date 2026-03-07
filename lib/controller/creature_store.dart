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

/// Chunk-based creature generation/culling like food. Uses [kFoodActiveRadiusWorld]; creatures in range, cull when far.
class CreatureStore {
  CreatureStore({
    required this.spawner,
    this.spawnChanceOneIn = 55,
    Random? random,
  }) : _random = random ?? Random();

  final Spawner spawner;
  final int spawnChanceOneIn;
  final Random _random;

  final Map<String, StoredCreature> _byChunk = {};
  /// Chunks we already rolled and did not spawn (so we don't re-roll every tick).
  final Set<String> _rolledEmpty = {};
  List<StoredCreature> get entities => _byChunk.values.toList();

  static double _distSqToAabb(double px, double py, double x0, double x1, double y0, double y1) {
    final dx = px < x0 ? x0 - px : (px > x1 ? px - x1 : 0.0);
    final dy = py < y0 ? y0 - py : (py > y1 ? py - y1 : 0.0);
    return dx * dx + dy * dy;
  }

  void _cullFar(double cx, double cy, double radius) {
    if (radius < 1) return;
    final r2 = radius * radius;
    final cellSize = kChunkSizeWorld;
    for (final key in List<String>.from(_byChunk.keys)) {
      final e = _byChunk[key]!;
      final x0 = e.chunkCx * cellSize;
      final x1 = (e.chunkCx + 1) * cellSize;
      final y0 = e.chunkCy * cellSize;
      final y1 = (e.chunkCy + 1) * cellSize;
      if (_distSqToAabb(cx, cy, x0, x1, y0, y1) > r2) _byChunk.remove(key);
    }
    for (final key in List<String>.from(_rolledEmpty)) {
      final parts = key.split(',');
      if (parts.length != 2) continue;
      final ci = int.tryParse(parts[0]);
      final cj = int.tryParse(parts[1]);
      if (ci == null || cj == null) continue;
      final x0 = ci * cellSize;
      final x1 = (ci + 1) * cellSize;
      final y0 = cj * cellSize;
      final y1 = (cj + 1) * cellSize;
      if (_distSqToAabb(cx, cy, x0, x1, y0, y1) > r2) _rolledEmpty.remove(key);
    }
  }

  void _ensureInRange(double cx, double cy, double radius) {
    if (radius < 1) return;
    final r2 = radius * radius;
    final cellSize = kChunkSizeWorld;
    final iMin = ((cx - radius) / cellSize).floor();
    final iMax = ((cx + radius) / cellSize).ceil();
    final jMin = ((cy - radius) / cellSize).floor();
    final jMax = ((cy + radius) / cellSize).ceil();
    for (var i = iMin; i <= iMax; i++) {
      for (var j = jMin; j <= jMax; j++) {
        final key = chunkKey(i, j);
        if (_byChunk.containsKey(key) || _rolledEmpty.contains(key)) continue;
        final x0 = i * cellSize;
        final x1 = (i + 1) * cellSize;
        final y0 = j * cellSize;
        final y1 = (j + 1) * cellSize;
        if (_distSqToAabb(cx, cy, x0, x1, y0, y1) > r2) continue;
        if (_random.nextInt(spawnChanceOneIn) != 0) {
          _rolledEmpty.add(key);
          continue;
        }
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
    }
  }

  /// Cull creatures in chunks outside [radius], then ensure chunks in range have a creature (1 in [spawnChanceOneIn]).
  void update(double cx, double cy, double radius) {
    _cullFar(cx, cy, radius);
    _ensureInRange(cx, cy, radius);
  }

  void tick() {
    for (final e in _byChunk.values) {
      e.botController.tick();
    }
  }
}
