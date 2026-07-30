# Code review — pokemon_randomizer 0.15.1

Reviewed: full `src/` (33 modules), `main.lua`, `tests/`, `tools/`, `docs/randomizer-spec.md`,
`docs/determinism-v1.md`, `docs/race-validation-v1.md`, `manifest.json`, and the shipped
`dist/` archives, against the gen1recomp wiki's Hook and Event references.

Test status: all 15 Lua test files pass on stock Lua 5.1.5.
Hook and event names used by `bootstrap.lua` all exist in the engine's published reference
(`encounter.species`, `encounter.roll`, `encounter.fishing`, `trainer.party`,
`ui.options.rows`, `save.created/loading/loaded/writing`, `game.ready`, `mods.loaded`,
`pokemon.before_give`).

---

## Overall

The deterministic foundation is the strongest part of this codebase and is genuinely
well built. `uint32.lua` / `hash128.lua` / `rng.lua` / `stable_sort.lua` / `canonical.lua`
avoid every trap that normally breaks cross-platform randomizer reproducibility: no native
bit library, every intermediate under 2^53, rejection sampling instead of modulo, sorted
keys everywhere, and no `pairs()` on any output path. `foundation_test.lua` locks all of it
with golden vectors computed from an independent JS implementation — including a vector that
specifically proves rejection sampling occurred (`foundation_test.lua:98-100`). That is a
higher standard than most randomizers reach.

The save lifecycle is also carefully ordered: generate → validate → checksum → *then*
assign into `save.modData` (`save_lifecycle.lua:85-87`), migrations clone-then-stamp so a
failed migration is atomic, and every runtime resolver re-validates the saved shape and
returns the prior hook's value on any mismatch without rewriting storage
(`wild_runtime.lua`, `trainer_runtime.lua:36-41`, `starter_offer.lua:42-47`).

The gap is between that foundation and everything built on top of it. The primitives are
proven; the *generator output* is not tested at all. And several security-flavoured promises
in the spec — CSPRNG seeding, a memory-hard KDF, organizer-controlled race unlock — are
implemented in name but not in substance. The mod is in good shape as a single-player
randomizer and not yet in shape for the race/sharing use case it advertises.

---

## High

### 1. Auto seeds are not drawn from an OS or LÖVE entropy source

`src/save_lifecycle.lua:14-23`

```lua
local function entropy(save)
  autoCounter = autoCounter + 1
  return table.concat({
    tostring(os.time()), tostring(os.clock()), tostring(save),
    tostring(save and save.player and save.player.id or ""),
    tostring(autoCounter),
  }, "\0")
end
```

Spec §6.1(4) requires "128 bits from the operating system or LÖVE entropy source". This is
`os.time()` (1-second resolution, and an attacker knows roughly when a run started),
`os.clock()` (process CPU time, low resolution and strongly correlated with launch-to-new-game
latency), a Lua table address, an empty player id at `save.created`, and a counter that is
1 or 2. The realistic search space is on the order of tens of bits, not 128.

For a solo run this is harmless. For Race Mode it is the whole ballgame: the canonical seed
determines every mapping, so an enumerable seed defeats spoiler locking regardless of how
good the envelope encryption is. Note `race_controller.lua:5-14` *does* reach for
`love.math.random` — the seed path, which matters more, does not. `love.math.random` is not
a CSPRNG either; `love.data.hash` over `love.timer.getTime()` plus `os.time()` is not much
better. If the engine exposes no CSPRNG, this is worth an upstream ask, and in the meantime
the README should state plainly that auto seeds are not cryptographically unpredictable.

Related: `hash128` is four salted FNV-1a/32 lanes. It is correctly documented as a content
hash, not a cryptographic one (`docs/determinism-v1.md:74-79`), but it is also the *seed*
hash that seeds the PRNG state, so lane correlation caps effective seed entropy independently
of the entropy problem above.

### 2. `Legendaries = EXCLUDE` is silently bypassed by `Trade Fairness = NO DOWNGRADE`

`src/trade_prize_category.lua:58-70`

```lua
if settings.trade_fairness == "no_downgrade" then
  local base = SpeciesFilters.candidates(
    manifest, requested, commonRules(settings, excluded, "allow"))
```

