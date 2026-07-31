-- Milestone-8 area-slot, fishing, level, coverage, and runtime tests.
local function loadFactory(path, ...)
  local chunk, err = loadfile(path)
  assert(chunk, err)
  local value = chunk()
  if type(value) == "function" then return value(...) end
  return value
end

local Constants = loadFactory("src/constants.lua")
local UInt32 = loadFactory("src/uint32.lua")
local Hash128 = loadFactory("src/hash128.lua", Constants, UInt32)
local StableSort = loadFactory("src/stable_sort.lua")
local Progression = loadFactory("src/progression.lua", StableSort)
local Matching = loadFactory("src/matching.lua", StableSort)
local Canonical = loadFactory("src/canonical.lua", StableSort)
local Rng = loadFactory("src/rng.lua", Constants, UInt32, Hash128)
local VanillaSpecies = loadFactory("src/vanilla_species.lua")
local Manifest = loadFactory("src/species_manifest.lua",
  Constants, StableSort, Canonical, Hash128, VanillaSpecies)
local Filters = loadFactory("src/species_filters.lua")
local WildGlobal = loadFactory(
  "src/wild_global.lua", StableSort, Filters, Matching)
local WildCategory = loadFactory(
  "src/wild_category.lua",
  StableSort, Filters, WildGlobal, Matching, Progression)
local WildRuntime = loadFactory("src/wild_runtime.lua")
local Fixture = loadFactory("tests/species_fixture.lua")

local manifest = Manifest.build(Fixture.records, {
  poolMode = "merged",
  metadata = {},
})
local sources = {
  encounters = {
    ROUTE_1 = {
      grass = {
        rate = 30,
        buckets = { 128, 256 },
        slots = {
          { species = "BULBASAUR", level = 3 },
          { species = "CHARMANDER", level = 5 },
        },
      },
      water = {
        rate = 10,
        slots = {{ species = "IVYSAUR", level = 15 }},
      },
    },
    CERULEAN_CAVE_1F = {
      grass = {
        rate = 15,
        slots = {{ species = "CHARIZARD", level = 70 }},
      },
    },
  },
  field = {
    fishing = {
      OLD_ROD = {
        always = { species = "BULBASAUR", level = 5 },
      },
      GOOD_ROD = {
        pool = {
          { species = "IVYSAUR", level = 10 },
          { species = "CHARMANDER", level = 10 },
        },
      },
      SUPER_ROD = { perMap = "superRod" },
    },
    superRod = {
      ROUTE_1 = {
        { species = "CHARIZARD", level = 20 },
        { species = "BULBASAUR", level = 25 },
      },
    },
  },
}
local settings = {
  wild_pokemon = "area_slots",
  fishing = "randomized",
  wild_levels = "plus_minus_2",
  catchability_guard = "off",
  similar_strength = "off",
  legendaries = "allow",
  duplicate_policy = "one_to_one",
}
local function streams(seed)
  return {
    global = Rng.fromSeed(seed, "wild.global"),
    area = Rng.fromSeed(seed, "wild.area"),
    levels = Rng.fromSeed(seed, "wild.levels"),
  }
end

local generated = WildCategory.generate(
  manifest, sources, settings, streams("MILESTONE 8"))
local grass = generated.wildAreaSlots.ROUTE_1.grass
assert(type(grass[1].species) == "string")
assert(type(grass[2].species) == "string")
assert(grass[1].species ~= grass[2].species,
  "one-to-one area slots must be unique before pool exhaustion")
assert(grass[1].level >= 2 and grass[1].level <= 5)
assert(grass[2].level >= 3 and grass[2].level <= 7)
assert(sources.encounters.ROUTE_1.grass.rate == 30)
assert(sources.encounters.ROUTE_1.grass.buckets[1] == 128,
  "generation must not mutate encounter rates or buckets")
