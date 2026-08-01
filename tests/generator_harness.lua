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
local ItemFilter = loadFactory("src/item_filter.lua")
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
local ItemCategory = loadFactory(
  "src/item_category.lua", StableSort, Progression, ItemFilter)
local EvolutionCategory = loadFactory(
  "src/evolution_category.lua", StableSort)
local MechanicsCategory = loadFactory(
  "src/mechanics_category.lua", StableSort, EvolutionCategory)
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
  MechanicsCategory, Progression, ValidationCategory)

local Harness = {
  Constants = Constants,
  Contracts = Contracts,
  Canonical = Canonical,
  Hash128 = Hash128,
  Rng = Rng,
  SaveState = SaveState,
  General = General,
  Generator = Generator,
  Validation = ValidationCategory,
  Progression = Progression,
  TradeCatalog = TradePrizeCatalog,
  ItemFilter = ItemFilter,
  ItemCategory = ItemCategory,
}

local TYPES = {
  "FIRE", "GRASS", "WATER", "ELECTRIC", "NORMAL", "POISON",
  "GROUND", "FLYING", "PSYCHIC", "ICE", "ROCK", "FIGHTING",
}
local LEGENDARY = {
  ARTICUNO = true, ZAPDOS = true, MOLTRES = true,
  MEWTWO = true, MEW = true,
}

local MOVE_IDS = {
  "BIDE", "BUBBLEBEAM", "THUNDERBOLT", "MEGA_DRAIN", "TOXIC",
  "PSYWAVE", "FIRE_BLAST", "FISSURE", "BLIZZARD", "BARRIER",
  "SKY_ATTACK", "CUT", "SURF",
}

