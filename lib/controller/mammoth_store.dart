import 'dart:math' show Random;
import 'package:creature_bio_sim/controller/bot_controller.dart';
import 'package:creature_bio_sim/controller/spawner.dart';
import 'package:creature_bio_sim/creature.dart';
import 'package:creature_bio_sim/simulation/spine.dart';
import 'package:creature_bio_sim/world/world.dart';

/// A mammoth (parallax layer): creature body + spine + controller, tied to a parallax chunk.
class StoredMammoth {
  StoredMammoth({
    required this.chunkCx,
    required this.chunkCy,
    required this.creature,
    required this.spine,
    required this.botController,
    required this.layerOpacity,
  });

  final int chunkCx;
  final int chunkCy;
  final Creature creature;
  final Spine spine;
  final BotController botController;

  /// Per-mammoth opacity for rendering (e.g. 0.01–0.5).
  final double layerOpacity;
}

/// Mammoths' universe: own chunk grid (same as main chunk 500×500), no biome coupling.
/// Procedural only; when cleared, state is discarded ("moved away").
double get _kParallaxChunkSize => 500; // 500
const double _kParallaxRadius = 3000.0;
const double _kParallaxFactor = 0.25;
const double _kParallaxZoomScale = 5.0;

String _parallaxKey(int i, int j) => 'p$i,$j';

/// Chunk-based store for mammoths (blurred, slow, parallax layer). Own lifecycle.
class MammothStore {
  MammothStore({
    required this.spawner,
    this.spawnChanceOneIn = 1,
    Random? random,
  }) : _random = random ?? Random();

  final Spawner spawner;
  final int spawnChanceOneIn;
  final Random _random;

  final Map<String, StoredMammoth> _byChunk = {};
  final Set<String> _generated = {};

  /// Update mammoth chunks from main camera: center = (cameraX × factor, cameraY × factor).
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
    for (var i = iMin; i <= iMax; i++) {
      for (var j = jMin; j <= jMax; j++) {
        final x0 = i * cell;
        final y0 = j * cell;
        if (distSqToAabb(px, py, x0, x0 + cell, y0, y0 + cell) > r2) continue;
        final key = _parallaxKey(i, j);
        inRange.add(key);
        if (!_generated.contains(key)) _generateChunk(i, j);
      }
    }
    for (final key in Set<String>.from(_generated)) {
      if (!inRange.contains(key)) {
        _byChunk.remove(key);
        _generated.remove(key);
      }
    }
  }

  void _generateChunk(int i, int j) {
    final key = _parallaxKey(i, j);
    if (_byChunk.containsKey(key)) return;
    if (_random.nextInt(spawnChanceOneIn) != 0) {
      _generated.add(key);
      return;
    }
    final cell = _kParallaxChunkSize;
    final x0 = i * cell;
    final y0 = j * cell;
    final spawnX = x0 + _random.nextDouble() * cell;
    final spawnY = y0 + _random.nextDouble() * cell;
    final (creature, spine) = spawner.createRandomAt(spawnX, spawnY);
    final botController = BotController(
      spine: spine,
      wanderRadius: 1400.0 + _random.nextDouble() * 600.0,
      ticksPerNewTarget: 350 + _random.nextInt(140),
      speed: 0.9,
    );
    final layerOpacity = 0.01 + _random.nextDouble() * 0.49;
    _byChunk[key] = StoredMammoth(
      chunkCx: i,
      chunkCy: j,
      creature: creature,
      spine: spine,
      botController: botController,
      layerOpacity: layerOpacity,
    );
    _generated.add(key);
  }

  /// Mammoths visible in the parallax view rect (world coords around camera × factor).
  List<StoredMammoth> getVisible(
    double cameraX,
    double cameraY,
    double viewWidthWorld,
    double viewHeightWorld,
  ) {
    final px = cameraX * _kParallaxFactor;
    final py = cameraY * _kParallaxFactor;
    // At least half a chunk so mammoths spawning anywhere in the center chunk are included.
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
    for (final m in _byChunk.values) {
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
    return out;
  }

  void tick() {
    for (final m in _byChunk.values) {
      m.botController.tick();
    }
  }
}
