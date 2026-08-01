# NPC Trades and Game Corner Prizes v1

Milestone 12 is a mod-only implementation for stock Recomp v0.1.30. It uses
public API-2 `commands`, `map_scripts`, `screens`, and `mod.ui` surfaces. It
does not require an engine patch, a custom executable, private `require`
access, or additional permissions.

## Supported NPC trades

Nine NPC offers are generated and saved by stable ID:

1. Route 11 Gate 2F — TERRY;
2. Route 2 Trade House — MARCEL;
3. Cinnabar Lab Fossil Room — SAILOR;
4. Vermilion Trade House — DUX;
5. Route 18 Gate 2F — MARC;
6. Cerulean Trade House — LOLA;
7. Cinnabar Lab Trade Room — DORIS;
8. Cinnabar Lab Trade Room — CRINKLES;
9. Underground Path Route 5 — SPOT.

The imported trade table also contains row 3, CHIKUCHIKU
(`BUTTERFREE -> BEEDRILL`). Stock Red and Blue have no NPC map script wired
to this row, so it is not a player-accessible offer and receives no saved
mapping.

Yellow uses the same nine wired indices and locations with its ROM-specific
GURIO, MILES, STICKY, BART, SPIKE, MARTY, BUFFY, CEZANNE, and RICKY source
offers. The saved IDs and spoiler labels follow that active Yellow table.

`IN-GAME TRADES: RECEIVED` keeps the requested species vanilla and saves a
new received species. `BOTH SIDES` saves both. `OFF` creates no mappings.

The runtime replaces only the nine named talk handlers. Each handler invokes
a namespaced randomizer command. That command:

1. reads the validated saved offer;
2. copies the active merged `field.trades[index]` record;
3. changes only the copied `give` and `get` fields;
4. delegates to the stock `trade` command; and
5. restores the exact original table entry even if the delegated command
   raises an error.

Consequently, dialogue families, party selection and cancellation, wrong-mon
checks, one-time flags, nickname, foreign OT behavior, Pokédex updates, and
the trade animation remain stock-engine behavior.

## Trade generation settings

- `ANY` uses the common eligible species pool without an additional
  request-to-reward strength constraint.
- `SIMILAR` applies the global Similar Strength band between the resolved
  requested and received species. The normal deterministic strength
  relaxation applies if the band is empty.
- `NO DOWNGRADE` requires received BST to be at least 95% of requested BST.
  If the eligible pool cannot satisfy that rule, it relaxes once to the
  common pool and records `TRADE_NO_DOWNGRADE_RELAXED`.
- Legendary policy remains a hard filter under every fairness mode. In
  particular, relaxing the No Downgrade BST floor never changes `EXCLUDE`
  or `MATCH`; the shipped Casual preset therefore cannot receive a legendary
  trade or Game Corner prize.
- `TRADE VALIDITY: ON` excludes offers whose requested and received species
  are identical.
- With Catchability Guard enabled, randomized requested species are
  preferentially selected from destinations already produced by the wild,
  fishing, starter, static, and gift generators. If that set has no valid
  candidate, generation records `TRADE_REACHABILITY_RELAXED` and uses the
  common pool. Exact before-this-NPC progression reachability remains a
  Milestone 14 validation responsibility.
- One-to-one Duplicate Policy avoids repeated requested species and repeated
  received species independently while candidates remain.

## Supported Game Corner prizes

The active save version receives six saved Pokémon prize records:

Only explicit `red`, `blue`, and `yellow` source versions select a prize catalog.
Missing or unknown versions retain their vanilla Pokémon prizes and add a
`PRIZE_VERSION_UNSUPPORTED` generation warning; they never default to Red.

- Red: Abra, Clefairy, Nidorina, Dratini, Scyther, and Porygon slots.
- Blue: Abra, Clefairy, Nidorino, Pinsir, Dratini, and Porygon slots.
- Yellow on gen1recomp 0.1.45: the public prize screen currently exposes the
  Red six-slot table, so the randomizer mirrors those sources under stable
  Yellow IDs. This keeps `OFF` behavior identical to the supported engine.

The three TM rows remain unchanged. The three prize counters all open the
same registered randomizer prize screen, matching the stock shared-counter
behavior. The screen uses the public `mod.ui.ListMenu` widget and preserves:

- the Coin Case gate and introductory text;
- active-version slot ordering;
- displayed species, level, and coin price;
- insufficient-coin handling;
- the live coin footer;
- repeat purchases; and
- unchanged TM awards and costs.

For a mapped Pokémon prize, `give_pokemon` must succeed before coins are
deducted. A full party and full boxes leave the coin balance unchanged.
When the category is disabled or its mapping is missing, the adapter retains
stock v0.1.30's original charge-before-award order.

## Prize generation settings

- `UNCHANGED` levels and prices preserve the source slot.
- `FIXED 15` saves level 15.
- `SCALED` saves
  `round(sourceLevel * sqrt(sourceBST / destinationBST))`, clamped to 5–30.
- `BY STRENGTH` saves
  `round-to-10(sourceCost * destinationBST / sourceBST)`, clamped to
  10–9999.
- `RANDOM +/-25%` saves one deterministic 75–125% cost modifier per slot,
  rounded to 10 and clamped to 10–9999.

Global species-pool, Similar Strength, Legendary, and Duplicate Policy
settings apply to prize species selection.

## Compatibility limits

- The adapter is scoped to the nine stock NPC bindings and the stock
  Red/Blue/Yellow Game Corner prize room exposed by supported recomp releases.
- A mod that replaces one of the same map-script winners may take precedence
  according to normal `map_scripts` composition rules.
- A mod that changes the base trade record still keeps its nickname,
  dialogue set, text overrides, and other fields; only `give` and `get` are
  substituted while the interaction runs.
- A total conversion with different trade indices, maps, or prize-room
  structure is outside this compatibility catalog and remains its own
  content owner's responsibility.
