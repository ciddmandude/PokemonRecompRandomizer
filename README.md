# Pokémon Gen 1 Recomp Randomizer

A deterministic, per-save randomizer for
[Pokémon Gen 1 Recomp](https://github.com/bryanthaboi/gen1recomp).

## Current status

Milestones 1 through 9 are complete. The project now includes the API-2
scaffold, a golden-vector-locked deterministic foundation, and a deterministic
species-pool pipeline:

- canonical seed normalization;
- versioned 128-bit hashing;
- independent named RNG streams;
- exact xoshiro128** unsigned-32-bit output;
- rejection-sampled integer ranges;
- stable merge sorting and deterministic key ordering;
- non-mutating Fisher–Yates shuffling.
- canonical vanilla-151 and merged-data pools;
- eligibility validation with structured exclusions;
- BST, type, evolution-stage, and legendary metadata;
- stable species and pool fingerprints;
- hard/soft candidate filters with recorded relaxation;
- a pre-generation inter-mod species metadata API.
- atomic per-save run creation and whole-run vanilla fallback;
- deterministic saved-state checksums and tamper detection;
- load-time mapped-species validation and session-only quarantine;
- pre-write validation that cannot re-checksum damaged state;
- ordered migration registration with an atomic schema-0 harness.
- a native `RANDOMIZER` Options entry and custom paged screen;
- 34 validated, persistent next-run preference fields;
- choice, number, and text editing with per-row help;
- active-run lock/vanilla/quarantine status display;
- confirmed, single-write reset-to-default behavior.
- locked Casual, Standard, and Chaos preset bundles;
- automatic custom-preset detection;
- manual seed validation and 26-character Crockford auto seeds;
- behavior-only settings hashes and compact run codes;
- scrollable next-run review and active-seed transcription screens;
- clipboard copying with an in-game fallback.
- deterministic global grass and surf species mappings;
- unchanged wild levels, encounter rates, and probability slots;
- saved `wildGlobal` mappings consumed through `encounter.species`;
- one-to-one destination selection with deterministic pool exhaustion;
- category-isolated `wild.global` RNG and headless runtime tests.
- deterministic per-map/terrain/slot wild mappings;
- saved Old, Good, and Super Rod mappings without changing bite odds;
- unchanged, ±2, and BST-scaled saved wild levels;
- post-generation pre-League catchability repair and diagnostics.
- a validated starter-offer contract and randomizer adapter;
- a stock-v0.1.30 API-2 Oak's Lab compatibility override;
- vanilla and transformed-offer parity coverage.

Global and area-slot walking, indoor, surfing, and optional fishing
randomization are active. Encounter rates and probability buckets remain
engine-owned and unchanged.

Milestone 9 uses the released recomp v0.1.30 API-2 `map_scripts` registry.
The mod replaces only the three starter-ball talk handlers; every other
Oak's Lab handler remains engine-owned. No engine patch or custom app build
is required. Starter replacement generation itself is planned for M10.

See the full [randomizer specification](docs/randomizer-spec.md).
The byte-level algorithm is locked in
[Deterministic Foundation v1](docs/determinism-v1.md).
Species eligibility and filtering are defined in
[Species Manifest v1](docs/species-manifest-v1.md).
Saved-state behavior is defined in
[Save Lifecycle v1](docs/save-lifecycle-v1.md).
Options UI and persistence behavior are defined in
[Options Shell v1](docs/options-shell-v1.md).
General setting semantics are defined in
[General Settings and Presets v1](docs/general-settings-v1.md).
Global grass and surf behavior is defined in
[Wild Global Mapping v1](docs/wild-global-v1.md).
Area slots, rods, levels, and coverage are defined in
[Wild Area, Fishing, and Levels v1](docs/wild-area-fishing-v1.md).
The scoped starter compatibility override is defined in
[Oak's Lab Starter Compatibility v1](docs/starter-compat-v1.md).

## Compatibility

- gen1recomp engine: `>=0.1.30 <0.2.0`
- mod API: `2`
- randomizer mod version: `0.9.1`
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
**Pokémon Gen 1 Randomizer** in the in-game mod manager. A successful load
writes a readiness message to the game log.

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
│   ├── canonical.lua          deterministic data serialization
│   ├── vanilla_species.lua    canonical 151 engine IDs
│   ├── species_metadata.lua   validated inter-mod metadata
│   ├── species_manifest.lua   eligibility, stages, and fingerprints
│   ├── species_filters.lua    candidate rules and relaxation
│   ├── save_state.lua         pure schema, checksum, and migration logic
│   ├── save_lifecycle.lua     save-event adapter and session quarantine
│   ├── options_schema.lua     all persistent next-run option rows
│   ├── preferences.lua        validated option storage and snapshots
│   ├── options_screen.lua     paged in-game Randomizer screen
│   ├── general_settings.lua   presets, seed resolution, and run identity
│   ├── review_screen.lua      scrollable review/transcription screen
│   ├── stable_sort.lua        stable sort and deterministic keys
│   └── uint32.lua             exact unsigned-32-bit arithmetic
├── tests/
│   ├── foundation_test.lua    algorithm and golden-vector tests
│   ├── golden_vectors.lua     locked independent reference results
│   ├── bootstrap_test.lua     headless mod entry integration test
│   ├── species_fixture.lua    synthetic ROM-independent species data
│   ├── species_manifest_test.lua manifest/filter integration tests
│   ├── save_state_test.lua    schema/checksum/migration tests
│   ├── options_ui_test.lua    preference and screen behavior tests
│   ├── general_settings_test.lua preset/seed/lifecycle identity tests
│   └── scaffold_test.lua      headless Lua contract smoke test
├── tools/
│   ├── test.ps1               syntax and complete test runner
│   └── validate-scaffold.ps1  repository/manifest validation
└── docs/
    ├── determinism-v1.md      exact hash/PRNG specification
    ├── species-manifest-v1.md species pool/filter specification
    ├── save-lifecycle-v1.md   save events and recovery contract
    ├── options-shell-v1.md    Options UI and persistence contract
    ├── general-settings-v1.md preset, seed, and run-code contract
    └── randomizer-spec.md     product and technical specification
```

Only `src/bootstrap.lua` knows about the engine mod object. Generator and
contract modules have no LÖVE or engine dependencies, so later generation
logic can be tested headlessly.

## Public inter-mod API

The mod publishes the following through `mod.exports`:

```lua
{
  contractVersion = 1,
  saveSchemaVersion = 1,
  algorithmVersion = "1.0.0-dev",
  hashVersion = "fnv1a32x4-v1",
  prngVersion = "xoshiro128ss-v1",
  gameVersionRange = ">=0.1.30 <0.2.0",
  registerSpeciesMeta = function(id, metadata) ... end,
  species = {
    manifestVersion = 1,
    buildManifest = function(options) ... end,
    candidates = function(manifest, sourceId, rules) ... end,
    metadataSnapshot = function() ... end,
    metadataFrozen = function() ... end,
  },
  generator = {
    available = true,
    foundationAvailable = true,
    validate = function(request) ... end,
    generate = function(request) ... end,
    emptyResult = function() ... end,
    normalizeSeed = function(value) ... end,
    hashSeed = function(canonicalSeed) ... end,
    newStream = function(canonicalSeed, streamName) ... end,
    stableSort = function(values, less) ... end,
    sortedKeys = function(map) ... end,
    buildSpeciesManifest = function(records, options) ... end,
    speciesCandidates = function(manifest, sourceId, rules) ... end,
  },
  contracts = {
    categoryKeys = function() ... end,
    mappingKeys = function() ... end,
    validateGenerationRequest = function(request) ... end,
    validateGenerationResult = function(result) ... end,
  },
  save = {
    checksumVersion = "fnv1a32x4-save-v1",
    validate = function(namespace, speciesSet, requireChecksum) ... end,
    checksum = function(namespace) ... end,
    activeRun = function() ... end,
    status = function() ... end,
  },
  preferences = {
    schema = function() ... end,
    pages = function() ... end,
    snapshot = function() ... end,
    preset = function(name) ... end,
    detectPreset = function(settings) ... end,
    behaviorSettings = function(settings) ... end,
  },
  runCode = function(savedRun) ... end,
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

## Design guarantees established through milestone 9

- Gameplay hooks are registered only after deterministic generation exists.
- No network, filesystem, or engine-internals permission is requested.
- Generator request validation does not mutate its input.
- Seed, hash, PRNG, sorting, and shuffle behavior is independent of platform
  bit libraries and table iteration order.
- Every randomizer category can receive a separately derived named stream.
- Integer ranges use rejection sampling rather than biased modulo-only draws.
- Invalid merged species are excluded with structured reasons.
- Registry insertion order cannot change species or pool fingerprints.
- Strength/type relaxation is ordered, bounded, and recorded; hard stage and
  legendary rules never relax silently.
- Inter-mod metadata is validated and freezes before play.
- A namespace is assigned on New Game only after complete validation and
  checksum stamping.
- Generator failures create an all-vanilla run, never partial mappings.
- Continue reads behavior state only from the validated saved snapshot.
- Missing or damaged state is quarantined for the session without overwriting
  recovery data.
- Pre-write validation refuses to replace a namespace whose existing checksum
  is invalid.
- Migrations preserve unknown fields and never regenerate mappings.
- Options use the engine's native namespaced persistence and screen registry.
- The Options hook decorates the rows returned by earlier handlers.
- Active-run data is read-only; edits target only the next New Game.
- Invalid stored preferences fall back to declared defaults.
- Reset defaults requires confirmation and persists as one options write.
- Standard exactly equals the declared default snapshot.
- Presets never overwrite master, seed, or race choices.
- Manual seed errors disable generation atomically and remain reviewable.
- Auto seeds are saved as deterministic 128-bit Crockford Base32 identities.
- Run codes bind canonical seed, behavior settings, and eligible pool.
- Settings-hash migration never rerolls an existing mapping.
- Clipboard absence cannot hide the seed or run code from the player.
- A source wild species resolves consistently across every grass and surf map.
- Wild runtime replacement calls the prior hook first and copies its result.
- M7 never changes wild levels, encounter rates, slot odds, or fishing.
- One-to-one wild destinations remain unique until the eligible pool exhausts.
- The `wild.global` stream cannot perturb future category RNG streams.
- Area selection calls the vanilla encounter roll once and draws no extra RNG.
- Ambiguous modded slot identities safely remain vanilla.
- Fishing no-bite behavior and rod candidate odds remain engine-owned.
- Wild levels are generated once, saved, clamped, and used by repel filtering.
- Catchability repair swaps destinations without changing rates or slot odds.
- Vanilla starter offers retain the original trio, level, flags, and objects.
- A resolved starter offer drives preview, confirmation, award, and rival flow.
- Invalid starter-offer output falls back to the original complete offer.
- Stock v0.1.30 receives only the three starter-ball talk overrides.
- Oak, rival battles, parcel and Pokédex delivery, and lab movement remain
  engine-owned.
- Unsupported engine or mod API versions fail before gameplay.
- Module load failures use the engine's normal attributed rollback behavior.
