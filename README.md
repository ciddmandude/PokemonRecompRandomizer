# Pokémon Gen 1 Recomp Randomizer

A deterministic, per-save randomizer for
[Pokémon Gen 1 Recomp](https://github.com/bryanthaboi/gen1recomp).
Red, Blue, and Yellow ROM imports are supported. Yellow support requires
gen1recomp 0.1.45 or newer.

## Settings

The Randomizer screen is opened from the main Options menu. These values are
preferences for the **next** New Game: starting a game validates the settings
and saves a snapshot with that run. Changing the Options menu later does not
reroll an existing save.

Before Oak's first introduction line, every New Game asks whether to enable
the randomizer. Choosing `NO` starts vanilla. Choosing `YES` asks whether to
load a preset. The preset picker includes the built-in and player-saved
presets and then starts immediately. Choosing custom settings opens a trimmed
setup screen; B confirms the run, while Save Preset, Delete Preset, and Reset
Defaults remain available.

### General

| Setting | Values | Default | Effect |
|---|---|---|---|
| Preset | `CUSTOM`, `CASUAL`, `STANDARD`, `CHAOS`, saved names | `STANDARD` | Applies a built-in bundle or a player-saved preset. Saved presets include Seed Mode, Seed Text, spoiler access, and every category option. Editing a value captured by an active saved preset changes this to `CUSTOM`. |
| Seed Mode | `AUTO`, `MANUAL` | `AUTO` | `AUTO` creates a new 128-bit seed; `MANUAL` uses Seed Text. |
| Seed Text | 1–32 characters | blank | Manual seed using letters, digits, spaces, hyphens, or underscores. It is trimmed, uppercased, and saved in canonical form. |
| Species Pool | `VANILLA 151`, `MERGED DATA` | `VANILLA 151` | Uses only the original 151, or all valid species contributed through the merged registry. |
| Similar Strength | `OFF`, `±10%`, `±20%`, `BST ±50`, `BST ±100`, `SAME STAGE` | `±20%` | Percentage modes use a relative BST band. `BST ±50` and `BST ±100` use an absolute five-stat-total difference. Empty BST bands widen deterministically. `SAME STAGE` ignores base stats and requires matching evolutionary stages. |
| Legendaries | `EXCLUDE`, `MATCH`, `ALLOW` | `MATCH` | Excludes legendaries, maps legendary status like-for-like, or treats them like any species. |
| Duplicate Policy | `ALLOW`, `ONE-TO-ONE` | `ONE-TO-ONE` | Samples with replacement or maximizes unique destinations until the eligible pool is exhausted. |
| Enable Spoiler Log | `OFF`, `ON` | `ON` | Saved with the new run. `ON` allows the in-game viewer and manual file export; `OFF` blocks both. Starting a game never exports a file automatically. It does not affect the seed or mappings. |

### Wild Pokémon

| Setting | Values | Default | Effect |
|---|---|---|---|
| Wild Pokémon | `OFF`, `GLOBAL MAP`, `AREA SLOTS` | `GLOBAL MAP` | Leaves encounters vanilla, consistently maps each source species everywhere, or randomizes each map/terrain/slot independently. |
| Fishing | `VANILLA`, `RANDOMIZED` | `RANDOMIZED` | Controls Old, Good, and Super Rod encounters separately from walking and surfing. |
| Wild Levels | `UNCHANGED`, `±2`, `SCALED` | `UNCHANGED` | Preserves levels, applies a saved -2 to +2 offset, or compensates for source/destination strength. |
| Pokémon Coverage | `OFF`, `ON` | `ON` | When mathematically possible, ensures every non-legendary destination is reachable before the Elite Four. |

Encounter rates, slot probability buckets, and Repel behavior remain vanilla.

### Starters

| Setting | Values | Default | Effect |
|---|---|---|---|
| Starters | `OFF`, `RANDOM`, `TYPE TRIAD` | `RANDOM` | In Red/Blue, keeps or replaces the original trio. In Yellow, `OFF` keeps Pikachu and Eevee; either enabled mode replaces the forced Pikachu and the rival's Eevee with two distinct saved species. `TYPE TRIAD` uses a triad as its candidate basis where possible. |
| Starter Stage | `ANY`, `BASIC ONLY` | `BASIC ONLY` | Allows any eligible species or only species without a pre-evolution. |
| Starter Level | `2`–`20` | `5` | Sets the level shown in Oak's Lab and the level of the received starter. |
| Rival Counterpick | `BALL ORDER`, `TYPE ADVANTAGE`, `RANDOM OTHER` | `TYPE ADVANTAGE` | Uses the vanilla ball relationship, strongest matchup, or another starter. In Yellow, `TYPE ADVANTAGE` chooses the strongest eligible rival matchup; the other modes choose a distinct saved rival species. |

When Yellow's randomized starter is not Pikachu, the engine's Pikachu-only
follower does not appear. Melanie's Bulbasaur gift no longer requires Pikachu
happiness for that run, so starter randomization cannot make it unobtainable.

### Static encounters and gifts

| Setting | Values | Default | Effect |
|---|---|---|---|
| Static Pokémon | `OFF`, `RANDOMIZED` | `RANDOMIZED` | Randomizes the supported named encounters: the eight Power Plant balls, legendary birds, Mewtwo, and both Snorlax. |
| Static Levels | `UNCHANGED`, `SCALED`, `RANDOM ±5` | `UNCHANGED` | Preserves levels, compensates for strength, or applies a saved -5 to +5 offset. |
| Gift Pokémon | `OFF`, `RANDOMIZED` | `RANDOMIZED` | Randomizes Celadon Eevee, Silph Lapras, both Fighting Dojo prizes, the Route 4 Magikarp seller, and all three Cinnabar fossil restorations. Yellow also includes Melanie's Bulbasaur, Damian's Charmander, and Officer Jenny's Squirtle. |
| Gift Levels | `UNCHANGED`, `SCALED`, `FIXED 15` | `UNCHANGED` | Preserves each gift level, compensates for strength, or gives supported gifts at level 15. |
| Gift Uniqueness | `ALLOW DUPLICATES`, `UNIQUE GIFTS` | `UNIQUE GIFTS` | Prevents duplicate destinations among supported gifts while candidates remain. |

Generic object-event statics, ghost Marowak, the catching tutorial, and
legendary overworld object sprites remain vanilla in the mod-only release
because the current public API has no safe pre-battle hook for them.

### In-game trades

| Setting | Values | Default | Effect |
|---|---|---|---|
| In-game Trades | `OFF`, `RECEIVED`, `BOTH SIDES` | `BOTH SIDES` | Keeps trades vanilla, randomizes only the received species, or randomizes both the requested and received species. |
| Trade Fairness | `ANY`, `SIMILAR STRENGTH`, `NO DOWNGRADE` | `SIMILAR STRENGTH` | Uses the full eligible pool, applies the selected global strength/stage rule, or avoids a received Pokémon more than 5% weaker when possible. |
| Trade Validity | `OFF`, `ON` | `ON` | Prevents same-species exchanges and requests that cannot be obtained under Pokémon Coverage. |

The nine NPC-wired trades are generated by stable trade index using the
active Red/Blue or Yellow trade table. Their normal
one-time completion flags, nicknames, OT behavior, and trade flow are retained.

### Celadon Game Corner Prize Exchange

| Setting | Values | Default | Effect |
|---|---|---|---|
| Prize Pokémon | `OFF`, `RANDOMIZED` | `RANDOMIZED` | Randomizes Pokémon prizes for the active game version. TM prizes remain unchanged. |
| Prize Levels | `UNCHANGED`, `FIXED 15`, `SCALED` | `UNCHANGED` | Preserves the slot level, fixes it at 15, or compensates for source/destination strength. |
| Prize Prices | `UNCHANGED`, `BY STRENGTH`, `RANDOM ±25%` | `UNCHANGED` | Preserves coin cost, scales it by base-stat total, or applies a saved ±25% modifier. |

### Items and shops

| Setting | Values | Default | Effect |
|---|---|---|---|
| Non-key Location | `VANILLA`, `SHUFFLED`, `MIXED` | `VANILLA` | Keeps ordinary items in place, shuffles ordinary checks as a closed pool, or combines them with every other item category set to `MIXED`. Both ordinary and safety-constrained mixed placement avoid leaving an original item at its own check whenever the pool permits it. |
| TM Location | `VANILLA`, `SHUFFLED`, `MIXED` | `VANILLA` | Keeps TMs in place, shuffles only TM checks, or joins TMs and supported one-time checks in the mixed pool. Randomized shops may also stock TMs when this is not `VANILLA`. |
| HM Location | `VANILLA`, `SHUFFLED`, `MIXED` | `VANILLA` | Keeps HMs in place, shuffles only HM checks, or joins them to the mixed pool. HMs are never sold in shops. |
| Key Item Location | `VANILLA`, `SHUFFLED`, `MIXED` | `VANILLA` | Keeps key items in place, shuffles only key-item checks, or joins supported key items to the mixed pool. |
| Badge Location | `VANILLA`, `SHUFFLED`, `MIXED` | `VANILLA` | Keeps badges with their Gym Leaders, shuffles them among Gym rewards, or joins badges to the mixed one-time-check pool. Repeatable shops and mutually exclusive fossil choices are excluded. |
| Hidden Items | `VANILLA`, `SHUFFLED`, `MIXED` | `VANILLA` | Keeps hidden checks untouched and out of every other pool, shuffles all hidden checks as a closed pool, or lets them exchange items with supported visible and scripted checks. |
| Progression Safety | `OFF`, `ON` | `ON` | Independently constrains enabled progression-item pools to reachable stages. Postgame and unknown-map checks remain vanilla instead of invalidating the reachable mixed pool. If safety cannot be proven for that reachable pool, it remains vanilla and a diagnostic is recorded. `OFF` honors unrestricted deterministic placement and may produce an unbeatable seed. |
| Shops | `VANILLA`, `RANDOMIZED` | `VANILLA` | Randomizes Poké Marts, Celadon Department Store counters, vending machines, and Game Corner TM prizes. Game Corner Pokémon remain controlled by Prize Pokémon. |
| Shop Prices | `VANILLA`, `RANDOM`, `CHEAP` | `VANILLA` | Uses normal slot/special-shop pricing, deterministic prices from ¥100–¥5000 (or the equivalent coin value), or a price of 100. This setting has no effect while Shops is vanilla. |

All item and badge mappings are generated from the seed, saved with the run, and restored
when the save is loaded. Each built-in preset leaves every item category and
Shops vanilla. Fixed gifts implemented with the engine's `give_item` command show
the randomized item immediately. A small number of direct-function rewards
retain their vanilla dialogue, then exchange the awarded inventory item for
the saved randomized result when the dialogue finishes.

### Trainers

| Setting | Values | Default | Effect |
|---|---|---|---|
| Trainer Pokémon | `OFF`, `GLOBAL MAP`, `BY SLOT`, `TYPE THEMED` | `BY SLOT` | Keeps parties vanilla, consistently maps source species, resolves every party slot independently, or gives each trainer class a saved type theme. Enabled modes avoid self-maps whenever another valid candidate exists. |
| Trainer Levels | `UNCHANGED`, `±10%`, `PROGRESSIVE` | `UNCHANGED` | Preserves levels, applies a saved 90–110% multiplier, or adjusts them by the source party's progression tier. |
| Boss Trainers | `INCLUDE`, `THEMED`, `VANILLA` | `THEMED` | Makes Gym Leaders and Elite Four members follow the main mode, guarantees a per-boss type theme, or leaves boss parties vanilla. |
| Rival Pokémon | `INCLUDE`, `THEMED`, `VANILLA` | `INCLUDE` | Makes rival battles follow Trainer Pokémon, use a rival-specific type theme, or preserve vanilla non-starter party members. |
| Rival Keep Pokémon | `NO`, `YES` | `YES` | `YES` assigns recurring rival slots randomized evolution families, advances them when their vanilla counterparts evolve, and removes/adds slots on the vanilla schedule. `NO` independently randomizes every later rival party, including the starter slot after Oak's Lab. |
| Party Size | `UNCHANGED`, `1–6 RANDOM` | `UNCHANGED` | Preserves party count or generates a saved count, with early-game limits when Trainer Safety is on. |
| Trainer Safety | `OFF`, `ON` | `ON` | Enforces valid, nonempty required parties and guards the first rival and other early mandatory battles against extreme results. |

### Pokemon data and learned moves

All settings in this section default to vanilla in `CASUAL`, `STANDARD`, and
`CHAOS`. They affect only a newly created save. The generated definitions are
stored with that save and restored when a different save is loaded.

| Setting | Values | Default | Effect |
|---|---|---|---|
| Base Stats | `VANILLA`, `SHUFFLED`, `REDISTRIBUTE`, `FULL RANDOM` | `VANILLA` | `SHUFFLED` permutes each species' five existing values. `REDISTRIBUTE` creates a new spread while preserving that species' exact five-stat total. `FULL RANDOM` rolls HP, Attack, Defense, Speed, and Special independently from 1 through 255. |
| Family Stats | `OFF`, `ON` | `ON` | Reuses a deterministic stat shape or permutation through an evolution family. Full Random still rolls every included stat independently. |
| Pokemon Types | `VANILLA`, `SHUFFLED`, `RANDOMIZED` | `VANILLA` | `SHUFFLED` applies a global one-to-one type permutation. `RANDOMIZED` generates one or two valid merged-registry types per species. |
| Family Types | `OFF`, `ON` | `ON` | Evolution families retain the generated primary type. An evolution may gain a secondary type or replace its existing secondary type. |
| Movesets | `VANILLA`, `RANDOMIZED`, `TYPE-AWARE`, `FULL RANDOM` | `VANILLA` | Randomizes starting moves and level-up move IDs while preserving entry counts. `RANDOMIZED` uses moves present in source species learnsets, `TYPE-AWARE` prefers moves matching either final Pokemon type, and `FULL RANDOM` uses every eligible registered move. |
| Early Damage | `OFF`, `ON` | `ON` | When Movesets is enabled, guarantees an ordinary damaging move by level 5 whenever the merged move pool contains one. OHKO, fixed-damage, conditional, and self-KO moves do not satisfy the guard. |
| Learn Levels | `VANILLA`, `SHUFFLED` | `VANILLA` | Keeps the original learning levels or shuffles those levels within each species and sorts the final learnset. |
| TM/HM Compatibility | `VANILLA`, `SHUFFLED` | `VANILLA` | Shuffles each machine's compatibility column across the species pool, preserving how many species can learn each TM or HM. TM and HM item locations remain separate settings. |

### Evolutions

| Setting | Values | Default | Effect |
|---|---|---|---|
| Evolutions | `VANILLA`, `KEEP STAGES`, `SIMILAR`, `FULL RANDOM` | `VANILLA` | Keeps vanilla destinations, replaces each destination with a species at the original destination's evolutionary stage, follows the global Similar Strength rule, or uses any eligible species. Every mode preserves which species evolve, branch counts, and the original trigger until Trade Evolutions converts it. |
| Evolution Repeats | `AVOID`, `ALLOW` | `AVOID` | Avoids reusing a destination across the generated graph until the pool is exhausted. Separate branches from one species are always distinct. |
| Trade Evolutions | `VANILLA`, `LEVEL 37`, `RANDOM 30-40` | `VANILLA` | Keeps trade triggers or converts them to level evolutions. This works independently, so vanilla evolution families can be retained while making trade evolutions obtainable without trading. |

Randomized graphs cannot contain self-evolutions or directed cycles. Hard graph
rules are never relaxed. If a complete graph cannot satisfy destination
uniqueness or the selected stage/strength preference, uniqueness is relaxed
first, followed by the soft preference. A graph that still cannot be completed
falls back atomically to vanilla and records a diagnostic.

### Move data

Move effects and special behavior are always preserved. The mod changes only
type, ordinary power, ordinary accuracy, and PP.

| Setting | Values | Default | Effect |
|---|---|---|---|
| Move Types | `VANILLA`, `SHUFFLED`, `RANDOMIZED` | `VANILLA` | Keeps types, globally permutes type IDs, or independently assigns a valid type to each move. |
| Move Data | `VANILLA`, `SHUFFLED`, `BALANCED`, `FULL RANDOM` | `VANILLA` | Shuffles compatible numeric fields; generates bounded power, accuracy, and PP; or rolls ordinary power 1-255, accuracy 1-100, and PP 1-64. Status moves remain non-damaging. |
| Move Safety | `OFF`, `ON` | `ON` | Protects special-damage and effect-defined moves and limits extreme high-power combinations. Effects, fixed damage, multi-hit rules, priority, critical flags, charge behavior, and animations are never randomized. |

### Actions

| Action | Effect |
|---|---|
| Review Next Run | Shows every editable setting and any validation warnings before starting. |
| Reset Defaults | Restores the `STANDARD` preset and clears manual Seed Text after confirmation. |
| Copy Active Seed | Copies the active seed and run code, or displays them when clipboard access is unavailable. |
| View Spoiler Log | Opens an unrestricted Pokémon/items/map browser. An eligible run also adds `SPOILER` immediately before `MODS` in the Start menu; B returns to that menu. Pokémon mode lists every merged-registry species in Pokédex order, then shows that species' current evolutions and triggers before its obtainable locations. Species without an evolution show `NONE`. Items mode alphabetically lists every merged item, supports partial-name search, and shows every current item ball, hidden pickup, PC item, scripted or Gym reward, mart slot, vending slot, and Game Corner TM prize with its source type and applicable price. Item locations are inline and have no additional drill-down. Map mode uses the Kanto map and omits empty tabs; its `ITEMS` tab uses the same complete current placement index. Encounter methods use separate tabs with combined `PCT`/level lines and rod `NO BITE` odds. Trades render complete offers inline; trainer rows open complete parties. Browser entries show only current results, never original randomized values. Bottom legends are hidden except for `SEARCH:SELECT` on the Pokémon and item lists. Settings are omitted. Both access paths are available only when the active run saved Spoiler Log as `ON`. |
| Export Spoiler Log | Manually writes the same active-run spoiler information without ROM bytes. Available only when that run saved Spoiler Log as `ON`; starting a game never creates the file. Saved at `%APPDATA%\pokemon-love2d\pokemon_randomizer\spoilers`. |
| Save Preset | Names and saves the current next-run options. Up to eight presets with unique 1–16 character names may be stored. Saving an existing name asks before overwriting it. |
| Delete Preset | Selects a saved preset and asks for confirmation before deleting it. Built-in presets cannot be deleted. |

For exact formulas, fallback order, supported encounter IDs, presets, and
validation rules, see the linked design documents above or the
[complete randomizer specification](docs/randomizer-spec.md).

## Compatibility

- gen1recomp `0.1.45+` is required for Yellow
- mod API: `2`
- randomizer mod version: `0.46.0`
- generator contract: `1`
- algorithm build: `1.17.0-dev`
- hash: `fnv1a32x4-v1`
- PRNG: `xoshiro128ss-v1`
- requested permissions: `filesystem` (spoiler export only)

The engine validates the API and game-version range before executing the mod.
The bootstrap also verifies the mod object's required API-2 surfaces. A failed
check is attributed to this mod and rolled back by gen1recomp's loader.
The disposable `save.created` event emitted before `game.ready` is ignored and
reported once at debug level; only the real New Game event creates mappings.

Pokémon Coverage uses an explicit Red/Blue/Yellow Kanto progression model. Walking,
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
payload through the Recomp 0.1.45 ROM-free fixture, and prints its SHA-256.
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
- Enabled field-item categories are shuffled as closed multisets. Supported
  scripted gifts and Gym TMs participate; SAFE HM/key-item modes constrain
  progression placements, and randomized shops never stock HMs.
- Loading or switching saves restores the merged baseline before applying that
  save's item placements, so saving and continuing require no application
  restart.
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
- Same Stage and absolute BST ranges remain enforced during catchability and
  trade-reachability repair swaps.
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
- Built-in presets preserve the seed options. Player-saved presets include
  both seed options. Selecting `CASUAL`, `STANDARD`, or `CHAOS` enables the
  spoiler log.
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
- Rival Pokémon is controlled independently from Gym Leaders and the Elite
  Four. The first Oak's Lab battle always uses the selected counterpick.
- With Rival Keep Pokémon on, each recurring vanilla team identity receives
  one randomized evolution family, evolves when its vanilla counterpart does,
  and follows the vanilla add/remove schedule. The selected starter follows
  the same evolution timing.
- With Rival Keep Pokémon off, every later rival slot is independently
  resolved by the selected Rival Pokémon mode.
- An out-of-pool trainer source falls back only for its affected saved slot;
  eligible neighboring slots and unrelated trainer classes still randomize.
- Scoped static and gift mappings are generated once and stored with the save.
- Recomp 0.1.45's `pokemon.before_give` event provides an award-time safety
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
