import 'dart:math' show sqrt;

import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';

import 'controller/bot_controller.dart';
import 'creature.dart';
import 'render/spine_painter.dart';
import 'render/view.dart' show CameraView;
import 'simulation/spine.dart';

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
  );
  late final Spine _spine = Spine(segmentCount: _creature.segmentCount);

  /// Second creature: bot-driven, wanders randomly in same view.
  final Creature _botCreature = Creature.withSegments(
    12,
    color: 0xFF1565C0,
    width: 18.0,
  );
  late final Spine _botSpine = Spine(segmentCount: _botCreature.segmentCount);
  late final BotController _botController = BotController(
    spine: _botSpine,
    wanderRadius: 2000.0,
    ticksPerNewTarget: 135,
  );

  double _touchX = 120;
  double _touchY = 0;

  /// Camera: world position at screen center. Does not affect creature positions; only the view.
  double _cameraX = 0;
  double _cameraY = 0;
  late Ticker _ticker;

  static const double _headMoveSpeed = 4.0;

  /// Dead zone: if head is within this distance of target, do not move (stops spasms).
  static const double _arrivalThreshold = 4.0;

  /// View zoom: 1 = 1:1, < 1 = zoom out (see more world), > 1 = zoom in. Creature size in world unchanged.
  static const double _viewZoom = 0.5;

  @override
  void initState() {
    super.initState();
    final pos = _spine.positions;
    if (pos.isNotEmpty) {
      final head = pos.last;
      _touchX = head.x;
      _touchY = head.y;
      _cameraX = head.x;
      _cameraY = head.y;
    } else {
      _touchX = _spine.segmentCount * 40.0;
      _cameraX = _touchX;
      _cameraY = _touchY;
    }
    // Offset bot so it doesn't start on top of the player.
    const botOffsetX = 180.0;
    for (final p in _botSpine.particles) {
      p.position.x += botOffsetX;
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
    // User creature: head toward touch target.
    final positions = _spine.positions;
    if (positions.isNotEmpty) {
      final head = positions.last;
      final dx = _touchX - head.x;
      final dy = _touchY - head.y;
      final len = sqrt(dx * dx + dy * dy);
      if (len <= _arrivalThreshold) {
        _spine.resolve(
          head.x,
          head.y,
          intendedTargetX: _touchX,
          intendedTargetY: _touchY,
        );
      } else {
        final step = _headMoveSpeed / len;
        final nx = head.x + dx * step;
        final ny = head.y + dy * step;
        _spine.resolve(
          nx,
          ny,
          intendedTargetX: _touchX,
          intendedTargetY: _touchY,
        );
      }
      _cameraX = head.x;
      _cameraY = head.y;
    }
    _botController.tick();
    if (mounted) setState(() {});
  }

  /// Convert screen point to world using current camera (camera does not move creatures).
  void _updateTouchFromLocal(
    Size screenSize,
    Offset local,
    double cameraX,
    double cameraY,
  ) {
    _touchX = cameraX + (local.dx - screenSize.width / 2) / _viewZoom;
    _touchY = cameraY + (local.dy - screenSize.height / 2) / _viewZoom;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: CreaturePainter(
              creature: _botCreature,
              spine: _botSpine,
              view: CameraView(
                cameraX: _cameraX,
                cameraY: _cameraY,
                zoom: _viewZoom,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: CreaturePainter(
              creature: _creature,
              spine: _spine,
              view: CameraView(
                cameraX: _cameraX,
                cameraY: _cameraY,
                zoom: _viewZoom,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, contextConstraints) {
              final size = contextConstraints.biggest;
              if (size.width < 1 || size.height < 1) {
                return const SizedBox.expand();
              }
              return Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) {
                  _updateTouchFromLocal(
                    size,
                    e.localPosition,
                    _cameraX,
                    _cameraY,
                  );
                  setState(() {});
                },
                onPointerMove: (e) {
                  _updateTouchFromLocal(
                    size,
                    e.localPosition,
                    _cameraX,
                    _cameraY,
                  );
                },
                onPointerUp: (_) {},
                onPointerCancel: (_) {},
                child: const SizedBox.expand(),
              );
            },
          ),
        ),
      ],
    );
  }
}
