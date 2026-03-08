import 'dart:math' show atan2, cos, sin, sqrt;
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'controller/mammoth_store.dart';
import 'controller/creature_store.dart';
import 'controller/spawner.dart';
import 'creature.dart' show Creature, CaudalFinType;
import 'input/simulation_gesture_region.dart';
import 'render/mammoth_painter.dart';
import 'render/background_painter.dart'
    show BackgroundPainter, SolidBackgroundPainter;
import 'render/food_painter.dart';
import 'render/spine_painter.dart';
import 'simulation/angle_util.dart' show relativeAngleDiff;
import 'simulation/spine.dart';
import 'simulation_view_state.dart';
import 'world/biome_map.dart';
import 'controller/chunk_manager.dart';
import 'controller/food_store.dart';
import 'world/food.dart' show CellType;
import 'world/world.dart'
    show aabbOverlapsRect, circleOverlapsRect, kFoodActiveRadiusWorld;

/// Screen that runs the spine simulation. Hold and drag on the screen:
/// the head moves toward the touch point; drag to change direction.
class SimulationScreen extends StatefulWidget {
  const SimulationScreen({super.key});

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen>
    with SingleTickerProviderStateMixin {
  final Creature _creature = Creature(
    vertexWidths: [
      // tail → head (index 0 = tail, last = head)
      20,
      20,
      20,
      20,
      20,
      20,
      20,
      20,
      20,
      10,
      10,
      20,
      30,
      30,
    ],
    dorsalFins: [
      ([14, 15, 16, 17, 18, 19], 8.0),
      ([2, 3, 4, 5, 6, 7, 8, 9, 10], null),
    ],
    color: 0xFF777777,
    finColor: 0xFF777777,
    tailFin: CaudalFinType.lunate,
    lateralFins: [4],
  );
  late final Spine _spine = Spine(segmentCount: _creature.segmentCount);

  final Spawner _spawner = Spawner();
  late final CreatureStore _creatureStore;
  final BiomeMap _biomeMap = BiomeMap();
  late final FoodStore _foodStore;
  late final MammothStore _mammothStore = MammothStore(
    spawner: _spawner,
    spawnChanceOneIn: 2,
  );
  late final ChunkManager _chunkManager = ChunkManager(
    foodStore: _foodStore,
    creatureStore: _creatureStore,
  );
  bool _chunksInitialized = false;
  bool _isDead = false;

  final SimulationViewState _viewState = SimulationViewState();
  late Ticker _ticker;

  static const double _headMoveSpeed = 6.0;
  static const double _arrivalThreshold = 10.0;

  /// Fraction of head (vertex) size used for head/mouth collision (epic touch and consume radius).
  static const double _kHeadMouthSizeFrac = 0.8;

  /// Fixed simulation timestep (seconds). Game logic runs at this rate regardless of display FPS.
  static const double _kSimFixedDt = 1 / 60.0;
  static const int _kMaxSimStepsPerFrame = 5;

  /// When neck is at bend limit, nudge whole creature this much (rad) toward touch per step. Only tuning for tight turns.
  static const double _kGlobalTurnNudge = 0.02;

  /// Fixed target distance from head when using joystick (angle only).
  static const double _kJoystickTargetDistance = 120.0;

  static const double _kJoystickPadding = 24.0;

  double _simTimeSeconds = 0;
  double? _lastRealTimeSeconds;

  @override
  void initState() {
    super.initState();
    _foodStore = FoodStore(biomeMap: _biomeMap);
    _creatureStore = CreatureStore(spawner: _spawner, biomeMap: _biomeMap);
    final pos = _spine.positions;
    if (pos.isNotEmpty) {
      final head = pos.last;
      _viewState.touchX = head.x;
      _viewState.touchY = head.y;
      _viewState.cameraX = head.x;
      _viewState.cameraY = head.y;
    } else {
      final x = _spine.segmentCount * 40.0;
      _viewState.touchX = x;
      _viewState.touchY = 0;
      _viewState.cameraX = x;
      _viewState.cameraY = 0;
    }
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final realTimeSeconds = elapsed.inMilliseconds / 1000.0;
    _lastRealTimeSeconds ??= realTimeSeconds;
    final realDt = realTimeSeconds - _lastRealTimeSeconds!;
    _lastRealTimeSeconds = realTimeSeconds;

    final steps = (realDt / _kSimFixedDt).round().clamp(
      0,
      _kMaxSimStepsPerFrame,
    );
    for (var i = 0; i < steps; i++) {
      _simTimeSeconds += _kSimFixedDt;
      _viewState.timeSeconds = _simTimeSeconds;
      _runSimulationStep();
    }

    if (mounted) _viewState.onTick();
  }

  void _runSimulationStep() {
    _viewState.refreshTouchFromStoredLocal();
    final positions = _spine.positions;
    if (positions.isNotEmpty &&
        _viewState.isJoystickActive &&
        _viewState.joystickOffset != null) {
      final head = positions.last;
      final off = _viewState.joystickOffset!;
      final len = off.distance;
      if (len > 1e-6) {
        final angle = atan2(off.dy, off.dx);
        _viewState.touchX = head.x + _kJoystickTargetDistance * cos(angle);
        _viewState.touchY = head.y + _kJoystickTargetDistance * sin(angle);
      } else {
        _viewState.touchX = head.x;
        _viewState.touchY = head.y;
      }
    }
    if (positions.isNotEmpty && !_isDead) {
      final head = positions.last;
      final headSize = _creature.vertexWidths.isNotEmpty
          ? _creature.vertexWidths.last
          : _foodStore.radiusWorld;
      final headCollision = headSize * _kHeadMouthSizeFrac;
      for (final e in _creatureStore.entities) {
        if (!e.isEpic) continue;
        final ep = e.spine.positions;
        if (ep.isEmpty) continue;
        final ex = ep.last.x;
        final ey = ep.last.y;
        final epicHeadSize = e.creature.vertexWidths.isNotEmpty
            ? e.creature.vertexWidths.last * CreaturePainter.kEpicRenderScale
            : 30.0;
        final epicCollision = epicHeadSize * _kHeadMouthSizeFrac;
        final touchRad = headCollision + epicCollision;
        final ddx = head.x - ex;
        final ddy = head.y - ey;
        if (ddx * ddx + ddy * ddy <= touchRad * touchRad) {
          _isDead = true;
          _foodStore.addConsumedRemnantAt(
            head.x,
            head.y,
            _viewState.timeSeconds,
            head.x,
            head.y,
            cellType: CellType.animal,
            scale: 4.0,
          );
          break;
        }
      }
      if (!_isDead) {
        final dx = _viewState.touchX - head.x;
        final dy = _viewState.touchY - head.y;
        final len = sqrt(dx * dx + dy * dy);
        if (len <= _arrivalThreshold) {
          _spine.resolve(
            head.x,
            head.y,
            intendedTargetX: _viewState.touchX,
            intendedTargetY: _viewState.touchY,
          );
        } else {
          final step = _headMoveSpeed / len;
          final nx = head.x + dx * step;
          final ny = head.y + dy * step;
          _spine.resolve(
            nx,
            ny,
            intendedTargetX: _viewState.touchX,
            intendedTargetY: _viewState.touchY,
          );
        }

        // When player asks for a turn sharper than one joint allows, nudge whole creature so we don't get stuck.
        if (_spine.segmentCount >= 2) {
          final headPos = _spine.positions.last;
          final headDir = _spine.segmentAngles.last;
          final towardTouch = atan2(
            _viewState.touchY - headPos.y,
            _viewState.touchX - headPos.x,
          );
          final turn = relativeAngleDiff(headDir, towardTouch);
          if (turn.abs() > _spine.maxJointAngleRad) {
            final nudge = turn.abs() < _kGlobalTurnNudge
                ? turn
                : (turn > 0 ? _kGlobalTurnNudge : -_kGlobalTurnNudge);
            _spine.rotateAroundBase(nudge);
          }
        }

        final headAfter = _spine.positions.last;
        _viewState.cameraX = headAfter.x;
        _viewState.cameraY = headAfter.y;
        final consumeRadius = _foodStore.radiusWorld + headCollision;
        _foodStore.consumeNear(
          headAfter.x,
          headAfter.y,
          consumeRadius,
          _viewState.timeSeconds,
        );
        for (final e in _creatureStore.entities) {
          if (!e.isBaby) continue;
          final pos = e.spine.positions;
          if (pos.isEmpty) continue;
          final bx = pos.last.x;
          final by = pos.last.y;
          final bdx = headAfter.x - bx;
          final bdy = headAfter.y - by;
          if (bdx * bdx + bdy * bdy <= consumeRadius * consumeRadius) {
            _foodStore.addConsumedRemnantAt(
              bx,
              by,
              _viewState.timeSeconds,
              headAfter.x,
              headAfter.y,
              cellType: CellType.animal,
            );
            _creatureStore.removeCreature(e);
          }
        }
      }
    }
    _mammothStore.tick();
    if (_viewState.viewWidthWorld > 0 && _viewState.viewHeightWorld > 0) {
      _mammothStore.update(_viewState.cameraX, _viewState.cameraY);
      _chunkManager.update(
        _viewState.cameraX,
        _viewState.cameraY,
        kFoodActiveRadiusWorld,
      );
      _creatureStore.tick();
    }
    _foodStore.tick(_viewState.timeSeconds);
  }

  List<Widget> _buildViewStack(Size size) {
    _viewState.setViewSize(size);
    if (!_chunksInitialized) {
      _mammothStore.update(_viewState.cameraX, _viewState.cameraY);
      _chunkManager.update(
        _viewState.cameraX,
        _viewState.cameraY,
        kFoodActiveRadiusWorld,
      );
      _chunksInitialized = true;
    }
    final cameraView = _viewState.cameraView;
    final bgView = _viewState.backgroundCameraView();
    final t = _viewState.timeSeconds;
    final bgColor = Color.lerp(
      const Color.fromARGB(255, 28, 30, 54),
      _biomeMap.blendedColorAt(_viewState.cameraX, _viewState.cameraY),
      0.18,
    )!;
    final (left, right, top, bottom) = _viewState.renderRectWithBuffer(0.15);
    final r = _foodStore.radiusWorld;
    final visibleItems = _foodStore.items
        .where((i) => circleOverlapsRect(i.x, i.y, r, left, right, top, bottom))
        .toList();
    const remnantRadius = 220.0;
    final visibleRemnants = _foodStore.consumedRemnants
        .where(
          (r) => circleOverlapsRect(
            r.x,
            r.y,
            remnantRadius,
            left,
            right,
            top,
            bottom,
          ),
        )
        .toList();
    const creatureMargin = 50.0;
    final visibleEntities = _creatureStore.entities.where((e) {
      final pos = e.spine.positions;
      if (pos.isEmpty) return false;
      var minX = pos[0].x, maxX = pos[0].x, minY = pos[0].y, maxY = pos[0].y;
      for (final p in pos) {
        if (p.x < minX) minX = p.x;
        if (p.x > maxX) maxX = p.x;
        if (p.y < minY) minY = p.y;
        if (p.y > maxY) maxY = p.y;
      }
      return aabbOverlapsRect(
        minX - creatureMargin,
        maxX + creatureMargin,
        minY - creatureMargin,
        maxY + creatureMargin,
        left,
        right,
        top,
        bottom,
      );
    }).toList();
    final visibleMammoths = _mammothStore.getVisible(
      _viewState.cameraX,
      _viewState.cameraY,
      _viewState.viewWidthWorld,
      _viewState.viewHeightWorld,
    );
    return [
      Positioned.fill(
        child: CustomPaint(painter: SolidBackgroundPainter(color: bgColor)),
      ),
      Positioned.fill(
        child: CustomPaint(
          painter: MammothPainter(
            mammoths: visibleMammoths,
            view: bgView,
            timeSeconds: t,
            blurSigma: 5,
          ),
        ),
      ),
      Positioned.fill(
        child: CustomPaint(
          painter: BackgroundPainter(
            view: cameraView,
            timeSeconds: t,
            biomeMap: _biomeMap,
            biomeTintFrac: 0.7,
          ),
        ),
      ),
      Positioned.fill(
        child: CustomPaint(
          painter: FoodPainter(
            view: cameraView,
            items: visibleItems,
            consumedRemnants: visibleRemnants,
            timeSeconds: t,
            foodRadiusWorld: _foodStore.radiusWorld,
          ),
        ),
      ),
      ...visibleEntities.map(
        (e) => Positioned.fill(
          child: CustomPaint(
            painter: CreaturePainter(
              creature: e.creature,
              spine: e.spine,
              view: cameraView,
              timeSeconds: t,
              isBaby: e.isBaby,
              isEpic: e.isEpic,
            ),
          ),
        ),
      ),
      if (!_isDead) ...[
        Positioned.fill(
          child: CustomPaint(
            painter: CreaturePainter(
              creature: _creature,
              spine: _spine,
              view: cameraView,
              timeSeconds: t,
              drawEyes: false,
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: InnerBodyCloudPainter(
              view: cameraView,
              spine: _spine,
              consumedRemnants: visibleRemnants,
              timeSeconds: t,
              bodyClipPath: CreaturePainter.buildBodyPath(
                _creature,
                _spine,
                cameraView,
                size,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: CreaturePainter(
              creature: _creature,
              spine: _spine,
              view: cameraView,
              timeSeconds: t,
              eyesOnly: true,
            ),
          ),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Stack(
      children: [
        ListenableBuilder(
          listenable: _viewState,
          builder: (context, _) => Stack(
            children: [const SizedBox.expand(), ..._buildViewStack(size)],
          ),
        ),
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, contextConstraints) {
              final layerSize = contextConstraints.biggest;
              if (layerSize.width < 1 || layerSize.height < 1) {
                return const SizedBox.expand();
              }
              final joystickCenter = Offset(
                _kJoystickPadding + _viewState.joystickMaxRadius,
                layerSize.height - _kJoystickPadding - _viewState.joystickMaxRadius,
              );
              final joystickZoneRadius = _viewState.joystickMaxRadius;
              bool isInJoystickZone(Offset local) {
                final dx = local.dx - joystickCenter.dx;
                final dy = local.dy - joystickCenter.dy;
                return dx * dx + dy * dy <= joystickZoneRadius * joystickZoneRadius;
              }

              return Stack(
                children: [
                  SimulationGestureRegion(
                    onSinglePointerDown: (local) {
                      if (isInJoystickZone(local)) {
                        _viewState.startJoystick(joystickCenter, local);
                      } else {
                        _viewState.updateTouchFromLocal(layerSize, local);
                        _viewState.onTouchDown();
                      }
                    },
                    onSinglePointerMove: (local) {
                      if (_viewState.isJoystickActive) {
                        _viewState.updateJoystick(local);
                      } else {
                        _viewState.updateTouchFromLocal(layerSize, local);
                      }
                    },
                    onSinglePointerUp: () {
                      if (_viewState.isJoystickActive) {
                        final head = _spine.positions.isNotEmpty
                            ? _spine.positions.last
                            : null;
                        if (head != null) {
                          _viewState.endJoystick(head.x, head.y);
                        } else {
                          _viewState.endJoystick(
                            _viewState.cameraX,
                            _viewState.cameraY,
                          );
                        }
                      } else {
                        _viewState.clearLastTouch();
                      }
                    },
                onScaleStart: (details) {
                  _viewState.startPinch(details.pointerCount >= 2);
                },
                onScaleUpdate: (details) {
                  _viewState.touchTargetFrozen = details.pointerCount >= 2;
                  if (_viewState.pinchStartZoom != null) {
                    _viewState.applyPinchZoom(
                      _viewState.pinchStartZoom! * details.scale,
                    );
                  }
                },
                onScaleEnd: () {
                  _viewState.endPinch();
                },
              ),
              IgnorePointer(
                child: ListenableBuilder(
                  listenable: _viewState,
                  builder: (context, _) => CustomPaint(
                    size: layerSize,
                    painter: _JoystickOverlayPainter(
                      viewState: _viewState,
                      layerSize: layerSize,
                      knobRadius: 20.0,
                    ),
                  ),
                ),
              ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Faint white joystick circles: outer always visible (hint when inactive, slightly more when active). Knob when active.
class _JoystickOverlayPainter extends CustomPainter {
  _JoystickOverlayPainter({
    required this.viewState,
    required this.layerSize,
    this.knobRadius = 20.0,
  });

  final SimulationViewState viewState;
  final Size layerSize;
  final double knobRadius;

  static const double _joystickPadding = 24.0;
  static const double _strokeWidth = 1.5;
  static const double _fillOpacity = 0.22;
  static const double _strokeOpacity = 0.5;
  static const double _outerActiveStrokeOpacity = 0.2;
  static const double _hintStrokeOpacity = 0.08;

  Offset get _zoneCenter => Offset(
        _joystickPadding + viewState.joystickMaxRadius,
        layerSize.height - _joystickPadding - viewState.joystickMaxRadius,
      );

  @override
  void paint(Canvas canvas, Size size) {
    final center = viewState.isJoystickActive ? viewState.joystickCenter : _zoneCenter;
    final outerOpacity = viewState.isJoystickActive ? _outerActiveStrokeOpacity : _hintStrokeOpacity;
    final outerPaint = Paint()
      ..color = Colors.white.withValues(alpha: outerOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;
    canvas.drawCircle(center, viewState.joystickMaxRadius, outerPaint);

    // Knob: only when joystick active
    if (viewState.isJoystickActive) {
      final knobCenter = viewState.joystickOffset != null
          ? center + viewState.joystickOffset!
          : center;
      final fillPaint = Paint()
        ..color = Colors.white.withValues(alpha: _fillOpacity)
        ..style = PaintingStyle.fill;
      final strokePaint = Paint()
        ..color = Colors.white.withValues(alpha: _strokeOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth;
      canvas.drawCircle(knobCenter, knobRadius, fillPaint);
      canvas.drawCircle(knobCenter, knobRadius, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _JoystickOverlayPainter old) =>
      old.viewState != viewState || old.layerSize != layerSize;
}