assert(type(generated.fishing.slots.OLD_ROD["*"][1].species) == "string")
assert(type(generated.fishing.slots.GOOD_ROD["*"][2].species) == "string")
assert(type(generated.fishing.slots.SUPER_ROD.ROUTE_1[1].species) == "string")

local reordered = {
  encounters = {
    CERULEAN_CAVE_1F = sources.encounters.CERULEAN_CAVE_1F,
    ROUTE_1 = sources.encounters.ROUTE_1,
  },
  field = sources.field,
}
local generatedAgain = WildCategory.generate(
  manifest, reordered, settings, streams("MILESTONE 8"))
for index = 1, 2 do
  assert(generatedAgain.wildAreaSlots.ROUTE_1.grass[index].species
    == grass[index].species)
  assert(generatedAgain.wildAreaSlots.ROUTE_1.grass[index].level
    == grass[index].level)
end

local duplicateSlots = WildCategory.generate(manifest, {
  encounters = {
    DUPLICATE_ROUTE = {
      grass = {
        rate = 30,
        buckets = { 128, 256 },
        slots = {
          { species = "BULBASAUR", level = 3 },
          { species = "BULBASAUR", level = 3 },
        },
      },
    },
  },
  field = sources.field,
}, settings, streams("DUPLICATE SLOTS"))
assert(type(duplicateSlots.wildAreaSlots.DUPLICATE_ROUTE
  .grass[1].species) == "string")
assert(type(duplicateSlots.wildAreaSlots.DUPLICATE_ROUTE
  .grass[2].species) == "string",
  "0.1.38 RNG tracing must allow duplicate source slots to be generated")

local run = {
  enabled = true,
  settings = {
    wild_pokemon = "area_slots",
    fishing = "randomized",
    wild_levels = "plus_minus_2",
  },
  mappings = {
    wildGlobal = {},
    wildAreaSlots = generated.wildAreaSlots,
    fishing = generated.fishing,
  },
}
local rollCalls = 0
local selected = WildRuntime.roll(function()
  rollCalls = rollCalls + 1
  return { species = "BULBASAUR", level = 3 }
end, sources.encounters.ROUTE_1, {
  mapId = "ROUTE_1", terrain = "grass",
}, run)
assert(rollCalls == 1 and selected.slotIndex == 1,
  "slot identity must be attached after exactly one vanilla roll")
local resolved = WildRuntime.resolve(
  selected, { mapId = "ROUTE_1", terrain = "grass" }, run)
assert(resolved.species == grass[1].species)
assert(resolved.level == grass[1].level,
  "the saved final level must be used by the later repel check")

local rngValues = { 0, 200 }
local rngIndex = 0
local duplicateSelected = WildRuntime.roll(function(_, context)
  context.rng(0, 255)
  context.rng(0, 255)
  return { species = "BULBASAUR", level = 3 }
end, { grass = { slots = {
  { species = "BULBASAUR", level = 3 },
  { species = "BULBASAUR", level = 3 },
}, buckets = { 128, 256 } } }, {
  mapId = "MOD_MAP",
  terrain = "grass",
  rng = function()
    rngIndex = rngIndex + 1
    return rngValues[rngIndex]
  end,
}, run)
assert(duplicateSelected.slotIndex == 2 and rngIndex == 2,
  "the delegated engine bucket roll must identify duplicate slots")

local untracedAmbiguous = WildRuntime.roll(function()
  return { species = "BULBASAUR", level = 3 }
end, { grass = { slots = {
  { species = "BULBASAUR", level = 3 },
  { species = "BULBASAUR", level = 3 },
} } }, { mapId = "OLD_ENGINE", terrain = "grass" }, run)
assert(untracedAmbiguous.slotIndex == nil,
  "engines without an RNG context must safely keep ambiguous slots vanilla")

local fishSource = { species = "IVYSAUR", level = 10 }
local fish = WildRuntime.fishing(fishSource,
  "GOOD_ROD", "ROUTE_1", sources.field.fishing.GOOD_ROD.pool, run)
