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
  access = function(mapId)
    return { available = true, stage = mapId == "EARLY" and 1 or 9 }
  end,
}
local Category = loadFactory("src/item_category.lua", StableSort, Progression)

local items = {
  POTION = { name = "POTION", price = 300 },
  ANTIDOTE = { name = "ANTIDOTE", price = 100 },
  TM_BIDE = { name = "TM34", price = 2000, machine = { kind = "TM" } },
  HM_CUT = { name = "HM01", price = 0, machine = { kind = "HM" } },
  OAKS_PARCEL = { name = "OAK'S PARCEL", price = 0, keyItem = true },
  BOULDERBADGE = { name = "BOULDERBADGE", price = 0, keyItem = true },
  CASCADEBADGE = { name = "CASCADEBADGE", price = 0, keyItem = true },
}
assert(Category.category("HM_CUT", items) == "hm")
assert(Category.category("TM_BIDE", items) == "tm")
assert(Category.category("OAKS_PARCEL", items) == "key")
assert(Category.category("POTION", items) == "non_key")

local rng = {
  next = 0,
  shuffle = function(_, values)
    local output = {}
    for index = #values, 1, -1 do output[#output + 1] = values[index] end
    return output
  end,
  nextU32 = function(self) self.next = self.next + 1 return self.next end,
  nextInt = function(_, first, last)
    if first == 1 and last == 50 then return 17 end
    return last
  end,
}
local sources = {
  items = items,
  maps = {
    EARLY = { label = "Early", objects = {
      { index = 1, item = "HM_CUT" }, { index = 2, item = "POTION" },
    } },
    LATE = { label = "Late", objects = {
      { index = 1, item = "TM_BIDE" }, { index = 2, item = "OAKS_PARCEL" },
    } },
  },
  field = { hiddenItems = {} },
  scriptedItems = {
    { id = "brock_badge", mapId = "EARLY", item = "BOULDERBADGE",
      flag = "BEAT_BROCK", battle = true, command = false, badge = true },
    { id = "misty_badge", mapId = "LATE", item = "CASCADEBADGE",
      flag = "BEAT_MISTY", battle = true, command = false, badge = true },
  },
  textPointers = { Early = { CLERK = { mart = { "POTION", "ANTIDOTE" } } } },
}

local off = Category.generate(sources, { non_key_items = "off", tms = "off",
  hms = "off", key_items = "off", shops = "off" }, rng)
assert(#off.placements == 0, "all item options default to no mappings")

local badgeShuffle = Category.generate(sources, {
  non_key_items = "off", tms = "off", hms = "off", key_items = "off",
  badges = "shuffled", ensure_beatable = "off", shops = "off",
}, rng)
assert(#badgeShuffle.placements == 2,
  "shuffled mode emits one mapping for each Gym badge reward")
assert(badgeShuffle.placements[1].item ~= badgeShuffle.placements[1].original,
  "shuffled mode permutes badge identities")

local badgeRandom = Category.generate(sources, {
  non_key_items = "off", tms = "off", hms = "off", key_items = "off",
  badges = "random", ensure_beatable = "on", shops = "off",
}, rng)
local badgeAtField = false
for _, row in ipairs(badgeRandom.placements) do
  if row.kind ~= "scripted" and (row.item == "BOULDERBADGE"
      or row.item == "CASCADEBADGE") then badgeAtField = true end
end
assert(badgeAtField,
  "random mode places badges at supported one-time item locations")

local shops = Category.generate(sources, { non_key_items = "off", tms = "on",
  hms = "full_random", key_items = "full_random", shops = "on",
  shop_prices = "random" }, rng)
local sawShop, sawTm, sawKey = false, false, false
for _, row in ipairs(shops.placements) do
  if row.kind == "shop" then
    sawShop = true
    assert(row.category ~= "hm", "shops must never stock HMs")
    assert(row.price == 1700, "random price is seeded and bounded")
    sawTm = sawTm or row.category == "tm"
    sawKey = sawKey or row.category == "key"
  end
end
assert(sawShop and sawTm and sawKey,
  "full-random shops include enabled TM and supported key-item pools")

local catalog = {
  { id = "direct", mapId = "EARLY", item = "POTION", flag = "GOT",
    talkKey = "TALK", command = false },
  { id = "brock_badge", mapId = "EARLY", item = "BOULDERBADGE",
    flag = "BEAT_BROCK", battle = true, command = false, badge = true },
}
local Runtime = loadFactory("src/item_runtime.lua", catalog)
local registered, commandOverride
local baseTalk = function(game, _, _, done)
  game.save.inventory.POTION = 1
  game.save.flags.GOT = true
  done()
end
local run = { mappings = { fieldItems = {
  { kind = "scripted", id = "direct", mapId = "EARLY",
    original = "POTION", item = "ANTIDOTE" },
} } }
local mod = {
  content = {
    commands = {
      get = function() return function() end end,
      override = function(_, _, fn) commandOverride = fn end,
    },
    map_scripts = {
      get = function(_, id)
        if id == "EARLY" then return { talk = { TALK = baseTalk } } end
        return { talk = {} }
      end,
      register = function(_, id, value) registered = registered or {}
        registered[id] = value end,
    },
  },
  ui = { ListMenu = { new = function() return {} end } },
}
Runtime.install(mod, function() return run end)
assert(type(commandOverride) == "function")
local game = { save = { inventory = {}, flags = {} } }
registered.EARLY.talk.TALK(game, {}, {}, function() end)
assert(game.save.inventory.POTION == nil
    and game.save.inventory.ANTIDOTE == 1,
  "direct reward wrapper exchanges the awarded item exactly once")
registered.EARLY.talk.TALK(game, {}, {}, function() end)
assert(game.save.inventory.ANTIDOTE == 1,
  "direct reward claim marker prevents duplicate exchange")

local badgeRun = { mappings = { fieldItems = {
  { kind = "scripted", id = "brock_badge", mapId = "EARLY",
    original = "BOULDERBADGE", item = "CASCADEBADGE" },
} } }
local battle = {
  game = game,
  onFinish = function()
    game.save.flags.BEAT_BROCK = true
    game.save.inventory.BOULDERBADGE = 1
  end,
}
assert(Runtime.prepareBattleRewards({ battle = battle }, badgeRun))
battle.onFinish("win")
assert(game.save.inventory.BOULDERBADGE == nil
    and game.save.inventory.CASCADEBADGE == 1,
  "post-battle exchange replaces the Gym's vanilla badge")

io.write("item_options_test: ok\n")
