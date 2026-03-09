import 'dart:math' show atan2, cos, pi, Random, sin, sqrt;

import 'package:creature_bio_sim/simulation/spine.dart';

/// Bot behavior mode: each runs for a duration then we switch.
enum BotBehavior {
  /// Move in a fixed direction; target stays ahead so we never arrive.
  wander,

  /// Like wander but with a smooth left-right slalom (swim) toward the same direction.
  wanderSlalom,

  /// Turn in place: target 90° to one side for a while.
  spin,

  /// Stay still: target = current head.
  stand,

  /// Gentle drift: target moves slowly in a direction.
  stroll,

  /// Move toward [home] position; ends when close or duration runs out.
  returnHome,
}

/// Drives a spine with multiple behaviors: wander, spin, stand, stroll.
/// Call [tick] each simulation step; behavior runs for a duration then switches.
class BotController {
  BotController({
    required this.spine,
    this.wanderRadius = 120.0,
    this.ticksPerNewTarget = 40,
    this.speed = 4.0,
    this.homeX,
    this.homeY,
    this.allowStandAndSpin = true,
    int? seed,
  }) : _rng = Random(seed);

  final Spine spine;
  final double wanderRadius;
  final int ticksPerNewTarget;
  final double speed;
  final double? homeX;
  final double? homeY;
  final bool allowStandAndSpin;

  final Random _rng;
  BotBehavior _behavior = BotBehavior.wander;
  int _behaviorTicksLeft = 0;
  int _spinSign = 1;
  double _wanderAngle = 0;
  int _wanderPhase = 0;
  double _slalomAmplitudeDeg = 12.0;
  double _slalomSpeed = 0.08;
  double _strollTargetX = 0;
  double _strollTargetY = 0;
  double _strollAngle = 0;

  static const int _minWanderDuration = 400;
  static const int _maxWanderDuration = 960;
  static const double _wanderTargetDist = 9999.0;
  static const double _slalomAmplitudeMin = 2.0;
  static const double _slalomAmplitudeMax = 20.0;
  static const double _slalomSpeedMin = 0.05;
  static const double _slalomSpeedMax = 0.12;
  static const int _minSpinDuration = 20;
  static const int _maxSpinDuration = 60;
  static const int _minStandDuration = 40;
  static const int _maxStandDuration = 120;
  static const int _minStrollDuration = 240;
  static const int _maxStrollDuration = 560;
  static const double _spinTargetDist = 70.0;
  static const double _strollDriftSpeed = 0.35;
  static const double _strollAngleNudge = 0.08;
  static const double _strollSpeedFrac = 0.8;
  static const double _strollMinDist = 50.0;
  static const int _minReturnHomeDuration = 200;
  static const int _maxReturnHomeDuration = 500;

  void _pickNextBehavior() {
    final roll = _rng.nextDouble();
    if (roll < 0.01) {
      if (allowStandAndSpin) {
        _behavior = BotBehavior.spin;
        _behaviorTicksLeft =
            _minSpinDuration +
            _rng.nextInt(_maxSpinDuration - _minSpinDuration + 1);
        _spinSign = _rng.nextBool() ? 1 : -1;
      } else {
        _behavior = BotBehavior.wander;
        _behaviorTicksLeft =
            _minWanderDuration +
            _rng.nextInt(_maxWanderDuration - _minWanderDuration + 1);
        _wanderAngle = _rng.nextDouble() * 2 * pi;
      }
    } else if (roll < 0.06) {
      if (allowStandAndSpin) {
        _behavior = BotBehavior.stand;
        _behaviorTicksLeft =
            _minStandDuration +
            _rng.nextInt(_maxStandDuration - _minStandDuration + 1);
      } else {
        _behavior = BotBehavior.wanderSlalom;
        _behaviorTicksLeft =
            _minWanderDuration +
            _rng.nextInt(_maxWanderDuration - _minWanderDuration + 1);
        _wanderAngle = _rng.nextDouble() * 2 * pi;
        _wanderPhase = 0;
        _slalomAmplitudeDeg =
            _slalomAmplitudeMin +
            _rng.nextDouble() * (_slalomAmplitudeMax - _slalomAmplitudeMin);
        _slalomSpeed =
            _slalomSpeedMin +
            _rng.nextDouble() * (_slalomSpeedMax - _slalomSpeedMin);
      }
    } else if (roll < 0.33) {
      _behavior = BotBehavior.wander;
      _behaviorTicksLeft =
          _minWanderDuration +
          _rng.nextInt(_maxWanderDuration - _minWanderDuration + 1);
      _wanderAngle = _rng.nextDouble() * 2 * pi;
    } else if (roll < 0.60) {
      _behavior = BotBehavior.wanderSlalom;
      _behaviorTicksLeft =
          _minWanderDuration +
          _rng.nextInt(_maxWanderDuration - _minWanderDuration + 1);
      _wanderAngle = _rng.nextDouble() * 2 * pi;
      _wanderPhase = 0;
      _slalomAmplitudeDeg =
          _slalomAmplitudeMin +
          _rng.nextDouble() * (_slalomAmplitudeMax - _slalomAmplitudeMin);
      _slalomSpeed =
          _slalomSpeedMin +
          _rng.nextDouble() * (_slalomSpeedMax - _slalomSpeedMin);
    } else if (roll < 0.92) {
      _behavior = BotBehavior.stroll;
      _behaviorTicksLeft =
          _minStrollDuration +
          _rng.nextInt(_maxStrollDuration - _minStrollDuration + 1);
      final positions = spine.positions;
      if (positions.length >= 2) {
        final head = positions.last;
        final neck = positions[positions.length - 2];
        final headA = atan2(head.y - neck.y, head.x - neck.x);
        _strollAngle = headA + (_rng.nextDouble() - 0.5) * 0.8;
        _strollTargetX = head.x + cos(_strollAngle) * wanderRadius * 0.3;
        _strollTargetY = head.y + sin(_strollAngle) * wanderRadius * 0.3;
      }
    } else {
      if (homeX != null && homeY != null) {
        _behavior = BotBehavior.returnHome;
        _behaviorTicksLeft =
            _minReturnHomeDuration +
            _rng.nextInt(_maxReturnHomeDuration - _minReturnHomeDuration + 1);
      } else {
        _behavior = BotBehavior.wander;
        _behaviorTicksLeft =
            _minWanderDuration +
            _rng.nextInt(_maxWanderDuration - _minWanderDuration + 1);
        _wanderAngle = _rng.nextDouble() * 2 * pi;
      }
    }
  }

