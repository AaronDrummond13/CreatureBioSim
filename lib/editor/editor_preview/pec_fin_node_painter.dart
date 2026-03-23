import 'package:bioism/editor/node_painter.dart';
import 'package:flutter/material.dart';

/// Four nodes for selected lateral fin (mirrored left/right): 0,2 = length; 1,3 = width. activeNode = raw index 0..3.
class PecFinNodePainter extends CustomPainter {
  PecFinNodePainter({required this.positions, this.activeNode});

  final List<Offset> positions;
  final int? activeNode;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < positions.length; i++) {
      drawNode(canvas, positions[i], active: activeNode == i);
    }
  }

  @override
  bool shouldRepaint(covariant PecFinNodePainter old) =>
      old.activeNode != activeNode || old.positions.length != positions.length;
}
