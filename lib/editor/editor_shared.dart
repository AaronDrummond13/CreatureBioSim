import 'package:flutter/material.dart';

import 'package:creature_bio_sim/editor/editor_style.dart';

/// Custom slider: track + draggable thumb (no Material).
class EditorSlider extends StatefulWidget {
  const EditorSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final void Function(double) onChanged;

  @override
  State<EditorSlider> createState() => _EditorSliderState();
}

class _EditorSliderState extends State<EditorSlider> {
  double get _frac => (widget.value - widget.min) / (widget.max - widget.min);

  void _onDrag(DragUpdateDetails d, double width) {
    final frac = (d.localPosition.dx / width).clamp(0.0, 1.0);
    final v = widget.min + frac * (widget.max - widget.min);
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final thumbX = _frac * w;
        return GestureDetector(
          onHorizontalDragUpdate: (d) => _onDrag(d, w),
          onTapDown: (d) => _onDrag(DragUpdateDetails(delta: Offset.zero, localPosition: d.localPosition, globalPosition: d.globalPosition), w),
          child: CustomPaint(
            size: Size(w, 24),
            painter: _SliderPainter(
              thumbX: thumbX,
              trackColor: EditorStyle.fill,
              strokeColor: EditorStyle.stroke,
              thumbColor: EditorStyle.selected,
            ),
          ),
        );
      },
    );
  }
}

class _SliderPainter extends CustomPainter {
  _SliderPainter({required this.thumbX, required this.trackColor, required this.strokeColor, required this.thumbColor});

  final double thumbX;
  final Color trackColor;
  final Color strokeColor;
  final Color thumbColor;

  @override
  void paint(Canvas canvas, Size size) {
    final r = 4.0;
    final track = RRect.fromRectAndRadius(Rect.fromLTWH(0, size.height / 2 - 2, size.width, 4), Radius.circular(r));
    canvas.drawRRect(track, Paint()..color = trackColor);
    canvas.drawRRect(track, Paint()..color = strokeColor..style = PaintingStyle.stroke..strokeWidth = EditorStyle.strokeWidth);
    canvas.drawCircle(Offset(thumbX, size.height / 2), 10, Paint()..color = thumbColor);
    canvas.drawCircle(Offset(thumbX, size.height / 2), 10, Paint()..color = strokeColor..style = PaintingStyle.stroke..strokeWidth = EditorStyle.strokeWidth);
  }

  @override
  bool shouldRepaint(covariant _SliderPainter old) => old.thumbX != thumbX;
}

/// Marker for lateral fin drag from panel to viewport.
class LateralDragPayload {}

/// Marker for dorsal fin drag from panel to viewport.
class DorsalDragPayload {}
