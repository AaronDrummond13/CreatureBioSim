import 'package:bioism/editor/node_painter.dart';
import 'package:flutter/material.dart';

class MouthNodePainter extends CustomPainter {
  MouthNodePainter({required this.positions, this.activeNode});

  final List<Offset> positions;
  final int? activeNode;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < positions.length; i++)
      drawNode(canvas, positions[i], active: activeNode == i);
  }

  @override
  bool shouldRepaint(covariant MouthNodePainter old) =>
      old.activeNode != activeNode || old.positions.length != positions.length;
}
