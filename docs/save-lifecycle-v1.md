# Save Lifecycle v1

This document locks the Milestone 4 saved-run contract for mod version `0.4.0`.
The authoritative product shape remains Section 7 of
`docs/randomizer-spec.md`.

## Engine lifecycle

The bootstrap registers these API-2 listeners:

| Event | Behavior |
|---|---|
| `save.created` | Builds the species manifest, resolves an auto seed, snapshots current settings, invokes the pure generator, validates the complete result, stamps its checksum, and only then assigns `save.modData.pokemon_randomizer`. |
| `save.loading` | Clears the prior session view. The lifecycle manager does not migrate or activate raw data; the runtime restores its baseline and may pre-apply mechanics only when the raw namespace already passes strict checksum validation. |
| `save.loaded` | Validates schema, seed hash, settings shape, compatibility shape, mapping buckets, mapped species, and checksum. It compares the current relevant mods with the New Game snapshot and reports differences without changing saved state. A valid enabled run is copied into session state, then its mechanics are reapplied from the baseline. |
| `save.writing` | Validates the existing checksum first, updates only operational engine-version metadata on a copy, validates and stamps that copy, then replaces the namespace atomically. The New Game relevant-mod snapshot is never refreshed. |

An absent namespace is a vanilla save. Loading it never creates randomizer
state.

## Runtime mechanics compatibility

Base stats, types, evolutions, movesets, TM/HM compatibility, and move data are
saved as mappings and projected onto the active merged `game.data` tables. The
runtime captures only their supported mutable fields once for each distinct
`game.data` identity. Repeated `game.ready` events do not replace that pristine
snapshot. Every apply restores the matching snapshot before projecting a valid
enabled run; vanilla, disabled, invalid, quarantined, and mechanics-free saves
therefore restore the merged values.

The overlay never replaces an entire PokÃ©mon or move record and does not touch
unsupported fields owned by the engine or another mod. Other mods that inspect
the supported fields while a randomized save is active will see the active
randomized values. Mods that require pristine values should capture them after
registries merge and before save mechanics are applied.

## Auto-seed source

`SaveLifecycle.new` accepts an optional `autoSeedEntropy(save)` provider. Tests
inject fixed material through this boundary; production uses the default
runtime provider only when Seed Mode is Auto. Manual mode never calls it.

The default provider mixes `love.timer.getTime()` and four
`love.math.random()` outputs when available, plus wall/process clocks, a
per-process counter, and stable save/player fields. These values are
best-effort, non-cryptographic uniqueness material: Recomp 0.1.38 documents no
operating-system CSPRNG for mods. Missing or failing optional LÖVE functions
cannot block New Game. A failed injected provider uses the same runtime
fallback. `SaveState.makeAutoSeed` hashes the resulting material and stores
one canonical 26-character Crockford Base32 seed with the save.

## Atomic generation

`SaveState.create(input, generate)` does not expose or assign intermediate
mapping tables. A generator exception, structured failure, or invalid result
produces one complete disabled namespace with empty mapping buckets and a
`fallbackCount` of one. The new playthrough therefore remains wholly vanilla
rather than mixing generated and vanilla categories.

Category generation is not implemented yet. In version `0.4.0`, the production
generator returns `GENERATOR_UNAVAILABLE`, so newly created saves receive a
checksummed, disabled namespace. Later category milestones can start producing
enabled runs without changing the lifecycle boundary.

## Checksum

The checksum record is:

```lua
checksum = {
  version = "fnv1a32x4-save-v1",
  value = "<32 uppercase hexadecimal characters>",
}
```

The hash covers schema and algorithm versions, enabled state, canonical seed,
the complete settings snapshot, compatibility data, every mapping bucket,
diagnostics, and any preserved legacy extension state. Canonical serialization makes the result
independent of Lua table insertion order.

This checksum detects accidental damage and ordinary editing. FNV is not a
cryptographic authentication mechanism and is not represented as one.

## Quarantine and recovery

Invalid loaded state is disabled only in the process-local session view.
`save.modData.pokemon_randomizer` is retained as its original Lua data
structure for diagnosis or recovery. Runtime consumers receive no active run.

A later `save.writing` event will not bless damaged data with a fresh checksum.
The invalid namespace is left unchanged and an attributed error is logged.
The exported `save.status()` reports the quarantine and ordered validation
errors; Milestone 5 can render that report in the Options UI.

## Relevant-mod compatibility

`compatibility.relevantMods` is an immutable, sorted New Game snapshot. On
Continue, the lifecycle compares that snapshot with the current loader mod
rows and reports added, removed, and fingerprint-changed mods through
`save.status().report.compatibility`. A difference does not quarantine the
run, alter its checksum-protected mappings, or rewrite the saved snapshot.
Runtime missing-content fallback remains separate and may be reported
alongside a mod-set difference.

The engine version is operational metadata and may be refreshed atomically on
`save.writing`. The pool hash, settings hash, algorithm version, seed,
mappings, and relevant-mod snapshot remain unchanged.

## Save-size accounting

Every newly created namespace records canonical `mappingBytes`,
`namespaceBytes`, and `budgetBytes` values in
`diagnostics.validation`. `namespaceBytes` measures the complete stored
randomizer namespace, including its fixed-width checksum record. The
authoritative vanilla-content budget is 262,144 bytes (256 KiB). Exceeding it
adds an attributed `SAVE_SIZE_BUDGET_EXCEEDED` warning with the measured and
budget byte counts; it never removes mappings or increments fallback counts.

## Species validation

Mapped `species`, `give`, and `get` fields must reference IDs in the current
merged eligible species manifest. String leaves in wild and fishing mapping
tables are also treated as species IDs. Missing content quarantines the active
run without rewriting its stored mapping, allowing the content mod to be
restored.

## Migration harness

The mod registers ordered migrations at versions `0.4.0`, `0.6.0`, `0.40.0`,
and `0.45.0`. The first recognizes development `schemaVersion = 0`
namespaces, converts a string seed to the v1 seed record, fills required v1
buckets, preserves unknown fields, validates the migrated copy, and commits it
only after a checksum is produced. The later handlers perform these upgrades:

- `0.6.0` recomputes the behavior-settings hash under the current exclusion
  rules;
- `0.40.0` adds the disabled legacy field-item setting and an empty
  `fieldItems` mapping bucket; and
- `0.45.0` adds every vanilla/default mechanics setting plus empty
  `pokemonMechanics` and `moveData` mapping buckets.

The field-item and mechanics handlers preserve every existing gameplay
mapping, recompute `compatibility.settingsHash`, and stamp a valid checksum.
They are idempotent and never rerun category generation. Because the settings
hash is part of the run code, migration can change the displayed run code even
though the mappings are byte-for-byte unchanged. Run-code comparison therefore
also requires matching mod and saved algorithm versions; the algorithm version
stored in the save remains authoritative. Unknown fields survive migration and
subsequent checksum stamping.

## Exported inspection API

```lua
mod.exports.save = {
  checksumVersion = "fnv1a32x4-save-v1",
  validate = function(namespace, speciesSet, requireChecksum) ... end,
  checksum = function(namespace) ... end,
  activeRun = function() ... end,
  status = function() ... end,
}
```

`activeRun()` and `status()` return copies. Callers cannot mutate the lifecycle
manager's session state through exported values.

`status().revision` is runtime-only and increments across New Game, load
transitions, and active-run replacement. The spoiler browser uses it to
invalidate cached indexes when a different save becomes active. It is never
written into `save.modData` and does not change saved-run compatibility.
