import 'dart:math' show atan2, cos, sin, sqrt;
import 'package:creature_bio_sim/controller/chunk_manager.dart';
import 'package:creature_bio_sim/controller/creature_store.dart';
import 'package:creature_bio_sim/controller/food_store.dart';
import 'package:creature_bio_sim/controller/mammoth_store.dart';
import 'package:creature_bio_sim/controller/spawner.dart';
import 'package:creature_bio_sim/creature.dart' show Creature, TrophicType;
import 'package:creature_bio_sim/input/simulation_gesture_region.dart';
import 'package:creature_bio_sim/render/background_painter.dart'
    show BackgroundPainter, SolidBackgroundPainter;
import 'package:creature_bio_sim/render/creature_painter.dart';
import 'package:creature_bio_sim/render/food_painter.dart';
import 'package:creature_bio_sim/render/joystick_overlay_painter.dart';
import 'package:creature_bio_sim/render/mammoth_painter.dart';
import 'package:creature_bio_sim/simulation/angle_util.dart'
    show relativeAngleDiff;
import 'package:creature_bio_sim/simulation/spine.dart';
import 'package:creature_bio_sim/simulation_view_state.dart';
import 'package:creature_bio_sim/world/biome_map.dart';
import 'package:creature_bio_sim/world/food.dart' show CellType;
import 'package:creature_bio_sim/world/world.dart'
    show aabbOverlapsRect, circleOverlapsRect, kFoodActiveRadiusWorld;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Screen that runs the spine simulation. Hold and drag on the screen:
/// the head moves toward the touch point; drag to change direction.
class SimulationScreen extends StatefulWidget {
  const SimulationScreen({super.key, this.initialCreature, this.onEdit});

  /// When provided, used as the player creature (simulation restarts with it).
  final Creature? initialCreature;

  /// When provided, an Edit button is shown (top-right) that calls this.
  final VoidCallback? onEdit;

