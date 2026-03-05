import 'dart:math' show sqrt;

import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';

import 'creature.dart';
import 'render/spine_painter.dart';
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
  final Creature _creature = const Creature(
    segmentCount: 50,
    color: 0xFF2E7D32,
  );
  late final Spine _spine = Spine(segmentCount: _creature.segmentCount);
  double _touchX = 120;
  double _touchY = 0;
  /// Camera: world position at screen center. Does not affect creature positions; only the view.
  double _cameraX = 0;
  double _cameraY = 0;
  bool _tickerActive = false;
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
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final positions = _spine.positions;
    if (positions.isEmpty) return;
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
    // Camera follows head (world position unchanged; only view target).
    _cameraX = head.x;
    _cameraY = head.y;
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
            painter: SpinePainter(
              positions: _spine.positions,
              segmentAngles: _spine.segmentAngles,
              vertexWidths: null,
              cameraX: _cameraX,
              cameraY: _cameraY,
              zoom: _viewZoom,
              fillColor: Color(_creature.color),
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
                  _updateTouchFromLocal(size, e.localPosition, _cameraX, _cameraY);
                  if (!_tickerActive) {
                    _tickerActive = true;
                    _ticker.start();
                  }
                  setState(() {});
                },
                onPointerMove: (e) {
                  _updateTouchFromLocal(size, e.localPosition, _cameraX, _cameraY);
                },
                onPointerUp: (_) {
                  _tickerActive = false;
                  _ticker.stop();
                },
                onPointerCancel: (_) {
                  _tickerActive = false;
                  _ticker.stop();
                },
                child: const SizedBox.expand(),
              );
            },
          ),
        ),
      ],
    );
  }
}
