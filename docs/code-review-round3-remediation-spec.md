# Code Review Round 3 Remediation Specification

Status: Proposed  
Applies to: Pokémon Gen 1 Recomp Randomizer `0.46.0`  
Source review: `code_review.md` round 3  
Priority order: combined-generator coverage, runtime safety, contract accuracy,
then performance hardening

## 1. Purpose

This specification resolves the valid findings in the round-3 code review
without changing the user-facing randomizer design unnecessarily. The primary
goal is to extend the determinism, isolation, and lifecycle protections from
the original Pokémon categories to items, Pokémon mechanics, evolutions, and
move data.

The remediation shall:

- make every serialized mapping bucket participate in the combined golden
  harness;
- exercise every active RNG stream in determinism and isolation tests;
- prevent repeated lifecycle events from replacing the pristine mechanics
  baseline with randomized data;
- accurately document runtime mechanics overlays, stage semantics, preset
  persistence, migrations, and implemented features;
- measure evolution-generator performance before changing its algorithm; and
- preserve existing save compatibility and generated results unless a
  separately reviewed algorithm change is required.

## 2. Decisions

### 2.1 Mapping keys have one source of truth

`Contracts.mappingKeys()` is the authoritative list of serialized mapping
buckets. Tests, validation, hashing helpers, and diagnostics shall consume that
list instead of maintaining independent copies.

The required mapping buckets are:

1. `wildGlobal`
2. `wildAreaSlots`
3. `fishing`
4. `starters`
5. `starterFlags`
6. `staticEncounters`
7. `gifts`
8. `trades`
9. `prizes`
10. `trainerParties`
11. `fieldItems`
12. `pokemonMechanics`
13. `moveData`

### 2.2 RNG stream names have one source of truth

All stream identifiers shall be declared in a structured constants table. The
generator and tests shall read identifiers from that table. Documentation may
be generated from it or tested against it, but shall not silently drift.

The current required streams are:

- `wild.global`
- `wild.area`
- `wild.levels`
- `starters`
- `rival.counterpick`
- `static.encounters`
- `static.levels`
- `gifts`
- `gift.levels`
- `trades`
- `prizes`
- `trainers.species`
- `trainers.levels`
- `trainers.sizes`
- `trainers.rival`
- `items`
- `mechanics.base_stats`
- `mechanics.pokemon_types`
- `mechanics.movesets`
- `mechanics.tmhm`
- `mechanics.evolutions`
- `mechanics.trade_evolutions`
- `mechanics.move_types`
- `mechanics.move_power`
- `mechanics.move_accuracy`
- `mechanics.move_pp`
- `validation.swaps`

### 2.3 Mechanics remain runtime overlays

Base stats, Pokémon types, evolutions, movesets, compatibility, and move data
must continue to affect all engine systems consistently. The supported mod-only
implementation therefore remains a reversible overlay on the active game's
merged runtime tables.

The specification shall no longer claim that these runtime tables are never
mutated. Instead, it shall require that:

- a pristine post-merge baseline is captured exactly once for each distinct
  game-data table;
- every application begins by restoring that baseline;
- switching to a vanilla, disabled, or invalid save restores the baseline;
- repeated `game.ready`, load, or apply events cannot promote randomized data
  into the baseline; and
- other mods may observe the active overlay while a randomized save is active.

### 2.4 Stage settings use original-lineage classification

To avoid reordering the generator and changing existing mappings, stage-based
selection shall explicitly mean the species' original merged-data lineage at
generation time, before evolution destinations are randomized.

This applies to:

- Starter Stage `BASIC ONLY`;
- Similar Strength `SAME STAGE` in Pokémon replacement categories; and
- Evolution mode `KEEP STAGES`.

The UI and documentation shall use wording such as `ORIGINALLY BASIC` and
`ORIGINAL EVOLUTION STAGE` where space permits. Randomized evolution results
may give an originally basic Pokémon a new pre-evolution. This is intentional
under `SIMILAR` and `FULL RANDOM` evolution modes and shall not be presented as
a violation of Starter Stage.

