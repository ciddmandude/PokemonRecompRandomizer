-- Shared real-generator harness for remediation M4 vectors and properties.
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
local SpeciesFilters = loadFactory("src/species_filters.lua")
local Contracts = loadFactory("src/contracts.lua", Constants)
local SaveState = loadFactory("src/save_state.lua",
  Constants, Seed, Hash128, Canonical, StableSort, Contracts)
local General = loadFactory("src/general_settings.lua", SaveState)
local WildGlobal = loadFactory(
  "src/wild_global.lua", StableSort, SpeciesFilters, Matching)
local WildCategory = loadFactory(
  "src/wild_category.lua",
  StableSort, SpeciesFilters, WildGlobal, Matching, Progression)
local StarterCategory = loadFactory(
  "src/starter_category.lua", StableSort)
local StaticGiftCatalog = loadFactory("src/static_gift_catalog.lua")
local StaticGiftCategory = loadFactory(
  "src/static_gift_category.lua",
  StableSort, SpeciesFilters, StaticGiftCatalog, Matching)
local TradePrizeCatalog = loadFactory("src/trade_prize_catalog.lua")
local TradePrizeCategory = loadFactory(
  "src/trade_prize_category.lua",
  StableSort, SpeciesFilters, TradePrizeCatalog, Matching, Progression)
local TrainerCategory = loadFactory(
  "src/trainer_category.lua", StableSort, SpeciesFilters, Matching)
local ItemCategory = loadFactory("src/item_category.lua", StableSort)
local ValidationCategory = loadFactory(
  "src/validation_category.lua",
  StableSort, Canonical, Progression, TradePrizeCatalog)
local Generator = loadFactory(
  "src/generator.lua", Constants, Contracts, {
    UInt32 = UInt32,
    Seed = Seed,
    Hash128 = Hash128,
    StableSort = StableSort,
    Rng = Rng,
    Canonical = Canonical,
  }, {
    Filters = SpeciesFilters,
  }, WildCategory, StarterCategory, StaticGiftCategory,
  TradePrizeCategory, TrainerCategory, ItemCategory,
  Progression, ValidationCategory)

local Harness = {
  Constants = Constants,
  Contracts = Contracts,
  Canonical = Canonical,
  Hash128 = Hash128,
  SaveState = SaveState,
  General = General,
  Generator = Generator,
  Validation = ValidationCategory,
  Progression = Progression,
  TradeCatalog = TradePrizeCatalog,
}

local TYPES = {
  "FIRE", "GRASS", "WATER", "ELECTRIC", "NORMAL", "POISON",
  "GROUND", "FLYING", "PSYCHIC", "ICE", "ROCK", "FIGHTING",
}
local LEGENDARY = {
  ARTICUNO = true, ZAPDOS = true, MOLTRES = true,
  MEWTWO = true, MEW = true,
}

