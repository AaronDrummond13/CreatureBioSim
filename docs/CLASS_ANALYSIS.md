# Class and file grouping analysis

**Goal:** Minimal classes per file, files grouped by responsibility. This doc flags issues and suggests moves/splits.

---

## 1. Per-file inventory

| File | Classes / enums / extensions | Top-level | Notes |
|------|------------------------------|-----------|--------|
| **lib/main.dart** | `MainApp` | — | OK (1 widget). |
| **lib/creature.dart** | `CaudalFinType` (enum), `Creature` | — | OK: one concept, enum is part of creature. |
| **lib/simulation_view_state.dart** | `SimulationViewState` | — | OK. |
| **lib/simulation_screen.dart** | `SimulationScreen`, `_SimulationScreenState` | — | OK (screen + private state). |
| **lib/simulation/vector.dart** | `Vector2` | — | OK. |
| **lib/simulation/angle_util.dart** | — | 4 functions, 1 const | OK (pure util, no types). |
| **lib/simulation/spine.dart** | `Spine` | — | OK. |
| **lib/simulation/spine_node.dart** | `SpineNode` | — | OK. |
| **lib/world/world.dart** | — | constants + 6 functions | OK (coords/chunk helpers only). |
| **lib/world/biome.dart** | `Biome` (enum), `BiomeColors` (ext) | — | OK. |
| **lib/world/biome_map.dart** | `BiomeMap` | — | OK. |
| **lib/world/food.dart** | `BiomeFoodConfig`, `CellType` (enum), `ConsumedRemnant`, `FoodItem` | `biomeFoodConfig()` | **4 types + 1 function** in one file. |
| **lib/world/chunk_manager.dart** | `ChunkManager` | — | OK. |
| **lib/controller/bot_controller.dart** | `BotController` | — | OK. |
| **lib/controller/spawner.dart** | `Spawner` | — | OK. |
| **lib/controller/creature_store.dart** | `BiomeCreatureConfig`, `StoredCreature`, `CreatureStore` | `biomeCreatureConfig()` | **3 classes + 1 function**; config is world/biome concern. |
| **lib/controller/mammoth_store.dart** | `StoredMammoth`, `MammothStore` | 4 consts, 1 getter, 1 function | **2 classes**; parallax constants could move. |
| **lib/controller/food_store.dart** | `FoodStore` | — | OK. |
| **lib/input/simulation_gesture_region.dart** | `SimulationGestureRegion`, `_SimulationGestureRegionState` | — | OK (widget + private state). |
| **lib/render/view.dart** | `CameraView` | — | OK. |
| **lib/render/render_utils.dart** | — | 3 functions | OK (no types). |
| **lib/render/background_painter.dart** | `SolidBackgroundPainter`, `BackgroundPainter` | `_sizeVariance()`, `kSimulationBackground` | **2 painters**; solid bg is generic. |
| **lib/render/spine_painter.dart** | `CreaturePainter` | — | OK. |
| **lib/render/food_painter.dart** | `FoodPainter`, `InnerBodyCloudPainter` | — | **2 painters** in one file. |
| **lib/render/mammoth_painter.dart** | `MammothPainter` | — | OK. |

---

## 2. Issues that stand out

### 2.1 Multiple classes / mixed responsibility in one file

- **lib/world/food.dart**  
  - Contains: `BiomeFoodConfig`, `biomeFoodConfig()`, `CellType`, `ConsumedRemnant`, `FoodItem`.  
  - **Issue:** Biome config is world/biome tuning; the rest are food data and consumption remnants. Two concerns in one file; 4 types is a lot.  
  - **Suggestion:**  
    - Option A: Split into `world/food_types.dart` (CellType, FoodItem, ConsumedRemnant) and keep `world/food.dart` for `BiomeFoodConfig` + `biomeFoodConfig()` (or move biome food config next to other biome config).  
    - Option B: Move `BiomeFoodConfig` and `biomeFoodConfig()` to something like `world/biome_food_config.dart` or alongside `BiomeMap`/biome config, and leave in `food.dart` only `CellType`, `FoodItem`, `ConsumedRemnant`.

- **lib/controller/creature_store.dart**  
  - Contains: `BiomeCreatureConfig`, `biomeCreatureConfig()`, `StoredCreature`, `CreatureStore`.  
  - **Issue:** `BiomeCreatureConfig` is per-biome tuning (world/balance), not store logic.  
  - **Suggestion:** Move `BiomeCreatureConfig` and `biomeCreatureConfig()` to `world/` (e.g. `world/biome_creature_config.dart` or next to biome map). Keep `StoredCreature` + `CreatureStore` in controller.

- **lib/render/background_painter.dart**  
  - Contains: `SolidBackgroundPainter`, `BackgroundPainter`, `_sizeVariance()`, `kSimulationBackground`.  
  - **Issue:** Solid fill is a generic primitive; procedural dots/bubbles/blobs are a different concern.  
  - **Suggestion:** Move `SolidBackgroundPainter` and `kSimulationBackground` to e.g. `render/solid_background_painter.dart` (or a small `render/solid_background.dart`). Keep `BackgroundPainter` + `_sizeVariance` in `background_painter.dart`.

