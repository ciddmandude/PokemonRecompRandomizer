# Pokémon Gen 1 Recomp Randomizer
## Code Review Round 2 Remediation Specification

Status: Proposed  
Baseline: mod `0.27.21`, Recomp `0.1.38`  
Scope: Valid and partially valid findings in `code_review.md` round 2

## 1. Purpose

This specification resolves the confirmed correctness, defensive-safety,
portability, performance, and maintainability findings from the second code
review. Work is ordered by user-visible risk and by the likelihood that a
change can alter generated mappings.

The implementation remains a mod-only release. No Recomp engine fork or
user-installed engine patch is required.

## 2. Finding disposition

| Finding | Disposition | Required response |
|---|---|---|
| M1 progression requirement sorting | Valid | Fix and test |
| M2 mutable public API subtables | Valid hardening opportunity | Wrap ordinary-assignment surfaces |
| M3 unmatched pending trainer slot | Latent defensive gap | Add slot fallback and diagnostic |
| M4 duplicate matching IDs | Valid contract gap | Reject duplicate or invalid IDs |
| L1 Auto-seed entropy/specification mismatch | Valid | Improve the provider and make the specification truthful |
| L2 spoiler index/background rebuilding | Valid performance opportunity | Cache with safe invalidation |
| L3 unaligned town-map tile image | Valid defensive gap | Validate dimensions and fail closed |
| L4 Fighting Dojo progression gate | Partially valid | Correct reachability; no claim that the current browser displays stages |
| L5 manually maintained test list | Valid maintainability issue | Discover tests deterministically |
| L6 indentation and silent boot suppression | Valid ergonomic issues | Normalize style and add debug diagnostics |

## 3. Non-goals

- Reintroducing Race Mode or cryptographic race-seed secrecy.
- Treating Lua tables as a security boundary against `rawset`, debug
  libraries, or replacement of the engine-owned `mod.exports` root.
- Changing randomizer settings or adding new randomization categories.
- Changing save schema solely for caches or diagnostics.
- Persisting spoiler-browser indexes or graphics objects in the save file.
- Claiming a performance improvement without measuring it.

## 4. Cross-cutting requirements

### CR2-GEN-01 — Determinism

For an unchanged algorithm version, identical canonical seed, settings,
species manifest, and source data shall produce byte-equivalent mappings and
diagnostics.

### CR2-GEN-02 — Algorithm versioning

The Fighting Dojo reachability correction can change trade candidate
eligibility and therefore generated mappings. Its milestone shall:

1. increment the generator algorithm version;
2. deliberately update affected golden vectors;
3. demonstrate that unrelated category streams remain isolated; and
4. preserve old saved mappings without regeneration.

Pure display, caching, test-runner, logging, and facade changes shall not
increment the generator algorithm version.

### CR2-SAVE-01 — Saved-run compatibility

Existing valid saves shall load without migration solely because of this
remediation. Caches shall be runtime-only and shall never be serialized.

### CR2-DIAG-01 — Diagnostics

Every newly introduced fallback shall identify its category, source identity,
and reason. Diagnostic ordering shall be deterministic.

### CR2-TEST-01 — Lua compatibility

Runtime and test code shall parse and run on stock Lua 5.1.5.

### CR2-CI-01 — Release qualification

The Windows and Ubuntu GitHub Actions matrix jobs shall both:

1. run every discovered Lua test;
2. package the mod;
3. validate `.modkit/pack.json`;
4. verify forward-slash archive paths; and
5. extract and locate the required runtime files.

## 5. Functional requirements

### 5.1 Progression correctness

#### CR2-PROG-01 — Sorted requirements

`Progression.access` shall return a new requirements array sorted in ascending
bytewise identifier order. The implementation shall use the returned value
from `StableSort.sort` and a two-argument strict comparator.

No caller shall rely on the original static-table order.

#### CR2-PROG-02 — Fighting Dojo access

`FIGHTING_DOJO` shall be reachable during the Lavender/Celadon stage after
Saffron access is obtained. It shall not require `SILPH_CO_CLEARED`.

The model shall use a named requirement such as `SAFFRON_ACCESS`, defined as
the guard-drink gate. This requirement is distinct from access to or
completion of Silph Co.

