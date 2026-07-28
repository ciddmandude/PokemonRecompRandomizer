-- Milestone-7 global wild generation and runtime integration tests.
local function loadFactory(path, ...)
  local chunk, err = loadfile(path)
  assert(chunk, err)
  local value = chunk()
  if type(value) == "function" then return value(...) end
  return value
end

local function sameMap(left, right)
  for key, value in pairs(left) do
    assert(right[key] == value, "mapping differs at " .. tostring(key))
  end
  for key, value in pairs(right) do
    assert(left[key] == value, "mapping differs at " .. tostring(key))
  end
end

local Constants = loadFactory("src/constants.lua")
local UInt32 = loadFactory("src/uint32.lua")
local Hash128 = loadFactory("src/hash128.lua", Constants, UInt32)
local StableSort = loadFactory("src/stable_sort.lua")
local Canonical = loadFactory("src/canonical.lua", StableSort)
local Rng = loadFactory("src/rng.lua", Constants, UInt32, Hash128)
local VanillaSpecies = loadFactory("src/vanilla_species.lua")
local Manifest = loadFactory("src/species_manifest.lua",
  Constants, StableSort, Canonical, Hash128, VanillaSpecies)
local Filters = loadFactory("src/species_filters.lua")
local WildGlobal = loadFactory(
  "src/wild_global.lua", StableSort, Filters)
local WildRuntime = loadFactory("src/wild_runtime.lua")
local Fixture = loadFactory("tests/species_fixture.lua")

local manifest = Manifest.build(Fixture.records, {
  poolMode = "merged",
  metadata = {},
})
local encounters = {
  ROUTE_2 = {
    grass = {
      rate = 25,
      slots = {
        { level = 4, species = "BULBASAUR" },
        { level = 6, species = "CHARMANDER" },
      },
    },
  },
  ROUTE_1 = {
    grass = {
      rate = 30,
      slots = {
        { level = 3, species = "BULBASAUR" },
        { level = 5, species = "IVYSAUR" },
      },
    },
    water = {
      rate = 10,
      slots = {
        { level = 12, species = "CHARIZARD" },
      },
    },
    fishing = {
      slots = {{ level = 99, species = "MODMON" }},
    },
  },
}
local settings = {
  wild_pokemon = "global_map",
  similar_strength = "off",
  legendaries = "allow",
  duplicate_policy = "one_to_one",
}

local first = WildGlobal.generate(
  manifest, encounters, settings, Rng.fromSeed("MILESTONE 7", "wild.global"))
local reordered = {
  ROUTE_1 = encounters.ROUTE_1,
  ROUTE_2 = encounters.ROUTE_2,
}
local second = WildGlobal.generate(
  manifest, reordered, settings, Rng.fromSeed("MILESTONE 7", "wild.global"))
sameMap(first.mapping, second.mapping)
assert(first.sourceCount == 4)
assert(first.mappedCount == 4)
assert(first.mapping.BULBASAUR ~= nil)
assert(first.mapping.CHARIZARD ~= nil,
  "surf species must participate in global mapping")
assert(first.mapping.MODMON == nil,
  "fishing records must remain isolated from M7")

local destinations = {}
for _, destination in pairs(first.mapping) do
  assert(not destinations[destination],
    "one-to-one mode duplicated a destination before exhaustion")
  destinations[destination] = true
end

local vanilla = { species = "BULBASAUR", level = 3, slot = 2 }
local run = {
  enabled = true,
  settings = { wild_pokemon = "global_map" },
  mappings = {
    wildGlobal = first.mapping,
    wildAreaSlots = {
      ROUTE_1 = { grass = { [2] = { level = 3 } } },
    },
  },
}
vanilla.slotIndex = 2
local resolved = WildRuntime.resolve(
  vanilla, { terrain = "grass", mapId = "ROUTE_1" }, run)
assert(resolved ~= vanilla, "mapped records must be copied")
assert(resolved.species == first.mapping.BULBASAUR)
assert(resolved.level == 3 and resolved.slot == 2,
  "species transform must preserve levels and other fields")
assert(vanilla.species == "BULBASAUR",
  "runtime transform must not mutate engine records")

local surf = WildRuntime.resolve(
  vanilla, { terrain = "water" }, run)
assert(surf.species == first.mapping.BULBASAUR)
assert(WildRuntime.resolve(vanilla, { terrain = "fishing" }, run) == vanilla)
run.settings.wild_pokemon = "off"
assert(WildRuntime.resolve(vanilla, { terrain = "grass" }, run) == vanilla)

local allowSettings = {
  wild_pokemon = "global_map",
  similar_strength = "20",
  legendaries = "match",
  duplicate_policy = "allow",
}
local allowed = WildGlobal.generate(
  manifest, encounters, allowSettings,
  Rng.fromSeed("FILTER TEST", "wild.global"))
assert(allowed.mapping.BULBASAUR ~= nil)
assert(allowed.mapping.BULBASAUR ~= "MEW",
  "legendary matching must keep a non-legendary source non-legendary")

local off = WildGlobal.generate(
  manifest, encounters, { wild_pokemon = "off" },
  Rng.fromSeed("OFF", "wild.global"))
assert(next(off.mapping) == nil and off.sourceCount == 0)

-- Named streams are isolated: wild generation cannot advance another stream.
local starterA = Rng.fromSeed("ISOLATION", "starters")
local expected = starterA:nextU32()
WildGlobal.generate(manifest, encounters, settings,
  Rng.fromSeed("ISOLATION", "wild.global"))
local starterB = Rng.fromSeed("ISOLATION", "starters")
assert(starterB:nextU32() == expected)

io.write("wild_global_test: ok\n")