local function baseStats(total)
  local keys = { "hp", "attack", "defense", "speed", "special" }
  local value, remainder = math.floor(total / #keys), total % #keys
  local result = {}
  for index, key in ipairs(keys) do
    result[key] = value + (index <= remainder and 1 or 0)
  end
  return result
end

local function compatibility(index)
  local result = {}
  for moveIndex, move in ipairs(MOVE_IDS) do
    -- Deliberately non-uniform columns let the compatibility shuffle produce
    -- observable changes while retaining several machines per species.
    if (index + moveIndex) % 3 ~= 0 then result[#result + 1] = move end
  end
  return result
end

local species = {}
for index, id in ipairs(VanillaSpecies) do
  local bst = 250 + (index * 17) % 351
  species[index] = {
    id = id,
    dex = index,
    bst = bst,
    stats = baseStats(bst),
    types = { TYPES[(index - 1) % #TYPES + 1] },
    stage = "basic",
    legendary = LEGENDARY[id] == true,
    level1Moves = { "TACKLE" },
    learnset = {
      { level = 7, move = "GROWL" },
      { level = 12, move = "QUICK_ATTACK" },
    },
    tmhm = compatibility(index),
    evolutions = {},
  }
end

local speciesById = {}
for _, entry in ipairs(species) do speciesById[entry.id] = entry end

local function setEvolution(sourceId, targetId, method, value)
  local source, target = assert(speciesById[sourceId]), assert(speciesById[targetId])
  local row = { species = targetId, method = method }
  if method == "LEVEL" then row.level = value end
  if method == "ITEM" then row.item = value end
  source.evolutions[#source.evolutions + 1] = row
  if source.stage == "basic" then target.stage = "middle" end
end

local function finishFamily(id) speciesById[id].stage = "final" end

setEvolution("BULBASAUR", "IVYSAUR", "LEVEL", 16)
setEvolution("IVYSAUR", "VENUSAUR", "LEVEL", 32); finishFamily("VENUSAUR")
setEvolution("CHARMANDER", "CHARMELEON", "LEVEL", 16)
setEvolution("CHARMELEON", "CHARIZARD", "LEVEL", 36); finishFamily("CHARIZARD")
setEvolution("SQUIRTLE", "WARTORTLE", "LEVEL", 16)
setEvolution("WARTORTLE", "BLASTOISE", "LEVEL", 36); finishFamily("BLASTOISE")
setEvolution("CATERPIE", "METAPOD", "LEVEL", 7)
setEvolution("METAPOD", "BUTTERFREE", "LEVEL", 10); finishFamily("BUTTERFREE")
setEvolution("WEEDLE", "KAKUNA", "LEVEL", 7)
setEvolution("KAKUNA", "BEEDRILL", "LEVEL", 10); finishFamily("BEEDRILL")
setEvolution("ABRA", "KADABRA", "LEVEL", 16)
setEvolution("KADABRA", "ALAKAZAM", "TRADE"); finishFamily("ALAKAZAM")
setEvolution("MACHOP", "MACHOKE", "LEVEL", 28)
setEvolution("MACHOKE", "MACHAMP", "TRADE"); finishFamily("MACHAMP")
setEvolution("GASTLY", "HAUNTER", "LEVEL", 25)
setEvolution("HAUNTER", "GENGAR", "TRADE"); finishFamily("GENGAR")
setEvolution("POLIWAG", "POLIWHIRL", "LEVEL", 25)
setEvolution("POLIWHIRL", "POLIWRATH", "ITEM", "WATER_STONE"); finishFamily("POLIWRATH")

local sources = {
  gameVersion = "red",
  typeIds = TYPES,
  moves = {
    TACKLE = { type = "NORMAL", power = 35, accuracy = 95, pp = 35, effect = "NONE" },
    GROWL = { type = "NORMAL", power = 0, accuracy = 100, pp = 40, effect = "ATTACK_DOWN" },
    QUICK_ATTACK = { type = "NORMAL", power = 40, accuracy = 100, pp = 30, effect = "PRIORITY" },
    BIDE = { type = "NORMAL", power = 0, accuracy = 100, pp = 10, effect = "BIDE" },
    BUBBLEBEAM = { type = "WATER", power = 65, accuracy = 100, pp = 20, effect = "SPEED_DOWN" },
    THUNDERBOLT = { type = "ELECTRIC", power = 95, accuracy = 100, pp = 15, effect = "PARALYZE" },
    MEGA_DRAIN = { type = "GRASS", power = 40, accuracy = 100, pp = 10, effect = "DRAIN" },
    TOXIC = { type = "POISON", power = 0, accuracy = 85, pp = 10, effect = "TOXIC" },
    PSYWAVE = { type = "PSYCHIC", power = 0, accuracy = 80, pp = 15, effect = "PSYWAVE" },
    FIRE_BLAST = { type = "FIRE", power = 120, accuracy = 85, pp = 5, effect = "BURN" },
    FISSURE = { type = "GROUND", power = 0, accuracy = 30, pp = 5, effect = "OHKO" },
    BLIZZARD = { type = "ICE", power = 120, accuracy = 90, pp = 5, effect = "FREEZE" },
    BARRIER = { type = "PSYCHIC", power = 0, accuracy = 100, pp = 30, effect = "DEFENSE_UP" },
    SKY_ATTACK = { type = "FLYING", power = 140, accuracy = 90, pp = 5, effect = "CHARGE" },
    CUT = { type = "NORMAL", power = 50, accuracy = 95, pp = 30, effect = "NONE" },
    SURF = { type = "WATER", power = 95, accuracy = 100, pp = 15, effect = "NONE" },
    LEECH_SEED = { type = "GRASS", power = 0, accuracy = 90, pp = 10, effect = "LEECH_SEED" },
  },
  items = {
    POTION = {}, ANTIDOTE = {}, ESCAPE_ROPE = {}, SUPER_POTION = {},
    RARE_CANDY = {}, MOON_STONE = {}, WATER_STONE = {},
    FRESH_WATER = {}, SODA_POP = {}, LEMONADE = {},
    TM_BIDE = { machine = { kind = "TM", move = "BIDE" } },
    TM_THUNDERBOLT = { machine = { kind = "TM", move = "THUNDERBOLT" } },
    TM_MEGA_DRAIN = { machine = { kind = "TM", move = "MEGA_DRAIN" } },
    TM_DRAGON_RAGE = { machine = { kind = "TM", move = "DRAGON_RAGE" } },
    TM_HYPER_BEAM = { machine = { kind = "TM", move = "HYPER_BEAM" } },
    TM_SUBSTITUTE = { machine = { kind = "TM", move = "SUBSTITUTE" } },
    HM_CUT = { keyItem = true, machine = { kind = "HM", move = "CUT" } },
    HM_SURF = { keyItem = true, machine = { kind = "HM", move = "SURF" } },
    OAKS_PARCEL = { keyItem = true }, S_S_TICKET = { keyItem = true },
    POKE_FLUTE = { keyItem = true }, SILPH_SCOPE = { keyItem = true },
    CARD_KEY = { keyItem = true }, SECRET_KEY = { keyItem = true },
    BOULDERBADGE = { keyItem = true }, CASCADEBADGE = { keyItem = true },
    THUNDERBADGE = { keyItem = true }, RAINBOWBADGE = { keyItem = true },
    SOULBADGE = { keyItem = true }, MARSHBADGE = { keyItem = true },
    VOLCANOBADGE = { keyItem = true }, EARTHBADGE = { keyItem = true },
  },
  maps = {
    ROUTE_1 = { label = "VIRIDIAN_MART", objects = {
      { index = 1, item = "POTION" }, { index = 2, item = "ANTIDOTE" },
    } },
    VIRIDIAN_FOREST = { objects = {
      { index = 1, item = "ESCAPE_ROPE" }, { index = 2, item = "TM_BIDE" },
    } },
    MT_MOON_1F = { objects = {
      { index = 1, item = "MOON_STONE" }, { index = 2, item = "RARE_CANDY" },
    } },
    CERULEAN_CITY = { label = "CERULEAN_MART", objects = {
      { index = 1, item = "S_S_TICKET" }, { index = 2, item = "TM_MEGA_DRAIN" },
    } },
    VERMILION_CITY = { objects = { { index = 1, item = "HM_CUT" } } },
    POKEMON_TOWER_7F = { objects = { { index = 1, item = "POKE_FLUTE" } } },
    CELADON_CITY = { objects = { { index = 1, item = "SILPH_SCOPE" } } },
    SILPH_CO_7F = { objects = { { index = 1, item = "CARD_KEY" } } },
    FUCHSIA_CITY = { objects = { { index = 1, item = "HM_SURF" } } },
    CINNABAR_ISLAND = { objects = { { index = 1, item = "SECRET_KEY" } } },
  },
  startingPcItems = { POTION = 1 },
  scriptedItems = {
    { id = "brock_badge", mapId = "PEWTER_GYM", item = "BOULDERBADGE", badge = true },
    { id = "misty_badge", mapId = "CERULEAN_GYM", item = "CASCADEBADGE", badge = true },
    { id = "surge_badge", mapId = "VERMILION_GYM", item = "THUNDERBADGE", badge = true },
    { id = "erika_badge", mapId = "CELADON_GYM", item = "RAINBOWBADGE", badge = true },
    { id = "koga_badge", mapId = "FUCHSIA_GYM", item = "SOULBADGE", badge = true },
    { id = "sabrina_badge", mapId = "SAFFRON_GYM", item = "MARSHBADGE", badge = true },
    { id = "blaine_badge", mapId = "CINNABAR_GYM", item = "VOLCANOBADGE", badge = true },
    { id = "giovanni_badge", mapId = "VIRIDIAN_GYM", item = "EARTHBADGE", badge = true },
    { id = "route22_tm", mapId = "ROUTE_22", item = "TM_THUNDERBOLT" },
  },
  textPointers = {
    VIRIDIAN_MART = { clerk = { mart = { "POTION", "ANTIDOTE", "ESCAPE_ROPE" } } },
    CERULEAN_MART = { clerk = { mart = { "POTION", "SUPER_POTION", "RARE_CANDY" } } },
  },
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
    hiddenItems = {
      ROUTE_2 = { { x = 4, y = 7, item = "ANTIDOTE" } },
      MT_MOON_1F = { { x = 11, y = 3, item = "MOON_STONE" } },
      CELADON_CITY = { { x = 8, y = 12, item = "RARE_CANDY" } },
    },
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
