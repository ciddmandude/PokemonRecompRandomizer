local function loadFactory(path, ...)
  local chunk, err = loadfile(path)
  assert(chunk, err)
  local value = chunk()
  return type(value) == "function" and value(...) or value
end

local StableSort = loadFactory("src/stable_sort.lua")
local Progression = {
  STAGES = { START = 1, CERULEAN = 3, VERMILION = 4,
    LAVENDER_CELADON = 5, FUCHSIA = 6, SAFFRON = 7,
    SURF = 8, VICTORY_ROAD = 9, POSTGAME = 10 },
  access = function() return { available = true, stage = 1 } end,
}
local ItemCategory = loadFactory("src/item_category.lua", StableSort, Progression)
local ItemRuntime = loadFactory("src/item_runtime.lua")

local sources = {
  items = {
    POTION = { id = "POTION", keyItem = false },
    ANTIDOTE = { id = "ANTIDOTE" },
    TM_BIDE = { id = "TM_BIDE", machine = { kind = "TM" } },
    CARD_KEY = { id = "CARD_KEY", keyItem = true },
  },
  maps = {
    VIRIDIAN_FOREST = { objects = {
      { index = 4, item = "POTION" },
      { index = 5, item = "CARD_KEY" },
    }},
    MT_MOON_1F = { objects = {
      { index = 2, item = "TM_BIDE" },
    }},
  },
  field = { hiddenItems = {
    ROUTE_2 = {{ x = 4, y = 3, item = "ANTIDOTE" }},
    SILPH_CO_5F = {{ x = 2, y = 2, item = "CARD_KEY" }},
  }},
  startingPcItems = { POTION = 1 },
}

local reverseRng = {
  shuffle = function(_, values)
    local output = {}
    for index, value in ipairs(values) do output[index] = value end
    local first, last = 1, #output
    while first < last do
      output[first], output[last] = output[last], output[first]
      first, last = first + 1, last - 1
    end
    return output
  end,
}

local generated = ItemCategory.generate(
  sources, { non_key_items = "on", tms = "on", hms = "off",
    key_items = "off", shops = "off" }, reverseRng)
assert(#generated.placements == 4,
  "non-key visible, hidden, and starting-PC items may participate")
assert(generated.placements[1].category == "non_key")
assert(generated.placements[3].kind == "pc")
assert(generated.placements[3].quantity == 1)
assert(generated.placements[4].category == "tm")

local game = { data = sources }
ItemRuntime.capture(game)
local applied = ItemRuntime.apply(game, {
  mappings = { fieldItems = generated.placements },
})
assert(applied == 3)
assert(game.data.maps.MT_MOON_1F.objects[1].item == "TM_BIDE")
assert(game.data.maps.VIRIDIAN_FOREST.objects[1].item == "POTION")
assert(game.data.field.hiddenItems.ROUTE_2[1].item == "ANTIDOTE")
assert(game.data.maps.VIRIDIAN_FOREST.objects[2].item == "CARD_KEY")
assert(game.data.field.hiddenItems.SILPH_CO_5F[1].item == "CARD_KEY")

game.save = { pcItems = { POTION = 1 } }
assert(ItemRuntime.initializeSave(game.save, {
  mappings = { fieldItems = generated.placements },
}) == 0)
assert(game.save.pcItems.POTION == 1)
assert(ItemRuntime.initializeSave(game.save, {
  mappings = { fieldItems = generated.placements },
}) == 0, "starting PC placement must not be applied twice")

-- Applying a vanilla/disabled save restores every prior placement without an
-- application restart.
ItemRuntime.apply(game, nil)
assert(game.data.maps.MT_MOON_1F.objects[1].item == "TM_BIDE")
assert(game.data.maps.VIRIDIAN_FOREST.objects[1].item == "POTION")
assert(game.data.field.hiddenItems.ROUTE_2[1].item == "ANTIDOTE")

assert(ItemRuntime.needsMapRefresh({
  mappings = { fieldItems = generated.placements },
}, { itemsTaken = {} }, "MT_MOON_1F"))
assert(not ItemRuntime.needsMapRefresh({
  mappings = { fieldItems = generated.placements },
}, { itemsTaken = { MT_MOON_1F_obj_2 = true } }, "MT_MOON_1F"))
assert(not ItemRuntime.needsMapRefresh({
  mappings = { fieldItems = generated.placements },
}, { itemsTaken = {} }, "ROUTE_2"),
  "hidden items do not require an item-ball actor refresh")

local invalidated
game.save = { itemsTaken = {}, pcItems = { TM_BIDE = 1 } }
local battleApplied, refreshed = ItemRuntime.afterBattle(game, {
  mappings = { fieldItems = generated.placements },
}, {
  current = function() return { mapId = "MT_MOON_1F" } end,
  invalidateMap = function(_, mapId) invalidated = mapId end,
})
assert(battleApplied == 3 and refreshed == true)
assert(invalidated == "MT_MOON_1F")
assert(game.data.maps.MT_MOON_1F.objects[1].item == "TM_BIDE",
  "post-battle repair must restore the randomized payload")

local off = ItemCategory.generate(sources, { non_key_items = "off",
  tms = "off", hms = "off", key_items = "off", shops = "off" }, reverseRng)
assert(#off.placements == 0)

io.write("item_randomizer_test: ok\n")
