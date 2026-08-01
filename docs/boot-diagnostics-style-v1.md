# Boot diagnostics and progression style v1

Round 2 Milestone 7 documents the intentional pre-game save suppression and
normalizes the progression model's source formatting.

## Disposable boot save

Recomp constructs a disposable New Game-shaped save before `game.ready` so
title-screen systems can access defaults. The engine emits `save.created` for
that skeleton, but it is not the save produced when the player chooses New
Game. Generating mappings there would incorrectly make the title-screen
randomizer appear locked.

The bootstrap continues to ignore every pre-`game.ready` `save.created`
payload. The first ignored event emits one debug-level message:

```text
suppressed disposable pre-game.ready save.created boot skeleton
```

Additional pre-ready events in the same process do not emit another message.
The suppression produces no warning, error, user-facing screen, saved
namespace, or locked settings state. After `game.ready`, the real New Game
event follows the normal atomic generation lifecycle.

## Progression formatting

`src/progression.lua` now uses two spaces for each indentation level and no tab
indentation. The change is whitespace-only. Progression access tests retain
their exact ordered requirements and Fighting Dojo stage, while the complete
24-vector generator golden suite retains the same mappings, warnings,
fallback counts, and hashes under algorithm `1.12.0-dev`.
