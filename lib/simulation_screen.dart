import 'dart:math' show cos, sin, sqrt;

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

  void _updateTouchFromLocal(Size screenSize, Offset local, double worldCenterX, double worldCenterY) {
    _touchX = local.dx - screenSize.width / 2 + worldCenterX;
    _touchY = local.dy - screenSize.height / 2 + worldCenterY;
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

  static const double _defaultWidth = 40.0;

  _SpinePainter({
    required this.positions,
    required this.segmentAngles,
    this.vertexWidths,
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
    final offsetX = centerX - mid.x;
    final offsetY = centerY - mid.y;
    final n = positions.length - 1;

    // Parametric: vertex i → angle a, width w. Right = pos - (sin a)*w, Left = pos + (sin a)*w.
    Offset rightAt(int i) {
      final a =
          segmentAngles[i < segmentAngles.length
              ? i
              : segmentAngles.length - 1];
      final w = _widthAt(i);
      return Offset(
        positions[i].x + offsetX - sin(a) * w,
        positions[i].y + offsetY + cos(a) * w,
      );
    }

    Offset leftAt(int i) {
      final a =
          segmentAngles[i < segmentAngles.length
              ? i
              : segmentAngles.length - 1];
      final w = _widthAt(i);
      return Offset(
        positions[i].x + offsetX + sin(a) * w,
        positions[i].y + offsetY - cos(a) * w,
      );
    }

    final tailA = segmentAngles[0];
    final headA = segmentAngles[segmentAngles.length - 1];
    final tailW = _widthAt(0);
    final headW = _widthAt(n);

    // Single list of curve vertices: tail tip (1 extra) → right side → head tip (1 extra) → left side → close.
    final curve = <Offset>[];
    curve.add(
      Offset(
        positions[0].x + offsetX - cos(tailA) * tailW,
        positions[0].y + offsetY - sin(tailA) * tailW,
      ),
    );
    for (var i = 0; i <= n; i++) curve.add(rightAt(i));
    curve.add(
      Offset(
        positions[n].x + offsetX + cos(headA) * headW,
        positions[n].y + offsetY + sin(headA) * headW,
      ),
    );
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
      ..strokeWidth = 3;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);

    // Eyes at head: left and right vertex, slightly inward.
    const eyeInset = 0.55;
    final headCx = positions[n].x + offsetX;
    final headCy = positions[n].y + offsetY;
    final rightEye = Offset(
      headCx - sin(headA) * headW * eyeInset,
      headCy + cos(headA) * headW * eyeInset,
    );
    final leftEye = Offset(
      headCx + sin(headA) * headW * eyeInset,
      headCy - cos(headA) * headW * eyeInset,
    );
    final eyeRadius = headW * 0.24;
    final eyePaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    canvas.drawCircle(rightEye, eyeRadius, eyePaint);
    canvas.drawCircle(leftEye, eyeRadius, eyePaint);
  }

  @override
  bool shouldRepaint(covariant _SpinePainter oldDelegate) => true;
}
