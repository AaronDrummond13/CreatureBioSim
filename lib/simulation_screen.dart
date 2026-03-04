import 'dart:math' show cos, pi, sin, sqrt;

import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';

import 'simulation/vector.dart';
import 'simulation/world.dart';

/// Screen that runs the spine simulation. Hold and drag on the screen:
/// the head moves toward the touch point; drag to change direction.
class SimulationScreen extends StatefulWidget {
  const SimulationScreen({super.key});

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen>
    with SingleTickerProviderStateMixin {
  final SimulationWorld _world = SimulationWorld();
  double _touchX = 120;
  double _touchY = 0;
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
    _touchX = _world.segmentCount * 40.0;
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final positions = _world.positions;
    if (positions.isEmpty) return;
    final head = positions.last;
    final dx = _touchX - head.x;
    final dy = _touchY - head.y;
    final len = sqrt(dx * dx + dy * dy);
    if (len <= _arrivalThreshold) {
      _world.resolve(head.x, head.y);
    } else {
      final step = _headMoveSpeed / len;
      final nx = head.x + dx * step;
      final ny = head.y + dy * step;
      _world.resolve(nx, ny);
    }
    if (mounted) setState(() {});
  }

  void _updateTouchFromLocal(
    Size screenSize,
    Offset local,
    double worldCenterX,
    double worldCenterY,
  ) {
    _touchX = worldCenterX + (local.dx - screenSize.width / 2) / _viewZoom;
    _touchY = worldCenterY + (local.dy - screenSize.height / 2) / _viewZoom;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _SpinePainter(
              positions: _world.positions,
              segmentAngles: _world.segmentAngles,
              vertexWidths: null,
              zoom: _viewZoom,
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
                  final pos = _world.positions;
                  if (pos.isNotEmpty) {
                    final mid = pos[(pos.length - 1) ~/ 2];
                    _updateTouchFromLocal(size, e.localPosition, mid.x, mid.y);
                  }
                  if (!_tickerActive) {
                    _tickerActive = true;
                    _ticker.start();
                  }
                  setState(() {});
                },
                onPointerMove: (e) {
                  final pos = _world.positions;
                  if (pos.isNotEmpty) {
                    final mid = pos[(pos.length - 1) ~/ 2];
                    _updateTouchFromLocal(size, e.localPosition, mid.x, mid.y);
                  }
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

class _SpinePainter extends CustomPainter {
  final List<Vector2> positions;
  final List<double> segmentAngles;

  /// Per-vertex width (half-width from spine to outline). If null, uses [defaultWidth].
  final List<double>? vertexWidths;

  /// View zoom: world units scale by this when drawing. 1 = 1:1, < 1 = zoom out.
  final double zoom;

  static const double _defaultWidth = 40.0;

  _SpinePainter({
    required this.positions,
    required this.segmentAngles,
    this.vertexWidths,
    this.zoom = 1.0,
  });

  double _widthAt(int i) {
    if (vertexWidths != null && i < vertexWidths!.length)
      return vertexWidths![i];
    return _defaultWidth;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.length < 2 || segmentAngles.length < 1) return;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final midIndex = (positions.length - 1) ~/ 2;
    final mid = positions[midIndex];
    final n = positions.length - 1;
    final z = zoom;

    // World → screen: center + (world - mid) * zoom. Widths scale with zoom.
    double sx(double wx) => centerX + (wx - mid.x) * z;
    double sy(double wy) => centerY + (wy - mid.y) * z;
    double wAt(int i) => _widthAt(i) * z;

    // Background dots (fixed in world space) for relative motion.
    const double dotSpacing = 120.0;
    const int dotExtent = 12;
    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.fill;
    const dotRadius = 2.0;
    for (var i = -dotExtent; i <= dotExtent; i++) {
      for (var j = -dotExtent; j <= dotExtent; j++) {
        final wx = i * dotSpacing;
        final wy = j * dotSpacing;
        final px = sx(wx);
        final py = sy(wy);
        if (px >= -dotRadius && px <= size.width + dotRadius &&
            py >= -dotRadius && py <= size.height + dotRadius) {
          canvas.drawCircle(Offset(px, py), dotRadius, dotPaint);
        }
      }
    }

    Offset rightAt(int i) {
      final a =
          segmentAngles[i < segmentAngles.length
              ? i
              : segmentAngles.length - 1];
      final w = wAt(i);
      return Offset(
        sx(positions[i].x) - sin(a) * w,
        sy(positions[i].y) + cos(a) * w,
      );
    }

    Offset leftAt(int i) {
      final a =
          segmentAngles[i < segmentAngles.length
              ? i
              : segmentAngles.length - 1];
      final w = wAt(i);
      return Offset(
        sx(positions[i].x) + sin(a) * w,
        sy(positions[i].y) - cos(a) * w,
      );
    }

    final tailA = segmentAngles[0];
    final headA = segmentAngles[segmentAngles.length - 1];
    final tailWWorld = _widthAt(0);
    final headWWorld = _widthAt(n);

    final curve = <Offset>[];
    // Tail cap: 3 points at body width, 60° apart on the back semicircle (order: left 240°, tip 180°, right 120°).
    curve.add(Offset(
      sx(positions[0].x + tailWWorld * cos(tailA + 4 * pi / 3)),
      sy(positions[0].y + tailWWorld * sin(tailA + 4 * pi / 3)),
    ));
    curve.add(Offset(
      sx(positions[0].x - tailWWorld * cos(tailA)),
      sy(positions[0].y - tailWWorld * sin(tailA)),
    ));
    curve.add(Offset(
      sx(positions[0].x + tailWWorld * cos(tailA + 2 * pi / 3)),
      sy(positions[0].y + tailWWorld * sin(tailA + 2 * pi / 3)),
    ));
    for (var i = 0; i <= n; i++) curve.add(rightAt(i));
    // Head cap: 3 points at body width, 60° apart (right 60°, tip 0°, left −60°).
    curve.add(Offset(
      sx(positions[n].x + headWWorld * cos(headA + pi / 3)),
      sy(positions[n].y + headWWorld * sin(headA + pi / 3)),
    ));
    curve.add(Offset(
      sx(positions[n].x + headWWorld * cos(headA)),
      sy(positions[n].y + headWWorld * sin(headA)),
    ));
    curve.add(Offset(
      sx(positions[n].x + headWWorld * cos(headA - pi / 3)),
      sy(positions[n].y + headWWorld * sin(headA - pi / 3)),
    ));
    for (var i = n; i >= 0; i--) curve.add(leftAt(i));

    // Connect all points with one smooth curve (Catmull-Rom style cubic between consecutive points).
    const tension = 1.0 / 6.0;
    final path = Path();
    path.moveTo(curve[0].dx, curve[0].dy);
    final len = curve.length;
    for (var i = 0; i < len; i++) {
      final p0 = curve[(i - 1 + len) % len];
      final p1 = curve[i];
      final p2 = curve[(i + 1) % len];
      final p3 = curve[(i + 2) % len];
      final c0 = Offset(
        p1.dx + (p2.dx - p0.dx) * tension,
        p1.dy + (p2.dy - p0.dy) * tension,
      );
      final c1 = Offset(
        p2.dx - (p3.dx - p1.dx) * tension,
        p2.dy - (p3.dy - p1.dy) * tension,
      );
      path.cubicTo(c0.dx, c0.dy, c1.dx, c1.dy, p2.dx, p2.dy);
    }
    path.close();

    final fillPaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = (3 * z).clamp(1.0, 3.0);

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);

    // Eyes at head: left and right vertex, slightly inward.
    const eyeInset = 0.55;
    final headW = wAt(n);
    final headCx = sx(positions[n].x);
    final headCy = sy(positions[n].y);
    final rightEye = Offset(
      headCx - sin(headA) * headW * eyeInset,
      headCy + cos(headA) * headW * eyeInset,
    );
    final leftEye = Offset(
      headCx + sin(headA) * headW * eyeInset,
      headCy - cos(headA) * headW * eyeInset,
    );
    final eyeRadius = headW * 0.24;
    final eyePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(rightEye, eyeRadius, eyePaint);
    canvas.drawCircle(leftEye, eyeRadius, eyePaint);
  }

  @override
  bool shouldRepaint(covariant _SpinePainter oldDelegate) =>
      oldDelegate.zoom != zoom || true;
}
