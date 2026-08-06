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
  FRESH_WATER = { name = "FRESH WATER", price = 200 },
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
local sawShop, sawTm, sawKey, sawSaffronDrink = false, false, false, false
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
    sawSaffronDrink = sawSaffronDrink
      or row.talkKey == "vending" and row.item == "FRESH_WATER"
  end
end
assert(sawShop and sawTm and sawKey,
  "full-random shops include enabled TM and supported key-item pools")
assert(sawSaffronDrink,
  "progression safety preserves a vending drink for Saffron access")

local CycleProgression = {
  STAGES = Progression.STAGES,
  access = Progression.access,
  itemAccess = function(row)
    return {
      available = true, stage = Progression.STAGES.START,
      requirements = row.mapId == "A" and { "S_S_TICKET" }
        or { "OAKS_PARCEL" },
    }
  end,
}
local CycleCategory = loadFactory(
  "src/item_category.lua", StableSort, CycleProgression, ItemFilter)
local cycle = CycleCategory.generate({
  items = {
    OAKS_PARCEL = { name = "OAK'S PARCEL", keyItem = true },
    S_S_TICKET = { name = "S.S. TICKET", keyItem = true },
  },
  maps = {
    A = { objects = { { index = 1, item = "OAKS_PARCEL" } } },
    B = { objects = { { index = 1, item = "S_S_TICKET" } } },
  },
}, {
  non_key_items = "vanilla", tms = "vanilla", hms = "vanilla",
  key_items = "shuffled", badges = "vanilla", hidden_items = "vanilla",
  ensure_beatable = "on", shops = "vanilla",
}, rng)
assert(#cycle.placements == 0 and #cycle.warnings == 1,
  "progression safety rejects a two-item dependency cycle")

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

local bagData
local TestBag = {}
function TestBag.add(save, itemId, quantity, data)
  bagData = data
  local inventory = save.inventory or {}
  save.inventory = inventory
  local function badge(id) return string.find(id, "BADGE", 1, true) ~= nil end
  local slots = 0
  for id, count in pairs(inventory) do
    if count > 0 and not badge(id) then slots = slots + 1 end
  end
  local capacity = data and data.constants and data.constants.bagSize or 20
  quantity = quantity or 1
  if not inventory[itemId] and not badge(itemId) and slots >= capacity then
    return false
  end
  if not badge(itemId) and (inventory[itemId] or 0) + quantity > 99 then
    return false
  end
  local isNew = not inventory[itemId]
  inventory[itemId] = (inventory[itemId] or 0) + quantity
  if isNew and not badge(itemId) then
    save.bagOrder = save.bagOrder or {}
    save.bagOrder[#save.bagOrder + 1] = itemId
  end
  return true
end

local VendingRuntime = loadFactory("src/item_runtime.lua", catalog, TestBag)
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
      register = function(_, mapId, value)
        if mapId == "CELADON_MART_ROOF" then vendingRegistration = value end
      end,
    },
  },
  ui = { ListMenu = { new = function(_, _, entries, options)
    vendingList = { items = entries, opts = options }
    return vendingList
  end } },
}
VendingRuntime.install(vendingMod, function() return vendingRun end)

local function openVending(gameState)
  vendingRegistration.talk.TEXT_CELADONMARTROOF_VENDING_MACHINE1(
    gameState, {}, {}, function() end)
  vendingList.opts.onChoose(vendingList.items[1])
end

local inventory, bagOrder = {}, {}
for index = 1, 20 do
  local itemId = "ITEM_" .. index
  inventory[itemId], bagOrder[index] = 1, itemId
end
local expandedBagGame = {
  data = {
    constants = { bagSize = 999 },
    items = { FRESH_WATER = { name = "Fresh Water" } },
  },
  save = { money = 200, inventory = inventory, bagOrder = bagOrder },
  stack = { push = function() end },
}
openVending(expandedBagGame)
assert(expandedBagGame.save.inventory.FRESH_WATER == 1
    and expandedBagGame.save.money == 0
    and expandedBagGame.save.bagOrder[21] == "FRESH_WATER"
    and bagData == expandedBagGame.data,
  "randomized vending honors merged bag capacity and acquisition order")

local fullBagGame = {
  data = {
    constants = { bagSize = 20 },
    items = { FRESH_WATER = { name = "Fresh Water" } },
  },
  save = { money = 200, inventory = {}, bagOrder = {} },
  stack = { push = function() end },
}
for index = 1, 20 do
  local itemId = "FULL_" .. index
  fullBagGame.save.inventory[itemId] = 1
  fullBagGame.save.bagOrder[index] = itemId
end
openVending(fullBagGame)
assert(fullBagGame.save.inventory.FRESH_WATER == nil
    and fullBagGame.save.money == 200
    and vendingList.footer == "No room in BAG!",
  "a rejected vending purchase does not deduct money")

local fullStackGame = {
  data = {
    constants = { bagSize = 20 },
    items = { FRESH_WATER = { name = "Fresh Water" } },
  },
  save = {
    money = 200, inventory = { FRESH_WATER = 99 },
    bagOrder = { "FRESH_WATER" },
  },
  stack = { push = function() end },
}
openVending(fullStackGame)
assert(fullStackGame.save.inventory.FRESH_WATER == 99
    and fullStackGame.save.money == 200
    and vendingList.footer == "No room in BAG!",
  "a vending purchase respects the engine stack limit")

io.write("item_options_test: ok\n")
