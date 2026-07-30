# Spoiler browser cache and asset safety v1

Round 2 Milestone 4 adds runtime-only caches for the in-game spoiler browser.
Neither cache is stored in `save.modData` or included in a saved-run checksum.

## Index cache

`SpoilerBrowser.buildCached(run, sources)` retains one constructed index. Its
key includes:

- the saved namespace checksum (or run object identity for non-save fixtures);
- the saved seed hash or canonical seed;
- active game version;
- the lifecycle/save revision; and
- the merged species, encounter, trainer, map, and field source identity.

The lifecycle revision changes on New Game, load transitions, and active-run
replacement. A checksum change covers regenerated mappings. Engine content
registries and `game.data` roots are immutable after mod loading; their table
identities therefore act as the merged-data revision for that loaded process.
Tests also supply an explicit revision and prove that changing it rebuilds the
index.

The cache exposes build/hit counters only for testing and measurement.
`clearCache()` clears runtime state without touching a save.

## Town Map background cache

The screen caches a successfully loaded image and its quads by tileset path,
declared asset identity or revision, declared dimensions, and the tiles table
identity. Each screen receives its own copy of the tile map.

Before quad construction, the loader requires:

- a nonempty tileset path and tile map;
- positive integer image dimensions;
- width and height divisible by eight; and
- integer tile IDs within the image's tile range.

Image loading, dimension lookup, and each quad construction are protected.
Failure returns `nil`, which selects the existing plain Town Map fallback.
Graphics objects remain in module-local runtime memory and never enter the
browser index or saved namespace.

## Measurement

On July 30, 2026, the Lua 5.1.5 Windows desktop regression fixture performed
500 browser opens in:

- `0.1930s` when directly rebuilding the index each time; and
- `0.0010s` through `buildCached` after the first construction.

The same test counted one index build and one hit across two identical opens.
For the 16x8 background fixture, the first open built one image and two quads;
the second open built neither and recorded one cache hit.

These are synthetic fixture measurements, not a claim of a guaranteed visible
speedup in gameplay. A manual release check should time the first and second
View Spoiler Log opens with the same save, then repeat after loading a
different save. On a low-power handheld, repeat the same sequence and record
the hardware, OS, engine build, first-open time, and repeated-open time.
Handheld timing was not available for this milestone.
