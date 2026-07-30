-- Remediation M9 explicit progression and access fixtures.
local function loadFactory(path, ...)
  local chunk, err = loadfile(path)
  assert(chunk, err)
  local value = chunk()
  if type(value) == "function" then return value(...) end
  return value
end

local StableSort = loadFactory("src/stable_sort.lua")
local Progression = loadFactory("src/progression.lua", StableSort)

for stage = Progression.STAGES.PEWTER, Progression.STAGES.POSTGAME do
  assert(Progression.GRAPH[stage].previous == stage - 1)
end

local walk = Progression.access("ROUTE_1", "walk", nil, "red")
assert(walk.available and walk.stage == Progression.STAGES.START)
assert(Progression.isPreEliteFour(walk))
assert(Progression.describe(walk):find("Pallet/Viridian", 1, true))
assert(Progression.locationName("ROUTE_11_GATE_2F") == "Route 11 Gate 2F")

local routeOneWater = Progression.access("ROUTE_1", "surf", nil, "red")
assert(routeOneWater.stage == Progression.STAGES.SURF)
assert(routeOneWater.stage > walk.stage)
assert(table.concat(routeOneWater.requirements, ","):find("HM03_SURF", 1, true))
assert(table.concat(routeOneWater.requirements, ","):find("SOUL_BADGE", 1, true))

local oldRod = Progression.access("*", "fish", "OLD_ROD", "red")
local goodRod = Progression.access("*", "fish", "GOOD_ROD", "red")
local superRod = Progression.access("ROUTE_12", "fish", "SUPER_ROD", "red")
assert(oldRod.stage == Progression.STAGES.VERMILION)
assert(goodRod.stage == Progression.STAGES.FUCHSIA)
assert(superRod.stage == Progression.STAGES.FUCHSIA)

local safari = Progression.access("SAFARI_ZONE_EAST", "walk", nil, "red")
assert(safari.stage == Progression.STAGES.FUCHSIA)
assert(table.concat(safari.requirements, ","):find("SAFARI_PASS", 1, true))

local lateStory = Progression.access("VICTORY_ROAD_2F", "walk", nil, "red")
assert(lateStory.stage == Progression.STAGES.VICTORY_ROAD)
assert(Progression.isPreEliteFour(lateStory))

local postgame = Progression.access("CERULEAN_CAVE_B1F", "walk", nil, "red")
assert(postgame.stage == Progression.STAGES.POSTGAME)
assert(postgame.postgame and not Progression.isPreEliteFour(postgame))

local unavailableVersion =
  Progression.access("ROUTE_1", "walk", nil, "yellow")
assert(not unavailableVersion.available)
assert(unavailableVersion.reason == "unsupported version")

local unknown = Progression.access("CUSTOM_MOD_MAP", "walk", nil, "red")
assert(not unknown.available and not unknown.known)
assert(Progression.describe(unknown):find("not present", 1, true))

local ceruleanTrade = Progression.tradeAccess({
  mapId = "CERULEAN_TRADE_HOUSE",
}, "red")
local fuchsiaTrade = Progression.tradeAccess({
  mapId = "ROUTE_18_GATE_2F",
}, "red")
local cinnabarTrade = Progression.tradeAccess({
  mapId = "CINNABAR_LAB_TRADE_ROOM",
}, "red")
assert(ceruleanTrade.stage == Progression.STAGES.CERULEAN)
assert(fuchsiaTrade.stage == Progression.STAGES.FUCHSIA)
assert(cinnabarTrade.stage == Progression.STAGES.SURF)
assert(not Progression.isAvailableAt(routeOneWater, ceruleanTrade.stage))
assert(Progression.isAvailableAt(walk, ceruleanTrade.stage))

print("progression_m9_test: ok")
