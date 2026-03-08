import 'package:flutter/material.dart';
import 'creature.dart';
import 'editor/editor_screen.dart';
import 'simulation_screen.dart';

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

/// Holds play/edit mode and current creature template. Top-right button toggles mode.
class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  bool _isEditMode = false;
  bool _editorPanelClosed = false;
  late Creature _playerCreature;
  final GlobalKey<EditorScreenState> _editorKey =
      GlobalKey<EditorScreenState>();

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

  void _onPlayFromOverlay() {
    _editorKey.currentState?.applyPlay();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isEditMode
          ? const Color.fromARGB(255, 28, 30, 54)
          : null,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_isEditMode)
            Positioned.fill(
              child: EditorScreen(
                key: _editorKey,
                initialCreature: _playerCreature,
                onPlay: _switchToPlay,
                panelClosed: _editorPanelClosed,
              ),
            )
          else
            Positioned.fill(
              child: SimulationScreen(initialCreature: _playerCreature),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: _isEditMode
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FilledButton.icon(
                            onPressed: _onPlayFromOverlay,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Play'),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.tonalIcon(
                            onPressed: () => setState(
                              () => _editorPanelClosed = !_editorPanelClosed,
                            ),
                            icon: Icon(
                              _editorPanelClosed ? Icons.edit : Icons.science,
                            ),
                            label: Text(_editorPanelClosed ? 'Edit' : 'Test'),
                          ),
                        ],
                      )
                    : IconButton.filled(
                        onPressed: _switchToEdit,
                        icon: const Icon(Icons.edit),
                        tooltip: 'Edit creature',
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
