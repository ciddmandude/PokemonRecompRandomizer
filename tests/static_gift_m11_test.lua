-- Mod-only static/gift generation and runtime compatibility tests.
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
local Catalog = loadFactory("src/static_gift_catalog.lua")
local Category = loadFactory(
  "src/static_gift_category.lua", StableSort, Filters, Catalog)
local Compat = loadFactory("src/static_gift_compat.lua", Catalog)

local legendary = {
  ARTICUNO = true, ZAPDOS = true, MOLTRES = true,
  MEWTWO = true, MEW = true,
}
local function entry(id, bst, typeId)
  return {
    id = id,
    bst = bst or 300,
    types = { typeId or "NORMAL" },
    primaryType = typeId or "NORMAL",
    stage = "basic",
    legendary = legendary[id] == true,
  }
end

local byId = {}
for _, record in ipairs(Catalog.statics) do
  byId[record.species] = byId[record.species]
    or entry(record.species, legendary[record.species] and 580 or 300)
end
for _, record in ipairs(Catalog.gifts) do
  byId[record.species] = byId[record.species]
    or entry(record.species, 300)
end
for index = 1, 24 do
  local id = ("CANDIDATE_%02d"):format(index)
  byId[id] = entry(id, 250 + index * 5)
end
byId.MEW = entry("MEW", 600, "PSYCHIC_TYPE")
local entries = {}
for _, id in ipairs(StableSort.keys(byId)) do
  entries[#entries + 1] = byId[id]
end
local manifest = { entries = entries, byId = byId }

local function streams(seed)
  return {
    staticSpecies = Rng.fromSeed(seed, "static.encounters"),
    staticLevels = Rng.fromSeed(seed, "static.levels"),
    giftSpecies = Rng.fromSeed(seed, "gifts"),
    giftLevels = Rng.fromSeed(seed, "gift.levels"),
  }
end

local settings = {
  static_pokemon = "randomized",
  static_levels = "random_5",
  gift_pokemon = "randomized",
  gift_levels = "fixed_15",
  gift_uniqueness = "unique",
  similar_strength = "off",
  legendaries = "match",
  duplicate_policy = "one_to_one",
}
local generatedA = Category.generate(
  manifest, settings, streams("M11 DETERMINISTIC"))
local generatedB = Category.generate(
  manifest, settings, streams("M11 DETERMINISTIC"))

local staticCount, giftCount = 0, 0
for _, record in ipairs(Catalog.statics) do
  staticCount = staticCount + 1
  local left = assert(generatedA.staticEncounters[record.id])
  local right = assert(generatedB.staticEncounters[record.id])
  assert(left.species == right.species and left.level == right.level)
  assert(left.level >= math.max(2, record.level - 5)
    and left.level <= math.min(100, record.level + 5))
  assert(byId[left.species].legendary == byId[record.species].legendary,
    "MATCH must preserve static legendary class")
end
assert(staticCount == 14)

local seenGifts = {}
for _, record in ipairs(Catalog.gifts) do
  giftCount = giftCount + 1
  local left = assert(generatedA.gifts[record.id])
  local right = assert(generatedB.gifts[record.id])
  assert(left.species == right.species and left.level == right.level)
  assert(left.level == 15)
  assert(not seenGifts[left.species],
    "unique gifts must not repeat while candidates remain")
  seenGifts[left.species] = true
  assert(not byId[left.species].legendary,
    "MATCH must keep non-legendary gifts non-legendary")
end
assert(giftCount == 8)

local scaledSettings = {}
for key, value in pairs(settings) do scaledSettings[key] = value end
scaledSettings.static_levels = "scaled"
scaledSettings.gift_levels = "scaled"
local scaled = Category.generate(
  manifest, scaledSettings, streams("M11 SCALED"))
for _, record in ipairs(Catalog.statics) do
  local mapping = scaled.staticEncounters[record.id]
  local expected = math.floor(record.level * math.sqrt(
    byId[record.species].bst / byId[mapping.species].bst) + 0.5)
  expected = math.max(2, math.min(100, expected))
  assert(mapping.level == expected)
end

local missing = Category.generate({
  entries = { entry("ONLY_MON", 300) },
  byId = { ONLY_MON = entry("ONLY_MON", 300) },
}, {
  static_pokemon = "randomized",
  static_levels = "unchanged",
  gift_pokemon = "off",
  similar_strength = "off",
  legendaries = "allow",
  duplicate_policy = "allow",
}, streams("M11 FALLBACK"))
assert(next(missing.staticEncounters) == nil)
assert(missing.fallbackCount == 1)
assert(missing.warnings[1].code == "STATIC_GENERATION_FAILED")

local commands = {}
local calls = {}
commands.show_text = function(_, text, subs)
  calls.show = { text = text, species = subs.RAM }
end
commands.ask = function(_, text, subs)
  calls.ask = { text = text, species = subs.RAM }
end
commands.play_cry = function(_, species) calls.cry = species end
commands.static_battle = function(_, species, level, flag)
  calls.battle = { species = species, level = level, flag = flag }
end
commands.give_pokemon = function(_, species, level)
  calls.give = { species = species, level = level }
end

local contributions = {}
local eventCallbacks = {}
local ui = {
  TextBox = {
    new = function(_, text, onDone, opts)
      return { text = text, onDone = onDone, opts = opts }
    end,
  },
  ListMenu = {
    new = function(_, title, items, opts)
      return { title = title, items = items, opts = opts }
    end,
  },
}
local mod = {
  events = {
    on = function(_, name, callback) eventCallbacks[name] = callback end,
  },
  ui = ui,
  content = {
    commands = {
      get = function(_, id) return commands[id] end,
      register = function(_, id, value) commands[id] = value end,
    },
    map_scripts = {
      register = function(_, mapId, value)
        contributions[mapId] = value
      end,
    },
  },
}
local active = {
  mappings = {
    staticEncounters = {
      MEWTWO = { species = "CANDIDATE_01", level = 66 },
    },
    gifts = {
      CELADON_EEVEE = { species = "CANDIDATE_02", level = 15 },
      MAGIKARP_SALE = { species = "CANDIDATE_03", level = 15 },
      DOJO_LEFT = { species = "CANDIDATE_04", level = 15 },
      SILPH_LAPRAS = { species = "CANDIDATE_05", level = 15 },
      FOSSIL_HELIX = { species = "CANDIDATE_06", level = 15 },
      FOSSIL_DOME = { species = "CANDIDATE_07", level = 15 },
      FOSSIL_OLD_AMBER = { species = "CANDIDATE_08", level = 15 },
    },
  },
}
Compat.install(mod, function() return active end)
local names = Compat.commands
commands[names.battle]({}, "MEWTWO", "MEWTWO", 70, "EVENT_BEAT_MEWTWO")
assert(calls.battle.species == "CANDIDATE_01"
  and calls.battle.level == 66)
commands[names.give]({}, "CELADON_EEVEE", "EEVEE", 25)
assert(calls.give.species == "CANDIDATE_02" and calls.give.level == 15)
commands[names.show]({},
  "gifts", "CELADON_EEVEE", "EEVEE", 25, "{RAM}!")
assert(calls.show.species == "CANDIDATE_02")
commands[names.cry]({},
  "staticEncounters", "MEWTWO", "MEWTWO", 70)
assert(calls.cry == "CANDIDATE_01")

assert(contributions.POWER_PLANT.talk.TEXT_POWERPLANT_ZAPDOS)
assert(contributions.ROUTE_12.snorlaxWake.script[3][1] == names.battle)
assert(contributions.CELADON_MANSION_ROOF_HOUSE.talk
  .TEXT_CELADONMANSION_ROOF_HOUSE_EEVEE_POKEBALL[5][1] == names.give)
assert(contributions.CINNABAR_LAB_FOSSIL_ROOM.talk
  .TEXT_CINNABARLABFOSSILROOM_SCIENTIST1)

local beforeGive = assert(eventCallbacks["pokemon.before_give"])
local fossilGift = {
  species = "OMANYTE",
  level = 30,
  ctx = { overworld = { map = { id = "CINNABAR_LAB_FOSSIL_ROOM" } } },
}
beforeGive(fossilGift)
assert(fossilGift.species == "CANDIDATE_06"
  and fossilGift.level == 15
  and fossilGift.randomizerGiftId == "FOSSIL_HELIX",
  "pokemon.before_give must resolve the saved fossil mapping")
local alreadyResolved = {
  species = "OMANYTE",
  level = 30,
  ctx = {
    randomizerGiftResolved = true,
    overworld = { map = { id = "CINNABAR_LAB_FOSSIL_ROOM" } },
  },
}
beforeGive(alreadyResolved)
assert(alreadyResolved.species == "OMANYTE",
  "the custom gift command must not be randomized twice")

local captured
contributions.MT_MOON_POKECENTER.talk
  .TEXT_MTMOONPOKECENTER_MAGIKARP_SALESMAN({
    save = { flags = {}, money = 500 },
  }, {
    runner = {
      run = function(_, rows) captured = rows end,
    },
  }, nil, function() end)
assert(captured[3][1] == names.give)
assert(captured[5][1] == "give_money",
  "sale must award successfully before charging money")
assert(captured[6][1] == "set_flag",
  "sale completion flag must be set only after a successful award")

active.mappings.gifts.MAGIKARP_SALE = nil
captured = nil
contributions.MT_MOON_POKECENTER.talk
  .TEXT_MTMOONPOKECENTER_MAGIKARP_SALESMAN({
    save = { flags = {}, money = 500 },
  }, {
    runner = {
      run = function(_, rows) captured = rows end,
    },
  }, nil, function() end)
assert(captured[3][1] == "give_money"
  and captured[4][1] == "set_flag"
  and captured[5][1] == names.give,
  "missing mapping must retain the vanilla sale operation order")

active.mappings.staticEncounters.MEWTWO = nil
commands[names.show]({}, "staticEncounters", "MEWTWO", "MEWTWO", 70,
  "{RAM}!", "_MewtwoBattleText")
assert(calls.show.text == "_MewtwoBattleText"
  and calls.show.species == "MEWTWO",
  "missing static mapping must retain vanilla text and species")

captured = nil
contributions.FIGHTING_DOJO.talk
  .TEXT_FIGHTINGDOJO_HITMONLEE_POKE_BALL({
    save = { flags = { EVENT_BEAT_KARATE_MASTER = true } },
  }, {
    runner = {
      run = function(_, rows) captured = rows end,
    },
  }, nil, function() end)
assert(captured[3][1] == names.give)
assert(captured[5][1] == "set_flag")

local stack = { values = {} }
function stack:push(value) self.values[#self.values + 1] = value end
function stack:pop() return table.remove(self.values) end
local fossilGame = {
  save = {
    flags = {},
    inventory = { HELIX_FOSSIL = 1 },
    player = { name = "RED" },
  },
  data = {
    text = {},
    pokemon = {
      CANDIDATE_06 = { name = "TESTMON" },
      OMANYTE = { name = "OMANYTE" },
    },
    items = {
      HELIX_FOSSIL = { name = "HELIX FOSSIL" },
      DOME_FOSSIL = { name = "DOME FOSSIL" },
      OLD_AMBER = { name = "OLD AMBER" },
    },
  },
  stack = stack,
}
captured = nil
local fossilDone = false
local fossilOverworld = {
  runner = { run = function(_, rows) captured = rows end },
}
local fossilTalk = contributions.CINNABAR_LAB_FOSSIL_ROOM.talk
  .TEXT_CINNABARLABFOSSILROOM_SCIENTIST1
fossilTalk(fossilGame, fossilOverworld, nil,
  function() fossilDone = true end)
local intro = assert(stack.values[#stack.values])
assert(intro.onDone)
intro.onDone()
local fossilList = assert(stack.values[#stack.values])
assert(fossilList.title == "FOSSIL" and #fossilList.items == 1)
fossilList.opts.onChoose(fossilList.items[1])
local seesFossil = assert(stack.values[#stack.values])
assert(seesFossil.text:find("TESTMON", 1, true),
  "the deposit preview must name the mapped Pokemon")
seesFossil.opts.choice(true)
assert(fossilGame.save.inventory.HELIX_FOSSIL == nil)
assert(fossilGame.save.labFossilMon == "OMANYTE",
  "the pending quest must retain the vanilla source identity")
assert(fossilGame.save.flags.EVENT_GAVE_FOSSIL_TO_LAB
  and fossilGame.save.flags.EVENT_LAB_STILL_REVIVING_FOSSIL)

stack.values = {}
fossilGame.save.flags.EVENT_LAB_STILL_REVIVING_FOSSIL = nil
fossilTalk(fossilGame, fossilOverworld, nil,
  function() fossilDone = true end)
local revived = assert(stack.values[#stack.values])
assert(revived.text:find("TESTMON", 1, true),
  "the resurrection announcement must name the mapped Pokemon")
revived.onDone()
assert(captured[1][1] == names.give
  and captured[1][2] == "FOSSIL_HELIX",
  "the handover must use the saved fossil gift mapping")

local excluded = {}
for _, id in ipairs(Catalog.exclusions) do excluded[id] = true end
assert(not excluded.FOSSIL_RESTORATION)
assert(excluded.POKEMON_TOWER_GHOST)
assert(excluded.GENERIC_OBJECT_EVENT_STATICS)
assert(excluded.GAME_CORNER_PRIZES)

io.write("static_gift_m11_test: ok\n")