#### CR2-PROG-03 — Reachability consumers

The corrected Dojo stage shall feed the existing earliest-obtainable-species
model used by the Catchability Guard. Trade generation shall not reject a
requested species merely because its only pre-Silph source is a Dojo gift.

The specification shall not state that the current in-game spoiler browser
shows progression stages unless that feature is separately implemented.

### 5.2 Auto-seed generation

#### CR2-SEED-01 — Injectable entropy provider

`SaveLifecycle` shall accept an injectable Auto-seed entropy provider. Tests
shall use a deterministic provider and shall not depend on wall-clock timing.

#### CR2-SEED-02 — Runtime source

At the real New Game `save.created` event, the default provider shall mix all
available runtime uniqueness sources, including:

- the highest-resolution LÖVE timer available;
- LÖVE random output when available;
- wall-clock and process-clock values;
- the per-process monotonic counter; and
- stable player/save context that is already available.

The mixed material shall continue through the existing hash and Crockford
Base32 pipeline, producing one saved 26-character canonical seed.

#### CR2-SEED-03 — Truthful guarantee

The main randomizer specification shall distinguish:

- a runtime source explicitly documented by the engine/LÖVE API as providing
  operating-system entropy; and
- best-effort uniqueness material from timers and a PRNG.

The mod shall not claim “128 bits of operating-system entropy” unless the
selected API guarantees it. If Recomp 0.1.38 exposes no such API, section 6.1
shall describe Auto mode as best-effort, non-cryptographic seed generation.

#### CR2-SEED-04 — Failure behavior

Absence of optional `love` functions shall not prevent New Game generation.
The fallback path shall remain deterministic under injected test inputs and
shall emit at most one debug or warning diagnostic per generated Auto seed.

### 5.3 Matching and trainer fallback safety

#### CR2-MATCH-01 — Unit identity validation

`Matching.assign` and each `Matching.newSession` instance shall reject:

- missing, empty, or non-string unit IDs; and
- an ID already added to the same assignment operation.

The failure message shall identify the duplicate or invalid ID.

#### CR2-MATCH-02 — Empty-pool invariant

Both batch and streaming matching paths shall explicitly assert that a
nonempty normalized preference list matches an empty uniqueness pool. The
batch path shall never repeat the same `poolStart` without either committing
a match, recording an unmatched unit, or failing the invariant.

#### CR2-MATCH-03 — Recursion bound

The augmenting-path implementation shall document that recursion depth is
bounded by the current uniqueness-pool size. Tests shall include a merged-data
pool larger than the vanilla 151 species without exceeding a reasonable CI
time budget.

#### CR2-TRAIN-01 — Missing final assignment

When a pending trainer row has no final assignment, generation shall:

1. replace only that row with a `fallback = true` marker;
2. retain the correct `sourceSlot`;
3. remove unresolved `species`, `level`, and `matchId` fields;
4. append `TRAINER_NO_CANDIDATE` with reason `UNMATCHED`; and
5. increment `fallbackCount` once.

Neighboring generated slots shall remain active at runtime.

### 5.4 Spoiler-browser safety and performance

#### CR2-BROWSE-01 — Index cache

Opening the in-game spoiler browser repeatedly for the same immutable active
run and merged data shall reuse its constructed index.

The cache key shall include, at minimum:

- saved run checksum or equivalent immutable mapping identity;
- saved seed hash;
- active game version; and
- a merged-data identity or revision sufficient to prevent reuse after the
  source registries change.

The cache shall invalidate on a different loaded save, regenerated run,
version change, or relevant merged-data change.

#### CR2-BROWSE-02 — Background cache

Town-map image/quads may be cached by asset identity and dimensions.
Graphics objects shall never be stored in the save. A failed or incompatible
background shall use the existing plain fallback map.

#### CR2-BROWSE-03 — Tile alignment

Before creating quads, the browser shall require positive image dimensions
divisible by eight. Quad construction shall be protected so a bad
mod-supplied asset cannot crash the spoiler screen.

#### CR2-BROWSE-04 — Measurement

Tests shall count index builds and quad builds across two opens. A manual
measurement plan shall compare first-open and repeated-open time on desktop
and, when available, a low-power handheld. Documentation shall describe a
measured result, not promise an unverified visible improvement.

