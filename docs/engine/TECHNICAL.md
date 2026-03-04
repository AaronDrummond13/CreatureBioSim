# Engine — Technical

Lives alongside `DESIGN.md`. Design = behaviour and intent; this doc = parameters, data, and implementation choices.

**Scope:** engine module only. Input and renderer are separate; engine exposes state and accepts head position + `dt`.

---

## Spine parameters (input)

| Parameter | Type | Meaning |
|-----------|------|---------|
| `segmentCount` | int | Number of segments (1, 2, 3, …). |
| `segmentLength` | double | Fixed length of every segment (e.g. metres). |
| `maxJointAngle` | double | Max bend at each joint (e.g. radians). Only used when `segmentCount ≥ 2`. |

**Derived (no separate storage):**

- **Vertex count** = `segmentCount + 1` (base, joints, head).
- **Joint count** = `segmentCount - 1` when `segmentCount ≥ 2`; 0 when `segmentCount == 1`.

So vertex index `0` = base, `segmentCount` = head. Joint `j` is between vertex `j` and `j+1`.

---

## Angle restriction: global vs per-joint

- **Global (current choice):** One `maxJointAngle` for all joints. Single number, same limit everywhere. Easiest to tune and reason about.
- **Per-joint (later):** Each joint could have its own limit (e.g. list/array of angles). Allows stiffer middle, looser head, etc.

**Recommendation:** Store a single `maxJointAngle` for now. API can later accept per-joint overrides or a list; internal representation can stay one value until we need variation.

---

## Capturing the config

One canonical spine config object (or constructor args) is enough:

- `segmentCount`
- `segmentLength`
- `maxJointAngle` (ignored when `segmentCount == 1`)

No extra "vertex count" or "joint count" fields — those are derived from `segmentCount`. Same for "position of vertex" — vertices are ordered 0 (base) to `segmentCount` (head); no separate list of roles.

---

## Summary

- **In:** `segmentCount`, `segmentLength`, `maxJointAngle`.
- **Derived:** vertex count, joint count, vertex ordering.
- **Angle:** global for now; per-joint reserved for later.
