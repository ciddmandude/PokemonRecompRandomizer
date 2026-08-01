# Pokemon Gen 1 Randomizer

Pokemon Gen 1 Randomizer creates deterministic, seed-based playthroughs of
Pokemon Red, Blue, and Yellow in Gen1Recomp. It is a mod-only randomizer and
does not require a patched or forked engine build.

Each New Game generates its results once and stores the seed, settings,
compatibility information, and resolved mappings in the save file. Reloading
the game therefore preserves the same run instead of rerolling its content.
Settings changed later in the Options menu apply to the next New Game, not an
existing save.

## What it randomizes

- Walking, surfing, and fishing encounters, including separate Old Rod, Good
  Rod, and Super Rod results.
- The three selectable starters in Red and Blue, or the player Pikachu and
  rival Eevee sequence in Yellow.
- Regular trainers, rival teams, Gym Leaders, the Elite Four, and Champion.
- Supported static encounters, including the legendary birds, Mewtwo, both
  Snorlax encounters, and the Power Plant item-ball Pokemon.
- Gift Pokemon, including fossils, the Fighting Dojo choices, Eevee, Lapras,
  the Magikarp seller, and supported Yellow-exclusive gifts.
- Both sides of supported in-game trades.
- Pokemon prizes, levels, and optional prices at the Celadon Game Corner Prize
  Exchange. TM prizes are not changed.
- Non-key visible item balls and hidden items. Key items, scripted gifts, Gym
  rewards, and shop inventories remain unchanged.

## Settings and safeguards

The Randomizer menu is available from the game's Options menu. Casual,
Standard, and Chaos presets provide quick starting points, while Custom mode
allows each category to be configured individually. Players can save up to
eight named presets directly in the game; saved presets include both seed
options and every next-run setting except the Randomizer master switch.

Options include the species pool, legendary handling, duplicate policy,
similar-strength or same-evolution-stage matching, level adjustment, boss and
rival behavior, rival team continuity, starter selection, gift and trade
rules, Pokémon Coverage, Trainer Safety, and spoiler availability. Every
randomization category can also be disabled independently.

Pokémon Coverage attempts to keep non-legendary randomized species obtainable
through normal Kanto progression. Trainer Safety protects required and
early-game battles from invalid or excessively extreme generated parties.
Encounter rates, encounter-slot probability buckets, and normal Repel behavior
remain unchanged.

## Spoiler log

When spoilers are enabled for a run, the in-game spoiler browser can be
searched by Pokemon or explored by location on the Kanto map. It displays wild
encounters by method and level, complete trainer parties, starters, static and
gift Pokemon, trades, and Game Corner prizes.

A plaintext spoiler log can also be exported manually. The mod requests
filesystem permission only for this explicit export and never writes a spoiler
file automatically when a game begins.

## Compatibility

- Requires Gen1Recomp mod API 2.
- Pokemon Yellow requires Gen1Recomp 0.1.45 or newer.
- Supports Red, Blue, and Yellow ROM imports.
- Uses public mod APIs and does not modify the user's engine installation.
- Linked players should use matching mod versions, seeds, settings, and content
  pools because randomized gameplay affects the link fingerprint.

Some encounters remain vanilla because the current public mod API does not
provide a safe pre-battle hook for them. These include generic object-event
static Pokemon, the Pokemon Tower ghost Marowak, and the catching tutorial.
Overworld sprites for randomized legendary encounters also remain unchanged.

## Installation

1. Install a supported version of
   [Gen1Recomp](https://github.com/bryanthaboi/gen1recomp) and import a supported
   Pokemon Red, Blue, or Yellow ROM.
2. Download `pokemon_randomizer-<version>.zip` from the mod's
   [GitHub Releases](https://github.com/ciddmandude/PokemonRecompRandomizer/releases).
3. Open Gen1Recomp's mod manager and import the downloaded ZIP.
4. Enable **Pokemon Gen 1 Randomizer**.
5. Open **Options > Randomizer**, choose the settings for the next run, and
   start a New Game.

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
