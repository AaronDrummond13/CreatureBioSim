# Engine — Design (2D)

**Scope of this doc:** engine module only. Input (e.g. WASD) and rendering are separate modules; not specified here.

---

## Scope (engine)

- **2D only.** Ground plane, bird's eye view. No height, no 3D.
- **No collision.** No interaction with ground or other bodies.
- **Deterministic.** Same inputs → same result. Fixed time step.
- **Fixed segment length.** All segments same length; set at creation.

---

## Spine

- **Spine** = chain of segments. Length = number of segments (1, 2, 3, …).
- **Segment** = rigid link between two points. One fixed length for all segments.
- **Points:** base (root), then one joint per extra segment, then head.  
  n segments ⇒ n+1 points.
- **Control:** only the head position is driven (by input module). All other points follow via constraints.

**Spine length 1:** Two points (base + head), one segment. No joints → no angle limits. The whole creature rotates toward the direction of travel (rigid rod).

**Spine length 2+:** One or more joints. Each joint can bend (fold/open) only within a critical angle.

- **Within limit:** Motion is absorbed at the joint. One segment can stay put while the other moves (e.g. head moves, base segment stationary until the angle forces it to move).
- **At limit:** The next segment must rotate too → the creature rotates as a whole until direction changes.
- **Head toward spine** → joint folds → crumpling.
- **Head away from spine** → angle opens; if it can open while keeping the next segment stationary it does, otherwise that segment follows → opening.

This gives crumple/open behaviour without rigid-body collision.

---

## Constraints

1. **Distance.** Each segment keeps a fixed length. Non-negotiable.
2. **Angle (at joints).** Max bend per joint. Defines the critical angle; beyond it the whole chain must rotate. Enables crumple/open.

---

## Growth

- Spine is growable (add segments).
- New segment = new joint + new fixed-length link. Growth rule (e.g. always at base end) TBD.

---

## Out of scope (engine)

- Collision, height, 3D, rendering, non-determinism, variable segment length.
- How head position is produced (input module).