Changing stage rules to use the generated graph is outside this remediation
because it would require generating evolutions before other categories and
would alter deterministic output across the generator.

### 2.5 Chooser selections are persistent preferences

Selecting a preset in the mandatory New Game chooser shall continue to write
that preset to the global next-run preferences. Choosing custom settings shall
continue to set the preset marker to `CUSTOM`. Documentation must state that a
choice made during New Game becomes the starting configuration for the next
New Game until changed.

### 2.6 Migrated run codes are version-sensitive

Migrations shall continue recomputing `compatibility.settingsHash` after they
add behavior-setting defaults. Retaining a stale hash would violate save
validation.

Documentation shall state that:

- a migration can change an existing save's displayed run code without
  rerolling its gameplay mappings;
- run-code comparisons are meaningful only when the randomizer algorithm and
  mod version are also the same; and
- the saved algorithm version remains the authoritative indication of which
  generator produced the mappings.

No run-code format change is required by this remediation.

## 3. Functional requirements

### 3.1 Combined golden coverage

`R3-FR-01` The golden test shall obtain its complete mapping-key list from
`Contracts.mappingKeys()`.

`R3-FR-02` Every mapping key returned by the contract shall be hashed
individually for every golden vector.

`R3-FR-03` The golden suite shall fail if any contract mapping bucket never
contains data in at least one golden vector.

`R3-FR-04` The golden suite shall hash the complete thirteen-bucket mapping
table. It shall not construct a legacy ten-bucket aggregate.

`R3-FR-05` The harness shall stop deleting item and mechanics settings before
generation.

`R3-FR-06` The combined harness shall provide representative item definitions,
item checks, moves, Pokémon learnsets, compatibility data, and evolution edges
sufficient to exercise every new generator.

`R3-FR-07` Golden vectors shall include, at minimum:

- one closed-pool non-key item shuffle;
- one progression-safe mixed item placement containing TMs, HMs, key items,
  badges, and hidden items;
- one randomized-shop and price configuration;
- one base-stat and Pokémon-type configuration;
- one moveset, learn-level, and TM/HM compatibility configuration;
- one randomized-evolution and converted-trade-evolution configuration;
- one move-type and move-data configuration; and
- one configuration enabling every supported new category together.

`R3-FR-08` Every new golden vector shall lock the input, manifest, sources,
individual mapping buckets, aggregate mappings, warnings, fallback count, and
validation summary.

`R3-FR-09` Expected vectors shall be regenerated only through the repository's
reviewed golden-vector update process. Expected values shall remain literal in
source control.

### 3.2 Property and isolation coverage

`R3-FR-10` Property tests shall validate every `fieldItems` destination against
the item registry and supported source catalog.

`R3-FR-11` Property tests shall validate progression-safe item placements
against their reachability constraints.

`R3-FR-12` Property tests shall validate randomized shop entries, prices, HM
exclusion, and item-category restrictions.

`R3-FR-13` Property tests shall validate Pokémon mechanic overlays for valid
species IDs, stat bounds, type IDs, move IDs, learn levels, compatibility
shape, and evolution triggers.

`R3-FR-14` Evolution property tests shall continue enforcing branch count,
distinct sibling branches, no self-evolution, no directed cycles, valid
destinations, deterministic fallback attribution, and bounded termination.

`R3-FR-15` Move-data properties shall validate registered move IDs, registered
types, power/accuracy/PP bounds, status-move preservation, and protected effect
behavior.

`R3-FR-16` Stream-isolation tests shall cover the `items` stream and every
`mechanics.*` stream.

`R3-FR-17` When multiple streams contribute to the same mapping bucket,
isolation shall compare field projections rather than only the complete bucket.
Required projections include:

- base stats;
- Pokémon types;
- starting moves and level-up learnsets;
- TM/HM compatibility;
- evolution destinations;
- evolution triggers;
- move types;
- move power;
- move accuracy; and
- move PP.

