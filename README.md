# Pokémon Gen 1 Recomp Randomizer

A deterministic, per-save randomizer for
[Pokémon Gen 1 Recomp](https://github.com/bryanthaboi/gen1recomp).

## Current status

Milestones 1 and 2 are complete. The project now includes the API-2 scaffold
and a fully documented, golden-vector-locked deterministic foundation:

- canonical seed normalization;
- versioned 128-bit hashing;
- independent named RNG streams;
- exact xoshiro128** unsigned-32-bit output;
- rejection-sampled integer ranges;
- stable merge sorting and deterministic key ordering;
- non-mutating Fisher–Yates shuffling.

Gameplay randomization is intentionally not active yet. The exported category
generator continues to return `GENERATOR_UNAVAILABLE` until later milestones
can build and validate complete per-save mappings. This prevents an unfinished
category implementation from creating a run that cannot be reproduced.

See the full [randomizer specification](docs/randomizer-spec.md).
The byte-level algorithm is locked in
[Deterministic Foundation v1](docs/determinism-v1.md).

## Compatibility

- gen1recomp engine: `>=1.0.0 <2.0.0`
- mod API: `2`
- randomizer mod version: `0.2.0`
- generator contract: `1`
- algorithm build: `1.0.0-dev`
- hash: `fnv1a32x4-v1`
- PRNG: `xoshiro128ss-v1`
- requested permissions: none

The engine validates the API and game-version range before executing the mod.
The bootstrap also verifies the mod object's required API-2 surfaces. A failed
check is attributed to this mod and rolled back by gen1recomp's loader.

## Installation

Place this repository's directory under either gen1recomp mod location:

- the game's source-tree `mods/` directory; or
- the LÖVE save directory's `mods/` directory.

The directory must contain `manifest.json` and `main.lua` at its root. Enable
**Pokémon Gen 1 Randomizer** in the in-game mod manager. At milestone 1, a
successful load writes a readiness message to the game log but changes no
gameplay.

## Project layout

```text
.
├── manifest.json              API-2 identity and compatibility gates
├── main.lua                   module assembly entry point
├── src/
│   ├── bootstrap.lua          engine-facing validation, exports, and logging
│   ├── constants.lua          identity and contract versions
│   ├── contracts.lua          pure request/result validation
│   ├── generator.lua          pure public generator boundary
│   ├── hash128.lua            versioned four-lane 128-bit hash
│   ├── rng.lua                named xoshiro128** streams and sampling
│   ├── seed.lua               canonical seed validation
│   ├── stable_sort.lua        stable sort and deterministic keys
│   └── uint32.lua             exact unsigned-32-bit arithmetic
├── tests/
│   ├── foundation_test.lua    algorithm and golden-vector tests
│   ├── golden_vectors.lua     locked independent reference results
│   ├── bootstrap_test.lua     headless mod entry integration test
│   └── scaffold_test.lua      headless Lua contract smoke test
├── tools/
│   ├── test.ps1               syntax and complete test runner
│   └── validate-scaffold.ps1  repository/manifest validation
└── docs/
    ├── determinism-v1.md      exact hash/PRNG specification
    └── randomizer-spec.md     product and technical specification
```

Only `src/bootstrap.lua` knows about the engine mod object. Generator and
contract modules have no LÖVE or engine dependencies, so later generation
logic can be tested headlessly.

## Public inter-mod API

Milestone 1 publishes the following through `mod.exports`:

```lua
{
  contractVersion = 1,
  saveSchemaVersion = 1,
  algorithmVersion = "1.0.0-dev",
  hashVersion = "fnv1a32x4-v1",
  prngVersion = "xoshiro128ss-v1",
  gameVersionRange = ">=1.0.0 <2.0.0",
  generator = {
    available = false,
    foundationAvailable = true,
    validate = function(request) ... end,
    generate = function(request) ... end,
    emptyResult = function() ... end,
    normalizeSeed = function(value) ... end,
    hashSeed = function(canonicalSeed) ... end,
    newStream = function(canonicalSeed, streamName) ... end,
    stableSort = function(values, less) ... end,
    sortedKeys = function(map) ... end,
  },
  contracts = {
    categoryKeys = function() ... end,
    validateGenerationRequest = function(request) ... end,
    validateGenerationResult = function(result) ... end,
  },
}
```

This API is scaffolding, not a stability promise for third-party integrations
until the first playable release.

## Validation

From PowerShell:

```powershell
./tools/test.ps1
```

With a Lua 5.1/LuaJIT-compatible interpreter:

```text
lua tests/scaffold_test.lua
```

The test runner compiles every Lua file, verifies valid and invalid generation
requests, runs all locked hash/PRNG/sampling/shuffle vectors, checks stable
sorting, and validates the repository without loading LÖVE or a ROM.

## Design guarantees established through milestone 2

- No gameplay hook is registered before deterministic generation exists.
- No network, filesystem, or engine-internals permission is requested.
- Generator request validation does not mutate its input.
- Seed, hash, PRNG, sorting, and shuffle behavior is independent of platform
  bit libraries and table iteration order.
- Every randomizer category can receive a separately derived named stream.
- Integer ranges use rejection sampling rather than biased modulo-only draws.
- Unsupported engine or mod API versions fail before gameplay.
- Module load failures use the engine's normal attributed rollback behavior.