### 5.5 Public export hardening

#### CR2-API-01 — Read-only subtable facades

The following public export subtables shall use ordinary-assignment
read-only facades:

- `species`;
- `save`;
- `preferences`; and
- `spoilers`.

Existing `generator` and `contracts` facade behavior shall remain unchanged.

#### CR2-API-02 — Captured implementation

Facade functions shall close over the original implementation functions.
Ordinary assignment to a facade key shall fail without changing internal
randomizer behavior.

#### CR2-API-03 — Mutable return isolation

Functions returning settings, schemas, pages, metadata, status, or active-run
data shall return fresh values or documented immutable values. Mutating one
result shall not change a subsequent result or internal saved state.

#### CR2-API-04 — Security boundary

Documentation shall state that the facades prevent accidental ordinary
assignment only. Protection against `rawset`, debug facilities, or wholesale
replacement of `mod.exports` is out of scope.

### 5.6 Test discovery and cross-platform release

#### CR2-TEST-02 — Automatic discovery

`tools/test.ps1` shall discover `tests/*_test.lua`, sort by filename using
ordinal deterministic ordering, and run every discovered file in a separate
Lua process.

Helper files such as harnesses and golden-vector data shall not be selected.

#### CR2-TEST-03 — Discovery self-test

CI shall fail if:

- no tests are found;
- two paths collide under case-folding on a supported runner; or
- any discovered test returns a nonzero exit code.

The final summary shall report the number of discovered tests and total Lua
files checked for syntax.

#### CR2-PACK-01 — Portability regression coverage

Release tests shall preserve the existing fixes for:

- CRLF and LF `.gitignore` validation; and
- explicit enumeration of hidden `.modkit/pack.json` content.

Both matrix jobs must be green before release qualification.

### 5.7 Diagnostics and style

#### CR2-BOOT-01 — Suppressed boot event

When the disposable pre-`game.ready` `save.created` event is ignored, the mod
shall emit a debug-level message explaining that the boot skeleton was
suppressed. It shall not log a warning or user-facing error during normal
startup.

The message shall occur no more than once per boot.

#### CR2-STYLE-01 — Progression formatting

`src/progression.lua` shall use the project’s two-space indentation convention.
Formatting shall not alter behavior, ordering, or golden outputs.

## 6. Required tests

The completed remediation shall include:

1. exact sorted requirement assertions for Rock Tunnel, Pokémon Tower, and
   surf-augmented routes;
2. Fighting Dojo stage and `SAFFRON_ACCESS` assertions;
3. a trade reachability case whose requested species is obtainable from the
   Dojo before Silph completion;
4. injected Auto-seed entropy tests with and without optional LÖVE functions;
5. duplicate matching-ID tests for batch and streaming APIs;
6. a forced missing-final-assignment trainer test proving slot-only fallback;
7. repeated spoiler-open tests proving index and background cache reuse;
8. malformed town-map image tests for odd and zero dimensions;
9. mutation tests for every exported facade and every mutable return value;
10. an automatically discovered sentinel test in a temporary test directory;
11. LF and CRLF scaffold-validation tests;
12. hidden-ledger package validation on Windows and Ubuntu; and
13. the complete golden-vector, property, package, and engine-integration
    suites.

## 7. Milestones ordered by urgency

### Milestone 1 — Progression correctness

Implements:

- `CR2-PROG-01` through `CR2-PROG-03`;
- `CR2-GEN-01` and `CR2-GEN-02` as applicable.

Deliverables:

- correct stable requirement sorting;
- Fighting Dojo at the Saffron-access stage;
- Catchability Guard reachability regression tests;
- algorithm-version and golden-vector update; and
- proof that unrelated mapping categories remain isolated.

Exit criteria:

- requirement order is exact;
- Dojo gifts are modeled before Silph completion;
- existing saves load unchanged; and
- all deterministic-generation tests pass.

### Milestone 2 — Auto-seed and specification alignment

Implements:

- `CR2-SEED-01` through `CR2-SEED-04`.

Deliverables:

- injectable entropy provider;
- best available Recomp/LÖVE runtime provider;
- safe fallback behavior; and
- corrected section 6.1 wording.

