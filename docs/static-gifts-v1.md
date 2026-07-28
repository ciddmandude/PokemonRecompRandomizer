# Static Encounters and Gifts v1

Milestone 11 is a deliberately partial, mod-only implementation for stock
Recomp v0.1.30. It uses public API-2 `commands` and `map_scripts` composition;
no engine patch or custom app build is required.

## Supported static encounters

Fourteen stable encounter IDs are generated and saved:

- eight Power Plant Voltorb/Electrode balls;
- Zapdos;
- Articuno;
- Moltres;
- Mewtwo;
- Route 12 Snorlax;
- Route 16 Snorlax.

Each saved record contains the stable encounter ID, source species and level,
resolved species and level, and map ID. Existing battle flags, capture/flee
behavior, object hiding, and Snorlax Poké Flute flow remain owned by the
engine's commands.

The original legendary overworld sprite is not replaced because v0.1.30 has
no per-save object-sprite seam. The mapped cry, interaction text, and battle
species agree after interaction begins.

## Supported gifts

Five stable gift IDs are generated and saved:

- Celadon Mansion Eevee;
- Route 4/Mt. Moon Pokémon Center Magikarp sale;
- Fighting Dojo left prize;
- Fighting Dojo right prize;
- Silph Co. Lapras.

The saved offer drives the displayed species name and final award. The
physical gift object or NPC, original event flags, Dojo choice group, payment,
nickname prompt, Pokédex update, and party/box handling remain engine-owned.

Gift completion flags, object hiding, and Magikarp payment occur only after
`give_pokemon` succeeds. A full party and full boxes therefore leave the
offer available for another attempt.

## Settings

`Static Pokémon: OFF` registers compatibility handlers but selects their
vanilla-parity script branches and complete vanilla species and levels because
the saved mapping is empty.
`RANDOMIZED` generates every supported static record once.

Static levels:

- `UNCHANGED` preserves the source level.
- `SCALED` uses
  `round(sourceLevel × sqrt(sourceBST / destinationBST))`, clamped to 2–100.
- `RANDOM ±5` saves an independent offset from -5 through +5 and clamps the
  result to 2–100.

`Gift Pokémon: OFF` resolves all supported gifts to their vanilla offers.
`RANDOMIZED` generates the five offers once.

Gift levels:

- `UNCHANGED` preserves the original level.
- `SCALED` uses the same BST compensation formula, clamped to 2–100.
- `FIXED 15` saves level 15 for every supported gift.

`UNIQUE GIFTS` prevents repeated destinations while candidates remain.
`ALLOW DUPES` samples independently. Dojo alternatives are both generated at
New Game and selecting one never changes the other saved offer.

Global Similar Strength, Legendary, Duplicate Policy, species-pool, and
eligibility rules apply. The static category uses Duplicate Policy; starter
and gift uniqueness retain their category-specific rules.

## Atomic fallback

If any supported static has no valid candidate, the complete supported static
category remains vanilla and records `STATIC_GENERATION_FAILED`. Gifts behave
the same way with `GIFT_GENERATION_FAILED`. Pool-exhaustion restarts are
deterministic and recorded.

Runtime commands resolve only the active run's validated, checksum-protected
mapping. Missing or invalid mappings use the command's complete vanilla
species and level.

## Explicit compatibility exclusions

These paths remain fully vanilla in v0.11.0:

- fossil restoration;
- the Pokémon Tower ghost Marowak;
- generic `object_event` static Pokémon not represented by a named map
  script;
- the catching tutorial;
- Game Corner Pokémon prizes, which remain assigned to M12.

Stock v0.1.30 exposes no stable pre-battle static hook and no pre-dialogue
gift-offer hook. Its `pokemon.before_give` event fires too late to keep fossil
dialogue consistent, and `battle.started` fires after the wild enemy and
intro have already been constructed. The mod therefore does not use either
late seam for excluded paths.