assert(fish ~= fishSource)
assert(fish.species == generated.fishing.slots.GOOD_ROD["*"][1].species)
assert(fish.level == generated.fishing.slots.GOOD_ROD["*"][1].level)
assert(WildRuntime.fishing(nil,
  "GOOD_ROD", "ROUTE_1", sources.field.fishing.GOOD_ROD.pool, run) == nil,
  "a no-bite fishing result must remain nil")

local scaledSettings = {
  wild_pokemon = "global_map",
  fishing = "vanilla",
  wild_levels = "scaled",
  catchability_guard = "off",
  similar_strength = "off",
  legendaries = "allow",
  duplicate_policy = "allow",
}
local scaled = WildCategory.generate(
  manifest, sources, scaledSettings, streams("SCALED"))
local overlay = scaled.wildAreaSlots.ROUTE_1.grass[1]
assert(overlay.level >= 2 and overlay.level <= 100)
assert(next(scaled.fishing) == nil, "vanilla fishing must have no mapping")

local coverageResult = {
  warnings = {}, fallbackCount = 0, coverageSwaps = 0,
}
local reachableA = { species = "BULBASAUR" }
local reachableB = { species = "BULBASAUR" }
local late = { species = "CHARMANDER" }
WildCategory.repairCoverage({
  { record = reachableA, reachable = true },
  { record = reachableB, reachable = true },
  { record = late, reachable = false },
}, manifest, coverageResult)
assert(coverageResult.coverageSwaps == 1)
assert(reachableA.species == "CHARMANDER"
    or reachableB.species == "CHARMANDER",
  "coverage guard must move a late-only destination into a reachable slot")
assert(late.species == "BULBASAUR")

local globalCoverage = {
  warnings = {}, fallbackCount = 0, coverageSwaps = 0,
}
local mapA = { A = "BULBASAUR", B = "BULBASAUR", C = "CHARMANDER" }
WildCategory.repairGlobalCoverage({
  { mapping = mapA, key = "A", reachable = true },
  { mapping = mapA, key = "B", reachable = true },
  { mapping = mapA, key = "C", reachable = false },
}, manifest, globalCoverage)
assert(globalCoverage.coverageSwaps == 1)
assert(mapA.A == "CHARMANDER" or mapA.B == "CHARMANDER")
assert(mapA.C == "BULBASAUR")

local stageCoverage = {
  warnings = {}, fallbackCount = 0, coverageSwaps = 0,
}
local stageReachableA = { species = "BULBASAUR" }
local stageReachableB = { species = "BULBASAUR" }
local stageLate = { species = "VENUSAUR" }
WildCategory.repairCoverage({
  { record = stageReachableA, reachable = true },
  { record = stageReachableB, reachable = true },
  { record = stageLate, reachable = false },
}, manifest, stageCoverage, true)
assert(stageCoverage.coverageSwaps == 0,
  "coverage repair must not swap across evolutionary stages")
assert(stageLate.species == "VENUSAUR"
    and stageCoverage.warnings[1].code == "WILD_COVERAGE_UNSATISFIED",
  "same-stage coverage must report unsatisfied instead of dropping stage")

local bstCoverage = {
  warnings = {}, fallbackCount = 0, coverageSwaps = 0,
}
local bstReachableA = { species = "BULBASAUR" }
local bstReachableB = { species = "BULBASAUR" }
local bstLate = { species = "VENUSAUR" }
WildCategory.repairCoverage({
  { record = bstReachableA, source = "BULBASAUR", reachable = true },
  { record = bstReachableB, source = "BULBASAUR", reachable = true },
  { record = bstLate, source = "VENUSAUR", reachable = false },
}, manifest, bstCoverage, "bst_50")
assert(bstCoverage.coverageSwaps == 0
    and bstLate.species == "VENUSAUR",
  "coverage repair must not violate an absolute BST range")

io.write("wild_m8_test: ok\n")
