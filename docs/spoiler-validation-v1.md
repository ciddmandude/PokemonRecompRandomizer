# Spoiler logs, validation, and compatibility v1

## Spoiler-log option

`GENERATE SPOILER LOG` is a next-run `OFF`/`ON` preference and defaults to
`OFF`. It is copied into the saved settings snapshot but excluded from the
behavior-settings hash because it cannot affect generation.

After a randomized New Game is generated and saved successfully, `ON` writes:

```text
pokemon_randomizer/spoilers/SEEDHASH.txt
```

The readable V2 file contains run identity, settings, category mappings, and
diagnostics without ROM bytes. Location and species identifiers are converted
to readable names where possible. Export failure is logged and does not
invalidate or remove the generated run.

`EXPORT SPOILERS` performs the same plaintext export manually for the active
run regardless of the saved automatic-generation choice.

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

The headless suite verifies readable formatting, automatic `ON`/`OFF`
behavior, manual plaintext export, output paths, legacy-save visibility,
reachability repairs, missing-content fallbacks, and mapping immutability.
