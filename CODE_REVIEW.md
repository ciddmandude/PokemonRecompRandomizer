# Code review round 2 — pokemon_randomizer 0.27.21

Previous review covered 0.15.1. This round re-verifies every prior finding against the
current tree and reviews the new code: `matching.lua`, `progression.lua`,
`public_facade.lua`, `spoiler_browser.lua`, `spoiler_browser_screen.lua`,
`spoiler_controller.lua`, the rewritten `static_gift_compat.lua` / `trainer_category.lua`,
nine new test files, `.github/workflows/package-validation.yml`, and the packaging tools.

**Test status:** 22/22 Lua test files pass on stock Lua 5.1.5, including
`generator_golden_test` (24 vectors, 17.7s) and `generator_property_test`
(23 real generations, 2.9s).

**Packaging verified by build:** ran `tools/package.ps1` and inspected the archive —
48 entries, **0 backslash entries**, `src/bootstrap.lua` style paths throughout.

---

## Verdict

This is a large, disciplined remediation pass, and the parts that were weakest last time are
now the parts I'd point at as exemplary. Three things stand out.

The **generator test infrastructure** is no longer nominal. `generator_golden_test.lua`
locks 24 combined vectors, hashing the request, manifest, sources, each of the ten mapping
buckets individually, the combined mappings, the warning codes, the fallback count, and the
validation summary — then asserts every mapping key participates in at least one vector and
that reversing every nested input map's insertion order produces an identical result.
`generator_property_test.lua` runs the real generator and checks the invariants spec §12.4
actually asks for: species existence, legendary `exclude`/`match` enforcement, level bounds,
party size 1–6, one-to-one uniqueness before exhaustion, trade reachability, safe
termination, serialization round-trip, and cross-category isolation. Both carry CI time
budgets. This is the fix I'd have prioritized above all others, and it was done properly.

The **static/gift scripts** went from ~50 absolute numeric jump targets to zero — every jump
is a named label, and `static_gift_safety_m10_test.lua` implements a small interpreter that
validates label definitions, rejects any numeric jump, and simulates execution paths. The
divergent mapped/unmapped branches were collapsed, so `CMD.give` now precedes
`give_money`/`set_flag` behind a `jump_if_false "full"` guard on every path.

**Removing Race Mode was the right call.** It retired four findings at once instead of
papering over them, and the removal is clean — no dead crypto modules, spec §16 updated,
and old saves with retired race metadata still load.

Everything below is either a small defect in the new code or a loose end. Nothing here is a
release blocker.

### Corrections to my previous review

Your remediation spec marks four items disproven against Recomp 0.1.38. Reviewing them again:

- **"Public run exports expose live saved tables" was wrong.** `Spoiler.publicRun` receives
  the output of `lifecycle:activeRun()`, which is already a `SaveState.clone`. A shallow copy
  of a fresh deep copy leaks nothing. I should have traced the call site before writing it up.
- `PSYCHIC_TYPE`, the type-chart `/10` conversion, and the boot-skeleton `save.created`
  ordering I raised as *unverified assumptions* rather than defects. You verified them
  against the engine, which is the correct resolution; I have no basis to re-raise them.

---

## Prior findings — status

| # | Finding | Status |
|---|---|---|
| 1 | Auto seeds not from OS/LÖVE entropy | **Open** (impact much reduced) — see below |
| 2 | `NO DOWNGRADE` bypasses `Legendaries = EXCLUDE` | **Fixed** — the `"allow"` override is gone; property test asserts the invariant |
| 3 | Backslash ZIP entry names | **Fixed and verified** — `ZipFile`/`ZipArchive` with explicit separator normalization, plus a two-OS CI job that packages, validates, and extracts |
| 4 | One bad species killed the whole trainer category | **Fixed** — per-slot `TRAINER_SOURCE_UNAVAILABLE` / `TRAINER_NO_CANDIDATE` warnings and a `fallbackSlot` marker the runtime resolves back to the prior hook's slot |
| 5 | `CREDITS` == `HALL OF FAME` | **Retired** with Race Mode |
| 6 | Self-service passphrase verifier | **Retired** with Race Mode |
| 7 | KDF not memory-hard | **Retired** with Race Mode |
| 8 | `relevantMods` rewritten on every save | **Fixed** — `onWriting` no longer touches it; `onLoaded` compares and reports `COMPATIBILITY_CHANGED` with added/removed/changed counts |
| 9 | 256 KiB vs 1 MiB budget | **Fixed** — `SAVE_SIZE_BUDGET_BYTES = 262144`, message and docs agree |
| 10 | No end-to-end vectors, vacuous fuzz | **Fixed** — see verdict |
| 11 | `ONE-TO-ONE` was greedy, not shuffle-based | **Fixed** — `matching.lua` does augmenting-path maximum bipartite matching over a shuffled preference order, and only opens a new pool when it has *proven* the unit cannot join |
| 12 | `save.created` guard fails silently | **Verified as correct** against 0.1.38; one ergonomic nit below |
| — | Sparse-settings UI crash | **Fixed** — `General.activeRunSummary` fills `UNAVAILABLE`/`UNKNOWN` defaults |
| — | Mutable generator export | **Partially fixed** — see M2 below |
| — | Metadata registration conflicts | **Fixed** — deterministic field policy plus `SPECIES_METADATA_CONFLICT_RESOLVED` diagnostics instead of a hard error |
| — | Coarse Catchability Guard | **Fixed** — real stage/gate model with a `PROGRESSION_MAP_UNKNOWN` diagnostic per unmodelled map |
| — | Oversized payload, committed archives, no CI | **Fixed** — 79 files → 48, `dist/` untracked and gitignored, two-OS workflow |

