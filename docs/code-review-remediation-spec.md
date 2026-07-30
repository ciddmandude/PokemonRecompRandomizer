# Pokémon Gen 1 Recomp Randomizer — Code Review Remediation Specification

Status: Draft for implementation  
Target mod version: post-`0.15.1`  
Target engine: gen1recomp `0.1.38`  
Release model: mod-only; no forked engine build  
Source review: `CODE_REVIEW.md`, validated against the current repository and
gen1recomp `0.1.38`

## 1. Purpose

This specification addresses the valid findings from the `0.15.1` code
review. Work is ordered by user impact and release urgency:

1. make the distributable load correctly on every supported platform;
2. correct settings that can produce prohibited or unexpectedly vanilla
   results;
3. protect saved-run identity and make failures visible;
4. establish generator-level regression coverage before changing algorithms;
5. bring Race Mode behavior and claims into line with what a mod-only build
   can enforce;
6. strengthen progression guarantees and fragile scripted gifts;
7. finish API, release, and maintenance cleanup.

Existing randomized saves must never be regenerated or silently rewritten as
part of these changes.

## 2. Scope

### 2.1 In scope

- Cross-platform ZIP creation and verification.
- Legendary-policy enforcement in NPC trades.
- Per-source and per-slot trainer fallback.
- Immutable compatibility snapshots and defensive active-run UI.
- Full-generator golden vectors and meaningful property tests.
- Deterministic one-to-one assignment that avoids preventable pool resets.
- Correct Hall of Fame and Race Mode unlock behavior.
- Organizer-bound passphrase setup, masked entry, seed entropy, and honest
  cryptographic capability reporting.
- A real progression model for Catchability Guard.
- Safer static/gift script control flow and box-full behavior.
- Save-size budget reconciliation.
- CI, release-payload cleanup, public API hardening, metadata conflict policy,
  and dead-code removal.

### 2.2 Out of scope

- Engine patches or a forked gen1recomp executable.
- Server-authoritative races or anti-cheat.
- Mechanics-randomizer features from other branches.
- Previously documented unsupported encounter paths.
- Regenerating mappings in an existing save after an algorithm update.
- Findings disproven against Recomp `0.1.38`, including the `PSYCHIC_TYPE`
  identifier, type-chart `/10` conversion, the boot-skeleton
  `save.created` guard, and claims that public run exports expose live saved
  tables.

## 3. Priority definitions

- **P0 — Release blocker:** the shipped mod cannot be trusted to install or
  execute on a supported platform.
- **P1 — Gameplay correctness:** a selected setting is violated or an enabled
  category unexpectedly becomes vanilla.
- **P2 — Run integrity and regression safety:** saved identity, validation, or
  tests cannot reliably detect behavior changes.
- **P3 — Race Mode integrity:** advertised unlock or encryption behavior is
  misleading or ineffective.
- **P4 — Progression and script safety:** guarantees are materially weaker
  than their labels, or hand-authored scripts can consume a one-time reward.
- **P5 — Maintenance:** API hardening, package size, repository hygiene, and
  low-risk cleanup.

## 4. Functional requirements

### 4.1 Cross-platform packaging

