-- Shared version and identity constants. This module has no engine
-- dependencies and is safe to load in headless tests.
return {
  MOD_ID = "pokemon_randomizer",
  MOD_VERSION = "0.1.0",
  MOD_API = 2,
  GAME_VERSION_RANGE = ">=1.0.0 <2.0.0",

  CONTRACT_VERSION = 1,
  SAVE_SCHEMA_VERSION = 1,

  -- Milestone 2 will introduce the first deterministic algorithm.
  ALGORITHM_VERSION = "unimplemented",
}
