import 'dart:math' show Random;

import '../creature.dart';
import '../simulation/spine.dart';
import '../world/world.dart' show distSqToAabb, aabbOverlapsRect, kChunkSizeWorld;
import 'bot_controller.dart';
import 'spawner.dart';

/// A background giant: creature + spine + controller, tied to a parallax chunk.
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

/// Parallax-only universe: own chunk grid (main chunk × 4 for 0.25 scale → 2000×2000), no biome coupling.
/// Procedural only; when cleared, state is discarded ("moved away").
double get _kParallaxChunkSize => kChunkSizeWorld * 4; // 500*4 = 2000 for parallax 0.25
const double _kParallaxRadius = 3000.0;
const double _kParallaxFactor = 0.25;
const double _kParallaxZoomScale = 5.0;

String _parallaxKey(int i, int j) => 'p$i,$j';

/// Chunk-based store for background giants (blurred, slow, parallax). Own lifecycle.
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
  final Set<String> _generated = {};

  /// Update parallax chunks from main camera: center = (cameraX * factor, cameraY * factor).
  void update(double cameraX, double cameraY) {
    final px = cameraX * _kParallaxFactor;
    final py = cameraY * _kParallaxFactor;
    final r2 = _kParallaxRadius * _kParallaxRadius;
    final cell = _kParallaxChunkSize;
    final iMin = ((px - _kParallaxRadius) / cell).floor();
    final iMax = ((px + _kParallaxRadius) / cell).ceil();
    final jMin = ((py - _kParallaxRadius) / cell).floor();
    final jMax = ((py + _kParallaxRadius) / cell).ceil();
    final inRange = <String>{};
    final centerChunkI = (px / cell).floor();
    final centerChunkJ = (py / cell).floor();
    for (var i = iMin; i <= iMax; i++) {
      for (var j = jMin; j <= jMax; j++) {
        final x0 = i * cell;
        final y0 = j * cell;
        if (distSqToAabb(px, py, x0, x0 + cell, y0, y0 + cell) > r2) continue;
        final key = _parallaxKey(i, j);
        inRange.add(key);
        final isCenterChunk = (i == centerChunkI && j == centerChunkJ);
        if (!_generated.contains(key)) _generateChunk(i, j, isCenterChunk ? (px, py) : null);
      }
    }
    for (final key in Set<String>.from(_generated)) {
      if (!inRange.contains(key)) {
        _byChunk.remove(key);
        _generated.remove(key);
      }
    }
  }

  void _generateChunk(int i, int j, (double, double)? nearCenter) {
    final key = _parallaxKey(i, j);
    if (_byChunk.containsKey(key)) return;
    final cell = _kParallaxChunkSize;
    final x0 = i * cell;
    final y0 = j * cell;
    final (spawnX, spawnY) = nearCenter != null
        ? (nearCenter.$1 + (_random.nextDouble() * 2 - 1) * 120,
           nearCenter.$2 + (_random.nextDouble() * 2 - 1) * 120)
        : (x0 + _random.nextDouble() * cell, y0 + _random.nextDouble() * cell);
    if (nearCenter == null && _random.nextInt(spawnChanceOneIn) != 0) {
      _generated.add(key);
      return;
    }
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
    _generated.add(key);
  }

  /// Giants visible in the parallax view rect (world coords around camera * factor).
  List<StoredBackgroundGiant> getVisible(
    double cameraX,
    double cameraY,
    double viewWidthWorld,
    double viewHeightWorld,
  ) {
    final px = cameraX * _kParallaxFactor;
    final py = cameraY * _kParallaxFactor;
    final halfW = (viewWidthWorld / _kParallaxZoomScale * 4.0).clamp(600.0, 3000.0);
    final halfH = (viewHeightWorld / _kParallaxZoomScale * 4.0).clamp(600.0, 3000.0);
    const margin = 150.0;
    final left = px - halfW;
    final right = px + halfW;
    final top = py - halfH;
    final bottom = py + halfH;
    final out = <StoredBackgroundGiant>[];
    for (final g in _byChunk.values) {
      final pos = g.spine.positions;
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
        out.add(g);
      }
    }
    return out;
  }

  void tick() {
    for (final g in _byChunk.values) {
      g.botController.tick();
    }
  }
}
