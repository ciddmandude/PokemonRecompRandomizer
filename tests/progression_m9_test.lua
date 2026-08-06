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

local progressionFile = assert(io.open("src/progression.lua", "rb"))
local progressionSource = progressionFile:read("*a")
progressionFile:close()
assert(progressionSource:find(
    "\n  local Progression = {}", 1, true),
  "progression module body must use a two-space indentation level")
assert(not progressionSource:find("\t", 1, true),
  "progression source must not use tab indentation")
for line in (progressionSource .. "\n"):gmatch("(.-)\n") do
  local leading = line:match("^( *)")
  assert(#leading % 2 == 0,
    "progression indentation must use two-space increments")
end

for stage = Progression.STAGES.PEWTER, Progression.STAGES.POSTGAME do
  assert(Progression.GRAPH[stage].previous == stage - 1)
end

local walk = Progression.access("ROUTE_1", "walk", nil, "red")
assert(walk.available and walk.stage == Progression.STAGES.START)
assert(Progression.isPreEliteFour(walk))
assert(Progression.describe(walk):find("Pallet/Viridian", 1, true))
assert(Progression.locationName("ROUTE_11_GATE_2F") == "Route 11 Gate 2F")

local routeTwo = Progression.access("ROUTE_2", "walk", nil, "red")
assert(routeTwo.stage == Progression.STAGES.START,
  "ordinary Route 2 access remains available at the start")
local routeTwoItem = Progression.itemAccess({
  kind = "visible", mapId = "ROUTE_2", objectIndex = 1,
}, "red")
assert(routeTwoItem.stage == Progression.STAGES.VERMILION,
  "Route 2 item balls require the Cut stage")
assert(table.concat(routeTwoItem.requirements, ",")
    == "CASCADE_BADGE,HM01_CUT",
  "Route 2 item balls record both halves of the Cut gate")

local routeTwentyFiveItem = Progression.itemAccess({
  kind = "visible", mapId = "ROUTE_25", original = "TM_SEISMIC_TOSS",
}, "red")
assert(routeTwentyFiveItem.stage == Progression.STAGES.VERMILION
    and table.concat(routeTwentyFiveItem.requirements, ",")
      == "CASCADE_BADGE,HM01_CUT",
  "Route 25's item ball records its Cut gate")

local routeTwelveIsland = Progression.itemAccess({
  kind = "visible", mapId = "ROUTE_12", original = "TM_PAY_DAY",
}, "red")
assert(routeTwelveIsland.stage == Progression.STAGES.SURF
    and table.concat(routeTwelveIsland.requirements, ",")
      == "HM03_SURF,POKE_FLUTE,SOUL_BADGE",
  "Route 12's island item records its Surf gate")

local safariIsland = Progression.itemAccess({
  kind = "visible", mapId = "SAFARI_ZONE_CENTER", original = "NUGGET",
}, "red")
assert(safariIsland.stage == Progression.STAGES.SURF
    and table.concat(safariIsland.requirements, ",")
      == "HM03_SURF,SAFARI_PASS,SOUL_BADGE",
  "Safari Zone Center's island item records its Surf gate")

local dreamEater = Progression.itemAccess({
  kind = "scripted", id = "tm_dream_eater", mapId = "VIRIDIAN_CITY",
  original = "TM_DREAM_EATER",
}, "red")
assert(dreamEater.stage == Progression.STAGES.VERMILION
    and #dreamEater.anyRequirements == 2,
  "Dream Eater records its alternative Cut-or-Surf routes")

local flash = Progression.itemAccess({
  kind = "scripted", id = "hm_flash", mapId = "ROUTE_2_GATE",
  original = "HM_FLASH",
}, "red")
assert(flash.stage == Progression.STAGES.VERMILION
    and table.concat(flash.requirements, ",")
      == "CASCADE_BADGE,CAUGHT_10_POKEMON,HM01_CUT",
  "Oak's Aide check records both Cut access and the caught-count gate")

local routeOneWater = Progression.access("ROUTE_1", "surf", nil, "red")
assert(routeOneWater.stage == Progression.STAGES.SURF)
assert(routeOneWater.stage > walk.stage)
assert(table.concat(routeOneWater.requirements, ",")
    == "HM03_SURF,SOUL_BADGE",
  "surf requirements use deterministic identifier order")

local rockTunnelWater =
  Progression.access("ROCK_TUNNEL_1F", "surf", nil, "red")
assert(table.concat(rockTunnelWater.requirements, ",")
    == "HM03_SURF,HM05_FLASH,SOUL_BADGE",
  "Rock Tunnel requirements are sorted after Surf gates are appended")
local towerWater =
  Progression.access("POKEMON_TOWER_3F", "surf", nil, "red")
assert(table.concat(towerWater.requirements, ",")
    == "HM03_SURF,SILPH_SCOPE,SOUL_BADGE",
  "Pokemon Tower requirements are sorted after Surf gates are appended")
local routeThreeWater =
  Progression.access("ROUTE_3", "surf", nil, "red")
assert(table.concat(routeThreeWater.requirements, ",")
    == "BOULDER_BADGE,HM03_SURF,SOUL_BADGE",
  "route requirements are sorted after Surf gates are appended")

local dojo = Progression.access("FIGHTING_DOJO", "walk", nil, "red")
assert(dojo.stage == Progression.STAGES.LAVENDER_CELADON
  and table.concat(dojo.requirements, ",") == "SAFFRON_ACCESS",
  "Fighting Dojo requires Saffron access, not Silph Co completion")

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

local yellowRoute =
  Progression.access("ROUTE_1", "walk", nil, "yellow")
assert(yellowRoute.available and yellowRoute.stage == Progression.STAGES.START)
local yellowGift = Progression.access(
  "CERULEAN_MELANIES_HOUSE", "walk", nil, "yellow")
assert(yellowGift.available
  and yellowGift.stage == Progression.STAGES.CERULEAN)

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
