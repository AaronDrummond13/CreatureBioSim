import 'package:creature_bio_sim/editor/node_painter.dart';
import 'package:flutter/material.dart';

/// Mirrored node overlay for eye radius handles (one or two nodes, like lateral fin).
class EyeNodePainter extends CustomPainter {
  EyeNodePainter({required this.nodePositions, this.activeNodeIndex});

  final List<Offset> nodePositions;
  final int? activeNodeIndex;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < nodePositions.length; i++)
      drawNode(canvas, nodePositions[i], active: activeNodeIndex == i);
  }

  @override
  bool shouldRepaint(covariant EyeNodePainter old) {
    if (old.nodePositions.length != nodePositions.length ||
        old.activeNodeIndex != activeNodeIndex)
      return true;
    for (var i = 0; i < nodePositions.length; i++) {
      if (nodePositions[i] != old.nodePositions[i]) return true;
    }
    return false;
  }
}
