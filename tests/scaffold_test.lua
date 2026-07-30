-- Standalone contract test:
--   lua tests/scaffold_test.lua
-- Run from the repository root.
local function loadFactory(path, ...)
  local chunk, err = loadfile(path)
  assert(chunk, err)
  local value = chunk()
  if type(value) == "function" then return value(...) end
  return value
end

local Constants = loadFactory("src/constants.lua")
local UInt32 = loadFactory("src/uint32.lua")
local Seed = loadFactory("src/seed.lua")
local Hash128 = loadFactory("src/hash128.lua", Constants, UInt32)
local StableSort = loadFactory("src/stable_sort.lua")
local Progression = loadFactory("src/progression.lua", StableSort)
local Matching = loadFactory("src/matching.lua", StableSort)
local Rng = loadFactory("src/rng.lua", Constants, UInt32, Hash128)
local Canonical = loadFactory("src/canonical.lua", StableSort)
local VanillaSpecies = loadFactory("src/vanilla_species.lua")
local Metadata = loadFactory("src/species_metadata.lua", StableSort)
local SpeciesManifest = loadFactory("src/species_manifest.lua",
  Constants, StableSort, Canonical, Hash128, VanillaSpecies)
local SpeciesFilters = loadFactory("src/species_filters.lua")
local Contracts = loadFactory("src/contracts.lua", Constants)
local WildGlobal = loadFactory(
  "src/wild_global.lua", StableSort, SpeciesFilters, Matching)
local WildCategory = loadFactory(
  "src/wild_category.lua",
  StableSort, SpeciesFilters, WildGlobal, Matching, Progression)
local StarterCategory = loadFactory(
  "src/starter_category.lua", StableSort)
local TradePrizeCatalog = loadFactory("src/trade_prize_catalog.lua")
local ValidationCategory = loadFactory(
  "src/validation_category.lua",
  StableSort, Canonical, Progression, TradePrizeCatalog)
local SaveState = loadFactory("src/save_state.lua",
  Constants, Seed, Hash128, Canonical, StableSort, Contracts)
local Generator = loadFactory("src/generator.lua", Constants, Contracts, {
  UInt32 = UInt32,
  Seed = Seed,
  Hash128 = Hash128,
  StableSort = StableSort,
  Rng = Rng,
  Canonical = Canonical,
}, {
  Metadata = Metadata.new(),
  Manifest = SpeciesManifest,
  Filters = SpeciesFilters,
  VanillaSpecies = VanillaSpecies,
}, WildCategory, StarterCategory, nil, nil, nil,
Progression, ValidationCategory)

assert(Constants.MOD_API == 2)
assert(Constants.MOD_ID == "pokemon_randomizer")
assert(Constants.MOD_VERSION == "0.34.3")
assert(Constants.SAVE_CHECKSUM_VERSION == "fnv1a32x4-save-v1")
assert(Constants.OPTIONS_SCREEN_ID == "PokemonRandomizerOptions")
assert(Constants.REVIEW_SCREEN_ID == "PokemonRandomizerReview")
assert(Generator.available == true)
assert(Generator.foundationAvailable == true)
assert(Generator.algorithmVersion == "1.4.0-dev")
assert(type(SaveState.validate) == "function")

local request = {
  contractVersion = 1,
  seed = { canonical = "MILESTONE ONE" },
  settings = {},
  species = {
    { id = "BULBASAUR" },
    { id = "CHARMANDER" },
    { id = "SQUIRTLE" },
  },
  sources = {},
}

local valid, errors = Generator.validate(request)
assert(valid, errors[1] and errors[1].message)

local result, generationError = Generator.generate(request)
assert(result ~= nil and generationError == nil)
assert(type(result.mappings.wildGlobal) == "table")

local invalid = {
  contractVersion = 1,
  seed = { canonical = "" },
  settings = {},
  species = { { id = "MEW" }, { id = "MEW" } },
}
valid, errors = Generator.validate(invalid)
assert(not valid)
assert(#errors == 2)

local empty = Generator.emptyResult()
valid, errors = Contracts.validateGenerationResult(empty)
assert(valid, errors[1] and errors[1].message)

local canonical = Generator.normalizeSeed(" milestone   two ")
assert(canonical == "MILESTONE TWO")
local stream = Generator.newStream(canonical, "wild.global")
assert(type(stream:nextU32()) == "number")

io.write("scaffold_test: ok\n")
