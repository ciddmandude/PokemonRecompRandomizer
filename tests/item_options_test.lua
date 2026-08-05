local function loadFactory(path, ...)
  local chunk, err = loadfile(path)
  assert(chunk, err)
  local value = chunk()
  return type(value) == "function" and value(...) or value
end

local StableSort = loadFactory("src/stable_sort.lua")
local ItemFilter = loadFactory("src/item_filter.lua")
local Progression = {
  STAGES = { START = 1, CERULEAN = 3, VERMILION = 4,
    LAVENDER_CELADON = 5, FUCHSIA = 6, SAFFRON = 7,
    SURF = 8, VICTORY_ROAD = 9, POSTGAME = 10 },
  access = function(mapId)
    if mapId == "POST" then
      return { available = false, stage = 10, postgame = true }
    end
    return { available = true, stage = mapId == "EARLY" and 1 or 9 }
  end,
}
local Category = loadFactory(
  "src/item_category.lua", StableSort, Progression, ItemFilter)

local items = {
  POTION = { name = "POTION", price = 300 },
  ANTIDOTE = { name = "ANTIDOTE", price = 100 },
  TM_BIDE = { name = "TM34", price = 2000, machine = { kind = "TM" } },
  HM_CUT = { name = "HM01", price = 0, machine = { kind = "HM" } },
  OAKS_PARCEL = { name = "OAK'S PARCEL", price = 0, keyItem = true },
  BOULDERBADGE = { name = "BOULDERBADGE", price = 0, keyItem = true },
  CASCADEBADGE = { name = "CASCADEBADGE", price = 0, keyItem = true },
  FLOOR_1F = { name = "1F", price = 0 },
  FLOOR_ROOF = { name = "ROOF", price = 0 },
  UNUSED_ITEM_1 = { name = "?????", price = 0 },
  UNUSED_ITEM_2 = { label = "?????", price = 0 },
}
assert(Category.category("HM_CUT", items) == "hm")
assert(Category.category("TM_BIDE", items) == "tm")
assert(Category.category("OAKS_PARCEL", items) == "key")
assert(Category.category("POTION", items) == "non_key")
assert(Category.category("FLOOR_1F", items) == nil
    and Category.category("FLOOR_ROOF", items) == nil,
  "elevator menu labels are not usable items")
assert(Category.category("UNUSED_ITEM_1", items) == nil
    and Category.category("UNUSED_ITEM_2", items) == nil,
  "question-mark placeholders are not usable items")

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
  field = { hiddenItems = {
    EARLY = { { x = 1, y = 2, item = "POTION" } },
    LATE = { { x = 3, y = 4, item = "ANTIDOTE" } },
  } },
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

local hiddenShuffle = Category.generate(sources, {
  non_key_items = "vanilla", tms = "vanilla", hms = "vanilla",
  key_items = "vanilla", badges = "vanilla", hidden_items = "shuffled",
  ensure_beatable = "off", shops = "vanilla",
}, rng)
assert(#hiddenShuffle.placements == 2,
  "hidden shuffled mode emits every hidden check")
for _, row in ipairs(hiddenShuffle.placements) do
  assert(row.kind == "hidden",
    "hidden shuffled mode stays inside the hidden-check pool")
end

local hiddenMixed = Category.generate(sources, {
  non_key_items = "vanilla", tms = "vanilla", hms = "vanilla",
  key_items = "vanilla", badges = "vanilla", hidden_items = "mixed",
  ensure_beatable = "off", shops = "vanilla",
}, rng)
local sawHidden, sawVisible = false, false
for _, row in ipairs(hiddenMixed.placements) do
  sawHidden = sawHidden or row.kind == "hidden"
  sawVisible = sawVisible or row.kind ~= "hidden"
  assert(row.category == "non_key",
    "hidden mixed mode does not unlock vanilla progression categories")
end
assert(sawHidden and sawVisible,
  "hidden mixed mode exchanges items with supported visible checks")

local ordinaryAndTmMixed = Category.generate(sources, {
  non_key_items = "mixed", tms = "mixed", hms = "vanilla",
  key_items = "vanilla", badges = "vanilla", hidden_items = "vanilla",
  ensure_beatable = "on", shops = "vanilla",
}, rng)
assert(#ordinaryAndTmMixed.placements == 2,
  "safe non-key and TM mixed modes share only their supported checks")