- **lib/render/food_painter.dart**  
  - Contains: `FoodPainter`, `InnerBodyCloudPainter`.  
  - **Issue:** Two unrelated painters: one draws food + remnants, the other draws inner-body “gas” clipped by creature body.  
  - **Suggestion:** Move `InnerBodyCloudPainter` to e.g. `render/inner_body_cloud_painter.dart` so each file has one painter.

- **lib/controller/mammoth_store.dart**  
  - Contains: `StoredMammoth`, `MammothStore`, and parallax constants/helpers (`_kParallaxRadius`, etc.).  
  - **Issue:** Two classes in one file is acceptable; constants could live in a small shared place if reused.  
  - **Suggestion:** Optional: extract parallax constants to e.g. `world/parallax.dart` or keep in file if single-use. No strong need to split the two classes.

### 2.2 Folder / layer grouping

- **ChunkManager in world, depending on controller**  
  - `world/chunk_manager.dart` imports `controller/food_store.dart` and `controller/creature_store.dart`.  
  - **Issue:** “World” usually means terrain/biomes/coords; chunk lifecycle that drives food and creature stores is orchestration, so it sits conceptually in controller.  
  - **Suggestion:** Move `ChunkManager` to `controller/chunk_manager.dart` so all “chunk-driven store” logic lives under controller. Alternatively, keep it in world but then consider renaming to something like “world chunk loader” and accept that world depends on controller for store interfaces.

- **Biome config split across world and controller**  
  - `BiomeFoodConfig` + `biomeFoodConfig()` live in `world/food.dart`; `BiomeCreatureConfig` + `biomeCreatureConfig()` in `controller/creature_store.dart`.  
  - **Issue:** Per-biome tuning is one kind of concern; having it in both world and controller is inconsistent.  
  - **Suggestion:** Put all per-biome config (food targets, creature rates) under `world/` (e.g. `world/biome_food_config.dart`, `world/biome_creature_config.dart`, or a single `world/biome_config.dart`). Controller only imports and uses these configs.

- **simulation_view_state at lib root**  
  - `simulation_view_state.dart` is next to `main.dart` and `simulation_screen.dart`.  
  - **Issue:** It’s view/camera state for the simulation screen, not app-level.  
  - **Suggestion:** Move to `lib/simulation/simulation_view_state.dart` or `lib/view/simulation_view_state.dart` (if you add a `view/` folder for screen-specific state). Keeps “simulation UI” grouped.

- **creature.dart at lib root**  
  - **Current:** Single place for creature definition (identity + appearance).  
  - **OK as-is** if you prefer a flat root for “core domain” types. Optional: move to `lib/creature/creature.dart` or `lib/domain/creature.dart` if you later add more domain types and want a clear domain folder.

---

## 3. Summary: minimal classes per file + grouping

| Priority | Change | Rationale |
|----------|--------|-----------|
| **High** | Split **world/food.dart**: move biome food config out; keep only food types + remnants (or split types into `food_types.dart`). | Single responsibility; fewer types per file. |
| **High** | Move **BiomeCreatureConfig** (and `biomeCreatureConfig`) from controller to world. | Per-biome config belongs in world; controller stays “store + lifecycle”. |
| **Medium** | Split **render/food_painter.dart**: move `InnerBodyCloudPainter` to its own file. | One painter per file. |
| **Medium** | Split **render/background_painter.dart**: move `SolidBackgroundPainter` + `kSimulationBackground` to e.g. `solid_background_painter.dart`. | Solid bg is a generic primitive; procedural background is separate. |
| **Medium** | Move **ChunkManager** from `world/` to `controller/`. | ChunkManager orchestrates stores; fits controller layer. |
| **Low** | Move **simulation_view_state.dart** into `simulation/` or a `view/` folder. | Clearer grouping for simulation UI state. |
| **Low** | Optional: extract mammoth parallax constants to a small shared module. | Only if reused or to shrink mammoth_store.dart. |

---

## 4. Suggested target layout (after changes)

```
lib/
  main.dart
  simulation_screen.dart
  creature.dart
  simulation/
    view_state.dart          # was simulation_view_state.dart
    spine.dart
    spine_node.dart
    vector.dart
    angle_util.dart
  world/
    world.dart
    biome.dart
    biome_map.dart
    biome_food_config.dart   # BiomeFoodConfig + biomeFoodConfig()
    biome_creature_config.dart # BiomeCreatureConfig + biomeCreatureConfig()
    food.dart                 # CellType, FoodItem, ConsumedRemnant only
    chunk_manager.dart        # optional: move to controller/
  controller/
    chunk_manager.dart        # if moved from world
    food_store.dart
    creature_store.dart       # StoredCreature, CreatureStore only
    mammoth_store.dart
    spawner.dart
    bot_controller.dart
  input/
    simulation_gesture_region.dart
  render/
    view.dart
    render_utils.dart
    solid_background_painter.dart  # SolidBackgroundPainter + kSimulationBackground
    background_painter.dart        # BackgroundPainter only
    spine_painter.dart             # CreaturePainter
    food_painter.dart              # FoodPainter only
    inner_body_cloud_painter.dart  # InnerBodyCloudPainter
    mammoth_painter.dart
```

This keeps “minimal classes per file” and groups by: **simulation** (engine + view state), **world** (coords, biomes, food data, optional chunk manager), **controller** (stores, chunk lifecycle, bots), **input**, **render**.
