-- Pure index and interactive spoiler-browser navigation tests.
local function loadFactory(path, ...)
  local chunk, err = loadfile(path)
  assert(chunk, err)
  local value = chunk()
  if type(value) == "function" then return value(...) end
  return value
end

local Constants = loadFactory("src/constants.lua")
local StableSort = loadFactory("src/stable_sort.lua")
local ItemFilter = loadFactory("src/item_filter.lua")
local StaticCatalog = loadFactory("src/static_gift_catalog.lua")
local TradeCatalog = loadFactory("src/trade_prize_catalog.lua")
local Browser = loadFactory(
  "src/spoiler_browser.lua", StableSort, StaticCatalog, TradeCatalog,
  ItemFilter)
local BrowserScreen = loadFactory(
  "src/spoiler_browser_screen.lua", Constants, Browser)
assert(BrowserScreen.searchFooter == "SEARCH:SELECT")
assert(BrowserScreen.abbreviateLocation("Route 1") == "Route 1")
assert(BrowserScreen.abbreviateLocation("Cerulean Trade House")
    == "Cer. Trade Hse."
  and #BrowserScreen.abbreviateLocation("Celadon Mansion Roof House") <= 16
  and #BrowserScreen.abbreviateLocation("Game Corner Prize Room") <= 16,
  "location names over 16 characters are meaningfully abbreviated")
local markerX, markerY = BrowserScreen.markerXY({ x = 4, y = 4 })
assert(markerX == 48 and markerY == 40,
  "Town Map markers include the two-tile X and one-tile Y origin offset")
local outerA, innerA = BrowserScreen.cursorColors(0)
local outerB, innerB = BrowserScreen.cursorColors(8)
assert(outerA[1] == 0 and innerA[1] == 1
  and outerB[1] == 1 and innerB[1] == 0,
  "Town Map cursor swaps black and white frame rings every flash phase")
local cursorFrames = BrowserScreen.cursorFrames(markerX, markerY)
assert(cursorFrames[1].x >= markerX
  and cursorFrames[1].y >= markerY
  and cursorFrames[1].x + cursorFrames[1].width <= markerX + 8
  and cursorFrames[1].y + cursorFrames[1].height <= markerY + 8
  and cursorFrames[2].x >= markerX
  and cursorFrames[2].y >= markerY
  and cursorFrames[2].x + cursorFrames[2].width <= markerX + 8
  and cursorFrames[2].y + cursorFrames[2].height <= markerY + 8,
  "Town Map cursor stays entirely inside one 8x8 map block")
local spacedLayout = BrowserScreen.listLayout(true)
assert(spacedLayout.rows == 4
  and spacedLayout.secondaryOffset >= 10
  and spacedLayout.stride >= 24,
  "two-line browser rows leave vertical space within and between entries")