  void tick() {
    final positions = spine.positions;
    if (positions.isEmpty) return;
    final head = positions.last;

    if (_behaviorTicksLeft <= 0) {
      _pickNextBehavior();
    }
    _behaviorTicksLeft--;

    const arrivalThreshold = 4.0;
    double useTargetX = head.x;
    double useTargetY = head.y;
    double useSpeed = speed;

    switch (_behavior) {
      case BotBehavior.wander:
        useTargetX = head.x + cos(_wanderAngle) * _wanderTargetDist;
        useTargetY = head.y + sin(_wanderAngle) * _wanderTargetDist;
        break;

      case BotBehavior.wanderSlalom:
        _wanderPhase++;
        final swayRad =
            (_slalomAmplitudeDeg * pi / 180) * sin(_wanderPhase * _slalomSpeed);
        final effectiveAngle = _wanderAngle + swayRad;
        useTargetX = head.x + cos(effectiveAngle) * _wanderTargetDist;
        useTargetY = head.y + sin(effectiveAngle) * _wanderTargetDist;
        break;

      case BotBehavior.spin:
        if (positions.length >= 2) {
          final neck = positions[positions.length - 2];
          final headA = atan2(head.y - neck.y, head.x - neck.x);
          final sideA = headA + _spinSign * (pi / 2);
          useTargetX = head.x + cos(sideA) * _spinTargetDist;
          useTargetY = head.y + sin(sideA) * _spinTargetDist;
        }
        break;

      case BotBehavior.stand:
        useTargetX = head.x;
        useTargetY = head.y;
        break;

      case BotBehavior.stroll:
        _strollTargetX += cos(_strollAngle) * _strollDriftSpeed;
        _strollTargetY += sin(_strollAngle) * _strollDriftSpeed;
        if (_rng.nextDouble() < 0.02) {
          _strollAngle += (_rng.nextDouble() - 0.5) * _strollAngleNudge * 2;
        }
        double sx = _strollTargetX - head.x;
        double sy = _strollTargetY - head.y;
        final d = sqrt(sx * sx + sy * sy);
        if (d < _strollMinDist && d > 1e-6) {
          sx = sx / d * _strollMinDist;
          sy = sy / d * _strollMinDist;
          _strollTargetX = head.x + sx;
          _strollTargetY = head.y + sy;
        }
        useTargetX = _strollTargetX;
        useTargetY = _strollTargetY;
        useSpeed = speed * _strollSpeedFrac;
        break;

      case BotBehavior.returnHome:
        useTargetX = homeX!;
        useTargetY = homeY!;
        final distToHome = sqrt(
          (homeX! - head.x) * (homeX! - head.x) +
              (homeY! - head.y) * (homeY! - head.y),
        );
        if (distToHome <= arrivalThreshold) _behaviorTicksLeft = 0;
        break;
    }

    final dx = useTargetX - head.x;
    final dy = useTargetY - head.y;
    final len = sqrt(dx * dx + dy * dy);

    if (len <= arrivalThreshold || _behavior == BotBehavior.stand) {
      spine.resolve(
        head.x,
        head.y,
        intendedTargetX: useTargetX,
        intendedTargetY: useTargetY,
      );
    } else {
      final step = useSpeed / len;
      final nx = head.x + dx * step;
      final ny = head.y + dy * step;
      spine.resolve(
        nx,
        ny,
        intendedTargetX: useTargetX,
        intendedTargetY: useTargetY,
      );
    }
  }
}
