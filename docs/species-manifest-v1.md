# Species Manifest v1

Status: implemented and tested  
Manifest schema: `1`  
Introduced in mod version: `0.3.0`

The species manifest converts the engine's merged `pokemon` registry into a
validated, deterministically ordered pool for later randomization milestones.
It contains no ROM-derived assets and can be tested entirely with synthetic
records.

## Pool modes

### `vanilla151`

Considers the canonical 151 Red/Blue species IDs in National Dex order. The
manifest output is still sorted by stable species ID before fingerprinting.
Missing or malformed species are excluded and produce an
`INCOMPLETE_VANILLA_POOL` warning.

Canonical engine spellings include:

- `NIDORAN_F`;
- `NIDORAN_M`;
- `FARFETCH_D`;
- `MR_MIME`.

The full ordered ID list is in `src/vanilla_species.lua`.

### `merged`

Considers every key in the merged `pokemon` registry, including valid species
registered by enabled mods. Registry traversal order cannot affect the output.

## Eligibility

A record is eligible only when it has:

- a registry key matching `record.id`;
- a positive integer `dex`;
- integer `hp`, `attack`, `defense`, `speed`, and `special` from 1 through 255;
- at least one nonempty type ID;
- a nonempty growth-rate ID;
- dense `level1Moves`, `learnset`, and `evolutions` arrays;
- nonempty front and back battle-sprite paths.

The gen1recomp loader already validates full record schemas. This second pass
protects randomizer generation and turns a malformed merged record into an
attributed exclusion rather than a partially generated run.

Every exclusion is:

```lua
{
  id = "BROKENMON",
  reasons = {
    {
      code = "MISSING_SPRITE",
      field = "spriteBack",
      message = "back battle sprite path is required",
    },
  },
}
```

Multiple validation failures are retained in stable field-check order.

## Manifest entry

Each eligible species produces:

```lua
{
  id = "BULBASAUR",
  dex = 1,
  bst = 253,
  stats = {
    hp = 45,
    attack = 49,
    defense = 49,
    speed = 45,
    special = 65,
  },
  types = { "GRASS", "POISON" },
  primaryType = "GRASS",
  secondaryType = "POISON",
  stage = "basic",
  legendary = false,
  vanilla = true,
  evolutions = { ... },
  fingerprint = "<32 uppercase hex characters>",
}
```

Generation I BST is the sum of five stats because Special is a single stat.

## Evolution stages

Stages are derived from the eligible pool's original merged-data evolution
graph when the manifest is built, before any evolution destinations are
randomized:

- `basic`: no eligible species evolves into this species;
- `middle`: at least one eligible species evolves into it and it has an
  eligible evolution target;
- `final`: at least one eligible species evolves into it and it has no
  eligible evolution target.

A standalone species is `basic`, even though it does not evolve. Metadata may
override a stage for mod-added mechanics the base evolution list cannot
describe.

Starter Stage `BASIC ONLY`, Similar Strength `SAME STAGE`, and Evolution
`KEEP STAGES` all use this saved original-lineage classification. A generated
evolution graph may later give an originally basic species a pre-evolution;
that does not retroactively change its manifest stage.

## Legendary metadata

The built-in legendary set is:

```text
ARTICUNO
ZAPDOS
MOLTRES
MEWTWO
MEW
```

Another mod may register metadata during its entry chunk:

```lua
local randomizer = mod.find("pokemon_randomizer")
if randomizer then
  randomizer.exports.registerSpeciesMeta("MODMON", {
    legendary = true,
    stage = "basic",
  })
end
```

Supported metadata fields:

| Field | Values |
|---|---|
| `legendary` | boolean |
| `stage` | `basic`, `middle`, or `final` |

An ID may be registered once. Unknown fields, duplicate registrations, and
invalid values fail immediately. Metadata freezes on `mods.loaded`; late
registration fails rather than changing an active manifest.

## Fingerprints

`src/canonical.lua` encodes data with explicit type/length markers, stable map
keys, dense-array order, finite decimal numbers, and cycle rejection.

A species fingerprint hashes generation-relevant validated data:

- ID and dex;
- all five base stats;
- types;
- growth rate;
- level-one moves and learnset;
- eligible evolutions;
- battle-sprite paths used by eligibility;
- resolved stage and legendary status.

The pool hash is:

```text
hash128(canonical({
  schemaVersion = 1,
  mode = poolMode,
  entries = sorted { id, fingerprint } rows,
}))
```

Changing registry insertion order does not change either hash. Changing a
generation-relevant field does.

## Candidate filters

Hard filters never relax:

- excluded IDs;
- `BASIC ONLY`;
- legendary policy `EXCLUDE`, `MATCH`, or `ALLOW`.

Soft filters:

- similar-strength percentage;
- required type.

BST comparison uses integer arithmetic:

```text
abs(candidateBST - sourceBST) × 100 <= sourceBST × percentage
```

When no candidate exists:

1. widen strength by five percentage points at a time through 100%;
2. drop the strength filter;
3. drop the required type only when `allowTypeRelaxation` is true.

Every change appends a deterministic diagnostic:

- `WIDEN_STRENGTH`;
- `DROP_STRENGTH`;
- `DROP_TYPE`.

Stage and legendary restrictions are never silently relaxed. If hard filters
remove everything, the result contains `NO_CANDIDATES`.

## Public API

Pure generator methods:

```lua
generator.buildSpeciesManifest(records, options)
generator.speciesCandidates(manifest, sourceId, rules)
```

Engine-facing methods:

```lua
exports.registerSpeciesMeta(id, metadata)
exports.species.buildManifest(options)
exports.species.candidates(manifest, sourceId, rules)
exports.species.metadataSnapshot()
exports.species.metadataFrozen()
```

`exports.species.buildManifest` reads the complete merged Pokémon registry at
call time and injects the frozen metadata snapshot.
