import 'dart:math' show Random;
import 'package:creature_bio_sim/controller/bot_controller.dart';
import 'package:creature_bio_sim/controller/spawner.dart';
import 'package:creature_bio_sim/creature.dart';
import 'package:creature_bio_sim/simulation/spine.dart';
import 'package:creature_bio_sim/world/world.dart';

class StoredMammoth {
  StoredMammoth({
    required this.creature,
    required this.spine,
    required this.botController,
    required this.layerOpacity,
    required this.chunkCx,
    required this.chunkCy,
  });

  final Creature creature;
  final Spine spine;
  final BotController botController;
  final double layerOpacity;
  int chunkCx;
  int chunkCy;
}

const double _kParallaxChunkSize = 500;
const double _kParallaxFactor = 0.25;
const double _kParallaxZoomScale = 5.0;

const double _kSpawnRadius = 1000.0;
const double _kCullRadius = 1200.0;

int _chunkIdx(double v) => (v / _kParallaxChunkSize).floor();
String _chunkKey(int i, int j) => 'p$i,$j';

class MammothStore {
  MammothStore({
    required this.spawner,
    this.spawnChanceOneIn = 1,
    Random? random,
  }) : _random = random ?? Random();

  final Spawner spawner;
  final int spawnChanceOneIn;
  final Random _random;

  final Map<String, List<StoredMammoth>> _byChunk = {};
  final Set<String> _generated = {};

  List<StoredMammoth> get entities =>
      _byChunk.values.expand((list) => list).toList();

  void clearChunk(int ci, int cj) {
    _byChunk.remove(_chunkKey(ci, cj));
  }

  void cullOutOfRange(double px, double py, double cullRadius) {
    final cullR2 = cullRadius * cullRadius;
    for (final list in _byChunk.values) {
      list.removeWhere((m) {
        final pos = m.spine.positions;
        if (pos.isEmpty) return true;
        final hx = pos.last.x;
        final hy = pos.last.y;
        return (hx - px) * (hx - px) + (hy - py) * (hy - py) > cullR2;
      });
    }
    _byChunk.removeWhere((_, list) => list.isEmpty);
  }

  void update(double cameraX, double cameraY) {
    final px = cameraX * _kParallaxFactor;
    final py = cameraY * _kParallaxFactor;
    final cell = _kParallaxChunkSize;
    final cullR2 = _kCullRadius * _kCullRadius;
    final spawnR2 = _kSpawnRadius * _kSpawnRadius;

    // Cull generated chunks beyond cull radius.
    for (final key in Set<String>.from(_generated)) {
      final parts = key.substring(1).split(',');
      if (parts.length != 2) continue;
      final ci = int.tryParse(parts[0]);
      final cj = int.tryParse(parts[1]);
      if (ci == null || cj == null) continue;
      final x0 = ci * cell;
      final x1 = (ci + 1) * cell;
      final y0 = cj * cell;
      final y1 = (cj + 1) * cell;
      if (distSqToAabb(px, py, x0, x1, y0, y1) > cullR2) {
        clearChunk(ci, cj);
        _generated.remove(key);
      }
    }

    cullOutOfRange(px, py, _kCullRadius);

    // Generate new chunks within spawn radius.
    final iMin = ((px - _kSpawnRadius) / cell).floor();
    final iMax = ((px + _kSpawnRadius) / cell).ceil();
    final jMin = ((py - _kSpawnRadius) / cell).floor();
    final jMax = ((py + _kSpawnRadius) / cell).ceil();
    for (var i = iMin; i <= iMax; i++) {
      for (var j = jMin; j <= jMax; j++) {
        final x0 = i * cell;
        final x1 = (i + 1) * cell;
        final y0 = j * cell;
        final y1 = (j + 1) * cell;
        if (distSqToAabb(px, py, x0, x1, y0, y1) > spawnR2) continue;
        final key = _chunkKey(i, j);
        if (_generated.contains(key)) continue;
        _generated.add(key);
        _trySpawnInChunk(i, j);
      }
    }
  }

