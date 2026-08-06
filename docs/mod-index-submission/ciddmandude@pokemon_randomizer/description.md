# Pokemon Gen 1 Randomizer

Pokemon Gen 1 Randomizer creates deterministic, seed-based playthroughs of
Pokemon Red, Blue, and Yellow in Gen1Recomp. It is a mod-only randomizer that
uses the public mod API and does not require a patched or forked engine build.

Every randomized New Game saves its seed, complete settings snapshot,
compatibility information, and resolved mappings with the save file. Reloading
or switching saves restores that run exactly without rerolling content or
requiring an application restart. Options changed later apply to the next New
Game and cannot silently alter an existing run.

## What it randomizes

- Walking, surfing, and fishing encounters, with separate Old Rod, Good Rod,
  and Super Rod results.
- The three Red/Blue starters or Yellow's player Pikachu and rival Eevee pair.
- Regular trainers, rival teams, Gym Leaders, the Elite Four, and Champion.
- Supported static encounters, including the legendary birds, Mewtwo, both
  Snorlax encounters, and the Power Plant item-ball Pokemon.
- Gift Pokemon, including fossils, the Fighting Dojo choices, Eevee, Lapras,
  the Magikarp seller, and supported Yellow-exclusive gifts.
- Both sides of supported in-game trades.
- Pokemon prizes, levels, and optional prices at the Celadon Game Corner.
- Visible items, hidden items, TMs, HMs, key items, badges, scripted rewards,
  shop inventories, vending machines, and Game Corner TM prizes.
- Pokemon base stats, types, starting moves, level-up learnsets, learning
  levels, and TM/HM compatibility.
- Evolution destinations and trade-evolution methods.
- Move types, power, accuracy, and PP while preserving move effects and other
  special behavior.

## Settings and safeguards

Before Oak's first line, each New Game asks whether to enable the randomizer.
Players can start with a built-in or player-saved preset, or open the complete
custom settings screen. The same next-run preferences are available from the
main Options menu.

Casual, Standard, and Chaos provide quick starting points. Up to eight custom
presets can be named, saved, loaded, overwritten, and deleted in game. Saved
presets include automatic or manual seed options, spoiler access, and every
randomization category. The built-in presets intentionally leave item and
Pokemon-mechanics randomization vanilla so those larger changes remain opt-in.

The available controls include:

- Vanilla-151 or merged-content species pools, legendary rules, duplicate
  handling, and similar-strength or same-original-stage matching.
- Global or per-area wild mappings, fishing, level adjustment, and Pokemon
  Coverage.
- Starter, gift, static, trade, Game Corner, trainer, boss, and rival options,
  including rival team continuity and themed parties.
- Closed-category shuffles or mixed item placement for non-key items, TMs,
  HMs, key items, badges, and hidden checks.
- Progression Safety for enabled progression-item pools, plus randomized or
  cheap shops. Turning safety off permits unrestricted and potentially
  unbeatable placements.
- Stat shuffling, total-preserving redistribution, or fully random 1-255 base
  stats, with optional evolution-family consistency.
- Shuffled or randomized Pokemon types, randomized or type-aware learnsets,
  early damaging-move protection, learning-level shuffling, and TM/HM
  compatibility shuffling.
- Stage-aware, strength-aware, or fully random evolution destinations,
  duplicate control, cycle protection, and optional conversion of trade
  evolutions to level-based evolutions.
- Shuffled or randomized move types and configurable move-data randomization.
  Move effects, fixed-damage behavior, multi-hit rules, priority, charge
  behavior, critical flags, and animations remain intact.

Pokemon Coverage attempts to place every eligible non-legendary species
somewhere obtainable before the Elite Four. Trainer Safety protects required
and early battles from invalid or excessively extreme parties. Progression
Safety constrains enabled progression items to reachable locations and falls
back safely when a valid placement cannot be proven. Encounter rates, encounter
slot probabilities, normal Repel behavior, and unchanged move effects remain
vanilla.

## Spoiler log

When spoiler access is enabled for a run, `SPOILER` appears in the Start menu
and the viewer is also available from Options. The in-game browser provides:

- A searchable Pokedex-order Pokemon list showing current evolutions and every
  obtainable location.
- A searchable item list showing current field, hidden, scripted, Gym, shop,
  vending, PC, and Game Corner locations and prices.
- A selectable Kanto map with relevant floors and buildings, separate encounter
  tabs, per-level percentages, rod no-bite odds, complete trainer parties,
  starters, gifts, statics, trades, prizes, and items.

The browser shows what is present in the current run rather than repeating the
original vanilla values. A complete plaintext spoiler, including settings, can
be exported manually to
`%APPDATA%\pokemon-love2d\pokemon_randomizer\spoilers`. The mod requests
filesystem permission only for this explicit export and never creates a
spoiler file automatically when a game starts.

## Compatibility and limitations

- Requires Gen1Recomp mod API 2.
- Pokemon Yellow requires Gen1Recomp 0.1.45 or newer.
- Supports Red, Blue, and Yellow ROM imports.
- Does not modify the user's ROM or Gen1Recomp installation.
- Linked players should use matching randomizer versions, seeds, settings, and
  content pools because randomized gameplay affects the link fingerprint.

Some encounters remain vanilla because the public mod API does not currently
provide a safe pre-battle hook for them. These include generic object-event
static Pokemon, the Pokemon Tower ghost Marowak, and the catching tutorial.
Overworld sprites for randomized legendary encounters also remain unchanged.

## Installation

1. Install a supported version of
   [Gen1Recomp](https://github.com/bryanthaboi/gen1recomp) and import a supported
   Pokemon Red, Blue, or Yellow ROM.
2. Download `pokemon_randomizer-<version>.zip` from the mod's
   [GitHub Releases](https://github.com/ciddmandude/PokemonRecompRandomizer/releases).
3. Open Gen1Recomp's mod manager (`F10`) and import the downloaded ZIP.
4. Enable **Pokemon Gen 1 Randomizer**.
5. Start a New Game, choose whether to enable randomization, and select a preset
   or configure custom settings before Oak's introduction continues.

Use the versioned `pokemon_randomizer-<version>.zip` release asset. GitHub's
automatically generated **Source code** ZIP and TAR archives are not installable
mod packages.

## Credits

- Randomizer design and development: **ciddmandude**
- [Gen1Recomp](https://github.com/bryanthaboi/gen1recomp): **bryanthaboi** and
  its contributors
- Thanks to the Gen1Recomp community and everyone who tested the mod and
  reported issues.

Pokemon and all related trademarks belong to their respective owners. This is
an unofficial, fan-made mod and is not affiliated with or endorsed by Nintendo,
Creatures Inc., or GAME FREAK inc.

Source code, releases, documentation, and issue tracking are available at
[github.com/ciddmandude/PokemonRecompRandomizer](https://github.com/ciddmandude/PokemonRecompRandomizer).
