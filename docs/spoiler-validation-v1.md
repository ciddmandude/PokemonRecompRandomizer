# Spoiler logs, validation, and compatibility v1

## Spoiler-log option

`ENABLE SPOILER LOG` is a next-run `OFF`/`ON` preference and defaults to
`ON`. It is copied into the saved settings snapshot but excluded from the
behavior-settings hash because it cannot affect generation.

New Game never writes a spoiler file automatically. When the saved run setting
is `ON`, `VIEW SPOILERS` opens the complete readable V2 log in a scrollable
in-game viewer and `EXPORT SPOILERS` explicitly writes:

```text
pokemon_randomizer/spoilers/SEEDHASH.txt
```

The viewer and file contain run identity, settings, category mappings, and
diagnostics without ROM bytes. Location and species identifiers are converted
to readable names where possible. Export failure is logged and does not
invalidate or remove the generated run.

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
saved-run access gating, the in-game viewer, manual plaintext export, output
paths, legacy-save visibility, reachability repairs, missing-content
fallbacks, and mapping immutability.