  void _trySpawnInChunk(int i, int j) {
    if (_random.nextInt(spawnChanceOneIn) != 0) return;
    final cell = _kParallaxChunkSize;
    final x0 = i * cell;
    final y0 = j * cell;
    final spawnX = x0 + _random.nextDouble() * cell;
    final spawnY = y0 + _random.nextDouble() * cell;
    final (creature, spine) = spawner.createRandomAt(spawnX, spawnY);
    final pos = spine.positions;
    final homeX = pos.isNotEmpty ? pos.last.x : null;
    final homeY = pos.isNotEmpty ? pos.last.y : null;
    final botController = BotController(
      spine: spine,
      wanderRadius: 1400.0 + _random.nextDouble() * 600.0,
      ticksPerNewTarget: 350 + _random.nextInt(140),
      speed: 0.9,
      homeX: homeX,
      homeY: homeY,
      allowStandAndSpin: false,
    );
    final layerOpacity = 0.01 + _random.nextDouble() * 0.49;
    final key = _chunkKey(i, j);
    _byChunk.putIfAbsent(key, () => []).add(StoredMammoth(
      creature: creature,
      spine: spine,
      botController: botController,
      layerOpacity: layerOpacity,
      chunkCx: i,
      chunkCy: j,
    ));
  }

  List<StoredMammoth> getVisible(
    double cameraX,
    double cameraY,
    double viewWidthWorld,
    double viewHeightWorld,
  ) {
    final px = cameraX * _kParallaxFactor;
    final py = cameraY * _kParallaxFactor;
    final halfChunk = _kParallaxChunkSize * 0.5;
    final halfW = (viewWidthWorld / _kParallaxZoomScale * 4.0).clamp(
      halfChunk,
      3500.0,
    );
    final halfH = (viewHeightWorld / _kParallaxZoomScale * 4.0).clamp(
      halfChunk,
      3500.0,
    );
    const margin = 150.0;
    final left = px - halfW;
    final right = px + halfW;
    final top = py - halfH;
    final bottom = py + halfH;
    final out = <StoredMammoth>[];
    for (final list in _byChunk.values) {
      for (final m in list) {
        final pos = m.spine.positions;
        if (pos.isEmpty) continue;
        var minX = pos[0].x, maxX = pos[0].x, minY = pos[0].y, maxY = pos[0].y;
        for (final p in pos) {
          if (p.x < minX) minX = p.x;
          if (p.x > maxX) maxX = p.x;
          if (p.y < minY) minY = p.y;
          if (p.y > maxY) maxY = p.y;
        }
        if (aabbOverlapsRect(
          minX - margin,
          maxX + margin,
          minY - margin,
          maxY + margin,
          left,
          right,
          top,
          bottom,
        )) {
          out.add(m);
        }
      }
    }
    return out;
  }

  void tick() {
    final moves = <StoredMammoth, (int, int)>{};
    for (final list in _byChunk.values) {
      for (final m in list) {
        m.botController.tick();
        final pos = m.spine.positions;
        if (pos.isEmpty) continue;
        final head = pos.last;
        final cx = _chunkIdx(head.x);
        final cy = _chunkIdx(head.y);
        if (cx != m.chunkCx || cy != m.chunkCy) moves[m] = (cx, cy);
      }
    }
    for (final entry in moves.entries) {
      final m = entry.key;
      final (cx, cy) = entry.value;
      final oldKey = _chunkKey(m.chunkCx, m.chunkCy);
      final newKey = _chunkKey(cx, cy);
      if (oldKey == newKey) continue;
      final oldList = _byChunk[oldKey];
      if (oldList != null) {
        oldList.remove(m);
        if (oldList.isEmpty) _byChunk.remove(oldKey);
      }
      _byChunk.putIfAbsent(newKey, () => []).add(m);
      m.chunkCx = cx;
      m.chunkCy = cy;
    }
  }
}
