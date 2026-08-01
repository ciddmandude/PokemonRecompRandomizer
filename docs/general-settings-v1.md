# General Settings and Presets v1

Milestone 6 implements the Section 5.1 settings semantics for mod version
`0.6.0`. Category mappings remain assigned to their later milestones.

## New Game enable choice

The persistent Randomizer ON/OFF option no longer exists. Before Oak's first
line, every New Game asks whether to enable the randomizer. Choosing NO bypasses
the generator and writes a valid disabled run namespace with empty mappings,
no warning, and `fallbackCount = 0`. It does not disable the mod, erase an
existing save, or change global preferences.

Choosing YES offers the built-in and player-saved preset picker or a custom
settings screen. Completion resolves and validates the seed and pool before
invoking the generator and resuming Oak.

## Preset scope

The built-in Casual, Standard, and Chaos presets control their category and
safeguard fields, enable spoiler access, and leave Seed Mode and Seed Text
unchanged. Selecting one applies its complete bundle in one options write.
Editing a bundled field recalculates the preset marker.

Players may also save up to eight named presets. Names are unique after
trimming, whitespace collapsing, and uppercasing; they contain 1-16 letters,
digits, spaces, hyphens, or underscores and cannot reuse a built-in name. A
saved preset captures every next-run option except the Preset label itself.
Seed Mode and Seed Text are therefore restored when that name is
selected from the existing Preset row.

Saving the current settings makes the saved name active. Editing any captured
value changes an active saved preset to `CUSTOM`; changing Randomizer does not.
Saving an existing name and deleting any saved name require confirmation.
Deleting the active name leaves its current settings in place and redetects a
built-in match or `CUSTOM`.

`STANDARD` exactly matches all published defaults, so Reset Defaults restores
Standard and clears Seed Text.

## Locked preset bundles

| Setting | Casual | Standard | Chaos |
|---|---|---|---|
| Species Pool | Vanilla 151 | Vanilla 151 | Merged Data |
| Similar Strength | +/-10% | +/-20% | Off |
| Legendaries | Exclude | Match | Allow |
| Duplicate Policy | One-to-One | One-to-One | Allow |
| Wild Pokémon | Global Map | Global Map | Area Slots |
| Fishing | Randomized | Randomized | Randomized |
| Wild Levels | Unchanged | Unchanged | +/-2 |
| Pokémon Coverage | On | On | Off |
| Starters | Random | Random | Random |
| Starter Stage | Basic Only | Basic Only | Any |
| Starter Level | 5 | 5 | 5 |
| Rival Counterpick | Type Advantage | Type Advantage | Random Other |
| Static Pokémon | Randomized | Randomized | Randomized |
| Static Levels | Unchanged | Unchanged | Random +/-5 |
| Gift Pokémon | Randomized | Randomized | Randomized |
| Gift Levels | Unchanged | Unchanged | Scaled |
| Gift Uniqueness | Unique Gifts | Unique Gifts | Allow Duplicates |
| In-game Trades | Received | Both Sides | Both Sides |
| Trade Fairness | No Downgrade | Similar Strength | Any |
| Trade Validity | On | On | Off |
| Game Corner Pokémon | Randomized | Randomized | Randomized |
| Prize Levels | Unchanged | Unchanged | Scaled |
| Prize Prices | Unchanged | Unchanged | Random +/-25% |
| Non-key Location | Vanilla | Vanilla | Vanilla |
| TM Location | Vanilla | Vanilla | Vanilla |
| HM Location | Vanilla | Vanilla | Vanilla |
| Key Item Location | Vanilla | Vanilla | Vanilla |
| Badge Location | Vanilla | Vanilla | Vanilla |
| Hidden Items | Vanilla | Vanilla | Vanilla |
| Progression Safety | On | On | Off |
| Shops | Vanilla | Vanilla | Vanilla |
| Shop Prices | Vanilla | Vanilla | Vanilla |
| Trainer Pokémon | Global Map | By Slot | By Slot |
| Trainer Levels | Unchanged | Unchanged | +/-10% |
| Boss Trainers | Vanilla | Themed | Include |
| Party Size | Unchanged | Unchanged | 1-6 Random |
| Trainer Safety | On | On | Off |

Casual narrows strength, removes legendary destinations, uses fairer trades,
keeps bosses vanilla, and retains progression safeguards. Standard uses the
published defaults. Chaos uses the merged pool and independent slot choices
while disabling soft coverage, trade, duplication, and progression guards.
Hard content-validity rules are never disabled.

## Seed resolution

Manual seeds preserve the entered display text and normalize the canonical
value through Deterministic Foundation v1:

- trim outer whitespace;
- collapse whitespace runs;
- uppercase;
- allow only `A-Z`, `0-9`, space, hyphen, and underscore;
- require 1-32 canonical characters.

An invalid manual seed does not invoke generation. The save receives a disabled
whole-run fallback with `INVALID_MANUAL_SEED`; the error is also visible in
Review Next Run.

Auto mode collects best-effort, non-cryptographic uniqueness material once at
`save.created`. The default provider mixes the available high-resolution
LÖVE timer and LÖVE PRNG output with wall/process clocks, a per-process
counter, and stable save/player context. Recomp 0.1.38 does not expose a
documented operating-system CSPRNG to mods, so this is not a claim of 128 bits
of operating-system entropy.

The mixed material is hashed into a 128-bit digest and encoded as 26 Crockford
Base32 characters with two leading zero padding bits. The first character is
therefore `0-7`; the alphabet omits `I`, `L`, `O`, and `U`. The resulting
display and canonical values are saved together. Missing optional LÖVE APIs
fall back safely to the remaining sources.

## Species pool and common filters

The lifecycle now builds the manifest using the saved preference:

- `vanilla151` selects canonical Gen I IDs;
- `merged` selects every eligible merged-registry species.

Common filter normalization exposes:

- strength percentage as `nil`, `10`, or `20`;
- legendary mode as `exclude`, `match`, or `allow`;
- duplicate policy as `allow` or `one_to_one`.

Later category generators consume these normalized rules.

## Settings identity

The saved namespace retains the complete 41-field snapshot. The settings hash,
however, includes only behavior-affecting fields. It excludes:

- Preset, because it is a label for the expanded bundle;
- Seed Mode and Seed Text, because the resolved canonical seed has its own
  saved identity;
- Enable Spoiler Log, because viewing/export access does not affect gameplay.

Randomizer remains included. This means two runs with the same
canonical seed and behavior receive the same identity even if one player typed
the seed differently or chose a different spoiler-log preference.

Version `0.6.0` registers an ordered migration that updates old full-snapshot
settings hashes and the namespace checksum without regenerating mappings.
Load validation now rejects a settings hash that does not match the saved
behavior fields.

## Run code

The compact code is:

```text
R1-<seed hash first 8>-<settings hash first 8>-<pool hash first 8>
```

All components use uppercase hexadecimal. The full canonical seed remains
visible separately.

## Review and clipboard behavior

The Actions page now provides:

- `REVIEW NEXT RUN`, a scrollable list of all editable values, manual-seed
  warnings, eligible pool count, exclusion count, and manifest warnings;
- `COPY ACTIVE SEED`, which displays the full active seed, run code, algorithm
  version, locked status, and category summary.
- `SAVE PRESET`, which names and stores every current next-run value;
- `DELETE PRESET`, which selects and confirms removal of a saved name.

When `love.system.setClipboardText` is available, Copy Active Seed copies the
full seed and run code. Whether copying succeeds or not, the transcription
screen opens. Without clipboard support, it shows `COPY UNAVAILABLE` while the
same full values remain visible.