  /// Default creature when [initialCreature] is null (e.g. first run).
  static Creature defaultCreature() =>
      Creature(vertexWidths: [20, 20], color: 0xFF987987, finColor: 0xFF987987);

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen>
    with SingleTickerProviderStateMixin {
  late final Creature _creature;
  late final Spine _spine;

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

  static const double _headMoveSpeed =
      4.5; //maybe start slow 3ish, have speed boosters like tail and fins ect. max 9ish
  static const double _arrivalThreshold = 20.0;

  /// Fraction of head (vertex) size used for head/mouth collision (epic touch and consume radius).
  static const double _kHeadMouthSizeFrac = 0.8;

  /// Fixed simulation timestep (seconds). Game logic runs at this rate regardless of display FPS.
  static const double _kSimFixedDt = 1 / 60.0;
  static const int _kMaxSimStepsPerFrame = 5;

  /// When neck is at bend limit, nudge whole creature this much (rad) toward touch per step. Only tuning for tight turns.
  static const double _kGlobalTurnNudge = 0.000000001;

  /// Fixed target distance from head when using joystick (angle only).
  static const double _kJoystickTargetDistance = 120.0;

  static const double _kJoystickPadding = 24.0;

  double _simTimeSeconds = 0;
  double? _lastRealTimeSeconds;
  double? _lastAteTimeSeconds;

  @override
  void initState() {
    super.initState();
    _creature = widget.initialCreature ?? SimulationScreen.defaultCreature();
    _spine = Spine(segmentCount: _creature.segmentCount);
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
        if (e.creature.trophicType == TrophicType.herbivore) continue;
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
          // No global nudge when arrived — avoids wiggle from curve spread and nudge fighting.
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
          // When moving, nudge whole creature if turn is sharper than one joint allows.
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
        }

        final headAfter = _spine.positions.last;
        _viewState.cameraX = headAfter.x;
        _viewState.cameraY = headAfter.y;
        final consumeRadius = _foodStore.radiusWorld + headCollision;
        final allowedFood = _creature.mouth == null || _creature.trophicType == TrophicType.none
            ? {CellType.bubble}
            : (_creature.trophicType == TrophicType.herbivore
                  ? {CellType.plant, CellType.bubble}
                  : (_creature.trophicType == TrophicType.carnivore
                        ? {CellType.animal, CellType.bubble}
                        : null));
        final consumed = _foodStore.consumeNear(
          headAfter.x,
          headAfter.y,
          consumeRadius,
          _viewState.timeSeconds,
          allowedFood,
          true, // consumedByPlayer
        );
        if (consumed > 0) _lastAteTimeSeconds = _viewState.timeSeconds;
        if (_creature.trophicType != TrophicType.herbivore && _creature.trophicType != TrophicType.none) {
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
                consumedByPlayer: true,
              );
              _creatureStore.removeCreature(e);
              _lastAteTimeSeconds = _viewState.timeSeconds;
            }
          }
          // Player is not epic: only babies (above loop). Only epic bots can eat adult creatures.
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
      _botConsumeFoodAndBabies();
    }
    _foodStore.tick(_viewState.timeSeconds);
  }

  void _botConsumeFoodAndBabies() {
    final timeSeconds = _viewState.timeSeconds;
    for (final e in _creatureStore.entities) {
      if (e.isBaby || e.spine.positions.isEmpty) continue;
      final head = e.spine.positions.last;
      final headSize = e.creature.vertexWidths.isNotEmpty
          ? e.creature.vertexWidths.last
          : _foodStore.radiusWorld;
      final headCollision = headSize * _kHeadMouthSizeFrac;
      final consumeRadius = _foodStore.radiusWorld + headCollision;
      final allowedFood = e.creature.mouth == null || e.creature.trophicType == TrophicType.none
          ? {CellType.bubble}
          : (e.creature.trophicType == TrophicType.herbivore
                ? {CellType.plant, CellType.bubble}
                : (e.creature.trophicType == TrophicType.carnivore
                      ? {CellType.animal, CellType.bubble}
                      : null));
      _foodStore.consumeNear(
        head.x,
        head.y,
        consumeRadius,
        timeSeconds,
        allowedFood,
      );
    }
    final babiesToRemove = <StoredCreature>[];
    for (final e in _creatureStore.entities) {
      if (e.isBaby || e.creature.trophicType == TrophicType.herbivore || e.creature.trophicType == TrophicType.none) continue;
      final pos = e.spine.positions;
      if (pos.isEmpty) continue;
      final head = pos.last;
      final headSize = e.creature.vertexWidths.isNotEmpty
          ? e.creature.vertexWidths.last
          : _foodStore.radiusWorld;
      final headCollision = headSize * _kHeadMouthSizeFrac;
      final consumeRadius = _foodStore.radiusWorld + headCollision;
      for (final other in _creatureStore.entities) {
        if (!other.isBaby || identical(e, other)) continue;
        final opos = other.spine.positions;
        if (opos.isEmpty) continue;
        final ox = opos.last.x;
        final oy = opos.last.y;
        final ddx = head.x - ox;
        final ddy = head.y - oy;
        if (ddx * ddx + ddy * ddy <= consumeRadius * consumeRadius) {
          babiesToRemove.add(other);
          break;
        }
      }
    }
    for (final b in babiesToRemove) {
      final pos = b.spine.positions;
      if (pos.isEmpty) continue;
      final bx = pos.last.x;
      final by = pos.last.y;
      _foodStore.addConsumedRemnantAt(
        bx,
        by,
        timeSeconds,
        bx,
        by,
        cellType: CellType.animal,
      );
      _creatureStore.removeCreature(b);
    }
    // Epic carnivores/omnivores can eat non-epic creatures.
    final nonEpicsToRemove = <StoredCreature>{};
    for (final e in _creatureStore.entities) {
      if (!e.isEpic || e.isBaby || e.spine.positions.isEmpty) continue;
      if (e.creature.trophicType != TrophicType.carnivore && e.creature.trophicType != TrophicType.omnivore) continue;
      final head = e.spine.positions.last;
      final headSize = e.creature.vertexWidths.isNotEmpty
          ? e.creature.vertexWidths.last
          : _foodStore.radiusWorld;
      final consumeRadius = _foodStore.radiusWorld + headSize * _kHeadMouthSizeFrac;
      for (final other in _creatureStore.entities) {
        if (other.isEpic || identical(e, other)) continue;
        final opos = other.spine.positions;
        if (opos.isEmpty) continue;
        final ox = opos.last.x;
        final oy = opos.last.y;
        final ddx = head.x - ox;
        final ddy = head.y - oy;
        if (ddx * ddx + ddy * ddy <= consumeRadius * consumeRadius) {
          nonEpicsToRemove.add(other);
        }
      }
    }
    for (final b in nonEpicsToRemove) {
      final pos = b.spine.positions;
      if (pos.isEmpty) continue;
      final bx = pos.last.x;
      final by = pos.last.y;
      _foodStore.addConsumedRemnantAt(
        bx,
        by,
        timeSeconds,
        bx,
        by,
        cellType: CellType.animal,
      );
      _creatureStore.removeCreature(b);
    }
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
        .where((i) =>
            !i.isGiant &&
            circleOverlapsRect(i.x, i.y, r, left, right, top, bottom))
        .toList();
    final visibleGiantItems = _foodStore.items
        .where((i) =>
            i.isGiant &&
            circleOverlapsRect(
                i.x, i.y, i.radiusWorld ?? r, left, right, top, bottom))
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
            consumedRemnants: const [],
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
              lastAteAt: _lastAteTimeSeconds,
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: InnerBodyCloudPainter(
              view: cameraView,
              spine: _spine,
              consumedRemnants: visibleRemnants
                  .where((r) => r.consumedByPlayer)
                  .toList(),
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
              lastAteAt: _lastAteTimeSeconds,
            ),
          ),
        ),
      ],
      // On top of creatures: remnants + giant (inedible) plants for visual cover.
      Positioned.fill(
        child: CustomPaint(
          painter: FoodPainter(
            view: cameraView,
            items: visibleGiantItems,
            consumedRemnants: visibleRemnants,
            timeSeconds: t,
            foodRadiusWorld: _foodStore.radiusWorld,
          ),
        ),
      ),
    ];
  }

  static const Color _kEditBtnStroke = Color(0xFF6b8a9e);
  static const Color _kEditBtnFill = Color(0xFF2e3d4d);
  static const Color _kEditBtnText = Color(0xFFe8eef2);
  static const double _kEditBtnRadius = 8.0;

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
                layerSize.height -
                    _kJoystickPadding -
                    _viewState.joystickMaxRadius,
              );
              final joystickZoneRadius = _viewState.joystickMaxRadius;
              bool isInJoystickZone(Offset local) {
                final dx = local.dx - joystickCenter.dx;
                final dy = local.dy - joystickCenter.dy;
                return dx * dx + dy * dy <=
                    joystickZoneRadius * joystickZoneRadius;
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
                      if (details.pointerCount >= 2) {
                        final pos = _spine.positions;
                        if (pos.isNotEmpty) {
                          final head = pos.last;
                          _viewState.touchX = head.x;
                          _viewState.touchY = head.y;
                        }
                      }
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
                      listenable: _viewState.joystickListenable,
                      builder: (context, _) => CustomPaint(
                        size: layerSize,
                        painter: JoystickOverlayPainter(
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
        if (widget.onEdit != null)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 10,
            right: MediaQuery.paddingOf(context).right + 10,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onEdit,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _kEditBtnFill,
                  borderRadius: BorderRadius.circular(_kEditBtnRadius),
                  border: Border.all(color: _kEditBtnStroke, width: 1.5),
                ),
                child: const Text(
                  'Edit',
                  style: TextStyle(
                    color: _kEditBtnText,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