---

## New findings

### M1 — `progression.lua` requirement sort is a double no-op

`src/progression.lua:352-354`

```lua
StableSort.sort(requirements, function(value)
    return value
end)
```

Two independent bugs in three lines:

1. `StableSort.sort` is **not in-place** — it copies into a new array and returns it
   (`stable_sort.lua:42-45`). The return value is discarded, so `requirements` is untouched.
2. The comparator has the wrong arity and semantics. `sort` calls `less(a, b)` expecting
   `a < b`; this takes one argument and returns a string, which is always truthy. If the
   return value *were* used, the merge would take the right element every time.

Demonstrated against the real module:

```
ROCK_TUNNEL_1F     surf  -> HM05_FLASH, HM03_SURF, SOUL_BADGE
POKEMON_TOWER_3F   surf  -> SILPH_SCOPE, HM03_SURF, SOUL_BADGE
ROUTE_3            surf  -> BOULDER_BADGE, HM03_SURF, SOUL_BADGE

  correct S.sort(a<b) on the first case: HM03_SURF, HM05_FLASH, SOUL_BADGE
```

`ROUTE_23` looks sorted only because its static `requirements` table happens to be in sorted
order already, which is probably why this passed review.

Output stays deterministic (the static tables and `appendUnique` order are fixed), so this is
cosmetic — requirement lists reach the spoiler browser and diagnostics unsorted. Fix:

```lua
requirements = StableSort.sort(requirements, function(a, b) return a < b end)
```

Worth grepping for the same pattern elsewhere; a discarded `StableSort.sort` return is silent.

### M2 — public API hardening covers two of six export sub-tables

`src/bootstrap.lua:151,172` wrap `generator` and `contracts` in `PublicFacade`, but
`publicApi.species` (`:155-171`), `publicApi.save` (`:233-241`), `publicApi.preferences`
(`:242-249`) and `publicApi.spoilers` (`:251-255`) are still plain tables copied into
`mod.exports`. `mod.exports.save.validate = evil` and
`mod.exports.species.candidates = evil` both still work.

This matches the letter of `API-01`/`API-02` (my original finding named the generator
specifically), so it isn't a missed requirement — but `Facade.readonly` is already written and
generic, and applying it to the other four is a four-line change.

Note also that `readonly` guards `__newindex`, not `rawset`, and `mod.exports.generator`
itself can be replaced wholesale since `mod.exports` is engine-owned. The docstring at
`public_facade.lua:1-2` scopes the claim to "ordinary assignment," which is accurate — just
don't let that harden into a stronger assumption later.

### M3 — an unmatched trainer slot voids the whole party with no warning

`src/trainer_category.lua:432-449`

```lua
for _, item in ipairs(pending) do
  local row = item.row
  local species = matched.assignments[row.matchId]
  row.matchId = nil
  if species then
    row.species = species
    ...
  end
end
```

There is no `else`. If `matched.assignments[row.matchId]` is nil, the row keeps its `level`
and `sourceSlot` but gets no `species` and no `fallback = true`. At runtime
`TrainerRuntime.validParty` takes the `elseif type(slot.species) ~= "string"` branch and
returns false, so **the entire party** reverts to vanilla — not just that slot — and no
warning was recorded, because warnings are only emitted at add-time when `#candidates == 0`.

Currently unreachable: `Matching.newSession:add` only records `unmatched` when
`stablePreferences` is empty, and `SpeciesFilters.candidates` always returns entries with
string ids, so `#candidates > 0` implies a non-empty preference list. But this is precisely
the path you just hardened for per-slot degradation, and the failure mode is the
category-wide silent revert you set out to remove. Add the `else`:

```lua
else
  result.warnings[#result.warnings + 1] = fallbackWarning(
    "TRAINER_NO_CANDIDATE", "...", item.classId, item.partyIndex,
    item.slotIndex, item.sourceSlot.species, "UNMATCHED")
  result.fallbackCount = result.fallbackCount + 1
  item.row.fallback = true
  item.row.species, item.row.level = nil, nil
end
```

### M4 — `Matching.assign` documents a precondition it doesn't enforce

`src/matching.lua:1-4` states each unit must have "a stable, unique `id`", and both commit
loops write through `pairs`:

```lua
for matchedIndex, destination in pairs(assigned) do
  assignments[units[matchedIndex].id] = destination
end
```

