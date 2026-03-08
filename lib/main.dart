import 'package:flutter/material.dart';
import 'package:creature_bio_sim/creature.dart';
import 'package:creature_bio_sim/editor/editor_screen.dart';
import 'package:creature_bio_sim/simulation_screen.dart';

void main() => runApp(const MainApp());

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(home: const _Shell());
}

/// Play vs Edit shell; UI is inside [SimulationScreen] and [EditorScreen].
class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  static const Color _editBg = Color.fromARGB(255, 28, 30, 54);

  bool _isEditMode = false;
  late Creature _playerCreature;

  @override
  void initState() {
    super.initState();
    _playerCreature = SimulationScreen.defaultCreature();
  }

  void _switchToPlay([Creature? fromEditor]) {
    if (fromEditor != null) _playerCreature = fromEditor;
    setState(() => _isEditMode = false);
  }

  void _switchToEdit() => setState(() => _isEditMode = true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isEditMode ? _editBg : null,
      body: _isEditMode
          ? EditorScreen(
              initialCreature: _playerCreature,
              onPlay: _switchToPlay,
            )
          : SimulationScreen(
              initialCreature: _playerCreature,
              onEdit: _switchToEdit,
            ),
    );
  }
}
