# Wild Global Mapping v1

Milestone 7 implements saved global walking and surfing randomization for mod
version `0.7.0`.

## Generation

When `wild_pokemon` is `global_map`, generation scans the merged encounter
registry in sorted map-ID order, then grass before water, then numeric slot
order. It collects each distinct source species and resolves it exactly once
through the eligible species manifest.

The category uses only the named `wild.global` RNG stream. Candidate selection
honors Similar Strength, Legendaries, Species Pool, and Duplicate Policy.
`ALLOW` samples with replacement. `ONE-TO-ONE` excludes destinations already
used by the category; if the filtered destination pool is exhausted, it
restarts the pool deterministically and records
`WILD_UNIQUENESS_POOL_RESET`.

The result is stored as:

```lua
mappings.wildGlobal[sourceSpecies] = destinationSpecies
```

Unknown or unmappable source species remain vanilla and produce a saved
diagnostic. A category-level error produces an empty wild mapping and one
fallback diagnostic without affecting other category buckets.

## Runtime

The mod wraps `encounter.species`. Its wrapper:

1. calls the next hook first;
2. checks for a validated active run using `GLOBAL MAP`;
3. accepts only `grass` or `water` terrain;
4. shallow-copies a mapped encounter record;
5. replaces only `species`.

The original record, level, slot metadata, encounter rate, and probability
buckets are unchanged. Missing mappings, malformed values, disabled runs, and
non-wild terrain return the prior hook result unchanged.

Fishing is deliberately excluded. `encounter.fishing`, area-slot mappings,
wild level adjustment, and catchability validation belong to milestone 8.

## Determinism and save behavior

Encounter registry insertion order cannot affect a mapping. The complete
mapping and diagnostics are created during `save.created`, validated against
the eligible species set, checksummed, and stored in the same save namespace
as the canonical seed. Continue never regenerates it.
