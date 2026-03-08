# ChangeNotifier / state management check

## Current usage

- **SimulationViewState** (lib/simulation_view_state.dart): single `ChangeNotifier` holding camera, zoom, touch target, time, joystick state, pinch state.
- **SimulationScreen** uses two `ListenableBuilder(listenable: _viewState)`:
  1. Wraps the main view stack (world, entities, background).
  2. Wraps the joystick overlay painter.

Every `notifyListeners()` rebuilds **both** subtrees. That happens on:
- Every tick (`onTick()`), i.e. every frame (~60×/s).
- Touch down, move, up; pinch start/update/end; joystick start/update/end.

## Issues

1. **Over-rebuild**: The joystick overlay only depends on `isJoystickActive`, `joystickOffset`, `joystickCenter`, `joystickMaxRadius`. It does not need to rebuild when `cameraX`/`cameraY`/`timeSeconds`/`zoom` change. Today it rebuilds every frame anyway because the whole `_viewState` notifies every tick.
2. **Single notifier**: One notifier for all view + input state means you cannot subscribe to “only camera” or “only joystick”; any change triggers every listener.
3. **Editor**: No ChangeNotifier; uses local `setState` in `EditorScreenState` and `_EditorPreviewState`. That’s appropriate for screen-local UI state.

## Recommendation

- **Keep** the current approach for the editor (setState in StatefulWidget).
- **Improve** simulation screen by splitting listenables:
  - **Camera/view notifier**: `cameraX`, `cameraY`, `zoom`, `timeSeconds` (and view size if needed). Notify on each tick and on zoom/pinch. Main view stack listens to this.
  - **Joystick notifier**: `isJoystickActive`, `joystickOffset`, `joystickCenter`, `joystickMaxRadius`. Notify only on joystick start/update/end. Joystick overlay listens to this.

That way the main view still rebuilds every frame (needed for camera/time), but the joystick overlay only rebuilds when joystick state actually changes.

## Editor (recent changes and state flow)

### Where state lives

- **EditorScreenState** (lib/editor/editor_screen.dart): owns `_creature`, `_panelClosed`, `_editorTabIndex`, `_selectedDorsalFinIndex`. Single source of truth for “what creature we’re editing” and “panel open/closed / which tab / which dorsal selected”. All viewport edits go up via callbacks and end up as `setState(() => _creature = ...)` or updating the other flags.
- **EditorPanel**: stateless. Receives `creature` and callbacks; tabs (Body, Colour, Fins) and their content are pure UI that call back into the screen.
- **EditorPreviewState** (lib/editor/editor_preview.dart): owns preview-only state: `_spine`, `_zoom`, `_dragTargetX/Y`, all gesture/drag state (dorsal/lateral/body node drags, pinch, etc.), `_backgroundTimeSeconds`, `_editorSimTimeSeconds`, and the ticker. Rebuilds on gesture updates and on tick when the sim steps (fixed timestep). No ChangeNotifier; `setState` is used when something changes.

### Recent editor-related changes

- **Panel state in editor**: `_panelClosed` (and the Test/Edit toggle) were moved from main into EditorScreen. Main no longer tracks panel visibility; the editor owns it and always starts with panel open (edit mode). Cleaner: one place owns the flag, no props/callbacks from shell.
- **Main**: only holds `_isEditMode` and `_playerCreature`; passes `initialCreature` and `onPlay` into EditorScreen. No `panelClosed` / `onTogglePanel` in main anymore.

### Could editor state management be improved?

- **No over-rebuild**: When EditorScreenState does `setState`, both the panel and the preview rebuild. They both depend on `_creature`, and the preview also needs `_panelClosed`, `_editorTabIndex`, `_selectedDorsalFinIndex`. So that rebuild is correct; there’s no “joystick rebuilding every frame” style waste.
- **Lifted state**: Creature is lifted to the screen; viewport callbacks (`_onDorsalRangeFromViewport`, `_onSegmentCountFromViewport`, etc.) update it. Standard pattern; no need for ChangeNotifier or a global store.
- **Preview local state**: The large amount of state in EditorPreviewState (zoom, spine, drag state, ticker) is all transient UI for the preview. It’s not shared with the panel. Keeping it in the preview’s State and using `setState` is appropriate. Moving it to a ChangeNotifier would add indirection without a real benefit.
- **Verdict**: Editor state and recent changes are in good shape. Keep the current approach.

---

## Optional (not recommended for current scope)

- **Provider/Riverpod/Bloc**: Unnecessary for this app; ChangeNotifier + ListenableBuilder is enough for simulation; setState is enough for editor.
- **ValueNotifier**: Only helps for a single value; we have many fields, so splitting into 2 notifiers is a better fit than many ValueNotifiers.
