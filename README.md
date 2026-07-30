# Pokémon Gen 1 Recomp Randomizer

A deterministic, per-save randomizer for
[Pokémon Gen 1 Recomp](https://github.com/bryanthaboi/gen1recomp).

## Settings

The Randomizer screen is opened from the main Options menu. These values are
preferences for the **next** New Game: starting a game validates the settings
and saves a snapshot with that run. Changing the Options menu later does not
reroll an existing save. `OFF` on the master Randomizer setting creates a
vanilla run without deleting saved preferences.

### General

| Setting | Values | Default | Effect |
|---|---|---|---|
| Randomizer | `OFF`, `ON` | `ON` | Master switch for the next New Game. |
| Preset | `CUSTOM`, `CASUAL`, `STANDARD`, `CHAOS` | `STANDARD` | Applies a settings bundle. Editing a bundled value changes this to `CUSTOM`. |
| Seed Mode | `AUTO`, `MANUAL` | `AUTO` | `AUTO` creates a new 128-bit seed; `MANUAL` uses Seed Text. |
| Seed Text | 1–32 characters | blank | Manual seed using letters, digits, spaces, hyphens, or underscores. It is trimmed, uppercased, and saved in canonical form. |
| Species Pool | `VANILLA 151`, `MERGED DATA` | `VANILLA 151` | Uses only the original 151, or all valid species contributed through the merged registry. |
| Similar Strength | `OFF`, `±10%`, `±20%` | `±20%` | Restricts candidates by base-stat total, widening deterministically if the band is empty. |
| Legendaries | `EXCLUDE`, `MATCH`, `ALLOW` | `MATCH` | Excludes legendaries, maps legendary status like-for-like, or treats them like any species. |
| Duplicate Policy | `ALLOW`, `ONE-TO-ONE` | `ONE-TO-ONE` | Samples with replacement or maximizes unique destinations until the eligible pool is exhausted. |
| Enable Spoiler Log | `OFF`, `ON` | `ON` | Saved with the new run. `ON` allows the in-game viewer and manual file export; `OFF` blocks both. Starting a game never exports a file automatically. It does not affect the seed or mappings. |

### Wild Pokémon

| Setting | Values | Default | Effect |
|---|---|---|---|
| Wild Pokémon | `OFF`, `GLOBAL MAP`, `AREA SLOTS` | `GLOBAL MAP` | Leaves encounters vanilla, consistently maps each source species everywhere, or randomizes each map/terrain/slot independently. |
| Fishing | `VANILLA`, `RANDOMIZED` | `RANDOMIZED` | Controls Old, Good, and Super Rod encounters separately from walking and surfing. |
| Wild Levels | `UNCHANGED`, `±2`, `SCALED` | `UNCHANGED` | Preserves levels, applies a saved -2 to +2 offset, or compensates for source/destination strength. |
| Catchability Guard | `OFF`, `ON` | `ON` | When mathematically possible, ensures every non-legendary destination is reachable before the Elite Four. |

Encounter rates, slot probability buckets, and Repel behavior remain vanilla.

### Starters

| Setting | Values | Default | Effect |
|---|---|---|---|
| Starters | `OFF`, `RANDOM`, `TYPE TRIAD` | `RANDOM` | Keeps the original trio, chooses three unique species, or attempts a three-way primary-type effectiveness cycle. |
| Starter Stage | `ANY`, `BASIC ONLY` | `BASIC ONLY` | Allows any eligible species or only species without a pre-evolution. |
| Starter Level | `2`–`20` | `5` | Sets the level shown in Oak's Lab and the level of the received starter. |
| Rival Counterpick | `BALL ORDER`, `TYPE ADVANTAGE`, `RANDOM OTHER` | `TYPE ADVANTAGE` | Uses the vanilla ball relationship, the strongest matchup, or either unchosen starter. |

### Static encounters and gifts

| Setting | Values | Default | Effect |
|---|---|---|---|
| Static Pokémon | `OFF`, `RANDOMIZED` | `RANDOMIZED` | Randomizes the supported named encounters: the eight Power Plant balls, legendary birds, Mewtwo, and both Snorlax. |
| Static Levels | `UNCHANGED`, `SCALED`, `RANDOM ±5` | `UNCHANGED` | Preserves levels, compensates for strength, or applies a saved -5 to +5 offset. |
| Gift Pokémon | `OFF`, `RANDOMIZED` | `RANDOMIZED` | Randomizes Celadon Eevee, Silph Lapras, both Fighting Dojo prizes, the Route 4 Magikarp seller, and all three Cinnabar fossil restorations. |
| Gift Levels | `UNCHANGED`, `SCALED`, `FIXED 15` | `UNCHANGED` | Preserves each gift level, compensates for strength, or gives supported gifts at level 15. |
| Gift Uniqueness | `ALLOW DUPLICATES`, `UNIQUE GIFTS` | `UNIQUE GIFTS` | Prevents duplicate destinations among supported gifts while candidates remain. |

Generic object-event statics, ghost Marowak, the catching tutorial, and
legendary overworld object sprites remain vanilla in the mod-only release
because the current public API has no safe pre-battle hook for them.

### In-game trades

| Setting | Values | Default | Effect |
|---|---|---|---|
| In-game Trades | `OFF`, `RECEIVED`, `BOTH SIDES` | `BOTH SIDES` | Keeps trades vanilla, randomizes only the received species, or randomizes both the requested and received species. |
| Trade Fairness | `ANY`, `SIMILAR STRENGTH`, `NO DOWNGRADE` | `SIMILAR STRENGTH` | Uses the full eligible pool, applies the strength band, or avoids a received Pokémon more than 5% weaker when possible. |
| Trade Evolution Safety | `OFF`, `ON` | `ON` | Prevents same-species exchanges and requests that cannot be obtained under Catchability Guard. |

The nine NPC-wired trades are generated by stable trade index. Their normal
one-time completion flags, nicknames, OT behavior, and trade flow are retained.

### Celadon Game Corner Prize Exchange

| Setting | Values | Default | Effect |
|---|---|---|---|
| Prize Pokémon | `OFF`, `RANDOMIZED` | `RANDOMIZED` | Randomizes Pokémon prizes for the active game version. TM prizes remain unchanged. |
| Prize Levels | `UNCHANGED`, `FIXED 15`, `SCALED` | `UNCHANGED` | Preserves the slot level, fixes it at 15, or compensates for source/destination strength. |
| Prize Prices | `UNCHANGED`, `BY STRENGTH`, `RANDOM ±25%` | `UNCHANGED` | Preserves coin cost, scales it by base-stat total, or applies a saved ±25% modifier. |

### Trainers

| Setting | Values | Default | Effect |
|---|---|---|---|
| Trainer Pokémon | `OFF`, `GLOBAL MAP`, `BY SLOT`, `TYPE THEMED` | `BY SLOT` | Keeps parties vanilla, consistently maps source species, resolves every party slot independently, or gives each trainer class a saved type theme. Enabled modes avoid self-maps whenever another valid candidate exists. |
| Trainer Levels | `UNCHANGED`, `±10%`, `PROGRESSIVE` | `UNCHANGED` | Preserves levels, applies a saved 90–110% multiplier, or adjusts them by the source party's progression tier. |
| Boss Trainers | `INCLUDE`, `THEMED`, `VANILLA` | `THEMED` | Makes bosses follow the main mode, guarantees a per-boss type theme, or leaves boss parties vanilla. |
| Party Size | `UNCHANGED`, `1–6 RANDOM` | `UNCHANGED` | Preserves party count or generates a saved count, with early-game limits when Progression Guard is on. |
| Progression Guard | `OFF`, `ON` | `ON` | Enforces valid, nonempty required parties and guards the first rival and other early mandatory battles against extreme results. |

### Actions

| Action | Effect |
|---|---|
| Review Next Run | Shows every editable setting and any validation warnings before starting. |
| Reset Defaults | Restores the `STANDARD` preset and clears manual Seed Text after confirmation. |
| Copy Active Seed | Copies the active seed and run code, or displays them when clipboard access is unavailable. |
| View Spoiler Log | Opens an unrestricted Pokémon/map browser. Pokémon mode lists every merged-registry species in Pokédex order, supports partial-name search, and shows obtainable/encounter locations. Displayed location names longer than 16 characters are abbreviated without changing their internal map identity. Wild locations display their method and one combined `PCT`/level line for every distinct level directly in the location list and do not drill down. Static locations identify the encounter inline as `STATIC - <Pokémon>` and also do not drill down. Starter and gift locations display their source plus the current Pokémon and level inline, also without drill-down. Trade locations replace the generic category with the complete numbered offer and current `REQUESTED`/`RECEIVED` Pokémon, also without drill-down. Prize locations replace the generic category with the Game Corner version and slot, current Pokémon, level, and coin cost, also without drill-down. Other locations with one result open it directly; locations with multiple results retain a chooser. Map mode uses the Kanto map, groups relevant buildings and floors, and offers populated categories from `GRASS`, `SURF`, `OLD ROD`, `GOOD ROD`, `SUPER ROD`, `TRAINERS`, `STARTERS`, `STATICS`, `GIFTS`, `TRADES`, and `PRIZES`; empty tabs are omitted per map. Starter and gift tabs show each current Pokémon and level inline and do not open detail screens. Encounter tabs show each Pokémon followed by one combined `PCT` line for every distinct level and do not open a separate detail screen. Each rod has its own tab and per-cast `NO BITE` percentage. The Trades tab displays every numbered offer inline with its requested and received Pokémon and has no detail screen. Trainer rows still open complete parties with levels. Browser entries show only the Pokémon, levels, prices, and offers currently present; original Pokémon and prices are omitted. Bottom control legends are hidden except for `SEARCH:SELECT` on the Pokémon list. Settings are omitted. Available only when that run saved Spoiler Log as `ON`. |
| Export Spoiler Log | Manually writes the same active-run spoiler information without ROM bytes. Available only when that run saved Spoiler Log as `ON`; starting a game never creates the file. Saved at `%APPDATA%\pokemon-love2d\pokemon_randomizer\spoilers`. |

For exact formulas, fallback order, supported encounter IDs, presets, and
validation rules, see the linked design documents above or the
[complete randomizer specification](docs/randomizer-spec.md).

## Compatibility

- gen1recomp engine: `>=0.1.30 <0.2.0` (`0.1.38` recommended)
- mod API: `2`
- randomizer mod version: `0.34.0`
- generator contract: `1`
- algorithm build: `1.4.0-dev`
- hash: `fnv1a32x4-v1`
- PRNG: `xoshiro128ss-v1`
- requested permissions: `filesystem` (spoiler export only)

The engine validates the API and game-version range before executing the mod.
The bootstrap also verifies the mod object's required API-2 surfaces. A failed
check is attributed to this mod and rolled back by gen1recomp's loader.
The disposable `save.created` event emitted before `game.ready` is ignored and
reported once at debug level; only the real New Game event creates mappings.

Catchability Guard uses an explicit Red/Blue progression model. Walking,
Surf-only water, all three rods, Safari access, story gates, Victory Road,
postgame maps, and the availability stage of each supported NPC trade are
evaluated separately. Unknown custom map IDs are excluded from guarantees and
reported in the run diagnostics instead of being assumed reachable.
Fighting Dojo gifts become obtainable with Saffron guard-drink access and do
not require Silph Co. completion.

## Release packaging

Run the following command from PowerShell for a release-qualified archive:

```powershell
tools/release.ps1 -EngineRoot C:\path\to\gen1recomp
```

This single command runs the complete suite, builds the versioned archive
under `dist/`, validates that exact ZIP, extracts it, loads the extracted
payload through the Recomp 0.1.38 ROM-free fixture, and prints its SHA-256.
`tools/package.ps1` remains available for a faster packaging-only development
build.

The packager includes only `README.md`, `manifest.json`, `main.lua`, the
runtime `src/*.lua` modules, and `.modkit/pack.json`. Hidden package metadata
is enumerated explicitly on every operating system, and scaffold validation
accepts native LF or CRLF line endings.

The build fails if an entry uses a backslash, an absolute or traversing path,
a duplicate or case-colliding name, or an unexpected development-only path.
It then verifies every packaged byte count and SHA-256 value against the
ledger and prints the final archive SHA-256. CI performs the same syntax,
test, package-validation, and native-extraction checks on Windows and Linux.

Release ZIPs are generated files: `dist/*.zip` is ignored and no current or
historical archive is kept in normal source history. Published versions
belong in the project’s release-artifact storage.

## Design guarantees

- Gameplay hooks are registered only after deterministic generation exists.
- The only requested permission is `filesystem`, used exclusively for
  user-requested or opt-in plaintext spoiler-log export. No network or
  engine-internals permission is requested.
- Generator request validation does not mutate its input.
- Seed, hash, PRNG, sorting, and shuffle behavior is independent of platform
  bit libraries and table iteration order.
- Every randomizer category can receive a separately derived named stream.
- Twenty-four real combined-generator vectors lock every mapping bucket,
  diagnostics, and complete input identity across Casual, Standard, Chaos,
  and targeted custom runs.
- Bounded properties execute the real generator for every shipped preset and
  verify species, levels, starters, trainer parties, hard filters,
  reachability attribution, uniqueness, canonical round trips, and category
  stream isolation.
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
- The relevant-mod list is frozen at New Game. Continue reports added,
  removed, or version-changed mods without rewriting that original snapshot
  or regenerating mappings.
- Missing or damaged state is quarantined for the session without overwriting
  recovery data.
- Pre-write validation refuses to replace a namespace whose existing checksum
  is invalid.
- Migrations preserve unknown fields and never regenerate mappings.
- Options use the engine's native namespaced persistence and screen registry.
- The Options hook decorates the rows returned by earlier handlers.
- Active-run data is mutation-isolated; edits target only the next New Game.
- Generator, contract, species, save, preferences, and spoiler exports are
  ordinary-assignment read-only facades. Their callbacks are captured and
  mutable return tables are recursively copied, so another mod cannot
  accidentally replace or mutate the implementation retained by the
  randomizer.
- Every public active-run view is a recursive copy, including nested mappings
  and diagnostics.
- Duplicate species metadata merges deterministically: legendary `true` wins
  conflicts, and the most evolved declared stage wins stage conflicts.
  Structured conflict records are available from
  `species.metadataDiagnostics()`.
- Invalid stored preferences fall back to declared defaults.
- Reset defaults requires confirmation and persists as one options write.
- Standard exactly equals the declared default snapshot.
- Presets never overwrite the master switch, seed, or spoiler-log choice.
- Manual seed errors disable generation atomically and remain reviewable.
- Auto seeds mix the available LÖVE timer/PRNG values, runtime clocks, a
  process counter, and save context as best-effort non-cryptographic
  uniqueness material. The hashed result is saved as a deterministic
  26-character Crockford Base32 identity.
- Run codes bind canonical seed, behavior settings, and eligible pool.
- Settings-hash migration never rerolls an existing mapping.
- Clipboard absence cannot hide the seed or run code from the player.
- Sparse or future saved settings display as `UNKNOWN` or `UNAVAILABLE` in
  the Active Run view instead of interrupting the Options screen.
- The canonical randomizer namespace has a 256 KiB budget. Diagnostics record
  both complete namespace bytes and mappings-only bytes; exceeding the budget
  warns without deleting or truncating mappings.
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
- NPC trade replacement delegates to the stock trade command and restores
  the exact merged trade record after every interaction.
- Legendary exclusion remains a hard rule under every trade fairness mode,
  including the Casual preset's No Downgrade setting.
- Game Corner TM rows and active-version prize ordering remain unchanged.
- Unknown or missing game versions retain vanilla Game Corner Pokémon prizes
  and record `PRIZE_VERSION_UNSUPPORTED`; they never silently use Red data.
- A failed mapped Pokemon prize award never consumes coins.
- Oak, rival battles, parcel and Pokédex delivery, and lab movement remain
  engine-owned.
- Three randomized player choices are unique and generated only once.
- Basic Only never silently admits an evolved form.
- Type Triad uses a directional primary-type effectiveness cycle or records
  its deterministic fallback to Random.
- The saved offer drives the preview, confirmation, gift, level, removed
  balls, rival pickup, and all vanilla rival party branches.
- Rival projection copies the prior trainer party and changes only its final
  species; original levels, moves, and party sizes remain intact.
- An out-of-pool trainer source falls back only for its affected saved slot;
  eligible neighboring slots and unrelated trainer classes still randomize.
- Scoped static and gift mappings are generated once and stored with the save.
- Recomp 0.1.38's `pokemon.before_give` event provides an award-time safety
  net, while the scoped fossil-room adapter resolves the mapped name before
  confirmation and resurrection dialogue.
- Static battle flags, object hiding, gift choice flags, payment, party/box
  handling, and retries remain vanilla-compatible.
- All supported static/gift script branches use named jump labels. Magikarp
  payment, gift completion flags, hidden prize objects, and fossil cleanup
  occur only after a successful award, so full party plus full boxes does not
  consume any one-time offer and the player can retry.
- Unsupported static paths remain completely vanilla rather than receiving a
  late or inconsistent species substitution.
- Unsupported engine or mod API versions fail before gameplay.
- Module load failures use the engine's normal attributed rollback behavior.