`R3-FR-18` Toggling one new category shall not change any unrelated old mapping
bucket.

`R3-FR-19` When every setting that feeds a mapping bucket is `VANILLA`, that
bucket shall remain empty and shall not perturb another category's output. A
vanilla mechanics subsetting may coexist with fields generated by another
enabled subsetting in the shared `pokemonMechanics` bucket.

### 3.3 Stream registry

`R3-FR-20` Generator code shall not contain independent literal stream names
outside the authoritative registry, except in tests that deliberately validate
invalid identifiers.

`R3-FR-21` The stream registry shall expose a deterministic dense list for
collision testing and structured names for generator call sites.

`R3-FR-22` The collision test shall derive all 27 active streams for multiple
seeds and assert that each derived state is distinct for a given seed.

`R3-FR-23` The test shall reject duplicate declared names and names that violate
the documented identifier grammar.

`R3-FR-24` A test shall compare the authoritative list with the stream lists in
the determinism and randomizer specifications, or those documentation blocks
shall be generated from the authoritative list.

### 3.4 Mechanics runtime lifecycle

`R3-FR-25` Mechanics baselines shall be associated with the identity of
`game.data`, not stored as one replaceable process-wide snapshot.

`R3-FR-26` Capturing an already known `game.data` table shall be idempotent and
shall not overwrite its baseline.

`R3-FR-27` Applying a run shall restore the appropriate baseline before writing
the run's overlays.

`R3-FR-28` Applying `nil`, a disabled run, a quarantined run, or a run without
mechanics mappings shall leave the active data at its baseline values.

`R3-FR-29` Repeating `game.ready` after mechanics are applied shall not change
the baseline.

`R3-FR-30` Repeating `apply` with the same run shall be idempotent.

`R3-FR-31` Switching randomized A → randomized B → vanilla → randomized A in
one process shall produce the correct data at every step without accumulated
changes.

`R3-FR-32` Baseline capture and restore shall copy only the supported mutable
fields and shall never replace entire Pokémon or move records.

`R3-FR-33` Runtime documentation shall disclose that other mods reading the
active game-data tables observe randomized mechanics while the run is active.

### 3.5 Documentation and semantics

`R3-FR-34` Section 14 of the main specification shall remove implemented
features from the out-of-scope list. Remaining exclusions shall distinguish
abilities, maps, warps, palettes, music, and any still-unsupported scripted
rewards.

`R3-FR-35` Both documented stream lists shall contain exactly the authoritative
27 names in deterministic order.

`R3-FR-36` NFR-04 shall prohibit mutation of executable save data and immutable
content registries while explicitly allowing the documented reversible
mechanics overlay on active game-data tables.

`R3-FR-37` Starter Stage, Similar Strength `SAME STAGE`, and Evolution `KEEP
STAGES` shall be documented as using original merged-data lineage.

`R3-FR-38` The README and New Game documentation shall state that preset and
custom choices made in the chooser persist as future next-run preferences.

`R3-FR-39` The README's run-code section shall describe migration- and
version-sensitive settings hashes.

`R3-FR-40` Migration tests shall assert that field-item and mechanics migrations
preserve existing gameplay mappings, add their required empty mapping buckets,
add vanilla/default settings, recompute the settings hash, and stamp a valid
checksum.

### 3.6 Evolution performance and robustness

`R3-FR-41` A headless benchmark shall record evolution generation time, PRNG
draw count, visited search nodes, relaxation counts, and success/fallback state.

`R3-FR-42` Benchmarks shall cover representative pools of 151, 500, and 1,000
species, including branching graphs and deliberately difficult constraints.

`R3-FR-43` No optimization shall be accepted solely on theoretical grounds.
Baseline and candidate implementations must be measured with identical inputs.

`R3-FR-44` Reusing candidate orders, replacing recursion, or changing search
order must not silently change seeded mappings. If mappings change, the
algorithm version shall be incremented and all golden vectors regenerated.

