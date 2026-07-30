-- Mod-only M12 generation and runtime compatibility tests.
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
local Rng = loadFactory("src/rng.lua", Constants, UInt32, Hash128)
local Filters = loadFactory("src/species_filters.lua")
local Catalog = loadFactory("src/trade_prize_catalog.lua")
local Category = loadFactory(
  "src/trade_prize_category.lua", StableSort, Filters, Catalog)
local Compat = loadFactory("src/trade_prize_compat.lua", Catalog)
local General = loadFactory("src/general_settings.lua", {
  behaviorSettings = function(value) return value end,
  hashBehaviorSettings = function() return "" end,
})

local function entry(id, bst)
  return {
    id = id,
    bst = bst or 300,
    types = { "NORMAL" },
    primaryType = "NORMAL",
    stage = "basic",
    legendary = false,
  }
end

local byId = {}
for _, trade in ipairs(Catalog.trades) do
  byId[trade.give] = byId[trade.give] or entry(trade.give, 300)
  byId[trade.get] = byId[trade.get] or entry(trade.get, 310)
end
for _, version in ipairs({ "red", "blue" }) do
  for _, prize in ipairs(Catalog.prizes[version]) do
    byId[prize.species] = byId[prize.species]
      or entry(prize.species, 280)
  end
end
for index = 1, 40 do
  local id = ("M12_CANDIDATE_%02d"):format(index)
  byId[id] = entry(id, 250 + index * 4)