Exit criteria:

- Auto mode always produces and saves a 26-character seed;
- deterministic injected tests pass;
- optional LÖVE API absence does not break New Game; and
- documentation makes no unsupported entropy claim.

### Milestone 3 — Matching and trainer isolation

Implements:

- `CR2-MATCH-01` through `CR2-MATCH-03`;
- `CR2-TRAIN-01`; and
- `CR2-DIAG-01`.

Deliverables:

- unique-ID enforcement;
- explicit empty-pool invariant;
- documented recursion bound;
- unmatched pending-row fallback; and
- exact warnings and fallback counts.

Exit criteria:

- duplicate IDs fail immediately;
- a forced missing assignment falls back only its slot;
- runtime preserves generated neighboring slots; and
- large merged-data matching terminates within the CI budget.

### Milestone 4 — Spoiler-browser reliability and caching

Implements:

- `CR2-BROWSE-01` through `CR2-BROWSE-04`;
- `CR2-SAVE-01`.

Deliverables:

- safely keyed runtime index cache;
- safely keyed background cache;
- tile-dimension and quad-construction guards; and
- automated build-count and manual timing evidence.

Exit criteria:

- two opens of the same run reuse both caches;
- switching saves or source identity rebuilds the index;
- invalid images fall back without a crash; and
- no cache data appears in serialized saves.

### Milestone 5 — Complete public API facades

Implements:

- `CR2-API-01` through `CR2-API-04`.

Deliverables:

- facades for all six public API subtables;
- captured function implementations;
- isolated mutable results; and
- explicit ordinary-assignment scope documentation.

Exit criteria:

- assignment replacement fails on every facade;
- `rawset` limitations remain accurately documented;
- mutation of returned data cannot mutate internal state; and
- existing API consumers retain the same callable names and return shapes.

### Milestone 6 — Automatic tests and two-OS release qualification

Implements:

- `CR2-TEST-01` through `CR2-TEST-03`;
- `CR2-CI-01`;
- `CR2-PACK-01`.

Deliverables:

- sorted test discovery;
- discovery failure guards;
- LF/CRLF regression coverage;
- hidden-ledger regression coverage; and
- green Windows and Ubuntu workflow runs.

Exit criteria:

- adding a new `*_test.lua` requires no runner edit;
- helper files are excluded;
- the reported test count matches the filesystem;
- both GitHub matrix jobs package, validate, and extract successfully.

### Milestone 7 — Boot diagnostics and style cleanup

Implements:

- `CR2-BOOT-01`;
- `CR2-STYLE-01`.

Deliverables:

- one debug message for the suppressed boot save event; and
- two-space formatting for `progression.lua`.

Exit criteria:

- normal startup produces no warning or user-facing error;
- the suppression is visible in debug logs;
- no generated mapping, diagnostic, or golden vector changes from formatting;
- the full release suite remains green.

## 8. Completion definition

Round 2 remediation is complete when:

1. all seven milestones meet their exit criteria;
2. the main specification reflects the implemented Auto-seed and progression
   guarantees;
3. deterministic changes have the required algorithm-version and golden
   updates;
4. existing saves load without regeneration;
5. Windows and Ubuntu package-validation jobs are green; and
6. a release archive passes local package and Recomp integration validation.

## 9. Traceability

| Review finding | Requirements | Milestone |
|---|---|---|
| M1 | CR2-PROG-01 | 1 |
| L4 | CR2-PROG-02, CR2-PROG-03 | 1 |
| L1 | CR2-SEED-01–04 | 2 |
| M3 | CR2-TRAIN-01, CR2-DIAG-01 | 3 |
| M4 | CR2-MATCH-01–03 | 3 |
| L2 | CR2-BROWSE-01, CR2-BROWSE-02, CR2-BROWSE-04 | 4 |
| L3 | CR2-BROWSE-03 | 4 |
| M2 | CR2-API-01–04 | 5 |
| L5 | CR2-TEST-02, CR2-TEST-03 | 6 |
| Packaging verification caveat | CR2-CI-01, CR2-PACK-01 | 6 |
| L6 | CR2-BOOT-01, CR2-STYLE-01 | 7 |
