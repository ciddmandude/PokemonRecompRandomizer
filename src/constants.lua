-- Shared version and identity constants. This module has no engine
-- dependencies and is safe to load in headless tests.
return {
  MOD_ID = "pokemon_randomizer",
  MOD_VERSION = "0.2.0",
  MOD_API = 2,
  GAME_VERSION_RANGE = ">=1.0.0 <2.0.0",

  CONTRACT_VERSION = 1,
  SAVE_SCHEMA_VERSION = 1,

  -- The category generator is still incomplete, but its deterministic
  -- foundation is versioned and locked by golden vectors.
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