`R3-FR-45` Cycle detection shall terminate safely for the maximum supported
merged pool. An iterative traversal or explicit depth/node guard shall be used
if the benchmark demonstrates a realistic Lua stack-risk.

`R3-FR-46` Mechanics baseline memory shall be measured for vanilla data and the
largest practical merged fixture. Optimization is required only if the copy is
shown to violate the project's memory or startup targets.

## 4. Non-functional requirements

`R3-NFR-01 Determinism` Identical seed, settings, sources, algorithm version,
and stream registry shall produce byte-equivalent normalized results on Lua
5.1.5 across supported operating systems.

`R3-NFR-02 Isolation` No category or mechanics subcategory may perturb an
unrelated mapping or field projection.

`R3-NFR-03 Compatibility` Existing saves shall load without rerolling mappings.
Runtime overlay changes shall not require an engine fork.

`R3-NFR-04 Safety` A repeated lifecycle event shall never make randomized
runtime content the restore baseline.

`R3-NFR-05 Performance` The complete generator shall remain within the existing
CI limits. Evolution-specific benchmarks shall report results rather than hide
regressions inside the full-suite average.

`R3-NFR-06 Maintainability` Mapping keys and stream identifiers shall each have
one authoritative machine-readable declaration.

`R3-NFR-07 Diagnostics` Any new fallback or bounded-search failure shall retain
its stable code and sufficient context for spoiler-log and manual-test review.

`R3-NFR-08 Documentation` User-facing descriptions shall distinguish original
lineage from randomized evolution results and global preferences from per-save
snapshots.

## 5. Compatibility and versioning

- The save schema remains version 1 unless implementation proves that a schema
  change is necessary.
- Merely adding tests, documentation, baseline guards, or a stream-name
  registry does not require an algorithm-version change.
- Any change to stream identifiers, stream assignment, RNG draw order,
  evolution candidate ordering, relaxation order, or generated mapping values
  requires an algorithm-version increment and regenerated golden expectations.
- A mod-version increment is required for the completed remediation release.
- Existing field-item and mechanics migrations must remain idempotent.
- The release archive must remain a mod-only package compatible with the
  supported Gen1Recomp API; no engine patch may be introduced.

## 6. Required tests

The remediation release gate shall include:

1. Lua 5.1 syntax validation for every Lua file.
2. Existing 30-test regression suite.
3. Contract-derived thirteen-bucket golden validation.
4. New item/mechanics/evolution/move golden vectors.
5. New item and mechanics combined-property checks.
6. Twenty-seven-stream collision and identifier validation.
7. Per-stream and per-field isolation checks.
8. Repeated-capture and multi-save mechanics-runtime tests.
9. Both migration tests, including run-code/settings-hash behavior.
10. Stage-semantics documentation/schema assertions.
11. Evolution benchmark output for required fixture sizes.
12. Package validation, native extraction validation, and checksum generation.

## 7. Seven implementation milestones

### Milestone 1 — Contract-driven golden mapping guard

Urgency: Critical  
Findings: H2  
Status: Implemented

- Replace the golden test's local mapping list with
  `Contracts.mappingKeys()`.
- Hash all thirteen buckets individually and as one complete mapping table.
- Make participation checks automatically cover every future contract key.
- Update expectation structure and failure messages so a changed bucket is
  named directly.
- Retain the existing legacy vectors without pretending their empty new
  buckets constitute enabled-category coverage.

Exit criteria:

- Removing any contract mapping from all vectors causes a clear test failure.
- Adding a future mapping key to the contract automatically makes the golden
  suite demand coverage for it.

### Milestone 2 — Combined item and mechanics golden vectors

Urgency: Critical  
Findings: H1
Status: Implemented

- Expand the generator harness with realistic item, shop, move, compatibility,
  and evolution sources.
- Stop deleting the new settings from golden requests.
- Add the minimum vectors required by `R3-FR-07`, including one all-enabled
  vector.
