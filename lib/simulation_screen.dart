import 'dart:math' show sqrt;
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'controller/bot_controller.dart';
import 'controller/spawner.dart';
import 'creature.dart' show Creature, CaudalFinType;
import 'input/simulation_gesture_region.dart';
import 'render/background_painter.dart'
    show BackgroundPainter, SolidBackgroundPainter;
import 'render/spine_painter.dart';
import 'simulation/spine.dart';
import 'simulation_view_state.dart';
import 'world/chunk_map.dart';

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
      10,
      10,
      10,
      10,
      10,
      15,
      20,
      30,
      30,
      30,
      35,
      35,
      30,
      30,
      30,
      20,
      20,
      30,
      30,
      30,
      20,
    ],
    dorsalFins: [
      ([14, 15, 16, 17, 18, 19], 8.0),
      ([2, 3, 4, 5, 6, 7, 8, 9, 10], null),
    ],
    color: 0xFF2E7D32,
    finColor: 0xFF5EAD62,
    tailFin: CaudalFinType.truncate,
    lateralFins: [17],
  );
  late final Spine _spine = Spine(segmentCount: _creature.segmentCount);

  final Spawner _spawner = Spawner(spawnInterval: 10.0);
  final ChunkMap _chunkMap = ChunkMap();

  /// Single background creature: big, blurred, slow, drawn behind the dots.
  late final Creature _bgCreature;
  late final Spine _bgSpine;
  late final BotController _bgController;

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

    final bg = _spawner.createRandomAt(0, 0);
    _bgCreature = bg.$1;
    _bgSpine = bg.$2;
    _bgController = BotController(
      spine: _bgSpine,
      wanderRadius: 1400,
      ticksPerNewTarget: 420,
      speed: 0.9,
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
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
    }
    _viewState.timeSeconds = elapsed.inMilliseconds / 1000.0;
    _bgController.tick();
    if (_viewState.viewWidthWorld > 0 && _viewState.viewHeightWorld > 0) {
      _spawner.tick(
        _viewState.timeSeconds,
        _viewState.cameraX,
        _viewState.cameraY,
        _viewState.viewWidthWorld,
        _viewState.viewHeightWorld,
      );
      for (final e in _spawner.entities) {
        e.botController.tick();
      }
    }
    if (mounted) setState(() {});
  }

  List<Widget> _buildViewStack(Size size) {
    _viewState.setViewSize(size);
    final cameraView = _viewState.cameraView;
    final bgView = _viewState.backgroundCameraView();
    final t = _viewState.timeSeconds;
    final bgColor = _chunkMap.blendedColorAt(
      _viewState.cameraX,
      _viewState.cameraY,
    );
    return [
      Positioned.fill(
        child: CustomPaint(painter: SolidBackgroundPainter(color: bgColor)),
      ),
      Positioned.fill(
        child: CustomPaint(
          painter: CreaturePainter(
            creature: _bgCreature,
            spine: _bgSpine,
            view: bgView,
            timeSeconds: t,
            blurSigma: 5,
            layerOpacity: 0.35,
            blurLayerBackgroundColor: bgColor,
          ),
        ),
      ),
      Positioned.fill(
        child: CustomPaint(
          painter: BackgroundPainter(
            view: cameraView,
            timeSeconds: t,
            chunkMap: _chunkMap,
          ),
        ),
      ),
      ..._spawner.entities.map(
        (e) => Positioned.fill(
          child: CustomPaint(
            painter: CreaturePainter(
              creature: e.creature,
              spine: e.spine,
              view: cameraView,
              timeSeconds: t,
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
        ..._buildViewStack(size),
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
                  setState(() {});
                },
                onSinglePointerMove: (local) {
                  _viewState.updateTouchFromLocal(layerSize, local);
                },
                onScaleStart: () {
                  _viewState.pinchStartZoom = _viewState.zoom;
                },
                onScaleUpdate: (scale) {
                  if (_viewState.pinchStartZoom == null) return;
                  final z = _viewState.clampZoom(
                    _viewState.pinchStartZoom! * scale,
                  );
                  if (z != _viewState.zoom) {
                    _viewState.zoom = z;
                    setState(() {});
                  }
                },
                onScaleEnd: () {
                  _viewState.pinchStartZoom = null;
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