The third argument to `commonRules` is `sourceLegendaryMode`, which overrides
`settings.legendaries` outright. On the `no_downgrade` path it is hardcoded to `"allow"`, so
the player's legendary policy is discarded for the received side of every NPC trade.

This is reachable from a shipped preset: `CASUAL` sets `legendaries = "exclude"` *and*
`trade_fairness = "no_downgrade"` (`general_settings.lua:72,89`).

Verified with a probe harness over 200 seeds using a synthetic manifest containing one
legendary inside the strength band:

```
legendaries=exclude + trade_fairness=no_downgrade: 90/200 seeds produced a MEWTWO trade
control (trade_fairness=similar):                   0/200 seeds
```

The fix is to drop the `"allow"` override and apply the no-downgrade BST floor as an extra
filter on top of the normal rules, which is what the surrounding code already does at
`:63-67`.

### 3. Release archives use backslash path separators

`tools/package.ps1:79` uses `Compress-Archive`, which under Windows PowerShell 5.1 writes
ZIP entries with `\` separators. Confirmed in the shipped artifacts:

```
$ unzip -l dist/pokemon_randomizer-0.15.1.zip
    18009  src\bootstrap.lua
     2047  src\canonical.lua
```

The ZIP spec requires `/`. Most non-Windows extractors will produce single files literally
named `src\bootstrap.lua`, and `main.lua:5` reads `mod:read("src/constants.lua")` with
forward slashes. This directly contradicts NFR-01's Windows/macOS/Linux support claim and
would present as "mod fails to load" for every Linux and macOS user installing from the zip.

Use `System.IO.Compression.ZipFile` / `ZipArchive` with explicit forward-slash entry names,
or require PowerShell 7+ for packaging, and add a packaging test that asserts no entry name
contains `\`.

### 4. One unmappable trainer species disables the entire trainer category

`src/trainer_category.lua:249-255` and `:266`

```lua
assert(type(sourceSlot) == "table" and manifest.byId[sourceSlot.species], ...)
...
assert(species, "trainer slot has no candidate")
```

`Category.generate` runs inside `pcall` (`generator.lua:194`), so *any* trainer slot whose
source species is absent from the eligible pool aborts generation for all trainers and falls
the whole category back to vanilla with a single generic warning.

The default `Species Pool` is `VANILLA 151`. Any mod that adds a trainer using a mod-added
species — or any vanilla species excluded because its merged record failed
`species_manifest.validateRecord` — therefore silently disables trainer randomization
entirely. That contradicts spec §2(4) ("content is read from the player's merged registries")
and makes the mod fragile in exactly the multi-mod setups the spec targets.

Per-slot degradation (keep that slot vanilla, record an attributed warning, continue) is a
better fit for §13's "attributable and isolated" policy than category-wide death. The same
applies to `globalMap`'s `assert(species, ...)` at `:201`.

---

## Medium

### 5. `CREDITS` unlock is indistinguishable from `HALL OF FAME`

`src/race_controller.lua:143-148`

```lua
commands:override("record_hall_of_fame", function(ctx, ...)
  unlockFor(ctx.game, lifecycle, "hall_of_fame")
  local results = { base(ctx, ...) }
  unlockFor(ctx.game, lifecycle, "credits")
  return unpack(results)
end)
```

Both policies fire from one command, separated only by the synchronous return of `base`.
Unless `record_hall_of_fame` blocks through the entire credits sequence — which
`docs/race-validation-v1.md:19-21` asserts but nothing verifies — `CREDITS` unlocks at the
same instant as `HALL OF FAME`, making it a no-op option in the menu.

Separately, `hall_of_fame` unlocks *before* `base` runs, i.e. before the record is written,
so a failed Hall of Fame entry still unlocks spoilers. Spec §5.1 says "after the first valid
Hall of Fame record."

### 6. `PASSPHRASE` race unlock is self-service, not organizer-controlled

`src/race_controller.lua:77-87, 116-122`

The passphrase verifier is created by whoever performs the first encrypted export, using
whatever passphrase they type. So the racer sets their own passphrase and can immediately
unlock with it. Meanwhile `unlockAction` refuses to run at all until an encrypted export has
happened ("EXPORT ENCRYPTED LOG FIRST"), which is a confusing gate for a legitimate racer.

Spec §5.1 requires "an organizer-supplied passphrase." There is no path for an organizer to
bind a verifier at seed-creation time. As shipped, `PASSPHRASE` provides no more protection
than `NEVER` would with a text editor. Either add organizer passphrase entry at New Game (so
the verifier is stamped into the run before play) or document the policy honestly as
"self-imposed delay."

Minor, same area: `prompt` at `:51-60` uses `mod.ui.NamingScreen`, which renders entry in the
clear. Spec §5.8 calls for "a masked passphrase-entry screen."

### 7. The race KDF is not memory-hard

`src/race_crypto.lua:8-9, 29-53`

`BLOCKS = 256`, `PASSES = 2`, blocks stored as 64-character hex strings — roughly 16 KiB of
working memory and about 768 SHA-256 evaluations. Argon2's *minimum* recommended setting is
several orders of magnitude above that. Against a native attacker this is a work factor of
roughly 2^10, so an offline dictionary attack on the envelope passphrase is cheap.

Spec §6.4 requires "a memory-hard password KDF." The pure-Lua SHA-256 makes the honest path
slow while doing almost nothing to the attacker, which is the worst of both worlds. Either
raise `BLOCKS` substantially and store blocks as raw 32-byte strings rather than 64-char hex
(4× the memory for the same hashing), or drop the "memory-hard" claim from the spec and
`docs/race-validation-v1.md:46`.

Smaller items in the same module:
- `decrypt` authenticates the metadata but never compares it to the current run
  (`:158-162`), despite §6.4 calling for "algorithm/settings/pool hashes as authenticated
  metadata."
- `decrypt` accepts an empty salt (`^[0-9A-F]*$` at `:152`) which then fails `derive`'s
  `^[0-9A-F]+$` assert and is reported as "invalid passphrase" — misleading.
- If `love` is absent, `race_controller.entropy` contributes no randomness at all, so two
  exports in the same second with the same passphrase reuse salt *and* nonce, i.e. keystream
  reuse.

### 8. `save.writing` rewrites `compatibility.relevantMods` on every save

`src/save_lifecycle.lua:195-199`

The relevant-mod list is recomputed from the *current* mod set and re-stamped on every write.
Spec §7 treats `compatibility` as part of the immutable run configuration, and §4.3 lists
"relevant enabled mod set" as one of the inputs that must match for two players to get
identical results. Rewriting it on save means the saved snapshot silently tracks the live mod
set, so the one record that could detect "you added a mod mid-run" is overwritten by the
change it was supposed to detect.

`engineVersion` is refreshed the same way at `:191-194`. That one is defensible; the mod list
is not.

### 9. Save-size budget contradiction

`src/validation_category.lua:132-137` warns above 1 MiB and the message says
"the 1 MiB M14 budget"; `docs/race-validation-v1.md:77` repeats it. Spec NFR-03 says
**256 KiB**. One of the three is wrong and should be reconciled — a 4× budget drift that only
lives in a warning string is easy to miss.

### 10. No end-to-end generator vectors, and the fuzz pass is vacuous

This is the largest gap between what the spec claims and what the suite proves.

Spec §12.1 requires "at least 20 golden vectors containing canonical seed, settings,
synthetic pool manifest, and expected hashes/mappings," run per-category and combined.
`tests/golden_vectors.lua` contains 3 hash digests, 2 stream digests, 10 `nextU32` values,
10 `nextInt` values and one shuffle — all PRNG/hash primitives. There is **not one expected
mapping table** anywhere in the suite.

`Generator.generate` is called exactly once in the whole suite
(`tests/scaffold_test.lua:75`), with `settings = {}` — which skips every category. So the
generator's actual output has no regression coverage at all, and FR-05 ("identical inputs
shall generate byte-equivalent normalized mapping tables") is unverified.

Spec §12.4's fuzz requirement is nominally satisfied by
`tests/race_validation_m14_test.lua:193-202`:

```lua
for seedIndex = 1, 10000 do
  local rng = Rng.fromSeed(preset:upper() .. " " .. tostring(seedIndex), "validation.swaps")
  local level = rng:nextInt(2, 100)
  local size  = rng:nextInt(1, 6)
  assert(level >= 2 and level <= 100 and size >= 1 and size <= 6)