local run = {
  enabled = true,
  checksum = {
    version = "fnv1a32x4-save-v1",
    value = "11111111111111111111111111111111",
  },
  seed = {
    canonical = "CACHE TEST",
    hash128 = "22222222222222222222222222222222",
  },
  settings = {
    generate_spoiler_log = "on",
    wild_pokemon = "global_map",
    wild_levels = "unchanged",
    fishing = "randomized",
    starters = "random",
    static_pokemon = "randomized",
    gift_pokemon = "randomized",
    in_game_trades = "both_sides",
    game_corner_pokemon = "randomized",
    trainer_pokemon = "by_slot",
    starter_level = 5,
  },
  mappings = {
    wildGlobal = { PIDGEY = "SNORLAX" },
    wildAreaSlots = {},
    fishing = {
      global = { MAGIKARP = "SNORLAX" },
      slots = {},
    },
    starters = {
      LEFT = { species = "SNORLAX", level = 5 },
    },
    staticEncounters = {
      SNORLAX_ROUTE_12 = {
        sourceSpecies = "SNORLAX", species = "PIKACHU",
        level = 30, mapId = "ROUTE_12",
      },
    },
    gifts = {
      CELADON_EEVEE = {
        sourceSpecies = "EEVEE", species = "SNORLAX",
        level = 25, mapId = "CELADON_MANSION_ROOF_HOUSE",
      },
    },
    trades = {
      TRADE_01_TERRY = {
        requested = { sourceSpecies = "NIDORINO", species = "PIKACHU" },
        received = { sourceSpecies = "NIDORINA", species = "SNORLAX" },
      },
    },
    prizes = {
      GAME_CORNER_RED_1 = {
        sourceSpecies = "ABRA", species = "SNORLAX",
        sourceLevel = 9, level = 9, sourceCost = 180, cost = 500,
      },
    },
    trainerParties = {
      OPP_YOUNGSTER = {
        [1] = {
          { sourceSlot = 1, species = "SNORLAX", level = 7 },
        },
      },
    },
    pokemonMechanics = {
      SNORLAX = {
        evolutions = {
          { species = "PIKACHU", method = "LEVEL", level = 35 },
        },
      },
    },
    fieldItems = {
      {
        kind = "visible", mapId = "ROUTE_1", objectIndex = 2,
        original = "POTION", item = "ANTIDOTE",
      },
      {
        kind = "scripted", id = "brock_tm", mapId = "ROUTE_1_GATE",
        original = "TM_BIDE", item = "ANTIDOTE", battle = true,
      },
      {
        kind = "shop", mapId = "ROUTE_1_GATE", pointerId = "TestMart",
        talkKey = "CLERK", slot = 1, original = "POKE_BALL",
        item = "POTION", price = 100,
      },
    },
  },
}

local sources = {
  items = {
    ANTIDOTE = { id = "ANTIDOTE", name = "Antidote" },
    POTION = { id = "POTION", name = "Potion", price = 300 },
    POKE_BALL = { id = "POKE_BALL", name = "Poke Ball", price = 200 },
    TM_BIDE = { id = "TM_BIDE", name = "TM34", price = 2000,
      machine = { kind = "TM" } },
    FLOOR_1F = { id = "FLOOR_1F", name = "1F" },
    FLOOR_B2F = { id = "FLOOR_B2F", name = "B2F" },
    FLOOR_ROOF = { id = "FLOOR_ROOF", name = "ROOF" },
    UNUSED_ITEM_1 = { id = "UNUSED_ITEM_1", name = "?????" },
    UNUSED_ITEM_2 = { id = "UNUSED_ITEM_2", label = "?????" },
  },
  species = {
    PIDGEY = { dex = 16, name = "Pidgey" },
    SNORLAX = { dex = 143, name = "Snorlax" },
    PIKACHU = { dex = 25, name = "Pikachu" },
    MAGIKARP = { dex = 129, name = "Magikarp" },
    MODMON = { name = "Modmon" },
  },
  encounters = {
    ROUTE_1 = {
      grass = {
        buckets = { 128, 256 },
        slots = {
          { species = "PIDGEY", level = 3 },
          { species = "PIDGEY", level = 5 },
        },
      },
    },
  },
  trainers = {
    OPP_YOUNGSTER = {
      parties = {
        {
          { species = "PIDGEY", level = 6 },
        },
      },
    },
  },
  maps = {
    ROUTE_1 = {
      label = "Route 1",
      objects = {
        { trainerClass = "OPP_YOUNGSTER", trainerParty = 1 },
        { index = 2, item = "POTION" },
      },
    },
    ROUTE_1_GATE = { label = "TestMart", name = "Route 1 Gate", objects = {} },
  },
  field = {
    fishing = {
      OLD_ROD = { always = { species = "MAGIKARP", level = 5 } },
      GOOD_ROD = {
        pool = {
          { species = "PIDGEY", level = 10 },
          { species = "MAGIKARP", level = 10 },
        },
      },
      SUPER_ROD = { perMap = "superRodData" },
    },
    superRodData = {
      ROUTE_1 = {
        { species = "PIDGEY", level = 10 },
        { species = "MAGIKARP", level = 15 },
      },
    },
    trades = {
      [1] = { give = "NIDORINO", get = "NIDORINA" },
    },
    townMap = {
      locations = {
        ROUTE_1 = { x = 4, y = 4, name = "ROUTE 1" },
        ROUTE_1_GATE = { x = 4, y = 4, name = "ROUTE 1" },
        ROUTE_12 = { x = 12, y = 7, name = "ROUTE 12" },
        OAKS_LAB = { x = 3, y = 12, name = "PALLET TOWN" },
        ROUTE_11_GATE_2F = { x = 11, y = 7, name = "ROUTE 11" },
        CELADON_MANSION_ROOF_HOUSE = {
          x = 5, y = 5, name = "CELADON CITY",
        },
        GAME_CORNER_PRIZE_ROOM = {
          x = 5, y = 5, name = "CELADON CITY",
        },
      },
    },
  },
  textPointers = {
    TestMart = { CLERK = { mart = { "POKE_BALL" } } },
  },
  scriptedItems = {
    { id = "brock_tm", mapId = "ROUTE_1_GATE", item = "TM_BIDE",
      battle = true },
  },
  gameVersion = "red",
}

