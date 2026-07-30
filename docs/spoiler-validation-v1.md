# Spoiler logs, validation, and compatibility v1

## Spoiler-log option

`ENABLE SPOILER LOG` is a next-run `OFF`/`ON` preference and defaults to
`ON`. It is copied into the saved settings snapshot but excluded from the
behavior-settings hash because it cannot affect generation.

New Game never writes a spoiler file automatically. When the saved run setting
is `ON`, `VIEW SPOILERS` opens an unrestricted Pokémon/map browser:

- Pokémon mode lists every merged-registry species in Pokédex order, placing
  unnumbered species alphabetically afterward. `SELECT` opens partial-name
  search. Each species has one entry per obtainable/encounter location.
- Map mode renders the extracted Kanto Town Map, groups relevant buildings and
  floors under their map coordinate, and presents `GRASS`, `SURF`, `OLD ROD`,
  `GOOD ROD`, `SUPER ROD`, `TRAINERS`,
  `STARTERS`, `STATICS`, `GIFTS`, `TRADES`, and `PRIZES` tabs.
- Encounter tabs combine slot probability by current species and distinct
  level, display every level directly, and do not open a detail screen.
- Trainer entries open a complete generic class/party listing with levels.
  Categories configured `OFF` remain visible and show their actual Pokémon
  without `VANILLA` or `RANDOMIZED` status labels.
- Pokémon locations include wild, fishing, starters, statics, gifts, received
  trades, and Game Corner prizes; trainer ownership and requested trades are
  excluded.

The viewer omits the saved settings section. `EXPORT SPOILERS` explicitly
writes the complete report, including settings:

```text
pokemon_randomizer/spoilers/SEEDHASH.txt
```

The viewer and file contain run identity, category mappings, and diagnostics
without ROM bytes; the exported file additionally contains saved settings.
Location and species identifiers are converted to readable names where
possible. Export failure is logged and does not invalidate or remove the
generated run.

When the saved run setting is `OFF`, both actions show `SPOILERS DISABLED`,
the public spoiler formatter/exporter returns an access error, and no file is
written. Changing next-run preferences cannot unlock an existing `OFF` save.

Race Mode, spoiler locking, passphrases, encrypted `.race` files, seed
redaction, Hall of Fame/Credits command overrides, and the `-R` run-code suffix
were removed in mod version `0.21.0`. Old saves containing legacy race metadata
remain checksummed and loadable, but that metadata has no runtime effect.

## Final cross-category validation

After all category generators finish, the independent `validation.swaps`
stream builds a reachability set from wild encounters, fishing, starters,
supported statics/gifts, and Game Corner Pokémon. If a requested NPC-trade
species is unreachable, the validator swaps it with a duplicate reachable
wild destination. This preserves mapping counts and the generated species
multiset.

If no safe donor exists, generation records
`TRADE_REACHABILITY_UNSATISFIED` without retrying indefinitely. Runtime
references to missing mod content use vanilla lookup fallbacks without
rewriting stored mappings.

Saved diagnostics include deterministic repair-swap count, reachable species
count, mapping node count, mappings byte count, and complete namespace byte
count. The complete-namespace budget is 256 KiB.

## Tests

The headless suite verifies the default, absence of automatic writes,
saved-run access gating, merged-species ordering/search, reverse location
indexing, global-map expansion, duplicate-slot probability aggregation,
map/building grouping, trainer-party drill-down, manual plaintext export,
output paths, legacy-save visibility, reachability repairs, missing-content
fallbacks, and mapping immutability.
