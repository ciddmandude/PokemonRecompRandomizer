# Options Shell v1

Milestone 5 adds a native API-2 Options entry and a custom paged screen for
next-run randomizer preferences. The shell is part of mod version `0.5.0`.

## Entry and screen

The mod wraps `ui.options.rows`, calls the previous handler first, and appends:

```lua
{
  id = "pokemon_randomizer",
  label = "RANDOMIZER",
  value = function() return "OPEN" or "LOCKED" end,
  activate = function(game)
    mod.ui.push(game, "PokemonRandomizerOptions")
  end,
}
```

The `PokemonRandomizerOptions` factory is registered in
`mod.content.screens`. The screen uses only the supported `mod.ui` facade,
the game's input object, and the normal state stack.

## Controls

| Input | Behavior |
|---|---|
| Up / Down | Moves through rows. Crossing an edge moves to the previous or next page and wraps at the ends. |
| Left / Right | Changes choice and number values. Choices wrap; numbers clamp to their declared range. |
| A | Advances a choice, opens the number picker, opens the text editor, or activates an action. |
| B | Closes the Randomizer screen and returns to Options. |
| Select | Advances directly to the next page. |
| Start | Opens the `RESET DEFAULTS` confirmation from any page. |

Reset defaults begins on `NO`. Confirming restores every declared default,
sets Preset to `STANDARD`, clears Seed Text, writes options once, returns to
the first page, and shows `DEFAULTS RESTORED`.

## Layout and help

At most four settings appear on a page. The header shows:

- current page and total page count;
- active-run state;
- `NEXT NEW GAME`, identifying the editable preference scope.

Every selected row has a one- or two-line help description in the bottom
panel. `SEL:PAGE ST:RESET` remains visible as a compact controller hint.

An enabled validated run displays `LOCKED:<seed prefix>`. A save using the
whole-run vanilla fallback displays `ACTIVE:VANILLA`. Quarantined saved state
displays `ACTIVE:DISABLED`. Editing always changes the next-New-Game template,
never the validated active-run copy.

## Persistence

The mod registers 44 option rows with `mod.options:define`. Values are stored
under:

```lua
options.modOptions.pokemon_randomizer
```

Each mutation updates both the live save-options table and the loader's live
preference view, then calls `game:writeOptions()`. Reset batches all mutations
and writes once.

Reads validate stored values against the registered row:

- choices must equal a declared internal value;
- numbers must be integers within their range;
- text must not exceed its declared maximum length.

Invalid stored values fall back to that row's default without being executed
or copied into a new save.

Player preset records are stored in the same namespace under `saved_presets`.
They are defensive table data rather than registered option rows. Invalid
names, malformed records, duplicates, and entries beyond the eight-preset
limit are ignored when the dynamic Preset choices are built.

## Pages

Rows are grouped and split into pages of at most four entries:

- General;
- Wild;
- Starters;
- Static & Gifts;
- Trades;
- Game Corner;
- Items;
- Trainers;
- Actions.

Large groups occupy consecutive pages with the same group name. The Actions
pages contain review, seed, spoiler, save-preset, delete-preset, and reset
actions.

## Milestone boundary

The shell stores and displays every preference specified in Section 5 of the
product specification. Its complete normalized snapshot is now written into a
new save by the Milestone 4 lifecycle.

Milestone 6 now supplies preset expansion, custom-state detection, seed
resolution, run identity, and review/copy actions. Category gameplay hooks
remain assigned to their corresponding later milestones.

## Exported preference API

```lua
mod.exports.preferences = {
  schema = function() ... end,
  pages = function() ... end,
  snapshot = function() ... end,
}
```

All returned tables are copies.
