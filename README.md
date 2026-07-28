# Pokémon Gen 1 Recomp Randomizer

A deterministic, per-save randomizer for
[Pokémon Gen 1 Recomp](https://github.com/bryanthaboi/gen1recomp).

## Current status

Milestone 1 is complete: the API-2 mod manifest, compatibility contract,
module layout, attributed logging bootstrap, and pure generator boundary are
in place.

Gameplay randomization is intentionally not active yet. The exported generator
returns `GENERATOR_UNAVAILABLE` until the deterministic seed and PRNG work in
milestone 2 is complete. This prevents an unfinished algorithm from creating a
save that cannot be reproduced later.

See the full [randomizer specification](docs/randomizer-spec.md).

## Compatibility

- gen1recomp engine: `>=1.0.0 <2.0.0`
- mod API: `2`
- randomizer mod version: `0.1.0`
- generator contract: `1`
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
│   └── generator.lua          pure public generator boundary
├── tests/
│   └── scaffold_test.lua      headless Lua contract smoke test
├── tools/
│   └── validate-scaffold.ps1  repository/manifest validation
└── docs/
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
  algorithmVersion = "unimplemented",
  gameVersionRange = ">=1.0.0 <2.0.0",
  generator = {
    available = false,
    validate = function(request) ... end,
    generate = function(request) ... end,
    emptyResult = function() ... end,
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
./tools/validate-scaffold.ps1
```

With a Lua 5.1/LuaJIT-compatible interpreter:

```text
lua tests/scaffold_test.lua
```

The Lua test verifies valid and invalid generation requests, explicit
unavailability, and the reserved result shape without loading LÖVE or a ROM.

## Design guarantees established in milestone 1

- No gameplay hook is registered before deterministic generation exists.
- No network, filesystem, or engine-internals permission is requested.
- Generator request validation does not mutate its input.
- Unsupported engine or mod API versions fail before gameplay.
- Module load failures use the engine's normal attributed rollback behavior.
