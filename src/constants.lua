-- Shared version and identity constants. This module has no engine
-- dependencies and is safe to load in headless tests.
return {
  MOD_ID = "pokemon_randomizer",
  MOD_VERSION = "0.8.0",
  MOD_API = 2,
  GAME_VERSION_RANGE = ">=1.0.0 <2.0.0",

  CONTRACT_VERSION = 1,
  SAVE_SCHEMA_VERSION = 1,
  SAVE_CHECKSUM_VERSION = "fnv1a32x4-save-v1",
  FIRST_MIGRATION_VERSION = "0.4.0",
  SETTINGS_HASH_MIGRATION_VERSION = "0.6.0",
  SPECIES_MANIFEST_VERSION = 1,
  OPTIONS_SCREEN_ID = "PokemonRandomizerOptions",
  REVIEW_SCREEN_ID = "PokemonRandomizerReview",

  -- The algorithm contract is locked while category implementations land.
  ALGORITHM_VERSION = "1.0.0-dev",
  HASH_VERSION = "fnv1a32x4-v1",
  PRNG_VERSION = "xoshiro128ss-v1",

  STREAM_NAMES = {
    "wild.global",
    "wild.area",
    "wild.levels",
    "starters",
    "rival.counterpick",
    "static.encounters",
    "static.levels",
    "gifts",
    "gift.levels",
    "trades",
    "prizes",
    "trainers.species",
    "trainers.levels",
    "trainers.sizes",
    "validation.swaps",
  },
}
