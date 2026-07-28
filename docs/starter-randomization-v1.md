# Starter Randomization v1

Milestone 10 generates all starter choices once during New Game and stores
them inside the checksummed randomizer namespace in the same save file as
player progress. Loading, inspecting, declining, or retrying a ball never
draws random numbers.

## Settings

### Starters

- `OFF` leaves the complete vanilla Oak's Lab flow unchanged.
- `RANDOM` chooses three unique species from the eligible starter pool.
- `TYPE TRIAD` chooses three unique species whose primary types form a
  directional cycle: left is super-effective against middle, middle against
  right, and right against left. If no such cycle exists, generation uses the
  `RANDOM` algorithm and records `STARTER_TRIAD_UNAVAILABLE`.

If fewer than three eligible unique species exist, the entire starter
category falls back to vanilla and records `STARTER_GENERATION_FAILED`.

### Starter Stage

- `BASIC ONLY` admits only manifest entries whose saved stage is `basic`.
- `ANY` admits basic, middle, and final-stage species.

This is a hard filter. It is never relaxed to satisfy uniqueness or a type
triad.

### Starter Level

The configured integer from 2 through 20 is saved in every offer and used by
the award command. Rival party levels remain the engine's original levels;
M10 changes only the rival starter species.

### Rival Counterpick

- `BALL ORDER` uses the vanilla physical cycle: left to middle, middle to
  right, and right to left.
- `TYPE ADVANTAGE` selects the unchosen starter with the strongest
  Generation-I type multiplier against the player's saved choice.
  LEFT/MIDDLE/RIGHT order resolves equal scores deterministically.
- `RANDOM OTHER` uses the independent `rival.counterpick` RNG stream to pick
  either unchosen offer. The result is saved and never rerolled.

## Candidate rules

The pool comes from the run's saved eligible species manifest. `BASIC ONLY`
is applied before selection. `EXCLUDE` and `MATCH` legendary policies exclude
legendary starter candidates; `ALLOW` admits them. Player choices are always
unique regardless of the global duplicate policy.

Type comparisons use the merged API-2 type-effectiveness registry when it
defines a matchup, so registered custom types can participate. Unspecified
pairs are neutral and the built-in Generation-I chart supplies vanilla
matchups.

## Saved representation

`mappings.starters` contains complete `LEFT`, `MIDDLE`, and `RIGHT` offers:

```lua
{
  slotId = "LEFT",
  starterIndex = 1,
  species = "VULPIX",
  level = 5,
  choseFlag = "EVENT_CHOSE_CHARMANDER",
  ballObject = "OAKSLAB_CHARMANDER_POKE_BALL",
  rivalBall = "OAKSLAB_SQUIRTLE_POKE_BALL",
  rivalSlot = "MIDDLE",
  rivalSpecies = "POLIWAG",
}
```

`mappings.starterFlags.partyOffsetSlots` saves the compatibility projection
from the engine's three vanilla choice branches to the randomizer's stable
physical slot identities.

Save validation requires three unique player species, levels from 2 through
20, a different rival slot, a matching saved rival species, and the fixed
LEFT/MIDDLE/RIGHT party-offset projection. Mapped and rival species must
still exist in merged content.

## Runtime behavior

The M9 API-2 handlers resolve the saved offer before building Oak's Lab
commands. A `trainer.party` wrapper calls the prior hook first and then, only
for `OPP_RIVAL1`, `OPP_RIVAL2`, or `OPP_RIVAL3`, copies the party and replaces
its final species with the saved counterpick for that choice branch. Levels,
moves, earlier party members, and party size remain untouched.