end
```

This asserts that `nextInt` respects its own bounds. It never touches the preset it names,
never calls the generator, and cannot fail. None of §12.4's nine actual invariants — species
exist, levels in range, starters unique, required parties nonempty and ≤6, one-to-one
uniqueness, catchability holds, bounded retries, serialization round-trips — is tested.
`docs/race-validation-v1.md:102-105` presents this as a completed deliverable.

Highest-value fix in the whole review: build one synthetic 151-species manifest fixture plus
synthetic encounter/trainer/field sources, run `Generator.generate` across the three presets,
and freeze the canonical encoding of `result.mappings` as golden vectors. That single test
would cover FR-05, the category-isolation claims, and most of §12.4's invariants at once, and
would have caught finding #2.

### 11. `ONE-TO-ONE` is not the specified algorithm

Spec §6.2 requires "one-to-one assignment uses Fisher–Yates with the category stream" and
§5.1 describes "a deterministic shuffled destination pool." Every category instead uses
used-set exclusion plus a uniform draw over the survivors, and resets the whole used set when
it dead-ends (`wild_category.lua:15-32`, `wild_global.lua:79-89`,
`static_gift_category.lua:13-29`, `trainer_category.lua:147-184`).

The result is still deterministic and still avoids duplicates, so this is a spec-conformance
issue rather than a correctness bug — but greedy exclusion under a strength band dead-ends on
inputs where a perfect matching exists, producing avoidable `*_UNIQUENESS_POOL_RESET`
warnings and worse variety. `Rng:shuffle` is implemented, tested, and unused by any category.

### 12. `save.created` gating fails silently

`src/bootstrap.lua:429-442`

```lua
local gameReady = false
mod.events:on("game.ready", function() gameReady = true end)
mod.events:on("save.created", function(event)
  if not gameReady then return end
  lifecycle:onCreated(event)
end)
```

The comment documents an observed double-emit of `save.created` (a boot skeleton, then the
real New Game). The engine's published event reference describes `save.created` as firing
once per new game, so this is a workaround for undocumented behavior.

The problem is the failure mode, not the workaround: if ordering ever changes, a genuine New
Game gets no namespace, no error, no log line, and the player receives a fully vanilla save
that reports `ACTIVE:NONE` in the options screen. Silent no-op is the worst outcome for a
randomizer. At minimum log at `warn` when the guard suppresses a `save.created`, and consider
distinguishing the skeleton by inspecting the event payload rather than by global ordering.

---

## Low / maintainability

- **`static_gift_compat.lua` reimplements five vanilla NPC scripts as row tables with
  absolute numeric jump targets** (`:100-314`) — roughly 50 magic indices such as
  `{ "jump_if_false", 9 }` that shift silently if any row is inserted. No test walks these
  tables. This is the highest-risk file in the repo by a wide margin and the most likely
  source of future "the Dojo prize vanished" bugs.

- **Inconsistent box-full handling in the same file.** The mapped branches of `saleHandler`
  (`:212-227`) and `dojoHandler` (`:256-270`) correctly `CMD.give` first and only then take
  money / set flags. The unmapped ("vanilla") branches (`:196-210`, `:242-254`) set the
  completion flag and deduct payment *before* the give, with no `jump_if_false`. If that
  mirrors vanilla, fine — but it is worth confirming against the engine's own script, because
  as written the non-randomized path can consume the Magikarp payment and the Dojo prize on a
  full box while the randomized path cannot. README line 190 claims the opposite.

- **Release archives ship `docs/`, `tests/`, and `tools/`** (`tools/package.ps1:31-42`) —
  79 files, 555 KB, including the full 46 KB internal spec and two PowerShell scripts, for a
  mod whose payload is `main.lua` + `src/`.

- **`.modkitignore` is dead configuration.** `package.ps1` uses an explicit copy allowlist and
  never reads it. It is also already stale — it lists the 0.11–0.14.2 zips but not 0.15.0 or
  0.15.1 — which suggests someone believes it is load-bearing. Delete it or wire it up.

- **Eight release zips (1.1 MB) are committed to git**, plus two empty tracked directories
  (`.agents/`, `engine-patches/`). Build outputs belong in releases, not history.

- **No CI.** Tests run only through `tools/test.ps1`, which is Windows-only and falls back to
  a hardcoded `%LOCALAPPDATA%\Programs\Lua\5.1.5` path. A three-line GitHub Actions job on
  `lua5.1` would run the whole suite, and given NFR-01's cross-platform determinism claim, a
  Linux matrix entry is arguably required rather than optional.

- **`Catchability Guard` is much coarser than advertised.** `wild_category.isReachable:52-56`
  treats every map as reachable except `CERULEAN_CAVE*` / `UNKNOWN_DUNGEON*`. No badge, HM,
  or story gating is modelled, so a species reachable only by Surf in a late-game area counts
  as "available before the Elite Four." README line 36 promises more than that.

- **Unvalidated engine-shape assumptions**, each of which fails silently rather than loudly:
  - `bootstrap.lua:139` divides type-chart multipliers by 10.
  - `starter_category.lua:42` assumes the psychic type id is `PSYCHIC_TYPE`; if the engine
    uses `PSYCHIC`, the entire built-in effectiveness table degrades to neutral for it, which
    quietly changes `TYPE TRIAD` and `TYPE ADVANTAGE` counterpicks.
  - `trade_prize_category.lua:206` maps any version string that is not exactly `"blue"` to the
    Red prize list, with no warning.
  - `wild_runtime.lua:104` assumes the engine's second RNG draw inside `encounter.roll` is the
    probability-bucket draw. This one is handled well — `rolledSlot` re-verifies species and
    level before trusting the index and falls back to `matchingSlot` — but it deserves a
    comment naming the engine version the assumption was observed on.

- **`copyActiveSeed` can throw inside a UI action.** `bootstrap.lua:306-312` concatenates
  `run.settings.wild_pokemon` and six siblings with no nil guard; a run saved by a build with
  a different settings key set raises `attempt to concatenate a nil value` from a menu press.

- **`Spoiler.publicRun` shallow-copies unlocked runs** (`spoiler_log.lua:604-610`), so
  `mod.exports.save.activeRun()` hands other mods live references to `run.mappings`. Deep-copy
  or freeze.

- **`mod.exports` publishes the live `Generator` and `Contracts` tables**
  (`bootstrap.lua:152,170-175`); another mod can replace `generate` in place.

- **`Species.Metadata:register` hard-errors on a duplicate id** (`species_metadata.lua:48-49`),
  so two mods describing the same species make the second one fail to load. A logged
  first-wins or last-wins policy would be friendlier.

- **Dead code:** `save_lifecycle.lua:141` assigns `local id` and never uses it;
  `starter_compat.lua:104` is an unreachable duplicate `{ "jump", 21 }`.

- **`race_controller.lua:147` uses the 5.1-only global `unpack`**, while `main.lua:9` carefully
  writes `loadstring or load` for version portability. Use `(table.unpack or unpack)` for
  consistency.

---

## Suggested order of work

1. Golden vectors for `Generator.generate` across the three presets, plus a real §12.4
   property test (finding #10). Everything below is easier to change safely once this exists.
2. Fix the packaging separator bug (#3) — it is a one-line change that currently breaks two of
   three supported platforms.
3. Fix the `no_downgrade` legendary bypass (#2) and make the trainer category degrade per-slot
   (#4).
4. Decide what Race Mode actually promises. Either invest in real seed entropy (#1), a real
   KDF (#7), and organizer-bound passphrases (#6) — or narrow the README and spec to
   "accidental-spoiler deterrent" and remove `CREDITS` (#5) until it is distinguishable.
5. Reconcile the 256 KiB / 1 MiB budget (#9), stop rewriting `relevantMods` (#8), and add a
   warn log to the `save.created` guard (#12).
6. Add CI, trim the release payload, and drop `dist/` from git.
