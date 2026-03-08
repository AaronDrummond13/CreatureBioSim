import 'dart:math' show sqrt;
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'controller/background_giant_store.dart';
import 'controller/creature_store.dart';
import 'controller/spawner.dart';
import 'creature.dart' show Creature, CaudalFinType;
import 'input/simulation_gesture_region.dart';
import 'render/background_giants_painter.dart';
import 'render/background_painter.dart'
    show BackgroundPainter, SolidBackgroundPainter;
import 'render/food_painter.dart';
import 'render/spine_painter.dart';
import 'simulation/spine.dart';
import 'simulation_view_state.dart';
import 'world/biome_map.dart';
import 'world/chunk_manager.dart';
import 'world/food.dart';
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
  late final CreatureStore _creatureStore = CreatureStore(spawner: _spawner);
  final FoodStore _foodStore = FoodStore();
  late final BackgroundGiantStore _backgroundGiantStore = BackgroundGiantStore(
    spawner: _spawner,
    spawnChanceOneIn: 2,
  );
  late final ChunkManager _chunkManager = ChunkManager(
    foodStore: _foodStore,
    creatureStore: _creatureStore,
  );
  final BiomeMap _biomeMap = BiomeMap();
  bool _chunksInitialized = false;

  final SimulationViewState _viewState = SimulationViewState();
  late Ticker _ticker;

  static const double _headMoveSpeed = 4.0;
  static const double _arrivalThreshold = 4.0;

  @override
  void initState() {
    super.initState();
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
    _viewState.refreshTouchFromStoredLocal();
    final positions = _spine.positions;
    if (positions.isNotEmpty) {
      final head = positions.last;
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
      _viewState.cameraX = head.x;
      _viewState.cameraY = head.y;
      final headSize = _creature.vertexWidths.isNotEmpty
          ? _creature.vertexWidths.last
          : _foodStore.radiusWorld;
      final consumeRadius = _foodStore.radiusWorld + headSize;
      _foodStore.consumeNear(
        head.x,
        head.y,
        consumeRadius,
        _viewState.timeSeconds,
      );
      for (final e in _creatureStore.entities) {
        if (!e.isBaby) continue;
        final pos = e.spine.positions;
        if (pos.isEmpty) continue;
        final bx = pos.last.x;
        final by = pos.last.y;
        final dx = head.x - bx;
        final dy = head.y - by;
        if (dx * dx + dy * dy <= consumeRadius * consumeRadius) {
          _foodStore.addConsumedRemnantAt(
            bx,
            by,
            _viewState.timeSeconds,
            head.x,
            head.y,
            cellType: CellType.animal,
          );
          _creatureStore.removeCreature(e);
        }
      }
    }
    _viewState.timeSeconds = elapsed.inMilliseconds / 1000.0;
    _backgroundGiantStore.tick();
    if (_viewState.viewWidthWorld > 0 && _viewState.viewHeightWorld > 0) {
      _backgroundGiantStore.update(_viewState.cameraX, _viewState.cameraY);
      _chunkManager.update(
        _viewState.cameraX,
        _viewState.cameraY,
        kFoodActiveRadiusWorld,
      );
      _creatureStore.tick();
    }
    _foodStore.tick(_viewState.timeSeconds);
    if (mounted) _viewState.onTick();
  }

  List<Widget> _buildViewStack(Size size) {
    _viewState.setViewSize(size);
    if (!_chunksInitialized) {
      _backgroundGiantStore.update(_viewState.cameraX, _viewState.cameraY);
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
    final visibleGiants = _backgroundGiantStore.getVisible(
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
          painter: BackgroundGiantsPainter(
            giants: visibleGiants,
            view: bgView,
            timeSeconds: t,
            blurSigma: 5,
            layerOpacity: 0.35,
          ),
        ),
      ),
      Positioned.fill(
        child: CustomPaint(
          painter: BackgroundPainter(
            view: cameraView,
            timeSeconds: t,
            biomeMap: _biomeMap,
            biomeTintFrac: 0.35,
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
              return SimulationGestureRegion(
                onSinglePointerDown: (local) {
                  _viewState.updateTouchFromLocal(layerSize, local);
                  _viewState.onTouchDown();
                },
                onSinglePointerMove: (local) {
                  _viewState.updateTouchFromLocal(layerSize, local);
                },
                onSinglePointerUp: () {
                  _viewState.clearLastTouch();
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
              );
            },
          ),
        ),
      ],
    );
  }
}
