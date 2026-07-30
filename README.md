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
| Race Mode | `OFF`, `ON` | `OFF` | Locks spoiler access, hides mapping details, and records race state in the run code. This is a local race aid, not tamper-proof anti-cheat. |
| Spoiler Unlock | `HALL OF FAME`, `CREDITS`, `PASSPHRASE`, `NEVER` | `HALL OF FAME` | Selects when spoilers for a Race Mode save become available. |

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
| Export Spoiler Log | Writes seed, hashes, settings, and mappings without ROM bytes. Locked Race Mode saves cannot export plaintext. Saved at %APPDATA%\pokemon-love2d\pokemon_randomizer\spoilers |
| Unlock Spoilers | Verifies the organizer passphrase for a Race Mode save configured to use `PASSPHRASE`. |

For exact formulas, fallback order, supported encounter IDs, presets, and race
validation rules, see the linked design documents above or the
[complete randomizer specification](docs/randomizer-spec.md).

## Compatibility

- gen1recomp engine: `>=0.1.30 <0.2.0` (`0.1.38` recommended)
- mod API: `2`
- randomizer mod version: `0.16.0`
- generator contract: `1`
- algorithm build: `1.0.0-dev`
- hash: `fnv1a32x4-v1`
- PRNG: `xoshiro128ss-v1`
- requested permissions: `filesystem` (spoiler export only)

The engine validates the API and game-version range before executing the mod.
The bootstrap also verifies the mod object's required API-2 surfaces. A failed
check is attributed to this mod and rolled back by gen1recomp's loader.

## Release packaging

Run `tools/package.ps1` from PowerShell to build the versioned archive under
`dist/`. The packager includes only `README.md`, `manifest.json`, `main.lua`,
the runtime `src/*.lua` modules, and `.modkit/pack.json`.

The build fails if an entry uses a backslash, an absolute or traversing path,
a duplicate or case-colliding name, or an unexpected development-only path.
It then verifies every packaged byte count and SHA-256 value against the
ledger and prints the final archive SHA-256. Release qualification loads that
exact archive against the Recomp 0.1.38 ROM-free fixture. The packaging
workflow also builds and natively extracts the archive on Windows and Linux.

## Design guarantees

- Gameplay hooks are registered only after deterministic generation exists.
- No network, filesystem, or engine-internals permission is requested.
- Generator request validation does not mutate its input.
- Seed, hash, PRNG, sorting, and shuffle behavior is independent of platform
  bit libraries and table iteration order.
- Every randomizer category can receive a separately derived named stream.
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
- Missing or damaged state is quarantined for the session without overwriting
  recovery data.
- Pre-write validation refuses to replace a namespace whose existing checksum
  is invalid.
- Migrations preserve unknown fields and never regenerate mappings.
- Options use the engine's native namespaced persistence and screen registry.
- The Options hook decorates the rows returned by earlier handlers.
- Active-run data is read-only; edits target only the next New Game.
- Invalid stored preferences fall back to declared defaults.
- Reset defaults requires confirmation and persists as one options write.
- Standard exactly equals the declared default snapshot.
- Presets never overwrite master, seed, or race choices.
- Manual seed errors disable generation atomically and remain reviewable.
- Auto seeds are saved as deterministic 128-bit Crockford Base32 identities.
- Run codes bind canonical seed, behavior settings, and eligible pool.
- Settings-hash migration never rerolls an existing mapping.
- Clipboard absence cannot hide the seed or run code from the player.
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
- Game Corner TM rows and active-version prize ordering remain unchanged.
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
- Scoped static and gift mappings are generated once and stored with the save.
- Recomp 0.1.38's `pokemon.before_give` event provides an award-time safety
  net, while the scoped fossil-room adapter resolves the mapped name before
  confirmation and resurrection dialogue.
- Static battle flags, object hiding, gift choice flags, payment, party/box
  handling, and retries remain vanilla-compatible.
- Magikarp payment and gift completion flags occur only after a successful
  award, so full storage does not consume the offer.
- Unsupported static paths remain completely vanilla rather than receiving a
  late or inconsistent species substitution.
- Unsupported engine or mod API versions fail before gameplay.
- Module load failures use the engine's normal attributed rollback behavior.
