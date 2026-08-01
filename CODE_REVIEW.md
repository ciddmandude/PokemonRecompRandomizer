# Code review round 3 — pokemon_randomizer 0.46.0

Round 1 covered 0.15.1, round 2 covered 0.27.21. This round reviews the growth from
0.34.4 to **0.46.0** (algorithm `1.4.0-dev` → `1.17.0-dev`): nine new modules
(`item_category`, `item_filter`, `item_runtime`, `item_source_catalog`,
`mechanics_category`, `mechanics_runtime`, `evolution_category`, `new_game_setup`,
plus supporting changes), seven new test files, Yellow support, an in-game New Game
chooser, and two new save migrations.

Codebase is now ~15,300 lines of Lua across 52 modules.

**Test status:** 30/30 test files pass on stock Lua 5.1.5, including
`generator_golden_test` (24 vectors, 17.4s), `generator_property_test`
(25 real generations, 3.1s), and `evolution_randomizer_test` (100 randomized graphs).

---

## Verdict

The engineering standard set in round 2 is holding in the parts that were already
built. Migrations are correct, the spoiler log grew to cover the new categories, Yellow
support is threaded properly through starters/prizes/progression/browser, and the
mechanics runtime's save-switch path is genuinely well designed.

The problem is that the safety net built in round 2 did not grow with the code. About
1,700 lines of new generation logic and eleven new RNG streams landed **outside** the
combined-generator harness that exists specifically to lock determinism and category
isolation. That harness is the reason round 2 was trustworthy. Right now it is
protecting the old two-thirds of the generator and silently ignoring the new third.

Separately, `mechanics_runtime` takes the codebase somewhere it has explicitly promised
not to go — in-place mutation of merged registry records. The mitigation is thoughtful
and mostly correct, but the promise in NFR-04 is now false as written, and one
unguarded path can poison it for a whole session.

Nothing here is a data-loss or corruption risk. The two High items are both
"the tests can no longer see this", which is exactly the condition that let the round-1
bugs exist.

---

## High

### H1 — The golden vectors and property test cover none of the new categories

`tests/generator_golden_vectors.lua`, `tests/generator_property_test.lua`,
`src/general_settings.lua`

Round 1 finding #10 was "no end-to-end generator coverage". Round 2 fixed it properly:
24 vectors hashing every mapping bucket, plus real property invariants. That fix does
not extend to anything added since.

Every new setting defaults to `"vanilla"` **in all three presets, including CHAOS**:

```lua
-- src/general_settings.lua, CHAOS preset
non_key_items = "vanilla",   key_items = "vanilla",
badges = "vanilla",          hidden_items = "vanilla",
base_stats = "vanilla",      evolutions = "vanilla",
pokemon_types = "vanilla",   pokemon_movesets = "vanilla",
tmhm_compatibility = "vanilla",
move_types = "vanilla",      move_data = "vanilla",
```

All 24 golden vectors run one of `standard` (13), `chaos` (6) or `casual` (5), and none
of them passes an override for any new key. So in every vector:

- `mappings.fieldItems` is `{}`
- `mappings.pokemonMechanics` is `{}`
- `mappings.moveData` is `{}`

The combined-mappings hash therefore locks in *empty* for all three, which is not
coverage — it only proves the categories stay off when they are off.

`generator_property_test.lua` is the same story: grepping it for any of
`field_items`, `non_key_items`, `key_items`, `hidden_items`, `badges`, `base_stats`,
`evolutions`, `pokemon_types`, `pokemon_movesets`, `tmhm_compatibility`, `move_types`,
`move_data` returns nothing. Its `isolated()` stream-isolation helper — the thing that
verifies FR-06 — is only ever called with old-category overrides.

Consequences:

- **FR-05** (identical inputs produce byte-equivalent mappings) is unverified for three
  mapping buckets.
