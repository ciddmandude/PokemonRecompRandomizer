# Pokemon Gen 1 Randomizer

Pokemon Gen 1 Randomizer creates deterministic, seed-based playthroughs of
Pokemon Red, Blue, and Yellow in Gen1Recomp. Each new game stores its seed,
settings, compatibility information, and generated mappings in that save, so
continuing the game does not reroll the run.

## Randomized content

- Walking, surfing, and fishing encounters, with separate settings for each
  method and safeguards for early progression.
- Red/Blue starter choices and Yellow's Pikachu/Eevee starter sequence.
- Regular trainers, rival teams, Gym Leaders, the Elite Four, and Champion.
- Supported static encounters and gift Pokemon, including Yellow-exclusive
  gifts.
- In-game trades and Celadon Game Corner Pokemon prizes.

The options menu provides presets and detailed controls for pools, legendary
Pokemon, duplicate policy, similar-strength matching, evolutionary stage,
levels, rival continuity, catchability safeguards, and spoiler availability.

## Spoilers and saves

When enabled for a run, the in-game spoiler browser can be searched by Pokemon
or explored through the Kanto map. A text spoiler can also be exported
manually. The mod requests filesystem permission only for that explicit text
export; it does not export a spoiler automatically when a game begins.

Randomizer settings are locked into each save. Changing Options affects the
next New Game and does not silently alter an existing run.

## Compatibility

- Gen1Recomp mod API 2.
- Engine versions `>=0.1.30 <0.2.0`.
- Pokemon Yellow support requires Gen1Recomp 0.1.45 or newer.
- The mod uses public mod APIs and does not require a forked engine build.
- Because randomized gameplay changes the link fingerprint, linked players
  should use matching mod versions, seeds, settings, and content pools.

## Installation

Download `pokemon_randomizer-<version>.zip` from the GitHub Release and import
the ZIP through Gen1Recomp's mod manager. Do not use GitHub's automatically
generated source-code archives as the installable mod.

Source, releases, documentation, and issue tracking are available at
[github.com/ciddmandude/PokemonRecompRandomizer](https://github.com/ciddmandude/PokemonRecompRandomizer).
