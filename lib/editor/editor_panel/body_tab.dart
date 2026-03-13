import 'package:creature_bio_sim/creature.dart';
import 'package:creature_bio_sim/editor/editor_style.dart';
import 'package:flutter/material.dart';

class BodyTab extends StatelessWidget {
  const BodyTab({
    super.key,
    required this.creature,
    required this.onCreatureChanged,
  });

  final Creature creature;
  final void Function(Creature) onCreatureChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          'Body shpae',
          style: TextStyle(
            color: EditorStyle.text,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Use the nodes to adjust the creatures size',
          style: TextStyle(fontSize: 12, color: EditorStyle.textMuted),
        ),
      ],
    );
  }
}
