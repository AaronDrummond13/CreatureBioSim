import 'package:flutter/material.dart';
import 'package:creature_bio_sim/creature.dart';
import 'package:creature_bio_sim/editor/editor_screen.dart';
import 'package:creature_bio_sim/simulation_screen.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: const _Shell());
  }
}

/// Switches between play and edit; no UI. Buttons live in EditorScreen and SimulationScreen.
class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  bool _isEditMode = false;
  bool _editorPanelClosed = false;
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

  void _switchToEdit() {
    setState(() => _isEditMode = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isEditMode
          ? const Color.fromARGB(255, 28, 30, 54)
          : null,
      body: _isEditMode
          ? EditorScreen(
              initialCreature: _playerCreature,
              onPlay: _switchToPlay,
              panelClosed: _editorPanelClosed,
              onTogglePanel: () => setState(() => _editorPanelClosed = !_editorPanelClosed),
            )
          : SimulationScreen(
              initialCreature: _playerCreature,
              onEdit: _switchToEdit,
            ),
    );
  }
}