- Lock individual and aggregate hashes, warnings, fallbacks, and validation
  results.
- Keep old vectors stable where their effective inputs have not changed.

Exit criteria:

- `fieldItems`, `pokemonMechanics`, and `moveData` each participate in multiple
  golden vectors.
- At least one vector generates all thirteen mapping buckets in one combined
  request where the category logically has data.

### Milestone 3 — Combined properties and complete stream isolation

Urgency: High  
Findings: H1, M1
Status: Implemented

- Add item, shop, Pokémon-mechanics, evolution, and move-data invariants to the
  real combined property test.
- Add isolation cases for `items` and every `mechanics.*` stream.
- Introduce stable field-projection hash helpers for mechanics subcategories.
- Prove new toggles cannot alter old mapping buckets or unrelated mechanics
  fields.
- Include disabled/vanilla cases and bounded failure cases.

Exit criteria:

- Every active stream is exercised by at least one enabled combined request.
- A deliberately reused or misspelled stream name causes a focused isolation
  or collision test failure.

### Milestone 4 — Mechanics baseline and save-switch hardening

Urgency: High  
Findings: M2
Status: Implemented

- Store pristine baselines per `game.data` identity.
- Make repeated capture idempotent.
- Restore before every apply and on vanilla/invalid save transitions.
- Add repeated-`game.ready`, repeated-apply, and A → B → vanilla → A tests.
- Update NFR-04 and compatibility documentation for reversible runtime
  overlays and cross-mod visibility.

Exit criteria:

- No tested event order can promote randomized data into a baseline.
- Switching saves in one process always restores or applies the correct values.

### Milestone 5 — Authoritative stream registry

Urgency: Medium  
Findings: M1, M4
Status: Implemented

- Introduce structured stream constants used directly by the generator.
- Derive the dense collision-test list from those constants.
- Validate all 27 identifiers and derived states.
- Synchronize or test both documented stream lists.
- Confirm that the refactor does not change any existing stream string or
  golden output.

Exit criteria:

- Searching generator code finds no independent production stream literals.
- Constants, generator call sites, collision tests, and documentation agree on
  the same 27 names.

### Milestone 6 — Semantics, migration, and scope reconciliation

Urgency: Medium  
Findings: M3, M5, L1, L2
Status: Implemented

- Correct the out-of-scope section.
- Define stage rules as original-lineage rules in schema help, README, full
  specification, and manual tests.
- Document chooser persistence and migration-sensitive run codes.
- Add complete field-item and mechanics migration assertions.
- Review spoiler terminology so it distinguishes original-stage rules from
  current randomized evolutions where relevant.

Exit criteria:

- No shipped mechanic is described as out of scope.
- A reader can predict preset persistence, stage behavior, and run-code changes
  after migration from the documentation alone.

### Milestone 7 — Evolution and runtime performance hardening

Urgency: Low  
Findings: L3
Status: Implemented

- Add repeatable evolution and baseline-memory benchmarks.
- Measure before selecting an optimization.
- If necessary, bound or replace recursive cycle traversal.
- Optimize per-edge candidate ordering only when measurements justify it.
- Preserve output exactly where possible; otherwise increment the algorithm
  version and regenerate all combined golden expectations.
- Run the complete release gate and build the verified archive/checksum.

Exit criteria:

- Benchmark results and the optimization decision are recorded.
- Large merged fixtures terminate without stack overflow or unbounded search.
- The full Lua, property, golden, migration, and package suites pass.

## 8. Completion definition

Round-3 remediation is complete only when:

- every contract mapping bucket has enabled combined golden coverage;
- every RNG stream is declared, collision-tested, and isolation-tested;
- mechanics overlays survive repeated lifecycle and multi-save tests without
  baseline contamination;
- stage semantics and migration behavior match their documentation;
- performance risks have measured dispositions; and
- the release package passes the repository's full CI and packaging checks.
