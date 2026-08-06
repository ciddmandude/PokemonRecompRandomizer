-- Shared version and identity constants. This module has no engine
-- dependencies and is safe to load in headless tests.
local STREAM_DEFINITIONS = {
  { "wild", "global", "wild.global" },
  { "wild", "area", "wild.area" },
  { "wild", "levels", "wild.levels" },
  { "starters", "selection", "starters" },
  { "starters", "rivalCounterpick", "rival.counterpick" },
  { "staticGift", "staticSpecies", "static.encounters" },
  { "staticGift", "staticLevels", "static.levels" },
  { "staticGift", "giftSpecies", "gifts" },
  { "staticGift", "giftLevels", "gift.levels" },
  { "tradePrize", "trades", "trades" },
  { "tradePrize", "prizes", "prizes" },
  { "trainers", "species", "trainers.species" },
  { "trainers", "levels", "trainers.levels" },
  { "trainers", "sizes", "trainers.sizes" },
  { "trainers", "rival", "trainers.rival" },
  { "items", "placements", "items" },
  { "mechanics", "baseStats", "mechanics.base_stats" },
  { "mechanics", "pokemonTypes", "mechanics.pokemon_types" },
  { "mechanics", "movesets", "mechanics.movesets" },
  { "mechanics", "compatibility", "mechanics.tmhm" },
  { "mechanics", "evolutions", "mechanics.evolutions" },
  { "mechanics", "tradeEvolutions", "mechanics.trade_evolutions" },
  { "mechanics", "moveTypes", "mechanics.move_types" },
  { "mechanics", "movePower", "mechanics.move_power" },
  { "mechanics", "moveAccuracy", "mechanics.move_accuracy" },
  { "mechanics", "movePp", "mechanics.move_pp" },
  { "validation", "swaps", "validation.swaps" },
}

local function buildStreamRegistry(definitions)
  assert(type(definitions) == "table",
    "stream definitions must be a table")
  local structured = {}
  local names = {}
  local seenNames = {}
  for index, definition in ipairs(definitions) do
    assert(type(definition) == "table",
      ("stream definition %d must be a table"):format(index))
    local group, key, name = definition[1], definition[2], definition[3]
    assert(type(group) == "string" and group ~= "",
      ("stream definition %d has an invalid group"):format(index))
    assert(type(key) == "string" and key ~= "",
      ("stream definition %d has an invalid key"):format(index))
    assert(type(name) == "string"
        and name:match("^[a-z][a-z0-9._%-]*$") ~= nil,
      ("stream definition %d has an invalid name: %s"):format(
        index, tostring(name)))
    assert(not seenNames[name], "duplicate stream name: " .. name)
    structured[group] = structured[group] or {}
    assert(structured[group][key] == nil,
      ("duplicate stream key: %s.%s"):format(group, key))
    structured[group][key] = name
    names[#names + 1] = name
    seenNames[name] = true
  end
  return structured, names
end

local Streams, StreamNames = buildStreamRegistry(STREAM_DEFINITIONS)

return {
  MOD_ID = "pokemon_randomizer",
  MOD_VERSION = "0.46.4",
  MOD_API = 2,

  CONTRACT_VERSION = 1,
  SAVE_SCHEMA_VERSION = 1,
  SAVE_CHECKSUM_VERSION = "fnv1a32x4-save-v1",
  SAVE_SIZE_BUDGET_BYTES = 262144,
  FIRST_MIGRATION_VERSION = "0.4.0",
  SETTINGS_HASH_MIGRATION_VERSION = "0.6.0",
  FIELD_ITEM_MIGRATION_VERSION = "0.40.0",
  MECHANICS_MIGRATION_VERSION = "0.45.0",
  SPECIES_MANIFEST_VERSION = 1,
  OPTIONS_SCREEN_ID = "PokemonRandomizerOptions",
  REVIEW_SCREEN_ID = "PokemonRandomizerReview",
  SPOILER_BROWSER_SCREEN_ID = "PokemonRandomizerSpoilerBrowser",

  -- The algorithm contract is locked while category implementations land.
  ALGORITHM_VERSION = "1.19.0-dev",
  HASH_VERSION = "fnv1a32x4-v1",
  PRNG_VERSION = "xoshiro128ss-v1",

  STREAMS = Streams,
  STREAM_NAMES = StreamNames,
  buildStreamRegistry = buildStreamRegistry,
}