local index = Browser.build(run, sources)
for _, item in ipairs(index.items) do
  assert(item.id ~= "FLOOR_1F" and item.id ~= "FLOOR_B2F"
      and item.id ~= "FLOOR_ROOF" and item.id ~= "UNUSED_ITEM_1"
      and item.id ~= "UNUSED_ITEM_2",
    "spoiler item index excludes non-item registry entries")
end
assert(#index.species == 5)
assert(index.species[1].id == "PIDGEY")
assert(index.species[4].id == "SNORLAX")
assert(index.species[5].id == "MODMON",
  "species without a dex number sort alphabetically after numbered species")
assert(index.species[4].evolutions[1].species == "PIKACHU"
  and index.species[4].evolutions[1].level == 35,
  "Pokemon index uses the finalized randomized evolution data")

local routeWild = index.maps.ROUTE_1.tabs.grass
assert(#routeWild == 1,
  "identical destination/source rows collapse into one map entry")
assert(math.abs(routeWild[1].chance - 100) < 0.001)
assert(routeWild[1].minLevel == 3 and routeWild[1].maxLevel == 5)
assert(#routeWild[1].slots == 2)
assert(routeWild[1].species == "SNORLAX")

local snorlaxLocations = index.locationsBySpecies.SNORLAX
local found = {}
for _, location in ipairs(snorlaxLocations) do found[location.mapId] = location end
assert(found.ROUTE_1 and found.ROUTE_1.summary:find("GRASS", 1, true))
assert(found["*"] and found["*"].label == "Any fishable area")
assert(found.OAKS_LAB and found.CELADON_MANSION_ROOF_HOUSE)
assert(found.ROUTE_11_GATE_2F and found.GAME_CORNER_PRIZE_ROOM)
assert(not found.ROUTE_12,
  "species mode indexes randomized destinations, not source species")

assert(#index.maps.ROUTE_1.tabs.trainers == 1)
local trainer = index.maps.ROUTE_1.tabs.trainers[1]
assert(trainer.label == "Youngster - 1")
assert(trainer.party[1].species == "SNORLAX"
  and trainer.party[1].level == 7)

local routeArea
for _, area in ipairs(index.areas) do
  if area.name == "ROUTE 1" then routeArea = area break end
end
assert(routeArea and #routeArea.maps == 2,
  "area lists retain only buildings/maps with spoiler content")
local routeTabs = BrowserScreen.availableTabs(index, index.maps.ROUTE_1)
assert(#routeTabs == 6
  and routeTabs[1] == "grass"
  and routeTabs[2] == "old_rod"
  and routeTabs[3] == "good_rod"
  and routeTabs[4] == "super_rod"
  and routeTabs[5] == "trainers"
  and routeTabs[6] == "items",
  "map tab carousel omits every empty category")
local routeFishing = index.maps.ROUTE_1.tabs.super_rod
local fishingTotal, noBite = 0, nil
for _, row in ipairs(routeFishing) do
  fishingTotal = fishingTotal + row.chance
  if row.kind == "fishing_no_bite" then noBite = row end
end
assert(#routeFishing == 3
  and noBite and math.abs(noBite.chance - (200 / 3)) < 0.001
  and math.abs(fishingTotal - 100) < 0.001,
  "rod tab includes Pokemon odds and the remaining no-bite chance")
local labTabs = BrowserScreen.availableTabs(index, index.maps.OAKS_LAB)
assert(#labTabs == 1 and labTabs[1] == "starters",
  "single-category maps expose only their populated tab")
local starterRow = index.maps.OAKS_LAB.tabs.starters[1]
local starterPreview = BrowserScreen.new(
  game or {}, { index = index }, { Font = {}, Theme = {} })
assert(BrowserScreen.rowSecondary(starterPreview, starterRow)
    == "Snorlax LV. 5"
  and BrowserScreen.isInlineTab("starters"),
  "starter rows show Pokemon and level inline without drill-down")
local giftRow = index.maps.CELADON_MANSION_ROOF_HOUSE.tabs.gifts[1]
assert(BrowserScreen.rowSecondary(starterPreview, giftRow)
    == "Snorlax LV. 25"
  and BrowserScreen.isInlineTab("gifts"),
  "gift rows show Pokemon and level inline without drill-down")
local lola = index.maps.CERULEAN_TRADE_HOUSE.tabs.trades[1]
local lolaLines = BrowserScreen.tradeLines(
  BrowserScreen.new(game or {}, { index = index }, { Font = {}, Theme = {} }),
  lola)
assert(#lolaLines == 5
  and lolaLines[1] == "07 Lola"
  and lolaLines[2] == "REQUESTED"
  and lolaLines[3] == "Poliwhirl"
  and lolaLines[4] == "RECEIVED"
  and lolaLines[5] == "Jynx",
  "trade tabs expose complete inline offers without a repeated Trade prefix")
assert(BrowserScreen.isInlineTab("trades"),
  "trade rows do not open a separate detail screen")
local itemRow = index.maps.ROUTE_1.tabs.items[1]
assert(itemRow.label == "Antidote"
  and BrowserScreen.rowSecondary(starterPreview, itemRow) == "ITEM BALL"
  and BrowserScreen.isInlineTab("items"),
  "field items appear inline on their map without drill-down")

local pressed = {}
local stack = {
  pushed = {},
  pops = 0,
  push = function(self, value) self.pushed[#self.pushed + 1] = value end,
  pop = function(self) self.pops = self.pops + 1 end,
}
local game = {
  input = {
    wasPressed = function(_, action) return pressed[action] == true end,
  },
  stack = stack,
}
local namingOptions
local ui = {
  NamingScreen = {
    new = function(_, options)
      namingOptions = options
      return { kind = "naming" }
    end,
  },
  Font = {},
  Theme = { cursor = 0xED },
}
local screen = BrowserScreen.new(game, { index = index }, ui)
assert(screen.mode == "root")
assert(#screen.rows == 3 and screen.rows[1].label == "POKEMON"
  and screen.rows[2].label == "ITEMS" and screen.rows[3].label == "MAP",
  "spoiler root offers Pokemon, Items, and Map")
local returnedToPause
local pauseScreen = BrowserScreen.new(game, {
  index = index,
  onCancel = function(activeGame) returnedToPause = activeGame end,
}, ui)
local popsBeforePauseReturn = stack.pops
pauseScreen:back()
assert(stack.pops == popsBeforePauseReturn + 1
    and returnedToPause == game,
  "root-level B closes the spoiler browser and invokes its return action")
local itemScreen = BrowserScreen.new(game, { index = index }, ui)
itemScreen.selection = 2
itemScreen:choose()
assert(itemScreen.mode == "items" and #itemScreen.rows == 4
  and itemScreen.rows[1].item.id == "ANTIDOTE"
  and itemScreen.rows[3].item.id == "POTION"
  and itemScreen.rows[4].item.id == "TM_BIDE",
  "item browser lists every merged item alphabetically")
itemScreen:openSearch("items")
assert(namingOptions and namingOptions.title == "ITEM SEARCH")
namingOptions.onDone("anti")
assert(itemScreen.itemSearch == "ANTI" and #itemScreen.rows == 1)
itemScreen:choose()
assert(itemScreen.mode == "item_locations" and #itemScreen.rows == 2
  and itemScreen.rows[1].label == "Route 1"
  and itemScreen.rows[1].right == "ITEM BALL"
  and itemScreen.rows[2].right == "GYM REWARD",
  "selecting an item opens all current locations with source type inline")
itemScreen:choose()
assert(itemScreen.mode == "item_locations",
  "item locations do not add another drill-down screen")
local shopLocation
for _, location in ipairs(index.locationsByItem.POTION or {}) do
  if location.sourceKind == "shop" then shopLocation = location break end
end
assert(shopLocation and BrowserScreen.rowSecondary(itemScreen, shopLocation)
    == "SHOP Y100",
  "item locations include current randomized shop stock and price")
assert(BrowserScreen.rowSecondary(screen, routeWild[1])
  == "100 PCT LV.3-5",
  "encounter rows use their second line for current level information")
local grassLines = BrowserScreen.encounterLines(routeWild[1])
assert(#grassLines == 2
  and grassLines[1] == "50 PCT LV. 3"
  and grassLines[2] == "50 PCT LV. 5",
  "grass list shows one combined percentage line per current level")
local vanillaStatic = index.maps.POWER_PLANT.tabs.statics[1]
assert(BrowserScreen.rowSecondary(screen, vanillaStatic)
  == Browser.speciesName(vanillaStatic.species, sources.species),
  "unchanged entries show their Pokemon instead of a vanilla status label")
local staticLocations = index.locationsBySpecies[vanillaStatic.species]
local powerPlantStatic
for _, location in ipairs(staticLocations or {}) do
  if location.mapId == "POWER_PLANT" then
    powerPlantStatic = location
    break
  end
end
assert(powerPlantStatic
  and powerPlantStatic.summary:find("STATIC %- VOLTORB"),
  "Pokemon locations identify static encounters directly")
local staticScreen = BrowserScreen.new(game, { index = index }, ui)
staticScreen.mode = "locations"
staticScreen.rows = { { location = powerPlantStatic } }
staticScreen:choose()
assert(staticScreen.mode == "locations",
  "static Pokemon locations do not drill down")
pressed.a = true
screen:update()
pressed = {}
assert(screen.mode == "pokemon")
pressed.select = true
screen:update()
pressed = {}
assert(namingOptions and namingOptions.title == "POKEMON SEARCH")
namingOptions.onDone("snor")
assert(screen.search == "SNOR" and #screen.rows == 1)
assert(screen.rows[1].species.id == "SNORLAX")
pressed.a = true
screen:update()
pressed = {}
assert(screen.mode == "locations" and #screen.rows >= 5)
assert(screen.rows[1].section and screen.rows[1].label == "EVOLUTIONS"
  and screen.rows[2].label == "Pikachu"
  and screen.rows[2].right == "LV.35"
  and screen.rows[3].section and screen.rows[3].label == "LOCATIONS",
  "Pokemon details show finalized evolutions before locations")
local firstLocationSelection = screen.selection
screen:move(-1)
assert(screen.selection == firstLocationSelection,
  "Pokemon location cursor skips non-interactive evolution rows")
assert(BrowserScreen.evolutionTrigger({ item = "THUNDER_STONE" })
    == "THUNDER ST."
  and BrowserScreen.evolutionTrigger({ method = "TRADE" }) == "TRADE",
  "evolution triggers are readable within the in-game screen width")
local routeLocationIndex
for indexValue, row in ipairs(screen.rows) do
  if row.location and row.location.mapId == "ROUTE_1" then
    routeLocationIndex = indexValue
    break
  end
end
assert(routeLocationIndex)
screen.selection = routeLocationIndex
screen:choose()
assert(screen.mode == "locations",
  "wild Pokemon locations do not drill down")
local routeLocation = screen.rows[routeLocationIndex].location
local routeLines = BrowserScreen.locationLines(screen, routeLocation)
assert(routeLines[1] == "GRASS"
  and routeLines[2] == "50 PCT LV. 3"
  and routeLines[3] == "50 PCT LV. 5",
  "Pokemon location list shows a row for every level at that location")
screen:back()

screen:openTabs(index.maps.ROUTE_1)
screen.tabIndex = 1
screen.rows = index.maps.ROUTE_1.tabs.grass
screen.selection = 1
screen:choose()
assert(screen.mode == "tabs",
  "grass entries do not open a separate detail screen")
screen.tabIndex = 5
screen.rows = index.maps.ROUTE_1.tabs.trainers
screen.selection = 1
screen:choose()
assert(screen.mode == "details")
local detail = table.concat(screen.rows, "\n")
assert(screen.detailTitle == "Youngster - 1"
  and not detail:find("Youngster", 1, true),
  "trainer identity appears only once as the detail title")
assert(not detail:find("Pidgey", 1, true)
  and detail:find("Snorlax", 1, true)
  and detail:find("LV.7", 1, true))
assert(not detail:find("RANDOMIZED", 1, true)
  and not detail:find("VANILLA", 1, true))

local tradeScreen = BrowserScreen.new(game, { index = index }, ui)
tradeScreen.mode = "locations"
tradeScreen.rows = {
  {
    location = {
      rows = { lola },
    },
  },
}
tradeScreen:choose()
assert(tradeScreen.mode == "locations",
  "trade Pokemon locations do not drill down")
local tradeLocationLines = BrowserScreen.locationLines(
  tradeScreen, tradeScreen.rows[1].location)
assert(#tradeLocationLines == 5
  and tradeLocationLines[1] == "Trade 07 Lola"
  and tradeLocationLines[2] == "REQUESTED"
  and tradeLocationLines[3] == "Poliwhirl"
  and tradeLocationLines[4] == "RECEIVED"
  and tradeLocationLines[5] == "Jynx",
  "Pokemon trade location contains the complete offer inline")

local prizeScreen = BrowserScreen.new(game, { index = index }, ui)
local prizeLocation = found.GAME_CORNER_PRIZE_ROOM
prizeScreen.mode = "locations"
prizeScreen.rows = {
  {
    location = prizeLocation,
  },
}
prizeScreen:choose()
assert(prizeScreen.mode == "locations",
  "prize Pokemon locations do not drill down")
local prizeLocationLines = BrowserScreen.locationLines(
  prizeScreen, prizeLocation)
assert(#prizeLocationLines == 4
  and prizeLocationLines[1] == "Game Corner Red 1"
  and prizeLocationLines[2] == "Snorlax"
  and prizeLocationLines[3] == "LV. 9"
  and prizeLocationLines[4] == "500 COINS",
  "Pokemon prize location contains the current prize inline")

local starterLocation = found.OAKS_LAB
local starterLocationScreen = BrowserScreen.new(game, { index = index }, ui)
starterLocationScreen.mode = "locations"
starterLocationScreen.rows = { { location = starterLocation } }
starterLocationScreen:choose()
assert(starterLocationScreen.mode == "locations",
  "starter Pokemon locations do not drill down")
local giftLocation = found.CELADON_MANSION_ROOF_HOUSE
local giftLocationScreen = BrowserScreen.new(game, { index = index }, ui)
giftLocationScreen.mode = "locations"
giftLocationScreen.rows = { { location = giftLocation } }
giftLocationScreen:choose()
assert(giftLocationScreen.mode == "locations",
  "gift Pokemon locations do not drill down")

Browser.clearCache()
sources.cacheIdentity = "merged-revision-1"
sources.saveIdentity = "save-1"
local cachedFirst = Browser.buildCached(run, sources)
local cachedSecond = Browser.buildCached(run, sources)
local cacheStats = Browser.cacheStats()
assert(cachedFirst == cachedSecond
    and cacheStats.builds == 1 and cacheStats.hits == 1,
  "two opens of one immutable run must reuse the spoiler index")

local priorBuilds = cacheStats.builds
sources.gameVersion = "blue"
assert(Browser.buildCached(run, sources) ~= cachedFirst)
assert(Browser.cacheStats().builds == priorBuilds + 1,
  "active game-version changes must invalidate the spoiler index")
sources.gameVersion = "red"
Browser.buildCached(run, sources)
priorBuilds = Browser.cacheStats().builds
sources.saveIdentity = "save-2"
Browser.buildCached(run, sources)
assert(Browser.cacheStats().builds == priorBuilds + 1,
  "switching loaded saves must invalidate the spoiler index")
priorBuilds = Browser.cacheStats().builds
sources.cacheIdentity = "merged-revision-2"
Browser.buildCached(run, sources)
assert(Browser.cacheStats().builds == priorBuilds + 1,
  "merged-data identity changes must invalidate the spoiler index")
priorBuilds = Browser.cacheStats().builds
local regenerated = {}
for key, value in pairs(run) do regenerated[key] = value end
regenerated.checksum = {
  version = run.checksum.version,
  value = "33333333333333333333333333333333",
}
Browser.buildCached(regenerated, sources)
assert(Browser.cacheStats().builds == priorBuilds + 1,
  "regenerated mapping identity must invalidate the spoiler index")
assert(run._spoilerIndexCache == nil
    and run._backgroundCache == nil
    and run.checksum.value == "11111111111111111111111111111111",
  "runtime caches must not add data to the saved run")

local previousLove = rawget(_G, "love")
local imageBuilds, quadBuilds = 0, 0
local quadFailure = false
_G.love = {
  graphics = {
    newImage = function(path)
      imageBuilds = imageBuilds + 1
      local width = path == "misaligned.png" and 10 or 16
      return {
        getDimensions = function() return width, 8 end,
      }
    end,
    newQuad = function(...)
      quadBuilds = quadBuilds + 1
      if quadFailure then error("bad mod-supplied tileset") end
      return { ... }
    end,
  },
}
BrowserScreen.clearBackgroundCache()
local backgroundIndex = {
  townMap = {
    background = {
      tiles = { path = "town.png", identity = "town-asset-v1" },
      map = { 0, 1 },
    },
  },
}
local backgroundFirst = BrowserScreen.new(
  game, { index = backgroundIndex }, ui)
local backgroundSecond = BrowserScreen.new(
  game, { index = backgroundIndex }, ui)
local backgroundStats = BrowserScreen.backgroundCacheStats()
assert(backgroundFirst.background and backgroundSecond.background)
assert(backgroundFirst.background.image == backgroundSecond.background.image)
assert(imageBuilds == 1 and quadBuilds == 2
    and backgroundStats.imageBuilds == 1
    and backgroundStats.quadBuilds == 2
    and backgroundStats.hits == 1,
  "two opens must reuse one image and its already-built quads")

local misaligned = BrowserScreen.new(game, { index = {
  townMap = {
    background = {
      tiles = {
        path = "misaligned.png",
        identity = "misaligned-asset",
      },
      map = { 0 },
    },
  },
}}, ui)
assert(misaligned.background == nil,
  "non-8x8-aligned images must use the plain fallback map")
local quadsBeforeFailure = quadBuilds
quadFailure = true
local badQuad = BrowserScreen.new(game, { index = {
  townMap = {
    background = {
      tiles = { path = "bad-quad.png", identity = "bad-quad-asset" },
      map = { 0, 1 },
    },
  },
}}, ui)
quadFailure = false
assert(badQuad.background == nil and quadBuilds == quadsBeforeFailure + 1,
  "quad construction failure must be contained by the fallback map")
_G.love = previousLove

local measurementIterations = 500
local uncachedStarted = os.clock()
for _ = 1, measurementIterations do Browser.build(run, sources) end
local uncachedElapsed = os.clock() - uncachedStarted
Browser.clearCache()
local cachedStarted = os.clock()
for _ = 1, measurementIterations do Browser.buildCached(run, sources) end
local cachedElapsed = os.clock() - cachedStarted
print(("spoiler_browser_cache_measure: %d opens uncached %.4fs, cached %.4fs")
  :format(measurementIterations, uncachedElapsed, cachedElapsed))

print("spoiler_browser_test: ok")