- **FR-06** (a disabled category consumes no other category's stream) is unverified for
  eleven new streams. This one matters most: the new categories run *last* in
  `Generator.generate`, so a stream mistake there would be invisible until someone
  compared two runs by hand.
- The `evolution_category` backtracking search — the most algorithmically delicate code
  in the project — has no locked vectors at all. `evolution_randomizer_test` runs 100
  graphs, but as invariants, not as frozen expected output.

The per-category unit tests (`item_randomizer_test`, `mechanics_randomizer_test`,
`evolution_randomizer_test`, `badge_randomizer_test`) are real and worth having. They
are not a substitute for the combined harness, because every bug round 2 was designed to
catch was a *cross-category* bug.

Fix: add overrides to the vector set that enable each new category — several vectors per
category, plus at least one with everything on at once — and regenerate
`generator_golden_expected.lua`. Then extend `isolated()` in the property test to cover
the new streams.

### H2 — The golden test's mapping-key list is stale

`tests/generator_golden_test.lua:6-9`

```lua
local MAPPING_KEYS = {
  "wildGlobal", "wildAreaSlots", "fishing", "starters", "starterFlags",
  "staticEncounters", "gifts", "trades", "prizes", "trainerParties",
}
```

`src/contracts.lua` and `src/save_state.lua` both list **thirteen** keys — the three new
ones are `fieldItems`, `pokemonMechanics`, `moveData`. The golden test still knows about
ten.

Two things break quietly:

1. The per-bucket assertion loop never hashes the three new buckets, so when H1 is fixed
   a regression in them will only surface as a mismatch in the aggregate `combined` hash,
   with no indication of which category moved.
2. `assert(participated[key], key .. " never participates in a golden vector")` — the
   guard specifically written to stop a category from silently dropping out of coverage —
   does not know the new keys exist, so it cannot fire for them. That guard is the reason
   H1 should have been caught automatically.

Derive this list from `Contracts.mappingKeys()` instead of duplicating it, and the class
of bug disappears permanently.

---

## Medium

### M1 — `Constants.STREAM_NAMES` is missing every mechanics stream

`src/constants.lua:26-44`

The generator draws from **27** distinct named streams. `STREAM_NAMES` declares **17**.
Missing, all ten:

```
mechanics.base_stats     mechanics.pokemon_types   mechanics.movesets
mechanics.tmhm           mechanics.evolutions      mechanics.trade_evolutions
mechanics.move_types     mechanics.move_power      mechanics.move_accuracy
mechanics.move_pp
```

`STREAM_NAMES` has exactly one consumer: `tests/foundation_test.lua:75`, which derives
every declared stream and asserts no two collide. So ten of twenty-seven streams are
outside the only test guarding stream separation.

I checked for an actual collision across all 27 used streams over four seeds — **none**,
and all 27 satisfy `Hash128.derive`'s identifier rule. So this is a coverage gap rather
than a live defect. But the failure it guards against is severe (two categories sharing
an identical PRNG sequence) and silent, and the gap arrived precisely because the list is
maintained by hand in a different file from the code that uses the names.

Consider deriving the names from a single table that `generator.lua` also reads, so the
test cannot drift from reality.

### M2 — `mechanics_runtime` mutates merged registry records in place

`src/mechanics_runtime.lua:30-40, 43-78`

```lua
local function project(records, mappings, fields)
  ...
      for _, field in ipairs(fields) do
        if overlay[field] ~= nil then target[field] = copy(overlay[field]) end
      end
```

`target` is a live record in `game.data.pokemon` / `game.data.moves`. This writes
randomized `baseStats`, `types`, `evolutions`, `level1Moves`, `learnset`, `tmhm`, and
move `type`/`power`/`accuracy`/`pp` directly into the merged content the engine and every
other mod read.

That contradicts a promise the project has made since round 1:

> `NFR-04 Safety` No randomizer code may parse executable save data, **mutate frozen
> merged content at runtime**, or use unvalidated species IDs.

The mitigation is real and I want to give it credit. `Runtime.apply` calls
`Runtime.restore` first, so applying is idempotent and cannot accumulate. And the
save-switch path is handled correctly — `bootstrap.lua:728-739` calls
`MechanicsRuntime.apply(activeGame, run)` on `save.loading` with `run = nil` for a
vanilla or invalid save, which restores the baseline before the new save is adopted.
Loading a vanilla save after a randomized one does *not* leak randomized stats. That is
the case I expected to be broken and it isn't.

Two problems remain.

**The baseline capture is unguarded against re-entry.** `bootstrap.lua:659-666`:

```lua
mod.events:on("game.ready", function(event)
  gameReady = true
  activeGame = ...
  if activeGame then
    ItemRuntime.capture(activeGame)
    MechanicsRuntime.capture(activeGame)
  end
end)
```

`Runtime.capture` unconditionally overwrites `baseline` from whatever is currently in
`game.data`. If `game.ready` ever fires a second time in one process while mechanics are
applied — returning to the title screen and starting again, for instance — the
*randomized* values become the new baseline, and `restore` can never undo them for the
rest of the session. Every subsequent save, vanilla ones included, would inherit that
run's stats.

This project already learned once that a documented-as-single lifecycle event fires more
than expected: the whole `gameReady`/`bootSuppressionLogged` guard around `save.created`
exists because of it. The same caution applies here. A one-line guard removes the risk
entirely:

```lua
if baseline then return true end
```

...or capture only when no run is currently applied.

**Cross-mod visibility.** While a randomized run is loaded, any other mod reading
`game.data.pokemon` sees randomized stats and types. For a mechanics randomizer that is
arguably the point, but it is a behavioural contract change that NFR-04 currently denies,
and `DRAMATIC_SHAPE` is loaded alongside this mod in at least one real install.

Whichever way you resolve it, the spec should stop claiming the mod never mutates merged
content. Either scope NFR-04 to "content registries are never mutated except through the
documented mechanics overlay, which is captured and restored at every save transition",
or move the projection behind a hook that returns copies.

### M3 — Spec §14 still lists implemented features as out of scope

`docs/randomizer-spec.md`, section 14:

> - moves, abilities, types, stats, learnsets, evolutions, scripted item gifts,
>   marts, maps, warps, palettes, or music;

Moves, types, stats, learnsets, and evolutions are all implemented now —
`mechanics_category.lua` randomizes base stats, Pokémon types, movesets, TM/HM
compatibility, evolutions, trade evolutions, and move type/power/accuracy/PP. The section
was clearly edited (items became "scripted item gifts", "Progression Guard" became
"Trainer Safety"), so this is an oversight rather than a stale file, but it currently
reads as a direct contradiction of five shipped features.

### M4 — Both documented stream lists are stale

- `docs/determinism-v1.md` — "Locked v1 stream names are:" lists **15**, missing
  `trainers.rival`, `items`, and all ten `mechanics.*`. The same document opens with
  "A conforming implementation must reproduce `tests/golden_vectors.lua` exactly", so a
  reader would reasonably treat that list as the contract.
- `docs/randomizer-spec.md` §6.1 "Required stream names" lists **16** (it gained
  `trainers.rival`), missing `items` and all ten `mechanics.*`.

Both should match the 27 in use, and ideally be generated from the same source as M1.

### M5 — Randomized evolutions invalidate the stage classification other features rely on

`src/species_manifest.lua:206-215`, `src/starter_category.lua`,
`src/evolution_category.lua:78-97`

`stage` (`basic` / `middle` / `final`) is derived from the **vanilla** evolution graph
when the manifest is built, before generation runs. Several features reason about it:

- `Starter Stage = BASIC ONLY` filters on `entry.stage == "basic"`
- evolution mode `preserve_stages` compares `candidate.stage == original.stage`
- evolution `similar` mode `same_stage` does the same

`Generator.generate` runs mechanics/evolutions **last**, after starters
(`generator.lua:291` vs `:75`). So with `evolutions` randomized, a species offered under
BASIC ONLY may well have a pre-evolution in the graph the player actually plays, and
`preserve_stages` preserves a stage relationship that no longer exists in-game.

Everything stays deterministic, so this is a semantics problem rather than a
reproducibility one. But "Basic Only never silently admits an evolved form" is a stated
design guarantee in the README, and with randomized evolutions it is no longer true in
the sense a player would read it. Either recompute stages from the randomized graph
before the starter category runs, or document that stage rules always refer to vanilla
lineage.

---

## Low

### L1 — The New Game chooser writes global preferences as a side effect

`src/new_game_setup.lua:41-42, 51`

```lua
local selected = item and preferences:set("preset", item.value, game)
...
preferences:set("preset", "custom", game)
```

Picking a preset in the mandatory New Game chooser persists it to
`options.modOptions.pokemon_randomizer`, so it becomes the default for every future New
Game too. That is arguably consistent with the "options are next-run templates" model,
but the chooser reads as a per-run question, and a player who picks CHAOS once will find
CHAOS preselected forever. Worth a line in the README at minimum.

### L2 — Both new migrations recompute `settingsHash`

`src/bootstrap.lua:598-599, 638-639`

The field-item and mechanics migrations backfill defaults correctly and preserve mappings
(I verified both add the missing mapping keys and stamp a fresh checksum — this part is
right). But each recomputes `compatibility.settingsHash`, which shifts the **run code**
of an existing save after a mod update.

Two players on the same seed who update at different times will see different run codes
while playing byte-identical mappings, which is the exact confusion the run code exists
to prevent. The same pattern shipped in the 0.6.0 migration so it is an established
convention here, not a new mistake — but it deserves a note in the README's run-code
section, since "the run code detects mismatched settings" is now only true within a
single mod version.

### L3 — Minor observations

- `evolution_category.randomizedMapping` allocates a full `rng:shuffle(rows)` **per
  edge** (`:108`). With ~80 vanilla evolution edges over 151 species that is roughly
  12,000 PRNG draws before the search even starts. Deterministic and bounded, but it is
  the dominant cost in that module and a single shuffled order reused with an offset
  would be far cheaper.
- `createsCycle` and `assign` are both recursive over the species graph. Bounded for
  vanilla, but a large `MERGED DATA` pool deepens both; the `budget` guard at `:114`
  covers `assign` but not `createsCycle`'s own recursion depth.
- `mechanics_runtime.capture` stores a deep copy of six fields for every species plus
  four for every move on each call. Fine at current sizes, worth remembering if the
  merged pool ever grows substantially.

---

## What's good

Worth stating explicitly, because these were the risky parts and they landed well:

- **Migrations are correct.** Both new ones backfill settings defaults *and* the new
  mapping keys, recompute the hash, stamp, and fail loudly on validation error. An
  0.34-era save loads without quarantine.
- **The mechanics save-switch path is right.** Restore-then-apply on `save.loading`, with
  `run = nil` for vanilla saves, is the correct design and handles the case I most
  expected to be broken.
- **Yellow support is threaded end to end** — `starter_category` (player/rival split),
  `starter_compat` (the Eevee ball handler), `progression`, `save_state` validation, and
  the spoiler browser all handle it, with a dedicated test.
- **The spoiler log kept pace** with the new categories: `ITEM LOCATIONS AND SHOPS`,
  `POKEMON MECHANICS`, and `MOVE DATA` sections plus four new settings groups. Given the
  spoiler log is the primary manual-verification channel, this mattered.
- **Round-2 findings all still fixed.** No regressions in the progression sort, the
  trainer unmatched-slot path, matching's id assertions, or the entropy provider.

---

## Suggested order

1. **H2** first — it is a two-line change (derive from `Contracts.mappingKeys()`), and it
   turns H1 from something you have to remember into something the suite reports.
2. **H1** — add vectors that actually enable items, badges, mechanics, evolutions and
   move data, and extend the property test's `isolated()` to the new streams. This is the
   bulk of the work and it is worth doing before the next feature.
3. **M2's capture guard** — one line, removes a session-poisoning failure mode.
4. **M1 and M4 together** — single source of truth for stream names, consumed by the
   generator, the collision test, and both documents.
5. **M3, M5, L1, L2** — documentation and semantics reconciliation.