end
byId.M12_LEGEND = entry("M12_LEGEND", 310)
byId.M12_LEGEND.legendary = true
local entries = {}
for _, id in ipairs(StableSort.keys(byId)) do
  entries[#entries + 1] = byId[id]
end
local manifest = { entries = entries, byId = byId }

local function streams(seed)
  return {
    trades = Rng.fromSeed(seed, "trades"),
    prizes = Rng.fromSeed(seed, "prizes"),
  }
end

local settings = {
  in_game_trades = "both_sides",
  trade_fairness = "no_downgrade",
  trade_evolution_safety = "on",
  game_corner_pokemon = "randomized",
  prize_levels = "scaled",
  prize_prices = "by_strength",
  similar_strength = "off",
  legendaries = "allow",
  duplicate_policy = "one_to_one",
  catchability_guard = "off",
}
local redA = Category.generate(
  manifest, { gameVersion = "red" }, settings, streams("M12 RED"), {})
local redB = Category.generate(
  manifest, { gameVersion = "red" }, settings, streams("M12 RED"), {})

local tradeCount = 0
for _, record in ipairs(Catalog.trades) do
  tradeCount = tradeCount + 1
  local left = assert(redA.trades[record.id])
  local right = assert(redB.trades[record.id])
  assert(left.requested.species == right.requested.species)
  assert(left.received.species == right.received.species)
  assert(left.requested.species ~= left.received.species,
    "trade safety must reject self-trades")
  assert(byId[left.received.species].bst * 100
    >= byId[left.requested.species].bst * 95,
    "NO DOWNGRADE must retain at least 95 percent of requested BST")
end
assert(tradeCount == 9, "only the nine wired NPC trades are supported")
for _, record in ipairs(Catalog.trades) do
  assert(record.index ~= 3, "unwired trade row 3 must not be generated")
end

local prizeCount = 0
for _, record in ipairs(Catalog.prizes.red) do
  prizeCount = prizeCount + 1
  local left = assert(redA.prizes[record.id])
  local right = assert(redB.prizes[record.id])
  assert(left.species == right.species
    and left.level == right.level and left.cost == right.cost)
  assert(left.level >= 5 and left.level <= 30)
  assert(left.cost >= 10 and left.cost <= 9999
    and (left.cost % 10 == 0 or left.cost == 9999))
end
assert(prizeCount == 6)

local blue = Category.generate(
  manifest, { gameVersion = "blue" }, settings, streams("M12 BLUE"), {})
assert(blue.prizes.GAME_CORNER_BLUE_1)
assert(not blue.prizes.GAME_CORNER_RED_1)

local receivedSettings = {}
for key, value in pairs(settings) do receivedSettings[key] = value end
receivedSettings.in_game_trades = "received"
receivedSettings.trade_fairness = "any"
local receivedOnly = Category.generate(
  manifest, { gameVersion = "red" }, receivedSettings,
  streams("M12 RECEIVED"), {})
for _, record in ipairs(Catalog.trades) do
  assert(receivedOnly.trades[record.id].requested.species == record.give)
end

local sawAllowedLegendary = false
for _, fairness in ipairs({ "similar", "any", "no_downgrade" }) do
  for _, legendaryPolicy in ipairs({ "exclude", "match", "allow" }) do
    for seedIndex = 1, 50 do
      local matrixSettings = {}
      for key, value in pairs(settings) do matrixSettings[key] = value end
      matrixSettings.in_game_trades = "received"
      matrixSettings.game_corner_pokemon = "off"
      matrixSettings.trade_fairness = fairness
      matrixSettings.legendaries = legendaryPolicy
      matrixSettings.duplicate_policy = "allow"
      local matrix = Category.generate(
        manifest, { gameVersion = "red" }, matrixSettings,
        streams(("POLICY %s %s %d"):format(
          fairness, legendaryPolicy, seedIndex)), {})
      for _, record in ipairs(Catalog.trades) do
        local received = assert(matrix.trades[record.id]).received.species
        local isLegendary = byId[received].legendary == true
        if legendaryPolicy == "exclude" or legendaryPolicy == "match" then
          assert(not isLegendary,
            ("legendary policy %s must remain hard under %s")
              :format(legendaryPolicy, fairness))
        elseif isLegendary then
          sawAllowedLegendary = true
        end
      end
    end
  end
end
assert(sawAllowedLegendary,
  "policy matrix must exercise an allowed legendary destination")

local casual = General.preset("casual")
for seedIndex = 1, 100 do
  local generatedCasual = Category.generate(
    manifest, { gameVersion = "red" }, casual,
    streams("CASUAL " .. tostring(seedIndex)), {})
  for _, record in ipairs(Catalog.trades) do
    local trade = assert(generatedCasual.trades[record.id])
    assert(not byId[trade.received.species].legendary,
      "the shipped Casual preset must never receive a legendary trade")
  end
  for _, prize in pairs(generatedCasual.prizes) do
    assert(not byId[prize.species].legendary,
      "the shipped Casual preset must never generate a legendary prize")
  end
end

local calls = {}
local commandRecords = {}
commandRecords.trade = function(ctx, index, flag)
  local offer = ctx.game.data.field.trades[index]
  calls.trade = {
    give = offer.give, get = offer.get, index = index, flag = flag,
  }
end
commandRecords.give_pokemon = function(ctx, species, level)
  calls.give = { species = species, level = level }
  ctx.lastCheck = calls.rejectGift ~= true
end

local screens, contributions = {}, {}
local mod = {
  content = {
    commands = {
      get = function(_, id) return commandRecords[id] end,
      register = function(_, id, fn) commandRecords[id] = fn end,
    },
    screens = {
      register = function(_, id, record) screens[id] = record end,
    },
    map_scripts = {
      register = function(_, id, contribution)
        contributions[id] = contribution
      end,
    },
  },
  ui = {
    TextBox = {
      new = function(_, text, done)
        return { text = text, done = done }
      end,
    },
    ListMenu = {
      new = function(_, title, items, opts)
        return {
          title = title, items = items, footer = opts.footer,
          onChoose = opts.onChoose, onCancel = opts.onCancel,
        }
      end,
    },
    push = function() end,
  },
}

local active = {
  mappings = {
    trades = {
      TRADE_02_MARCEL = {
        requested = { species = "M12_CANDIDATE_01" },
        received = { species = "M12_CANDIDATE_02" },
      },
    },
    prizes = {
      GAME_CORNER_RED_1 = {
        species = "M12_CANDIDATE_03", level = 15, cost = 200,
      },
    },
  },
}
Compat.install(mod, function() return active end)
assert(type(commandRecords[Compat.tradeCommand]) == "function")
assert(type(screens[Compat.prizeScreen].new) == "function")
assert(contributions.ROUTE_2_TRADE_HOUSE.talk
  .TEXT_ROUTE2TRADEHOUSE_GAMEBOY_KID[2][1] == Compat.tradeCommand)
assert(contributions.GAME_CORNER_PRIZE_ROOM)

local original = { give = "ABRA", get = "MR_MIME", nickname = "MARCEL" }
local context = {
  game = { data = { field = { trades = { [2] = original } } } },
}
commandRecords[Compat.tradeCommand](
  context, "TRADE_02_MARCEL", 2, "DONE")
assert(calls.trade.give == "M12_CANDIDATE_01")
assert(calls.trade.get == "M12_CANDIDATE_02")
assert(context.game.data.field.trades[2] == original,
  "temporary trade replacement must always restore merged data")

local game = {
  save = {
    version = "red", coins = 500,
    inventory = { COIN_CASE = 1 },
  },
  data = {
    pokemon = {},
    items = {
      TM_DRAGON_RAGE = { name = "TM23" },
      TM_HYPER_BEAM = { name = "TM15" },
      TM_SUBSTITUTE = { name = "TM50" },
    },
  },
}
for id in pairs(byId) do game.data.pokemon[id] = { name = id } end
local menu = screens[Compat.prizeScreen].new(game, function() end)
assert(#menu.items == 9, "six Pokemon and three TM prizes must be shown")
menu.onChoose(menu.items[1])
assert(calls.give.species == "M12_CANDIDATE_03"
  and calls.give.level == 15)
assert(game.save.coins == 300,
  "a successful mapped prize deducts its displayed cost once")

game.save.coins = 500
calls.rejectGift = true
menu.onChoose(menu.items[1])
assert(game.save.coins == 500,
  "a failed mapped prize must not consume coins")
assert(menu.footer == "No room for Pokemon!")

active.mappings.prizes = {}
game.save.coins = 500
local vanillaMenu = screens[Compat.prizeScreen].new(game, function() end)
vanillaMenu.onChoose(vanillaMenu.items[1])
assert(game.save.coins == 320,
  "disabled/missing prize mappings retain v0.1.30 charge-first order")

io.write("trade_prize_m12_test: ok\n")
