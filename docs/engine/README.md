# Engine module — docs

**Three modules; do not mix scope.**

| Module   | Responsibility                    | Out of scope here        |
|----------|-----------------------------------|---------------------------|
| **Engine**   | Simulation state, constraints, step(dt), head position in | How head position is chosen; how state is drawn |
| **Renderer** | Drawing the creature (e.g. Flutter/Canvas)                 | —                        |
| **Input**    | User input (e.g. WASD, touch) → head target or velocity    | —                        |

This folder documents the **engine** only. Input (e.g. WASD keys) and rendering are separate; the engine accepts head position and fixed `dt`, and exposes state for the renderer to read.

- `DESIGN.md` — behaviour, spine, constraints (non-technical).
- `TECHNICAL.md` — parameters, data, implementation choices.
