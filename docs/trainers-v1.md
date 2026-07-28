# Trainer randomization v1

Milestone 13 implements trainer randomization as a mod-only feature for
gen1recomp v0.1.30. It uses the public `trainer.party` wrapper and requires no
engine patch.

## Saved mapping

Every randomized party variant is resolved when a new save is created and
stored at:

```lua
mappings.trainerParties[trainerClass][partyIndex] = {
  { species = "ID", level = 12, moves = { "MOVE" } },
}
```

The optional `moves` field is present only when the source party already
specified moves or when an incompatible v0.1.30 legacy boss move must be
suppressed. Type-themed classes also save a `theme` field beside their numeric
party indices. Runtime lookup is O(1), and the wrapper allocates only the party
copy it returns.

## Trainer Pokémon

- `OFF`: no trainer mappings are generated. Trainer level and party-size
  settings are ignored.
- `GLOBAL MAP`: each source species has one destination across every trainer
  class, variant, and slot.
- `BY SLOT`: each class, party variant, and slot rolls independently.
- `TYPE THEMED`: one deterministic type is saved per trainer class. Candidate
  strength widens first if necessary, then the type restriction may relax so a
  valid party is always preferred over a generation failure.

The general Similar Strength, Legendary, Species Pool, and Duplicate Policy
settings apply. With One-to-One enabled, destinations are not reused until the
eligible pool is exhausted, at which point the pool deterministically restarts.

## Trainer levels

- `UNCHANGED`: preserves source levels.
- `+/-10%`: rolls and saves an integer percentage from 90 through 110 for each
  slot, rounds to the nearest level, and clamps to levels 2 through 100.
- `PROGRESSIVE`: uses the source party's highest level as a stable progression
  proxy. Parties at maximum levels 15, 30, 45, 60, and above receive
  respectively -20%, -10%, 0%, +10%, and +20%, with the same 2-100 clamp.

No level is rerolled during play or after loading.

## Boss trainers

Bosses are the eight Gym Leader classes, the four Elite Four classes, and all
three rival classes.

- `INCLUDE`: bosses follow the selected Trainer Pokémon mode.
- `THEMED`: bosses receive a saved type theme even when ordinary trainers use
  Global Map or By Slot, and retain their source party size.
- `VANILLA`: no trainer-category mapping is saved for boss classes. Starter
  randomization may still project its saved rival counterpick because that is
  required for starter continuity.

Gen1recomp v0.1.30 applies several hard-coded leader, Elite Four, Giovanni, and
rival moves after the trainer hook. When the destination species can legally
learn that move, the engine behavior is retained. Otherwise the mapping saves
the species' normal up-to-four moves at the generated level; this explicit list
wins over the incompatible legacy move. Explicit moves supplied by trainer data
or by an earlier mod hook are always authoritative.

## Party size and progression guard

- `UNCHANGED`: retains every source party's count.
- `1-6 RANDOM`: saves a count from one through six. Expanded parties cycle
  through source slots as templates before every destination is rolled.

With Progression Guard on, parties whose source maximum is level 14 or lower
are limited to one through three Pokémon, legendary destinations are excluded
for those early parties, destinations are capped at 450 BST, a normal moveset
must be constructible by level 14, and the first level-5 rival parties remain
size one.
That rival's level is also capped at three levels above the configured starter.
Every generated required party remains nonempty. Progression Guard off removes
these restrictions.

## Hook composition and failure behavior

The wrapper calls the previous `trainer.party` implementation first. Saved
species and levels are then projected onto that result; explicit moves from the
previous result are retained. The starter-rival projection runs last. Missing
or malformed class/variant mappings return the previous hook's complete party
unchanged. If creation-time trainer generation fails, the category is empty and
all trainer parties remain vanilla.
