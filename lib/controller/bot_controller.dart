import 'dart:math' show cos, pi, Random, sin, sqrt;

import 'package:creature_bio_sim/simulation/spine.dart';

/// Drives a spine toward random wander targets. Pure Dart; no Flutter.
/// Call [tick] each simulation step; the spine's head moves toward the current
/// target and a new target is chosen periodically.
class BotController {
  BotController({
    required this.spine,
    this.wanderRadius = 120.0,
    this.ticksPerNewTarget = 40,
    this.speed = 4.0,
    int? seed,
  }) : _rng = Random(seed);

  final Spine spine;
  final double wanderRadius;
  final int ticksPerNewTarget;
  final double speed;

  final Random _rng;
  int _tickCount = 0;
  double _targetX = 0;
  double _targetY = 0;
  bool _targetSet = false;

  /// Advance one step: move head toward current target, optionally pick a new target.
  void tick() {
    final positions = spine.positions;
    if (positions.isEmpty) return;
    final head = positions.last;

    if (!_targetSet || _tickCount >= ticksPerNewTarget) {
      final angle = _rng.nextDouble() * 2 * pi;
      final dist = wanderRadius * (0.5 + _rng.nextDouble() * 0.5);
      _targetX = head.x + cos(angle) * dist;
      _targetY = head.y + sin(angle) * dist;
      _targetSet = true;
      _tickCount = 0;
    }
    _tickCount++;

    final dx = _targetX - head.x;
    final dy = _targetY - head.y;
    final len = sqrt(dx * dx + dy * dy);
    const arrivalThreshold = 4.0;

    if (len <= arrivalThreshold) {
      spine.resolve(
        head.x,
        head.y,
        intendedTargetX: _targetX,
        intendedTargetY: _targetY,
      );
    } else {
      final step = speed / len;
      final nx = head.x + dx * step;
      final ny = head.y + dy * step;
      spine.resolve(
        nx,
        ny,
        intendedTargetX: _targetX,
        intendedTargetY: _targetY,
      );
    }
  }
}
