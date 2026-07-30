# Wild Area, Fishing, and Levels v1

Milestone 8 completes the version `0.8.0` wild category.

## Area-slot identity

`AREA SLOTS` stores one record at:

```lua
mappings.wildAreaSlots[mapId][terrain][slotIndex] = {
  species = destinationId,
  level = resolvedLevel,
}
```

The runtime wraps `encounter.roll` and calls the previous hook exactly once.
On engine `0.1.38` and newer it delegates through the engine-provided RNG
function and records the engine's own probability-bucket draw. The wrapper
does not make an extra RNG draw or reroll the encounter. This gives every
walking and surfing result its exact `slotIndex`, including slots that have
the same source species and level. A native `slotIndex` supplied by another
compatible hook is used directly.

On an older compatible engine that does not provide the RNG in hook context,
the runtime falls back to matching the returned species and level. Only a
duplicate slot that is inherently ambiguous under that fallback remains
vanilla.

Grass, indoor walking encounters, and surfing are supported. Indoor encounter
definitions use the saved grass table because that is how the target engine
represents cave and building encounters.

## Fishing

Generation snapshots `field.fishing` plus each registry key referenced by a
rod's `perMap` value. Old Rod fixed catches, Good Rod candidates, and all
Super Rod map groups receive saved mappings when Fishing is `RANDOMIZED`.

`encounter.fishing` always calls the prior hook first. A `nil` no-bite result
stays `nil`, so hook probabilities are unchanged. `GLOBAL MAP` uses a saved
source mapping under `mappings.fishing.global`; `AREA SLOTS` uses saved
rod/map/slot records under `mappings.fishing.slots`. Gifted or sold Pokémon
never pass through this hook.

## Levels

- `UNCHANGED` saves and returns the source level.
- `±2` draws one offset in `[-2, 2]` per stable slot from `wild.levels`, then
  clamps the result to levels 2–100.
- `SCALED` computes
  `round(level * sqrt(sourceBST / destinationBST))`, clamped to 2–100.

All resolved levels are generated once and saved. Repel filtering occurs after
the species hook in the target engine and therefore observes the saved final
level.

## Catchability guard

With Catchability Guard enabled, generated non-legendary destinations are
checked across walking, surfing, and enabled fishing records. Cerulean Cave
and legacy `UNKNOWN_DUNGEON` map IDs are classified as post–Elite Four; other
merged maps are conservatively treated as reachable.

For area mappings, a late-only destination is swapped with a reachable
duplicate donor. For global mappings, source-to-destination entries are
swapped under the same rule. This preserves the set of generated
destinations, encounter rates, and slot probabilities. If no donor exists,
coverage is mathematically impossible without introducing a new destination;
the mapping stays deterministic and records `WILD_COVERAGE_UNSATISFIED`.

## Isolation and fallback

Species choices use only `wild.global` or `wild.area`; level choices use only
`wild.levels`. Fishing is generated after walking/surfing so enabling it
cannot alter their already-resolved mappings. A category exception clears all
three wild mapping buckets and records a wild-category fallback.