for _, row in ipairs(ordinaryAndTmMixed.placements) do
  assert(row.item ~= row.original,
    "safe mixed ordinary and TM items avoid original checks")
end

local retryRng = {
  calls = 0,
  shuffle = function(self, values)
    self.calls = self.calls + 1
    if self.calls == 1 then return { values[1], values[2] } end
    return { values[2], values[1] }
  end,
}
local retried = Category.generate({
  items = items,
  maps = { EARLY = { objects = {
    { index = 1, item = "POTION" },
    { index = 2, item = "ANTIDOTE" },
  } } },
  field = { hiddenItems = {} },
}, {
  non_key_items = "shuffled", tms = "vanilla", hms = "vanilla",
  key_items = "vanilla", badges = "vanilla", hidden_items = "vanilla",
  ensure_beatable = "on", shops = "vanilla",
}, retryRng)
assert(retryRng.calls == 2
    and retried.placements[1].item == "ANTIDOTE"
    and retried.placements[2].item == "POTION",
  "ordinary shuffle retries an identity permutation")

local safeMixedWithPostgame = Category.generate({
  items = items,
  maps = {
    EARLY = { objects = {
      { index = 1, item = "POTION" },
      { index = 2, item = "ANTIDOTE" },
    } },
    POST = { objects = {
      { index = 1, item = "POTION" },
    } },
  },
  field = { hiddenItems = {} },
}, {
  non_key_items = "mixed", tms = "vanilla", hms = "vanilla",
  key_items = "vanilla", badges = "vanilla", hidden_items = "vanilla",
  ensure_beatable = "on", shops = "vanilla",
}, rng)
assert(#safeMixedWithPostgame.warnings == 0
    and #safeMixedWithPostgame.placements == 2,
  "unreachable source checks are locked instead of invalidating safe MIXED")
for _, row in ipairs(safeMixedWithPostgame.placements) do
  assert(row.mapId == "EARLY" and row.item ~= row.original,
    "safe MIXED randomizes reachable checks and leaves postgame checks vanilla")
end

local shops = Category.generate(sources, { non_key_items = "off", tms = "on",
  hms = "full_random", key_items = "full_random", shops = "on",
  shop_prices = "random" }, rng)
local sawShop, sawTm, sawKey = false, false, false
for _, row in ipairs(shops.placements) do
  if row.kind == "shop" then
    sawShop = true
    assert(row.category ~= "hm", "shops must never stock HMs")
    assert(row.item ~= "FLOOR_1F" and row.item ~= "FLOOR_ROOF",
      "shops must not stock elevator labels")
    assert(row.item ~= "UNUSED_ITEM_1" and row.item ~= "UNUSED_ITEM_2",
      "shops must not stock question-mark placeholders")
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

local vendingRegistration, vendingList
local vendingRun = { mappings = { fieldItems = {
  { kind = "shop", mapId = "CELADON_MART_ROOF", talkKey = "vending",
    slot = 1, item = "FRESH_WATER", price = 200 },
} } }
local vendingMod = {
  content = {
    commands = { get = function() return nil end },
    map_scripts = {
      get = function() return { talk = {} } end,
      register = function(_, _, value) vendingRegistration = value end,
    },
  },
  ui = { ListMenu = { new = function(_, _, items, opts)
    vendingList = { items = items, opts = opts }
    return vendingList
  end } },
}
Runtime.install(vendingMod, function() return vendingRun end)

local inventory, bagOrder = {}, {}
for i = 1, 20 do
  local id = "ITEM_" .. i
  inventory[id], bagOrder[i] = 1, id
end
local vendingGame = {
  data = {
    constants = { bagSize = 999 },
    items = { FRESH_WATER = { name = "Fresh Water" } },
  },
  save = { money = 200, inventory = inventory, bagOrder = bagOrder },
  stack = { push = function() end },
}
vendingRegistration.talk.TEXT_CELADONMARTROOF_VENDING_MACHINE1(
  vendingGame, {}, {}, function() end)
vendingList.opts.onChoose(vendingList.items[1])
assert(vendingGame.save.inventory.FRESH_WATER == 1
    and vendingGame.save.money == 0,
  "randomized vending honors the active bag capacity")

io.write("item_options_test: ok\n")