local species = {}
for index, id in ipairs(VanillaSpecies) do
  local bst = 250 + (index * 17) % 351
  species[index] = {
    id = id,
    dex = index,
    bst = bst,
    types = { TYPES[(index - 1) % #TYPES + 1] },
    stage = "basic",
    legendary = LEGENDARY[id] == true,
    level1Moves = { "TACKLE" },
    learnset = {
      { level = 7, move = "GROWL" },
      { level = 12, move = "QUICK_ATTACK" },
    },
    tmhm = {
      "BIDE", "BUBBLEBEAM", "THUNDERBOLT", "MEGA_DRAIN", "TOXIC",
      "PSYWAVE", "FIRE_BLAST", "FISSURE", "BLIZZARD", "BARRIER",
      "SKY_ATTACK",
    },
    evolutions = {},
  }
end

local sources = {
  gameVersion = "red",
  encounters = {
    ROUTE_1 = {
      grass = {
        slots = {
          { species = "PIDGEY", level = 3 },
          { species = "RATTATA", level = 3 },
          { species = "PIDGEY", level = 4 },
        },
      },
    },
    ROUTE_22 = {
      grass = {
        slots = {
          { species = "NIDORAN_M", level = 4 },
          { species = "NIDORAN_F", level = 4 },
          { species = "SPEAROW", level = 5 },
        },
      },
      water = {
        slots = {
          { species = "POLIWAG", level = 10 },
          { species = "GOLDEEN", level = 10 },
        },
      },
    },
    CERULEAN_CAVE_1F = {
      grass = {
        slots = {
          { species = "DITTO", level = 52 },
          { species = "RHYDON", level = 54 },
        },
      },
    },
  },
  field = {
    fishing = {
      OLD_ROD = {
        always = { species = "MAGIKARP", level = 5 },
      },
      GOOD_ROD = {
        pool = {
          { species = "POLIWAG", level = 10 },
          { species = "GOLDEEN", level = 10 },
        },
      },
      SUPER_ROD = { perMap = "superRodGroups" },
    },
    superRodGroups = {
      PALLET_TOWN = {
        { species = "TENTACOOL", level = 15 },
        { species = "STARYU", level = 15 },
      },
      CERULEAN_CAVE_1F = {
        { species = "SLOWBRO", level = 23 },
        { species = "SEAKING", level = 23 },
      },
    },
  },
  trainers = {
    OPP_RIVAL1 = {
      parties = {
        {{ species = "SQUIRTLE", level = 5 }},
      },
    },
    OPP_BROCK = {
      parties = {
        {
          { species = "GEODUDE", level = 12 },
          { species = "ONIX", level = 14 },
        },
      },
    },
    OPP_MISTY = {
      parties = {
        {
          { species = "STARYU", level = 18 },
          { species = "STARMIE", level = 21 },
        },
      },
    },
    OPP_BUG_CATCHER = {
      parties = {
        {
          { species = "CATERPIE", level = 7 },
          { species = "WEEDLE", level = 7 },
        },
        {
          { species = "METAPOD", level = 10 },
          { species = "KAKUNA", level = 10 },
          { species = "CATERPIE", level = 10 },
        },
      },
    },
    OPP_RIVAL3 = {
      parties = {
        {
          { species = "PIDGEOT", level = 61 },
          { species = "ALAKAZAM", level = 59 },
          { species = "RHYDON", level = 61 },
          { species = "ARCANINE", level = 61 },
          { species = "EXEGGUTOR", level = 61 },
          { species = "BLASTOISE", level = 65 },
        },
      },
    },
  },
}

local function clone(value)
  return SaveState.clone(value)
end

local function settings(profile, seedText, overrides)
  local result = assert(General.preset(profile))
  result.randomizer = "on"
  result.preset = profile
  result.seed_mode = "manual"
  result.seed_text = seedText
  result.generate_spoiler_log = "off"
  for key, value in pairs(overrides or {}) do result[key] = value end
  if overrides and next(overrides) then result.preset = "custom" end
  return result
end

function Harness.request(seedText, profile, overrides, sourceOverrides)
  local requestSources = clone(sources)
  for key, value in pairs(sourceOverrides or {}) do
    requestSources[key] = clone(value)
  end
  return {
    contractVersion = Constants.CONTRACT_VERSION,
    seed = { canonical = seedText },
    settings = settings(profile, seedText, overrides),
    species = clone(species),
    sources = requestSources,
  }
end

function Harness.hash(value)
  return Hash128.digest(Canonical.encode(value)).hex
end

function Harness.warningCodes(result)
  local output = {}
  for index, warning in ipairs(result.diagnostics.warnings or {}) do
    output[index] = warning.code
  end
  return output
end

function Harness.reversedMaps(value)
  if type(value) ~= "table" then return value end
  local keys = StableSort.keys(value)
  local output = {}
  for index = #keys, 1, -1 do
    local key = keys[index]
    output[key] = Harness.reversedMaps(value[key])
  end
  return output
end

Harness.species = species
Harness.sources = sources

return Harness
