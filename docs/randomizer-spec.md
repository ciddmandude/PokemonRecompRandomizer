# Pokémon Gen 1 Recomp Randomizer — Product and Technical Specification

Status: Draft for review  
Target: `gen1recomp` engine 1.0.0, mod API 2  
Document date: 2026-07-28

## 1. Purpose

Build a first-class `gen1recomp` mod that creates deterministic randomized playthroughs of Pokémon Red/Blue content while preserving the engine's vanilla-parity and save-safety guarantees.

The randomizer must support:

- wild Pokémon;
- the three starter choices;
- static encounters and non-starter gift Pokémon;
- in-game NPC trades;
- Pokémon sold by the Game Corner Prize Exchange ("shop Pokémon");
- all trainer parties, including rivals, Gym Leaders, Elite Four, Champion, and optional encounters.

The seed and the complete settings snapshot must be stored with the game save. Randomizer preferences must be configurable from the in-game Options menu. A loaded playthrough must always reproduce the same randomized content, even if global preferences, the mod version, or RNG calls elsewhere in the engine change.

## 2. Source constraints and design basis

This specification is based on the project wiki and corresponding engine source:

- [Wiki home](https://github.com/bryanthaboi/gen1recomp/wiki): the engine is a native LÖVE2D/Lua recreation whose mod platform exposes content through registries and decisions through hooks.
- [Mod lifecycle](https://github.com/bryanthaboi/gen1recomp/wiki/Concepts-Lifecycle): content registries freeze after merge, before play and before a new save is created; event and hook buses remain live.
- [Save model](https://github.com/bryanthaboi/gen1recomp/wiki/Concepts-Save-Model): per-mod state belongs in `save.modData[modId]` through `mod.save`; global mod preferences belong in `options.modOptions[modId]`; `save.created`, `save.loading`, `save.loaded`, and `save.writing` are available.
- [Registry reference](https://github.com/bryanthaboi/gen1recomp/wiki/Reference-Registries): encounters and trainer definitions are registries; `field` contains the imported trade data.
- [Hook reference](https://github.com/bryanthaboi/gen1recomp/wiki/Reference-Hooks): `encounter.species` and `trainer.party` are runtime interception points.
- [Event reference](https://github.com/bryanthaboi/gen1recomp/wiki/Reference-Events): the mutable `pokemon.before_give` event can replace a scripted gift before the Pokémon object is created.
- [Options recipe](https://github.com/bryanthaboi/gen1recomp/wiki/Cookbook-UI-And-Infrastructure): mod options persist in `options.lua` and may be exposed through the mod manager or Options UI.

The design follows these platform rules:

1. With the mod disabled, vanilla behavior is unchanged.
2. Randomization is performed without shipping ROM-derived data.
3. Mod failures are attributable and isolated; invalid randomizer state must not corrupt a save.
4. Content is read from the player's merged registries, so compatible mod-added species may be included when the selected pool permits it.

## 3. Terminology and assumptions

- **Seed**: the player-facing text that identifies a randomized run.
- **Canonical seed**: the normalized seed string used by the generator.
- **Run configuration**: the immutable seed, settings snapshot, algorithm version, and generated lookup tables stored in the save.
- **Global preferences**: editable values in `options.lua`; they are templates for the next New Game, not live rules for an existing run.
- **Vanilla pool**: the 151 Generation I species present in the imported base data.
- **Merged pool**: every valid species in the merged `pokemon` registry after enabled mods are applied.
- **Shop Pokémon**: the Pokémon entries at the Celadon Game Corner Prize Exchange. Ordinary Poké Marts remain item shops and are not changed.
- **Similar strength**: selection from a base-stat-total band around the source species.
- **One-to-one mapping**: each eligible source species maps to one destination species, with no duplicate destinations until the pool is exhausted.

## 4. Player experience

### 4.1 Starting a randomized run

1. The player opens `OPTIONS > RANDOMIZER`.
2. The player selects a preset or changes individual settings.
3. The player enters a seed or leaves Seed Mode on `AUTO`.
4. The player returns to the title screen and selects `NEW GAME`.
5. On `save.created`, the mod snapshots the current randomizer preferences, resolves the seed, validates the eligible species pool, generates every enabled mapping, and writes the run configuration into the new save.
6. Oak's intro and normal gameplay continue. The starter balls, encounters, trades, prizes, and trainer teams use the stored configuration.

If generation cannot produce a valid run, New Game must show a clear error and fall back to vanilla content for that new save. It must never produce a partially randomized save.

### 4.2 Continuing a run

On `CONTINUE`, the mod loads the run configuration from the save. The active run never reads behavior-affecting values from global preferences. Changing Options while a run exists affects only the next New Game.

The Randomizer screen must show:

- `ACTIVE SEED`;
- `ALGORITHM`;
- `RUN SETTINGS: LOCKED`;
- a read-only summary of enabled categories;
- `NEXT NEW GAME` above editable preferences.

### 4.3 Sharing a run

Two players using the same:

- canonical seed;
- settings snapshot;
- randomizer algorithm version;
- game version;
- eligible species manifest;
- relevant enabled mod set

must receive identical generated lookup tables.

The Randomizer screen must provide a compact run code:

`R1-<seed-hash>-<settings-hash>-<pool-hash>`

The full seed remains visible separately. The run code detects mismatched settings or species pools; it is not a substitute for the saved seed.

## 5. Options menu specification

Add a `RANDOMIZER` row to the main Options menu using `ui.options.rows`. Activating it opens a custom paged screen registered in `screens`. This is preferable to a long flat list because the screen needs help text, actions, locked-run status, and more rows than fit at once.

Every row must show a one- or two-line help description in a bottom panel. Left/Right changes enumerated values, A edits or activates, B returns, and Start opens a confirmation for `RESET DEFAULTS`.

### 5.1 General settings

| Option | Values | Default | Detailed behavior |
|---|---|---:|---|
| Randomizer | `OFF`, `ON` | `ON` | Master switch for the next New Game. `OFF` creates no randomized mappings and all categories behave as vanilla. It does not disable the mod or erase configuration already stored in a save. |
| Preset | `CUSTOM`, `CASUAL`, `STANDARD`, `CHAOS` | `STANDARD` | Applies a documented bundle of settings. Editing any bundled setting changes the display to `CUSTOM`. `CASUAL` uses similar-strength choices and progression safeguards; `STANDARD` uses independent random choices with safeguards; `CHAOS` enables full-pool, independent choices and disables most safeguards except hard validity rules. |
| Seed Mode | `AUTO`, `MANUAL` | `AUTO` | `AUTO` generates a new 128-bit seed when New Game is confirmed. `MANUAL` uses Seed Text after normalization. Changing this setting never rerolls an existing save. |
| Seed Text | text, 1–32 characters | blank | Used only in `MANUAL`. Accept uppercase letters, digits, space, hyphen, and underscore. Trim outer spaces, collapse repeated spaces, and uppercase before hashing. Reject an empty canonical seed. The original display text and canonical value are both saved. |
| Species Pool | `VANILLA 151`, `MERGED DATA` | `VANILLA 151` | `VANILLA 151` excludes mod-added species. `MERGED DATA` includes every valid merged-registry species that has battle sprites, stats, growth data, and a learnset. Missing or invalid species are excluded with a logged reason. |
| Similar Strength | `OFF`, `±10%`, `±20%` | `±20%` | Restricts candidate base-stat totals to the selected percentage around the source. If no candidate exists, widen in 5-point increments until at least one exists. Legendary filtering and other hard rules still apply. |
| Legendaries | `EXCLUDE`, `MATCH`, `ALLOW` | `MATCH` | `EXCLUDE` removes legendary/mythical species from destinations. `MATCH` lets legendary sources map only to legendary destinations and non-legendaries only to non-legendaries. `ALLOW` treats them like any species. The built-in classification is Articuno, Zapdos, Moltres, Mewtwo, and Mew; merged species may declare randomizer metadata through the mod's exported API. |
| Duplicate Policy | `ALLOW`, `ONE-TO-ONE` | `ONE-TO-ONE` | `ALLOW` samples with replacement. `ONE-TO-ONE` uses a deterministic shuffled destination pool, maximizing variety and preventing duplicate destinations until the eligible pool is exhausted. Category-specific uniqueness rules take precedence for starters. |
| Race Mode | `OFF`, `ON` | `OFF` | `ON` marks the run as a race seed, locks spoiler viewing/export according to Spoiler Unlock, includes race state in the run code, and suppresses mapping details from errors and UI. This is a best-effort local race aid, not tamper-proof anti-cheat. |
| Spoiler Unlock | `HALL OF FAME`, `CREDITS`, `PASSPHRASE`, `NEVER` | `HALL OF FAME` | Used when Race Mode is on. `HALL OF FAME` unlocks after the first valid Hall of Fame record; `CREDITS` unlocks after the ending completes; `PASSPHRASE` requires an organizer-supplied passphrase; `NEVER` keeps in-game and plaintext export locked. Before unlock, export may create only an authenticated encrypted spoiler file. |

### 5.2 Wild Pokémon settings

| Option | Values | Default | Detailed behavior |
|---|---|---:|---|
| Wild Pokémon | `OFF`, `GLOBAL MAP`, `AREA SLOTS` | `GLOBAL MAP` | `OFF` leaves all walking, surfing, and fishing encounters vanilla. `GLOBAL MAP` replaces a source species consistently everywhere using one saved source-to-destination table. `AREA SLOTS` saves a replacement for each map, terrain, and encounter slot, allowing the same source species to differ by location. |
| Fishing | `VANILLA`, `RANDOMIZED` | `RANDOMIZED` | Controls Old/Good/Super Rod candidates independently. When randomized, it follows the selected Wild mode and uses saved fishing mappings. Gifted Magikarp is not a fishing encounter. |
| Wild Levels | `UNCHANGED`, `±2`, `SCALED` | `UNCHANGED` | `UNCHANGED` preserves each original slot level. `±2` deterministically adjusts each slot from -2 to +2, clamped to 2–100. `SCALED` preserves the source area's relative difficulty but compensates for destination strength using `round(level × sqrt(sourceBST/destinationBST))`, clamped to 2–100. |
| Catchability Guard | `OFF`, `ON` | `ON` | Ensures every non-legendary destination species is available in at least one reachable pre–Elite Four encounter when mathematically possible. It does not alter encounter rates, map access, or require sequence-breaking. A post-generation validator swaps destinations between slots to meet coverage. |

Wild encounter rate and the ten-slot probability buckets remain vanilla. Repel checks continue to use the final randomized level. Static encounters and gifts are controlled separately below. The catching tutorial remains vanilla because it teaches a fixed mechanic and awards no Pokémon.

### 5.3 Starter settings

| Option | Values | Default | Detailed behavior |
|---|---|---:|---|
| Starters | `OFF`, `RANDOM`, `TYPE TRIAD` | `RANDOM` | `OFF` keeps Bulbasaur, Charmander, and Squirtle. `RANDOM` chooses three unique eligible species. `TYPE TRIAD` attempts to choose three unique species whose primary types form a directional effectiveness cycle; if no valid cycle exists, it falls back to `RANDOM` and records a warning. |
| Starter Stage | `ANY`, `BASIC ONLY` | `BASIC ONLY` | `BASIC ONLY` permits species with no pre-evolution in the eligible pool. `ANY` permits evolved forms. This filter applies only to the three player choices, not the rival's later randomized parties. |
| Starter Level | number 2–20 | `5` | Sets the received starter's level and the level shown in the starter preview. The first rival battle remains governed by Trainer Levels, but cannot be more than three levels above the chosen starter when Progression Guard is on. |
| Rival Counterpick | `BALL ORDER`, `TYPE ADVANTAGE`, `RANDOM OTHER` | `TYPE ADVANTAGE` | `BALL ORDER` preserves the vanilla positional counterpick. `TYPE ADVANTAGE` gives the rival whichever unchosen starter has the strongest type matchup against the player's choice, with deterministic ties. `RANDOM OTHER` selects either unchosen starter from the saved seed. This choice controls starter flags and every vanilla rival-party branch that depends on them. |

The Pokédex preview, confirmation text, received species, ball removal, rival movement, rival selection, and first rival team must agree. A solution that changes only `pokemon.before_give` is incomplete because the current Oak's Lab script displays the original species before the gift event.

### 5.4 Static encounter and gift settings

| Option | Values | Default | Detailed behavior |
|---|---|---:|---|
| Static Pokémon | `OFF`, `RANDOMIZED` | `RANDOMIZED` | On stock v0.1.30, randomizes 14 named map-script encounters: eight Power Plant balls, Zapdos, Articuno, Moltres, Mewtwo, and both Snorlax. Each stable encounter ID resolves once. Generic object-event statics, ghost Marowak, and the catching tutorial remain vanilla. |
| Static Levels | `UNCHANGED`, `SCALED`, `RANDOM ±5` | `UNCHANGED` | `UNCHANGED` preserves the encounter's level. `SCALED` compensates using `round(level × sqrt(sourceBST/destinationBST))`, clamped to 2–100. `RANDOM ±5` adds a saved deterministic offset from -5 through +5, clamped to 2–100. |
| Gift Pokémon | `OFF`, `RANDOMIZED` | `RANDOMIZED` | On stock v0.1.30, randomizes Celadon Eevee, Silph Lapras, both Fighting Dojo prizes, and the Route 4 Magikarp seller. Fossil restoration remains vanilla because the released API exposes no pre-dialogue gift-offer seam. Game Corner prizes and NPC trades remain controlled separately. |
| Gift Levels | `UNCHANGED`, `SCALED`, `FIXED 15` | `UNCHANGED` | `UNCHANGED` preserves each supported gift's original level. `SCALED` uses the BST compensation formula and clamps to 2–100. `FIXED 15` gives every supported randomized gift at level 15. Excluded gifts remain completely vanilla. |
| Gift Uniqueness | `ALLOW DUPLICATES`, `UNIQUE GIFTS` | `UNIQUE GIFTS` | `UNIQUE GIFTS` prevents duplicate destinations among the five supported gifts while candidates remain. It does not make gifts unique relative to wild encounters, starters, trades, or prizes. Both Fighting Dojo choices are generated and remain internally unique while candidates remain. |

Supported static and gift mappings use stable catalog IDs rather than source
species alone. Mapped names, cries after interaction, purchase prompts,
Pokédex updates, event flags, and the Pokémon actually awarded or battled use
the same saved resolution. Legendary overworld object sprites remain vanilla
because v0.1.30 has no per-save object-sprite seam.

### 5.5 In-game trade settings

| Option | Values | Default | Detailed behavior |
|---|---|---:|---|
| In-game Trades | `OFF`, `RECEIVED`, `BOTH SIDES` | `BOTH SIDES` | `OFF` keeps every NPC trade vanilla. `RECEIVED` randomizes only the Pokémon the NPC gives. `BOTH SIDES` randomizes both the requested and received species. Dialog substitutions, party validation, Pokédex updates, nickname, OT behavior, and trade animation must use the resolved offer. |
| Trade Fairness | `ANY`, `SIMILAR STRENGTH`, `NO DOWNGRADE` | `SIMILAR STRENGTH` | `ANY` uses the common pool rules. `SIMILAR STRENGTH` applies the global strength band between requested and received species. `NO DOWNGRADE` requires received BST to be at least requested BST minus 5%; relax deterministically only if no candidate exists. |
| Trade Evolution Safety | `OFF`, `ON` | `ON` | Prevents offers that require giving the same species received, and prevents impossible request species under Catchability Guard. Trade-evolution species remain legal; the normal in-game trade itself does not trigger a link evolution unless the base engine does so. |

Each of the nine NPC-wired trades is generated once by stable trade index and
stored. Completion flags remain vanilla so a trade cannot be repeated. The
imported CHIKUCHIKU table row at index 3 has no NPC script in stock Red or
Blue and is not a player-accessible offer.

### 5.6 Shop Pokémon settings

| Option | Values | Default | Detailed behavior |
|---|---|---:|---|
| Game Corner Pokémon | `OFF`, `RANDOMIZED` | `RANDOMIZED` | Randomizes only Pokémon prizes at the Celadon Game Corner. TM prizes remain unchanged. The Red and Blue prize lists are generated from the active game version, keeping the same number of Pokémon slots. |
| Prize Levels | `UNCHANGED`, `FIXED 15`, `SCALED` | `UNCHANGED` | `UNCHANGED` keeps each prize slot's original level. `FIXED 15` sets all Pokémon prizes to level 15. `SCALED` uses the same BST compensation formula as wild levels, clamped to 5–30. |
| Prize Prices | `UNCHANGED`, `BY STRENGTH`, `RANDOM ±25%` | `UNCHANGED` | `UNCHANGED` preserves each slot's coin cost. `BY STRENGTH` multiplies slot cost by destinationBST/sourceBST, rounded to the nearest 10 and clamped to 10–9999. `RANDOM ±25%` applies a saved deterministic modifier to the original slot cost, rounded and clamped. |

Purchasing a randomized prize must show the correct species and level before payment, deduct the displayed cost once, and pass the resolved species through the normal gift flow.

### 5.7 Trainer settings

| Option | Values | Default | Detailed behavior |
|---|---|---:|---|
| Trainer Pokémon | `OFF`, `GLOBAL MAP`, `BY SLOT`, `TYPE THEMED` | `BY SLOT` | `OFF` leaves all parties vanilla. `GLOBAL MAP` consistently maps every source species to one destination. `BY SLOT` independently resolves every trainer class, party index, and party position. `TYPE THEMED` assigns each trainer class a saved type and fills all its slots from that type when possible. |
| Trainer Levels | `UNCHANGED`, `±10%`, `PROGRESSIVE` | `UNCHANGED` | `UNCHANGED` preserves levels. `±10%` applies a saved per-slot multiplier from 0.90–1.10. `PROGRESSIVE` may scale early trainers down and late trainers up along a fixed badge/progression table, never changing a level by more than 20%. All values clamp to 2–100. |
| Boss Trainers | `INCLUDE`, `THEMED`, `VANILLA` | `THEMED` | Applies to Gym Leaders, Elite Four, Champion, and major rival fights. `INCLUDE` follows Trainer Pokémon. `THEMED` guarantees a single saved type theme per boss while retaining party size. `VANILLA` excludes boss parties from species and level randomization. |
| Party Size | `UNCHANGED`, `1–6 RANDOM` | `UNCHANGED` | `UNCHANGED` preserves each party's count. `1–6 RANDOM` generates a saved count, but Progression Guard limits pre–Brock trainers to 1–3 and prevents required battles from exceeding six. |
| Progression Guard | `OFF`, `ON` | `ON` | Enforces valid species, levels, and nonempty required parties; limits the first rival battle relative to the starter; prevents early mandatory teams composed only of high-BST or legendary Pokémon; and ensures generated moves can be constructed. It does not guarantee a particular difficulty. |

Trainer randomization runs before the engine constructs battlers. Vanilla special boss-move overrides must only be applied when legal for the resolved species; otherwise the normal generated moveset remains. Explicit per-slot move lists from other mods remain authoritative unless a compatibility conflict is reported.

### 5.8 Actions

| Action | Behavior |
|---|---|
| Review Next Run | Opens a scrollable summary of all editable settings and validation warnings. |
| Reset Defaults | Confirms, then restores the `STANDARD` preset and clears manual Seed Text. |
| Copy Active Seed | Copies the active seed and run code to the system clipboard when clipboard support exists; otherwise displays both for transcription. |
| Export Spoiler Log | Outside Race Mode, writes an optional human-readable log containing the seed, hashes, settings, and mappings but no ROM bytes. In Race Mode before unlock, plaintext export and on-screen mappings are unavailable; export produces only an authenticated encrypted file. After the configured unlock condition, normal export becomes available. |
| Unlock Spoilers | Visible for a locked `PASSPHRASE` race. Opens a masked passphrase-entry screen, derives a candidate key, and unlocks only after authenticated verification succeeds. Failed attempts reveal no mapping data and do not alter the save. |

## 6. Determinism and generation algorithm

### 6.1 Seed handling

1. Normalize a manual seed as defined in Section 5.1.
2. Encode it as UTF-8 bytes.
3. Hash it with a documented, versioned 128-bit hash implementation.
4. In Auto mode, obtain 128 bits from the operating system or LÖVE entropy source once at `save.created`, encode them as 26 Crockford Base32 characters, and save that text.
5. Derive independent RNG streams using `hash(rootSeed || "\0" || streamName)`.

Required stream names:

- `wild.global`;
- `wild.area`;
- `wild.levels`;
- `starters`;
- `rival.counterpick`;
- `static.encounters`;
- `static.levels`;
- `gifts`;
- `gift.levels`;
- `trades`;
- `prizes`;
- `trainers.species`;
- `trainers.levels`;
- `trainers.sizes`;
- `validation.swaps`.

Adding RNG calls to one category must not change another category. Do not use the process-wide `math.random` or `love.math.random` for generation.

### 6.2 PRNG

Use a repository-owned, tested integer PRNG with fully specified unsigned operations, output transformation, rejection sampling, and shuffle. `xoshiro128**` is recommended for LuaJIT compatibility. Persist resolved mappings rather than live PRNG state.

Rules:

- no floating-point value may decide permutation order;
- integer ranges use rejection sampling to avoid modulo bias;
- array iteration must use numeric indices;
- map keys must be sorted before generation;
- no Lua `pairs()` iteration may affect generated output;
- one-to-one assignment uses Fisher–Yates with the category stream.

### 6.3 Eligible pool manifest

Build a sorted manifest containing, for every eligible species:

- stable species ID;
- dex number when present;
- base stat total;
- primary and secondary types;
- evolution-stage classification;
- legendary classification;
- data fingerprint of generation-relevant fields.

Hash the manifest and store `poolHash`. On Continue, compare the active manifest to the saved hash. Because resolved mappings are saved, a mismatch is normally a warning rather than a reroll. If a mapped species no longer exists, use the save model's quarantine principles: report the missing content, substitute the original vanilla species for that lookup, and never rewrite the stored mapping silently.

### 6.4 Race-mode spoiler protection

Race Mode is a local coordination feature, not an anti-cheat boundary:

- while locked, the UI may show seed/settings hashes and category status but no species mappings;
- logs and error messages must redact resolved species and mapping keys;
- encrypted spoiler export uses authenticated encryption with a unique random salt and nonce and always prompts for an organizer passphrase before writing;
- `PASSPHRASE` derives the encryption key with a memory-hard password KDF; neither the passphrase nor derived key is stored in the save;
- automatic unlock policies set a one-way saved flag only after the corresponding engine event;
- unlocking permits plaintext viewing/export but never changes gameplay mappings;
- the encrypted file format is versioned and includes algorithm/settings/pool hashes as authenticated metadata;
- failure to initialize cryptography disables encrypted export and reports the problem; it must never fall back to plaintext.

## 7. Saved data contract

Use mod ID `pokemon_randomizer`. The save namespace is:

```lua
save.modData.pokemon_randomizer = {
  schemaVersion = 1,
  algorithmVersion = "1.0.0",
  enabled = true,

  seed = {
    mode = "manual",
    display = "MY SEED",
    canonical = "MY SEED",
    hash128 = "0123456789ABCDEF0123456789ABCDEF",
  },

  settings = {
    -- complete normalized snapshot of every behavior-affecting option
  },

  compatibility = {
    gameVersion = "red",
    engineVersion = "1.0.0",
    modApi = 2,
    poolHash = "...",
    settingsHash = "...",
    relevantMods = {
      -- sorted { id, version } rows
    },
  },

  mappings = {
    wildGlobal = {},
    wildAreaSlots = {},
    fishing = {},
    starters = {},
    starterFlags = {},
    staticEncounters = {},
    gifts = {},
    trades = {},
    prizes = {},
    trainerParties = {},
  },

  diagnostics = {
    warnings = {},
    fallbackCount = 0,
  },

  race = {
    enabled = false,
    unlockPolicy = "hall_of_fame",
    unlocked = false,
    encryptedSpoilerDigest = nil,
  },
}
```

Requirements:

- The canonical seed must be present in the same serialized `save.lua` as player progress.
- `save.writing` validates the namespace and stamps a deterministic checksum over configuration and mappings.
- `save.loading` must not execute save content.
- `save.loaded` validates schema, checksum, mapped species IDs, and settings before hooks use the data.
- Mod migrations upgrade older namespace shapes in semver order. An algorithm upgrade must not regenerate an existing run.
- Unknown future fields are preserved.
- If the namespace is absent, the save is vanilla and remains vanilla; loading it must not auto-randomize.
- If the namespace is malformed or fails checksum validation, disable randomization for that session, show a load report, and retain the original data for recovery.

## 8. Runtime integration

### 8.1 Existing engine seams

| Feature | Integration |
|---|---|
| Save initialization | Listen to `save.created` after `Game:adoptSave`; generate and store the complete run configuration atomically. |
| Save verification | Listen to `save.loading`, `save.loaded`, and `save.writing`; use `mod.migrations` for schema changes. |
| Wild walking/surfing | Wrap `encounter.species` for global mappings. Wrap `encounter.roll` only when area-slot mapping or saved level adjustment needs the original slot identity. |
| Fishing | Wrap `encounter.fishing`. |
| Trainers | Wrap `trainer.party` and return the saved party for `(trainerClass, partyIndex)`. |
| Oak's Lab starters | Register API-2 `map_scripts` winners for only the three starter-ball talk keys. Each handler resolves one offer record before building the preview, confirmation, gift, flags, ball removal, and rival counterpick rows. |
| Scoped statics/gifts | Register namespaced commands that resolve saved stable IDs, then replace only the supported v0.1.30 `map_scripts` talk/wake handlers. Excluded paths remain entirely vanilla. |
| NPC trades | Replace only the nine stock talk handlers with a namespaced command. Temporarily install a copied saved offer at its original trade index, delegate to the stock `trade` command, then restore the exact merged record. |
| Game Corner prizes | Replace the three shared prize-counter talk handlers with a public `screens`/`mod.ui.ListMenu` implementation that resolves the active version's six saved Pokémon rows and preserves all three TM rows. |
| Race unlock | Listen to Hall of Fame and credits completion events, validate the configured condition, persist the one-way unlock flag, and enable plaintext spoiler access only after unlock. |
| Options entry | Wrap `ui.options.rows` and register a custom `screens` entry. |

### 8.2 Optional future upstream seams

Version 0.12.0 requires no engine extension. The following hooks would make
future total-conversion interoperability simpler, but the stock-v0.1.30
implementation uses only public API-2 composition. If added upstream, unused
hooks must return vanilla data unchanged.

| New hook | Signature | Call site and purpose |
|---|---|---|
| `trade.offer` | `trade, ctx -> trade` where `ctx = { tradeIndex, doneFlag, save, game }` | `Commands.trade`, immediately after reading `field.trades[tradeIndex]`. Return a copied record; never mutate merged data. |
| `shop.pokemon_prizes` | `prizes, ctx -> prizes` where `ctx = { shopId = "GAME_CORNER", version, save, game }` | Game Corner prize menu before rows are built. Moves the version-specific Pokémon/TM prize lists into `field.gameCornerPrizes` or an equivalent registry-backed record, then exposes the runtime list. |

Additionally, `encounter.roll` should include the selected slot index in its returned encounter or context. If that API change is not accepted, `AREA SLOTS` must be omitted from version 1 rather than reimplementing vanilla encounter probability logic.

All new hook results must be type-checked. Invalid results log an attributed error and fall back to vanilla data for that call.

## 9. Category generation rules

### 9.1 Wild encounters

- Enumerate every merged encounter record in sorted map ID order.
- Preserve grass/water rate and slot ordering.
- Generate mappings from original records, never from already randomized output.
- Save keys as `<mapId>/<terrain>/<slotIndex>` and `<mapId>/<rod>/<candidateIndex>`.
- In global mode, save a source-species table once and use it everywhere.
- Run Catchability Guard after all wild/trade mappings exist so safe swaps do not change counts or rates.

### 9.2 Starters

- Resolve exactly three unique species or fail the category to vanilla.
- Store each ball's original stable identity and resolved offer.
- Ensure the starter preview and received Pokémon are identical.
- Translate the chosen ball into a stable randomizer starter index. Do not overload vanilla species-named flags as the source of truth.
- Provide a compatibility projection to the vanilla flags/counterpick table so rival scripts continue to select a valid party.
- Static starter choices are generated once; reopening a ball does not reroll it.

### 9.3 Trades

- Enumerate imported `field.trades` by numeric index.
- Preserve dialog set, nickname, OT behavior, completion flag, and received level rule.
- Save `{ give, get }` for each index.
- Validate that the requested species can be acquired before that trade when Catchability Guard and Trade Evolution Safety are on.
- A trade offer must not change after it is viewed.

### 9.4 Partial mod-only static encounters and gifts

- Enumerate the 14 named static and five named gift records in
  `static_gift_catalog.lua` by stable ID.
- Preserve one-time event flags, capture/defeat state, payment behavior,
  choice groups, nickname prompts, party/box handling, and Pokédex updates.
- Generate both Dojo alternatives at New Game; selecting one never rerolls
  or rewrites the other.
- Resolve supported static species and levels before battle setup and
  supported gifts before their mapped species name or confirmation appears.
- Full storage or a declined purchase retains the same saved offer.
- Fossil restoration, ghost Marowak, generic object-event statics, the
  catching tutorial, and Game Corner prizes remain vanilla in M11.

### 9.5 Game Corner prizes

- Preserve the active version's Pokémon slot count and all TM prize rows.
- Save resolved species, level, and cost per original prize index.
- Select the Red or Blue six-slot source list from the new save's version.
- For mapped Pokémon, award successfully before deducting the displayed
  price; a full party and full boxes consume no coins.
- When no valid mapping exists, preserve the stock v0.1.30 prize record and
  operation order.
- Do not reroll after purchase.
- Preserve the Coin Case requirement, coin cap, insufficient-funds behavior, party/box-full behavior, and Pokédex updates.

### 9.6 Trainers

- Enumerate trainer IDs, party indices, and slots in sorted/numeric order.
- Preserve party membership order unless a setting explicitly changes size.
- Generate and save the final `{ species, level }` list for every party variant, including rival branches.
- Type-themed selection prefers dual-type candidates containing the theme. If none exist after filters, relax Similar Strength before relaxing the type requirement; record every relaxation.
- Required battles may never have zero valid Pokémon.
- Runtime lookup must be O(1) by trainer ID and party index and must allocate only the returned party copy.

## 10. Functional requirements

`FR-01` The mod shall expose every setting and action in Section 5 through the in-game Options menu.

`FR-02` A New Game shall snapshot global randomizer preferences into the new save before gameplay.

`FR-03` The canonical seed, algorithm version, settings, pool hash, and resolved mappings shall be serialized with player progress.

`FR-04` Continue shall use only the run configuration stored in that save.

`FR-05` Identical inputs defined in Section 4.3 shall generate byte-equivalent normalized mapping tables.

`FR-06` Disabled categories shall make no behavior changes and shall not consume another category's RNG stream.

`FR-07` Wild randomization shall cover grass, surfing, and optionally fishing while preserving encounter rates.

`FR-08` Starter randomization shall keep preview, confirmation, received Pokémon, rival selection, and choice state consistent.

`FR-09` In-game trade randomization shall preserve completion and dialog behavior while using the saved offer.

`FR-10` Game Corner Pokémon prizes shall display and award the saved species, level, and cost.

`FR-11` Trainer randomization shall cover every party variant and return valid parties through `trainer.party`.

`FR-12` Every generated species and level shall validate against the merged game data and engine limits.

`FR-13` Existing randomized saves shall never reroll automatically after a mod or algorithm update.

`FR-14` Invalid or missing mapped content shall produce a visible report and a safe per-lookup vanilla fallback.

`FR-15` Disabling the mod shall restore vanilla runtime behavior and allow the save to load under the engine's normal missing-mod policy.

`FR-16` The mod shall optionally export a spoiler log without ROM-derived assets or text dumps.

`FR-17` The active seed, run code, algorithm version, and locked settings summary shall be viewable in-game.

`FR-18` The generator shall record deterministic fallback/relaxation warnings for review and tests.

`FR-19` Each static encounter in the v0.1.30 partial catalog shall use saved species and levels while preserving its stable identity and one-time state; excluded static paths shall remain vanilla.

`FR-20` Each gift in the v0.1.30 partial catalog shall use its saved offer consistently across mapped names, payment, choice state, and awards; fossil restoration and other excluded gifts shall remain vanilla.

`FR-21` Race Mode shall hide mapping details and block plaintext spoiler export until its saved unlock condition is satisfied.

`FR-22` Locked Race Mode shall export spoilers only through authenticated encryption and shall never silently downgrade to plaintext.

## 11. Non-functional requirements

`NFR-01 Determinism` Generation results must be identical across supported Windows, macOS, and Linux builds and across LuaJIT/LÖVE environments supported by the engine.

`NFR-02 Performance` Generation should complete in under 250 ms on the project's minimum supported desktop hardware; runtime lookup should add less than 0.1 ms to an encounter or battle setup under profiling.

`NFR-03 Save size` Randomizer state should add no more than 256 KiB for vanilla data with all categories enabled. Compact repeated strings or derive global mappings where possible without sacrificing stability.

`NFR-04 Safety` No randomizer code may parse executable save data, mutate frozen merged content at runtime, or use unvalidated species IDs.

`NFR-05 Isolation` Errors must be logged against `pokemon_randomizer` and degrade to vanilla for the affected call or session.

`NFR-06 Compatibility` The mod must declare supported engine and API ranges, fingerprint relevant merged content, and document known conflicts.

`NFR-07 Accessibility` Settings must be usable with keyboard, controller, and touch mappings supported by the base Options menu. Information must not depend on color alone.

`NFR-08 Testability` The generator must be a pure Lua module whose inputs and normalized outputs can be tested without starting LÖVE or loading a ROM.

`NFR-09 Privacy` Seeds, settings, and spoiler logs stay local unless the player explicitly copies or shares them.

`NFR-10 Documentation` Player documentation must define presets, seed normalization, compatibility requirements, and the meaning of every safeguard.

`NFR-11 Race security` The documentation must state that local saves and client code are inspectable and that Race Mode deters accidental spoilers rather than providing server-grade anti-cheat.

## 12. Acceptance and test requirements

### 12.1 Golden determinism tests

- Store at least 20 golden vectors containing canonical seed, settings, synthetic pool manifest, and expected hashes/mappings.
- Run vectors with categories individually and together.
- Verify enabling fishing does not alter starters, trades, prizes, or trainers.
- Verify enabling static encounters or gifts does not alter any other category stream.
- Verify sorted output is identical when input maps are inserted in different Lua table orders.

### 12.2 Save tests

- New Game with Auto and Manual seeds.
- Save, exit, change every global preference, Continue, and verify no mapping changes.
- Upgrade the mod with a migration and verify no reroll.
- Tamper with checksum and verify session-safe disable plus report.
- Remove a mapped species through a test mod and verify vanilla fallback without rewriting the stored mapping.
- Disable and re-enable the randomizer mod and verify the original namespace is reclaimed.
- Exercise every race unlock policy, confirm the unlock flag is one-way, and verify unlocking never alters mappings.
- Verify a locked race save cannot export or display a plaintext mapping through normal UI, logs, errors, or spoiler actions.
- Verify encrypted export decrypts with the correct passphrase, rejects an incorrect passphrase or modified ciphertext, and never stores the passphrase/key in the save.

### 12.3 Gameplay integration tests

- Sample every wild map/terrain and all fishing rods.
- Inspect all three starter balls, pick each in separate runs, and verify rival behavior.
- Trigger every static in the partial M11 catalog and verify capture, defeat,
  escape, and reload behavior; verify each excluded static remains vanilla.
- Accept, decline, retry, purchase, and exhaust storage for all five partial
  M11 gifts; verify the Fighting Dojo choice group and confirm fossil
  restoration remains vanilla.
- Complete every NPC trade, including wrong-mon, cancel, and already-completed branches.
- Buy every Game Corner Pokémon prize with insufficient funds, enough funds, full party, and full storage cases.
- Instantiate every trainer party variant and complete required boss battles.
- Exercise Red and Blue data paths where supported.

### 12.4 Fuzz/property tests

For at least 10,000 generated seeds per preset:

- every species ID exists;
- every level is within 2–100;
- starters are unique;
- static and gift IDs are stable and all saved offers are valid;
- required trainer parties are nonempty and at most six;
- one-to-one mappings obey uniqueness while candidates remain;
- Catchability Guard and trade reachability invariants hold when enabled;
- generation terminates within bounded retries;
- saved mappings serialize and parse to the same normalized table.

## 13. Compatibility and failure policy

- The mod reads merged data but never assumes registry iteration order.
- When `MERGED DATA` is selected, other mods may add metadata through `pokemon_randomizer.exports.registerSpeciesMeta(id, meta)`.
- If another mod wraps the same hook, standard hook priorities apply. This mod should call `next` first for base resolution, then apply its saved mapping unless the integration contract for that hook specifies otherwise.
- Link battles are out of scope; randomized owned Pokémon use normal species records and the engine's existing link fingerprint rules.
- Saves with the randomizer missing use the engine's normal `modsDiff` notice. Because all owned Pokémon are valid registry species rather than mod-created species, they remain usable.
- A category generation failure falls back that entire category to vanilla and records why. It must not leave half of the category randomized.
- A whole-run validation failure marks `enabled = false` before play and displays a report.

## 14. Out of scope for version 1

- moves, abilities, types, stats, learnsets, evolutions, items, TMs, field items, marts, maps, warps, palettes, or music;
- changing Pokémon species already owned in an existing save;
- randomizing during Continue when the save was originally vanilla;
- network seed synchronization or an online seed server;
- server-grade competitive anti-cheat, remote race administration, or proof that a player has not inspected local files;
- guaranteed beatability under every combination with Progression Guard off.

## 15. Fifteen implementation milestones

1. **Project skeleton and contracts** — Add the API-2 manifest, module layout, supported-version checks, logging, pure generator interfaces, and player-facing README.
2. **Deterministic RNG foundation** — Implement seed normalization, 128-bit hashing, named stream derivation, integer PRNG, rejection sampling, stable sorting, and Fisher–Yates; land golden vectors.
3. **Species manifest and filters** — Build vanilla/merged eligible pools, metadata export API, BST/type/evolution/legendary filters, pool fingerprints, and relaxation diagnostics.
4. **Save lifecycle and migrations** — Generate atomically on `save.created`, implement the Section 7 schema, checksum validation, load/write listeners, safe disable, and first migration harness.
5. **Options shell** — Add the `RANDOMIZER` Options row, custom paged screen, input behavior, help panel, active-run lock display, reset confirmation, and persistence of next-run preferences.
6. **General options and presets** — Implement every Section 5.1 setting, Casual/Standard/Chaos bundles, custom-state detection, run review, seed/run-code display, and clipboard fallback.
7. **Wild global mapping** — Implement grass/surf global species mapping through `encounter.species`, unchanged levels, category isolation, and integration tests.
8. **Wild area, fishing, and levels** — Add stable slot identity support, area-slot mappings, `encounter.fishing`, level modes, catchability validation, and rate/repel regression tests.
9. **Starter mod compatibility seam** — Register only the three Oak's Lab
   starter-ball talk handlers through API-2 `map_scripts`, resolve one offer
   through preview/gift/flags/rival movement, and prove stock-v0.1.30 vanilla
   parity without an engine patch.
10. **Starter randomization** — Implement unique choices, basic-stage/type-triad rules, starter levels, saved rival counterpick projection, and three-choice end-to-end tests.
11. **Partial mod-only static encounters and gifts** — Save stable mappings for
    14 named static and five named gift scripts through public API-2 commands
    and `map_scripts`; implement level/legendary/uniqueness settings, keep
    unsupported v0.1.30 paths vanilla, and document the exclusions.
12. **Mod-only trades and Game Corner prizes** — Save mappings for all nine
    wired NPC trades and the active version's six Pokémon prize slots;
    delegate scoped trades to the stock command, provide a public API-2 prize
    screen, preserve flags/dialogue/animation/TM rows/payment/storage
    behavior, and document the unwired trade-table row.
13. **Trainer randomization** — Implement global/slot/themed modes, level/party-size/boss/progression rules, special-move legality, all party variants, and O(1) saved lookup.
14. **Race mode, validation, and compatibility** — Add spoiler locking, automatic/passphrase unlock, authenticated encrypted export, cross-category reachability, deterministic repair swaps, missing-content fallbacks, relevant-mod fingerprints, fuzzing, and performance/save-size budgets.
15. **Release qualification** — Complete Red/Blue regression passes, controller/touch accessibility review, vanilla-disabled parity suite, migration rehearsal, documentation, packaging validation, and a release candidate with reproducible checksums.

## 16. Resolved product decisions

1. "Shop Pokémon" means only the Celadon Game Corner Prize Exchange; ordinary Poké Marts remain unchanged.
2. Static encounters and non-starter gifts are independently configurable,
   and v0.12.0 static/gift coverage remains limited to the explicit
   stock-v0.1.30 catalog in
   Section 9.4. Excluded paths remain vanilla until public pre-battle and
   pre-dialogue offer seams exist.
3. Race-oriented spoiler locking and authenticated encrypted export are included. Race Mode is explicitly a local accidental-spoiler safeguard, not tamper-proof anti-cheat.
