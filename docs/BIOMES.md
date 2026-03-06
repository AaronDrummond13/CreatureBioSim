# Biomes / zones

World is divided into **chunks** (5000 units by default). Chunks form a **10×10 grid that wraps** (endless in both axes). Each chunk has a **biome** (deterministic, hash of chunk index).

## Biomes (current)

| Biome    | Colour tone   | Use now                |
|----------|---------------|------------------------|
| Clear    | Gentle blue   | Background, dots tint  |
| Deep     | Darker blue   | Background, dots tint  |
| Algae    | Greenish     | Background, dots tint  |
| Poisoned | Purplish     | Background, dots tint  |
| Dirty    | Brownish     | Background, dots tint  |

**Blending:** At any world position we blend the colours of the 4 neighbouring chunk corners (bilinear) so boundaries are smooth.

## Staging (see IDEAS.md)
- Start with no biomes (e.g. fresh water everywhere). When the organism “grows” (implied scale), either introduce biomes as a concept or turn on biome effects. TBD.

## Not done yet (ideas)

- **Creature schematics** – which creatures/spawns appear per biome
- **Objects** – pickups, obstacles, or decor per biome
- **Chunk shape/size** – smaller chunks, non-square, or hand-authored regions
- **Per-biome rules** – e.g. speed, visibility, damage over time
- **Names** – “Poisoned” vs “Toxic” / “Polluted”; “Clear” vs “Clear Water”
