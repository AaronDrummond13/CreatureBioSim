import 'package:bioism/controller/chunk_manager.dart';
import 'package:bioism/controller/creature_store.dart';
import 'package:bioism/controller/food_store.dart';
import 'package:bioism/controller/mammoth_store.dart';
import 'package:bioism/controller/spawner.dart';
import 'package:bioism/creature.dart' show Creature;
import 'package:bioism/input/simulation_input_layer.dart';
import 'package:bioism/render/simulation_layers.dart';
import 'package:bioism/simulation/play_step.dart';
import 'package:bioism/simulation/spine.dart';
import 'package:bioism/simulation_view_state.dart';
import 'package:bioism/ui/edit_button.dart';
import 'package:bioism/world/biome_map.dart';
import 'package:bioism/world/world.dart'
    show kChunkLoadRadiusWorld, kChunkCullRadiusWorld;
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
  static Creature defaultCreature() => Creature(
    segmentWidths: [16, 22, 20],
    color: 0xFF987987,
    finColor: 0xFF987987,
  );

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

  final SimulationViewState _viewState = SimulationViewState();
  final PlayStepOutput _stepOutput = PlayStepOutput();
  late Ticker _ticker;

  static const double _kSimFixedDt = 1 / 60.0;
  static const int _kMaxSimStepsPerFrame = 5;
  static const double _kJoystickPadding = 24.0;

  static const Color _kEditBtnStroke = Color(0xFF6b8a9e);
  static const Color _kEditBtnFill = Color(0xFF2e3d4d);
  static const Color _kEditBtnText = Color(0xFFe8eef2);
  static const double _kEditBtnRadius = 8.0;

  double _simTimeSeconds = 0;
  double? _lastRealTimeSeconds;

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
      runPlayStep(
        _viewState,
        _spine,
        _creature,
        _creatureStore,
        _foodStore,
        _mammothStore,
        _chunkManager,
        _stepOutput,
      );
    }

    final pos = _spine.positions;
    if (pos.isNotEmpty) {
      final head = pos.last;
      _viewState.cameraX = head.x;
      _viewState.cameraY = head.y;
    }

    if (mounted) _viewState.onTick();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    _viewState.initWithScreenSize(size.width);
    return Stack(
      children: [
        ListenableBuilder(
          listenable: _viewState,
          builder: (context, _) {
            if (!_chunksInitialized) {
              _mammothStore.update(_viewState.cameraX, _viewState.cameraY);
              _chunkManager.update(
                _viewState.cameraX,
                _viewState.cameraY,
                kChunkLoadRadiusWorld,
                kChunkCullRadiusWorld,
              );
              _chunksInitialized = true;
            }
            return Stack(
              children: [
                const SizedBox.expand(),
                ...buildSimulationLayers(
                  size: size,
                  viewState: _viewState,
                  foodStore: _foodStore,
                  creatureStore: _creatureStore,
                  mammothStore: _mammothStore,
                  biomeMap: _biomeMap,
                  creature: _creature,
                  spine: _spine,
                  isDead: _stepOutput.isDead,
                  lastAteTimeSeconds: _stepOutput.lastAteTimeSeconds,
                ),
              ],
            );
          },
        ),
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, contextConstraints) {
              final layerSize = contextConstraints.biggest;
              return SimulationInputLayer(
                viewState: _viewState,
                spine: _spine,
                layerSize: layerSize,
                joystickPadding: _kJoystickPadding,
              );
            },
          ),
        ),
        if (widget.onEdit != null)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 20,
            right: MediaQuery.paddingOf(context).right + 20,
            child: EditButton(
              onTap: widget.onEdit,
              detailOption: CreatureIconDetail.rna,
            ),
          ),
      ],
    );
  }
}