`PKG-01` Every ZIP entry shall use `/` as its path separator. No entry may
contain `\`, an absolute path, `..`, or an empty path segment.

`PKG-02` `manifest.json`, `main.lua`, and every runtime file under `src/`
shall be stored at the ZIP root using the same paths passed to `mod:read`.

`PKG-03` Packaging shall be deterministic except for explicitly documented
ledger timestamps. Given identical source files, the payload file list,
per-file hashes, and path spelling shall be identical.

`PKG-04` A packaging test shall inspect entry names through a ZIP API without
normalizing separators. Listing through `tar` or another tool that silently
normalizes names is not sufficient.

`PKG-05` The packaged archive shall be extracted and loaded by the official
Recomp `0.1.38` ROM-free modkit fixture before release.

`PKG-06` Release validation shall run on Windows and Linux. A macOS extraction
smoke test should be added when a runner is available.

### 4.2 Legendary policy and NPC trades

`TRD-01` `Legendaries = EXCLUDE` shall be a hard filter for requested,
received, and prize Pokémon under every fairness mode.

`TRD-02` `Trade Fairness = NO DOWNGRADE` shall add a minimum-BST rule without
replacing the active legendary rule.

`TRD-03` If no candidate satisfies both the legendary policy and the
no-downgrade floor, generation may relax only the documented soft BST rule.
It shall never relax `EXCLUDE`.

`TRD-04` Tests shall cover all combinations of legendary policy and trade
fairness, including the Casual preset and a pool where a legendary is the
only species inside the initial strength band.

### 4.3 Trainer isolation and fallback

`TRN-01` One source species missing from the eligible manifest shall not
disable trainer randomization for unrelated species, parties, or classes.

`TRN-02` In `GLOBAL MAP` mode, an unmappable source species shall remain
vanilla everywhere while other source species keep their saved global
mappings.

`TRN-03` In slot-based and themed modes, an unmappable slot shall retain its
original species and level. Remaining slots in the party shall still
randomize.

`TRN-04` Each fallback shall record an attributed diagnostic containing the
trainer class, party index, slot index, source species, and reason. Runtime
logs shown during a locked race shall redact resolved destinations.

`TRN-05` A malformed party structure may still reject that party, but it shall
not clear already generated mappings for unrelated trainers.

`TRN-06` Required parties shall remain nonempty and contain no more than six
valid Pokémon after partial fallback.

### 4.4 Saved-run integrity and defensive UI

`SAV-01` `compatibility.relevantMods` shall remain the New Game snapshot for
the lifetime of the run.

`SAV-02` `save.writing` may update operational metadata such as the engine
version, but shall not replace the original pool hash, settings hash,
algorithm version, seed, mappings, or relevant-mod snapshot.

`SAV-03` On Continue, the current relevant-mod set shall be compared with the
saved snapshot. Differences shall produce a non-destructive compatibility
report and shall not regenerate mappings.

`SAV-04` `Copy Active Seed` and the active-run summary shall tolerate missing
or future settings keys. Missing values shall display `UNKNOWN` or
`UNAVAILABLE` rather than throwing.

`SAV-05` Save validation shall preserve unknown future fields and continue to
quarantine checksum or structural damage.

`SAV-06` The randomizer namespace shall remain assigned only after generation,
validation, and checksum stamping succeed.

### 4.5 Save-size budget

`SIZE-01` The authoritative vanilla-content budget shall be **256 KiB** of
canonical serialized randomizer state with all categories enabled.

`SIZE-02` The specification, README, validation warning, and tests shall use
the same 256 KiB value.

`SIZE-03` Exceeding the budget shall produce an attributed warning containing
the measured byte count and budget. It shall not corrupt or partially remove
mappings.

`SIZE-04` Tests shall measure both the complete namespace and the mappings
subtree so future growth is attributable.

## 5. Generator requirements

### 5.1 Golden vectors

`GEN-01` The repository shall contain at least 20 generator-level golden
vectors.

`GEN-02` Each vector shall include:

- canonical seed;
- complete normalized settings;
- canonical species manifest;
- encounters, trainers, field data, and type-chart inputs;
- expected canonical hash of every mapping category;
- expected combined mappings hash;
- expected warning codes, fallback count, and validation summary.

`GEN-03` Vectors shall cover Casual, Standard, Chaos, and targeted custom
settings. At least one vector shall exercise every enabled category together.

`GEN-04` Reordering input map keys shall not change any expected mapping or
diagnostic.

`GEN-05` An intentional algorithm change shall require:

- an algorithm-version change;
- reviewed golden-vector updates;
- confirmation that old saves continue using their stored mappings.

### 5.2 Meaningful property tests

`GEN-06` Property tests shall call the real combined generator rather than
testing the PRNG in isolation.

`GEN-07` Across a documented bounded seed set, the tests shall verify:

- every mapped species exists in the selected manifest;
- every generated level is an integer in its allowed range;
- the three starter choices are unique when required;
- trainer parties are nonempty and no larger than six;
- hard legendary and stage filters are never relaxed;
- one-to-one destinations do not repeat before proven pool exhaustion;
- Catchability Guard invariants hold when enabled;
- generation terminates with bounded work;
- canonical serialization round-trips without changing its hash;
- category stream isolation holds when unrelated categories are toggled.

`GEN-08` Test iteration counts shall be selected from measured runtime budgets.
A smaller test that executes the generator is preferable to 30,000 vacuous
PRNG-bound checks.

### 5.3 One-to-one assignment

`GEN-09` One-to-one generation shall begin from sources and candidates in
stable order and use the category RNG stream to Fisher–Yates shuffle
destination preference order.

`GEN-10` Strength, legendary, stage, type, reachability, and progression
constraints shall form explicit candidate edges.

`GEN-11` The implementation shall use a deterministic matching procedure that
finds a complete assignment when one exists. A greedy dead end shall not by
itself trigger a uniqueness-pool reset.

`GEN-12` A pool reset or duplicate destination is permitted only after the
matching procedure proves that the remaining sources cannot receive unique
destinations under the active hard constraints.

`GEN-13` Each unavoidable reset shall record the category, exhausted pool
size, affected source, and active hard constraints.

`GEN-14` Starter selection may continue using its existing shuffled selection
when its uniqueness and type-triad requirements are satisfied.

## 6. Race Mode requirements

### 6.1 Mod-only security boundary

`RACE-01` Documentation shall describe Race Mode as local accidental-spoiler
deterrence, not anti-cheat.

`RACE-02` The mod shall not advertise OS entropy, organizer control, masked
entry, or a memory-hard KDF unless that capability is actually active and
tested.

`RACE-03` If a required cryptographic primitive is unavailable to the
mod-only runtime, the affected encrypted mode shall be unavailable with a
clear explanation. It shall not silently fall back to weaker encryption or
plaintext.

### 6.2 Automatic unlock policies

`RACE-04` `HALL OF FAME` shall unlock only after the base command has
successfully added a Hall of Fame entry.

`RACE-05` `CREDITS` shall not unlock from the synchronous return of
`record_hall_of_fame`, because Recomp `0.1.38` returns immediately after
pushing asynchronous screens.

`RACE-06` Because no public `credits.completed` event exists in the target
mod-only API, the `CREDITS` option shall be removed or shown as unavailable
until a public completion seam exists.

`RACE-07` Failed Hall of Fame processing shall leave the run locked.

`RACE-08` Unlock state shall be one-way, checksummed, saved immediately where
appropriate, and incapable of changing gameplay mappings.

### 6.3 Organizer passphrase

`RACE-09` `PASSPHRASE` shall bind a verifier before gameplay begins. The
racer shall not establish the verifier during spoiler export.

`RACE-10` The verifier and salt shall be included in the initial checksummed
run configuration. Changing them after New Game shall invalidate the
configuration.

`RACE-11` Passphrase entry and confirmation shall use a masked input screen.
Plaintext characters shall not remain visible after entry.

`RACE-12` Spoiler export may request the encryption passphrase, but exporting
shall not create or replace the saved unlock verifier.

`RACE-13` An organizer workflow shall be documented, including setup,
confirmation, distribution, export, and unlock.

### 6.4 Seed entropy and encrypted exports

`RACE-14` Race Mode automatic seeds shall require at least 128 bits from a
verified operating-system or engine cryptographic random-byte provider.

`RACE-15` If no verified provider exists, Race Mode shall require an
organizer-supplied manual seed with documented entropy guidance. Solo
automatic seeding may remain available only if the UI and documentation do
not describe it as cryptographically unpredictable.

`RACE-16` Salt and nonce values shall be unique for every encrypted export.
The implementation shall not depend on `os.time`, `os.clock`, a table address,
or an unverified game PRNG as its sole entropy source.

`RACE-17` The password KDF shall use an audited memory-hard primitive exposed
to the mod-only runtime. Its identifier and parameters shall be stored in the
versioned envelope.

`RACE-18` If no audited memory-hard primitive is available, encrypted export
shall be labeled experimental/local deterrence or disabled. The current
256-block SHA-256 mixer shall not be described as memory-hard.

`RACE-19` Envelope parsing shall reject empty salt, nonce, tag, and metadata
fields as malformed before KDF execution.

`RACE-20` Tests shall cover correct passphrases, wrong passphrases, modified
ciphertext, modified metadata, malformed or empty fields, repeated exports,
and unavailable entropy/KDF providers.

## 7. Progression and scripted-gift requirements

### 7.1 Catchability Guard

`CATCH-01` “Reachable before the Elite Four” shall be based on an explicit
progression model rather than treating every non–Cerulean Cave map as early.

`CATCH-02` The model shall represent, at minimum:

- Surf access;
- required HMs and their badge gates;
- major story gates;
- Safari Zone access;
- fishing-rod acquisition;
- version-specific map availability;
- postgame-only areas.

`CATCH-03` Walking, surfing, and fishing slots shall be evaluated using their
actual access requirements.

`CATCH-04` Trade request reachability shall be evaluated at the point where
that trade becomes available, not merely somewhere before the Elite Four.

`CATCH-05` If the implementation remains coarse during an intermediate
release, the setting and documentation shall say `BASIC COVERAGE` and list
the approximation. It shall not promise full progression reachability.

`CATCH-06` Synthetic progression fixtures shall test early walking, gated
Surf, gated fishing, Safari Zone, late story maps, and postgame maps.

### 7.2 Static and gift script safety

`GIFT-01` New or rewritten scripts shall use labels rather than absolute
numeric jump targets.

`GIFT-02` Existing supported scripts shall receive interpreter-level tests
that execute yes, no, already-collected, insufficient-money, party-full, and
box-full branches.

`GIFT-03` Payment, one-time completion flags, and object removal shall occur
only after `give_pokemon` reports success.

`GIFT-04` The safety rule shall apply equally to mapped and vanilla-fallback
branches. Falling back because a mapping is missing shall not reintroduce
reward loss.

`GIFT-05` The Magikarp sale and both Fighting Dojo choices shall remain
retryable after a full-storage failure.

`GIFT-06` Tests shall assert final save state, money, flags, object visibility,
party/box contents, displayed message, and callback completion—not only the
shape of generated row tables.

## 8. API and maintenance requirements

### 8.1 Public API hardening

`API-01` Public exports shall not expose mutable tables used internally by
later generation.

`API-02` Generator and contract APIs shall be exposed through immutable
facades or wrapper functions. Reassigning an exported field shall not replace
the function used internally.

`API-03` Active-run exports shall remain deep-cloned or read-only. Tests shall
prove that mutating an exported run cannot change session or saved mappings.

`API-04` Species metadata conflicts shall follow a documented deterministic
policy. The API shall return a structured conflict result or an attributed
error rather than unexpectedly terminating an unrelated mod load.

`API-05` Metadata conflict behavior shall be independent of mod discovery
order, or the precedence order shall be explicit and tested.

### 8.2 Release and repository hygiene

`REL-01` Runtime archives should contain only `manifest.json`, `main.lua`,
`src/`, required user documentation, and the package ledger.

`REL-02` Tests, development tools, internal specifications, and historical
archives shall not be included unless the Recomp installer requires them.

`REL-03` Historical ZIPs shall be published as release artifacts rather than
kept as normal source files. Repository policy shall state whether the current
release ZIP remains tracked.

`REL-04` `.modkitignore` shall have a documented owner. If external tooling
uses it, packaging tests shall verify that behavior; otherwise it shall be
removed to avoid stale configuration.

`REL-05` CI shall run Lua 5.1 syntax checks and the complete test suite on
Windows and Linux.

`REL-06` The release job shall build the ZIP once, validate that exact
artifact, publish its SHA-256 hash, and reject dirty or mismatched staging
content.

### 8.3 Cleanup

`MAINT-01` Remove unused locals and unreachable duplicate rows after tests
cover their surrounding behavior.

`MAINT-02` Unknown game versions shall not silently receive Red Game Corner
data. Because the product scope is Red/Blue, unsupported versions shall
retain vanilla prizes and record a warning.

`MAINT-03` README guarantees shall match fallback behavior, especially
box-full handling, Catchability Guard, Race Mode, and platform support.

## 9. Nonfunctional requirements

`NFR-01 Determinism` Identical canonical seed, normalized settings, algorithm
version, merged content manifest, and source records shall produce identical
canonical mappings on Windows and Linux.

`NFR-02 Save safety` No remediation may regenerate an existing run or mutate
stored mappings during load.

`NFR-03 Isolation` A failure attributable to one source record shall preserve
unrelated category output whenever a safe vanilla fallback exists.

`NFR-04 Bounded work` Matching, validation, KDF handling, and property tests
shall have documented finite bounds.

`NFR-05 Mod-only compatibility` The release shall load on stock Recomp
`0.1.38` without modifying the engine installation.

`NFR-06 Honest capability reporting` UI and documentation shall distinguish
implemented security/progression guarantees from approximations or unavailable
features.

## 10. Milestones ordered by urgency

### Milestone 1 — P0 cross-platform release repair

Status: Implemented in `0.16.0`.

Deliver:

- replace backslash-producing ZIP creation;
- add raw ZIP entry-name validation;
- reduce the payload to an explicit runtime allowlist;
- load the exact packaged artifact through the official `0.1.38` fixture;
- publish the artifact hash.

Exit criteria:

- zero ZIP entries contain `\`;
- Windows and Linux validation pass;
- the archive loads without unpacking-path repair.

### Milestone 2 — P1 trade policy and trainer isolation

Status: Implemented in `0.17.0`.

Deliver:

- preserve `EXCLUDE` under `NO DOWNGRADE`;
- add the complete trade-policy matrix tests;
- replace trainer category assertions with per-source/per-slot fallbacks;
- add attributed trainer diagnostics.

Exit criteria:

- Casual produces no legendary trade destinations;
- one mod-added trainer species cannot disable Forest or other vanilla
  trainers;
- all unaffected trainer mappings remain deterministic.

### Milestone 3 — P2 saved-run integrity and defensive UI

Deliver:

- freeze `relevantMods` as the New Game snapshot;
- compare current and saved compatibility without rewriting the snapshot;
- make active-run UI tolerate absent settings;
- reconcile the save-size budget at 256 KiB.

Exit criteria:

- adding or removing a mod mid-run produces a report while the original
  snapshot remains byte-identical;
- active-seed actions cannot throw on a sparse settings table;
- all budget references and tests agree.

### Milestone 4 — P2 generator vectors, real properties, and CI

Deliver:

- at least 20 combined generator golden vectors;
- meaningful generator property tests;
- serialization and stream-isolation tests;
- Windows and Linux CI;
- removal of the vacuous preset/PRNG fuzz loop.

Exit criteria:

- every category participates in at least one combined vector;
- intentional mapping changes require reviewed vector changes;
- CI validates Lua 5.1 and the packaged artifact.

### Milestone 5 — P2 deterministic one-to-one matching

Deliver:

- stable candidate graphs;
- category-stream Fisher–Yates destination preferences;
- deterministic maximum matching;
- proof-based pool reset diagnostics;
- algorithm-version and golden-vector update.

Exit criteria:

- fixtures with an available perfect matching never reset;
- unavoidable exhaustion is deterministic and attributed;
- existing saves are not regenerated.

### Milestone 6 — P3 correct automatic race unlocks

Deliver:

- move Hall of Fame unlock after successful base record creation;
- remove or disable `CREDITS` on stock `0.1.38`;
- add failure and one-way persistence tests;
- correct UI and documentation.

Exit criteria:

- Hall of Fame and Credits are no longer equivalent;
- failed Hall of Fame processing leaves spoilers locked;
- no unavailable policy can be selected for a new run.

### Milestone 7 — P3 organizer-bound, masked passphrase workflow

Deliver:

- pre-run organizer verifier setup and confirmation;
- masked passphrase entry;
- immutable saved verifier state;
- export behavior separated from verifier creation;
- organizer workflow documentation.

Exit criteria:

- a racer cannot establish or replace the verifier during export;
- the verifier is present in the initial checksum;
- passphrases are not displayed in clear text.

### Milestone 8 — P3 entropy and encryption capability correction

Deliver:

- verified strong entropy-provider detection;
- manual organizer seed requirement when strong automatic entropy is absent;
- audited memory-hard KDF integration if available to the mod-only runtime;
- otherwise disable or explicitly downgrade encrypted mode claims;
- strict envelope validation and repeated-export tests.

Exit criteria:

- no security path silently uses weak fallback entropy or KDF claims;
- repeated exports cannot reuse nonce/salt material;
- malformed empty fields are reported as malformed.

### Milestone 9 — P4 progression-aware Catchability Guard

Deliver:

- explicit progression graph;
- map/terrain/rod access requirements;
- trade-time reachability;
- progression fixtures and readable diagnostics;
- interim label downgrade if full modeling is not yet complete.

Exit criteria:

- Surf-only and late-game locations are not treated as early walking access;
- every advertised coverage guarantee is tested against the progression
  model.

### Milestone 10 — P4 static/gift script safety

Deliver:

- label-based control flow;
- interpreter-level branch tests;
- award-before-payment/flag behavior for mapped and fallback paths;
- retry-safe Magikarp and Dojo rewards.

Exit criteria:

- a full party and box cannot consume money, flags, objects, or a one-time
  reward;
- all supported branches terminate and invoke their callback exactly once.

### Milestone 11 — P5 public API hardening

Deliver:

- immutable generator/contract facades;
- mutation-isolation tests for active-run exports;
- deterministic species-metadata conflict policy;
- structured conflict diagnostics.

Exit criteria:

- another mod cannot replace the randomizer's internal generator through
  `mod.exports`;
- returned run data cannot mutate saved/session data;
- duplicate metadata cannot unpredictably break load order.

### Milestone 12 — P5 release hygiene and cleanup

Deliver:

- move historical archives out of normal source history according to project
  release policy;
- resolve `.modkitignore` ownership;
- exclude development-only files from releases;
- remove verified dead code;
- reject unsupported game versions for Red/Blue prize catalogs;
- reconcile README claims with tested behavior.

Exit criteria:

- one documented command produces the tested release artifact;
- no stale release-ignore entries remain;
- documentation contains no stronger guarantee than the implementation and
  tests support.

## 11. Final release gate

A remediation release is ready only when:

1. all P0 and P1 milestones are complete;
2. generator golden vectors and cross-platform CI are active;
3. any unfinished Race Mode security feature is unavailable or honestly
   labeled rather than silently weakened;
4. all existing-save compatibility tests pass without regeneration;
5. the exact published ZIP passes raw-entry inspection, Linux extraction,
   and Recomp `0.1.38` fixture loading;
6. its SHA-256 hash is recorded in the release notes.

## 12. Finding traceability

| Validated finding | Requirements | Milestone |
|---|---|---|
| Weak automatic seed entropy | `RACE-14`–`RACE-16` | 8 |
| Legendary exclusion bypass in no-downgrade trades | `TRD-01`–`TRD-04` | 2 |
| Backslash ZIP entry names | `PKG-01`–`PKG-06` | 1 |
| Trainer category-wide fallback | `TRN-01`–`TRN-06` | 2 |
| Hall of Fame and Credits unlock together | `RACE-04`–`RACE-08` | 6 |
| Racer establishes the passphrase verifier | `RACE-09`–`RACE-13` | 7 |
| KDF and envelope capability overclaims | `RACE-17`–`RACE-20` | 8 |
| Relevant-mod snapshot rewritten during saves | `SAV-01`–`SAV-03` | 3 |
| 256 KiB versus 1 MiB budget contradiction | `SIZE-01`–`SIZE-04` | 3 |
| Missing combined vectors and vacuous fuzz pass | `GEN-01`–`GEN-08` | 4 |
| Greedy one-to-one assignment and avoidable resets | `GEN-09`–`GEN-14` | 5 |
| Fragile numeric gift scripts and unsafe fallback order | `GIFT-01`–`GIFT-06` | 10 |
| Oversized release payload and committed archives | `REL-01`–`REL-04`, `REL-06` | 1 and 12 |
| No cross-platform CI | `PKG-06`, `REL-05` | 4 |
| Coarse Catchability Guard | `CATCH-01`–`CATCH-06` | 9 |
| Sparse-settings UI failure | `SAV-04` | 3 |
| Mutable generator export | `API-01`, `API-02` | 11 |
| Metadata registration conflicts | `API-04`, `API-05` | 11 |
| Dead code and unsupported version fallback | `MAINT-01`–`MAINT-03` | 12 |