With unique ids every write targets a distinct key, so `pairs` order cannot affect the result
and determinism holds. With duplicate ids, last-write-wins — and which write is last depends
on `pairs` traversal, i.e. on table internals. That is exactly the class of nondeterminism
spec §6.2 forbids, reachable only through a caller mistake, with no assertion to catch it.

One line at the top of `assign` and `newSession:add` closes it:

```lua
assert(not seenIds[unit.id], "matching unit ids must be unique")
```

Two smaller notes on the same module. `augment` recurses to a depth bounded by the current
pool size, which is fine for a 151-species pool but grows with large `MERGED DATA` pools —
worth a comment noting the bound. And `Matching.assign`'s reset path relies on the implicit
invariant that a non-empty preference list always matches an empty pool; `newSession` asserts
this at `:167`, `assign` doesn't, and if it were ever violated `assign` would spin forever
because `poolStart = index` leaves the loop variable unchanged.

### L1 — auto-seed entropy is still not what spec §6.1 requires

`src/save_lifecycle.lua:14-23` is unchanged. The traceability table maps this to
"Weak race-export entropy → milestones 6–8 (removed)", but those are two different code
paths: the removed one was `race_controller.entropy` feeding salt/nonce; this one is
`save_lifecycle.entropy` feeding `SaveState.makeAutoSeed`.

Removing Race Mode removes the adversarial motivation, so I'd now call this low priority.
But `docs/randomizer-spec.md:6.1(4)` still says "obtain 128 bits from the operating system or
LÖVE entropy source," and the implementation derives them from `os.time()` (1-second
resolution), `os.clock()`, a table address, and a per-process counter. Two players starting a
New Game in the same second are more likely to collide than a 26-character Crockford Base32
identity implies. Either seed from `love.math.random`/`love.timer.getTime` in addition to what
is there, or amend §6.1(4) to describe what the mod actually does.

### L2 — the spoiler browser rebuilds its entire index on every open

`src/bootstrap.lua:213` calls `SpoilerBrowser.build(run, ...)` inside the model builder, which
runs each time the screen is pushed. `build` walks every wild map/terrain/slot, all fishing
rods, starters, statics, gifts, trades, prizes and every trainer party, then constructs
species→location indexes (`spoiler_browser.lua:602-627`). `loadBackground`
(`spoiler_browser_screen.lua:360-375`) additionally allocates one `Quad` per 8×8 tile of the
town-map image — over a thousand for a 256×256 sheet — with no caching.

Nothing is wrong, but none of it is memoized, and the engine targets handhelds like the
Anbernic RG34XXSP. Caching the index against `run.seed.hash128` plus `run.checksum.value`,
and caching the background globally, removes a visible hitch for a screen players will open
repeatedly.

### L3 — `loadBackground` assumes 8-pixel-aligned image dimensions

`spoiler_browser_screen.lua:366-373`: `perRow = width / 8` and the loop bound
`perRow * (height / 8) - 1` are only integers when both dimensions are multiples of 8. A
mod-supplied town map of another size yields a fractional loop bound and fractional quad
offsets. The `pcall` guards `newImage` but not the quad loop. A
`width % 8 == 0 and height % 8 == 0` check before building quads makes this fail closed.

### L4 — Fighting Dojo is over-gated in the progression model

`src/progression.lua:122`:

```lua
FIGHTING_DOJO = { stage = 7, requirements = { "SILPH_CO_CLEARED" } },
```

The Dojo is in Saffron City, which opens once the player brings a vending-machine drink to the
guards — Silph Co. does not have to be cleared, and the Dojo is normally fought well before
it. Placing it at stage 7 makes the Dojo prizes look later than they are in the spoiler
browser and makes the Catchability Guard more conservative than necessary. Stage 4 with a
`SAFFRON_ACCESS`-style requirement matches the real gate. (`SILPH_CO_7F` at stage 7 is
correct.)

### L5 — `tools/test.ps1` still hand-maintains the test list

22 files in `tests/`, 22 invocations in `test.ps1` — currently correct, but each new test
needs a matching edit, and forgetting one means it silently never runs in CI. A glob over
`tests/*_test.lua` with a deterministic sort would keep CI honest for free. (The suite has to
stay in a fixed order for reproducibility, which `Sort-Object Name` gives you.)

### L6 — style and ergonomics

- `src/progression.lua` uses 4-space indentation; every other module in `src/` uses 2.
- The `save.created` guard (`bootstrap.lua:450-457`) is correct for 0.1.38, but still returns
  silently. A single `mod.log:debug`/`info` line when it suppresses an event would turn a
  future engine-ordering change from "the randomizer did nothing and said nothing" into a
  one-line diagnosis.

---

## Suggested order

1. M1 — one-line fix, and grep for other discarded `StableSort.sort` returns.
2. M3 and M4 — two defensive guards in the paths that just got hardened.
3. L4 — progression-model accuracy.
4. M2, L2, L3 — API surface and spoiler-browser polish.
5. L1 — decide whether to implement §6.1(4) or amend it; don't leave the spec claiming
   something the code doesn't do.
6. L5, L6 — housekeeping.
