local function loadFactory(path, ...)
  local value = assert(loadfile(path))()
  return type(value) == "function" and value(...) or value
end

local Constants = loadFactory("src/constants.lua")
local UInt32 = loadFactory("src/uint32.lua")
local Hash128 = loadFactory("src/hash128.lua", Constants, UInt32)
local StableSort = loadFactory("src/stable_sort.lua")
local Rng = loadFactory("src/rng.lua", Constants, UInt32, Hash128)
local Evolution = loadFactory("src/evolution_category.lua", StableSort)
local Mechanics = loadFactory(
  "src/mechanics_category.lua", StableSort, Evolution)
local Runtime = loadFactory("src/mechanics_runtime.lua")

local function streams(seed)
  return {
    stats = Rng.fromSeed(seed, "mechanics.base_stats"),
    pokemonTypes = Rng.fromSeed(seed, "mechanics.pokemon_types"),
    movesets = Rng.fromSeed(seed, "mechanics.movesets"),
    compatibility = Rng.fromSeed(seed, "mechanics.tmhm"),
    evolutions = Rng.fromSeed(seed, "mechanics.evolutions"),
    tradeEvolutions = Rng.fromSeed(seed, "mechanics.trade_evolutions"),
    moveData = {
      types = Rng.fromSeed(seed, "mechanics.move_types"),
      power = Rng.fromSeed(seed, "mechanics.move_power"),
      accuracy = Rng.fromSeed(seed, "mechanics.move_accuracy"),
      pp = Rng.fromSeed(seed, "mechanics.move_pp"),
    },
  }
end

local species = {
  {
    id = "A_CHILD", bst = 350,
    stats = { hp = 70, attack = 80, defense = 70, speed = 60, special = 70 },
    types = { "GRASS", "POISON" }, level1Moves = { "TACKLE" },
    learnset = { { level = 7, move = "GROWL" } },
    tmhm = { "CUT", "MEGA_DRAIN" }, stage = "middle",
    evolutions = { { species = "SOLO", method = "TRADE" } },
  },
  {
    id = "Z_ROOT", bst = 250,
    stats = { hp = 45, attack = 49, defense = 49, speed = 45, special = 62 },
    types = { "GRASS", "POISON" }, level1Moves = { "GROWL" },
    learnset = { { level = 7, move = "LEECH_SEED" } },
    tmhm = { "CUT" }, stage = "basic",
    evolutions = { { species = "A_CHILD", method = "level", level = 16 } },
  },
  {
    id = "SOLO", bst = 300,
    stats = { hp = 60, attack = 60, defense = 60, speed = 60, special = 60 },
    types = { "WATER" }, level1Moves = {},
    learnset = { { level = 10, move = "GROWL" } },
    tmhm = { "MEGA_DRAIN" }, stage = "final", evolutions = {},
  },
}
local moves = {
  TACKLE = { id = "TACKLE", type = "NORMAL", power = 35,
    accuracy = 95, pp = 35, effect = "NO_ADDITIONAL_EFFECT" },
  MEGA_DRAIN = { id = "MEGA_DRAIN", type = "GRASS", power = 40,
    accuracy = 100, pp = 10, effect = "DRAIN_HP_EFFECT" },
  CUT = { id = "CUT", type = "NORMAL", power = 50,
    accuracy = 95, pp = 30, effect = "NO_ADDITIONAL_EFFECT" },
  GROWL = { id = "GROWL", type = "NORMAL", power = 0,
    accuracy = 100, pp = 40, effect = "ATTACK_DOWN1_EFFECT" },
  LEECH_SEED = { id = "LEECH_SEED", type = "GRASS", power = 0,
    accuracy = 90, pp = 10, effect = "LEECH_SEED_EFFECT" },
  BIDE = { id = "BIDE", type = "NORMAL", power = 0,
    accuracy = 100, pp = 10, effect = "BIDE_EFFECT" },
}
local settings = {
  base_stats = "redistributed", stat_family_consistency = "on",
  evolutions = "full_random", evolution_repeats = "avoid",
  evolution_trade_safety = "random_30_40",
  pokemon_types = "randomized", type_family_consistency = "on",
  pokemon_movesets = "type_aware", early_damage = "on",
  learnset_levels = "shuffled", tmhm_compatibility = "shuffled",
  move_types = "randomized", move_data = "full_random", move_safety = "on",
}
local source = { moves = moves,
  typeIds = { "GRASS", "NORMAL", "POISON", "WATER" } }
local first = Mechanics.generate({ entries = species }, source, settings,
  streams("MECHANICS TEST"))
local second = Mechanics.generate({ entries = species }, source, settings,
  streams("MECHANICS TEST"))
local alternate = Mechanics.generate({ entries = species }, source, settings,
  streams("MECHANICS TEST B"))

local function encode(value)
  if type(value) ~= "table" then return tostring(value) end
  local parts = {}
  for _, key in ipairs(StableSort.keys(value)) do
    parts[#parts + 1] = tostring(key) .. "=" .. encode(value[key])
  end
  return "{" .. table.concat(parts, ",") .. "}"
end
local function clone(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, child in pairs(value) do result[key] = clone(child) end
  return result
end
assert(encode(first) == encode(second), "mechanics must be deterministic")

for _, entry in ipairs(species) do
  local final = assert(first.pokemonMechanics[entry.id].baseStats)
  local total = 0
  for _, key in ipairs({ "hp", "attack", "defense", "speed", "special" }) do
    assert(final[key] >= 1 and final[key] <= 255)
    total = total + final[key]
  end
  assert(total == entry.bst, "redistribution must preserve BST")
end
assert(first.pokemonMechanics.A_CHILD.types[1]
  ~= nil, "randomized family types must be generated")

local adjacency, edgeCount = {}, 0
for _, entry in ipairs(species) do
  local final = assert(first.pokemonMechanics[entry.id].evolutions)
  assert(#final == #(entry.evolutions or {}),
    "evolution branch count must be preserved")
  adjacency[entry.id] = {}
  for _, evolution in ipairs(final) do
    assert(evolution.species ~= entry.id, "self evolution is forbidden")
    adjacency[entry.id][#adjacency[entry.id] + 1] = evolution.species
    assert(first.pokemonMechanics[entry.id].types[1]
      == first.pokemonMechanics[evolution.species].types[1],
      "type families must follow the randomized evolution graph")
    edgeCount = edgeCount + 1
    if entry.id == "A_CHILD" then
      assert(string.lower(evolution.method) == "level")
      assert(evolution.level >= 30 and evolution.level <= 40)
    end
  end
end
assert(edgeCount == 2)
local function cyclic(id, stack, done)
  if stack[id] then return true end
  if done[id] then return false end
  stack[id] = true
  for _, child in ipairs(adjacency[id] or {}) do
    if cyclic(child, stack, done) then return true end
  end
  stack[id], done[id] = nil, true
  return false
end
local done = {}
for id in pairs(adjacency) do assert(not cyclic(id, {}, done)) end

for _, entry in ipairs(species) do
  local row = first.pokemonMechanics[entry.id]
  local hasDamage = false
  for _, id in ipairs(row.level1Moves) do
    hasDamage = hasDamage or first.moveData[id].power > 0
  end
  for _, learned in ipairs(row.learnset) do
    if learned.level <= 5 then
      hasDamage = hasDamage or first.moveData[learned.move].power > 0
    end
  end
  assert(hasDamage, "early-damage protection must cover every species")
end

for _, field in ipairs({ "power", "accuracy", "pp" }) do
  assert(first.moveData.BIDE[field] == moves.BIDE[field],
    "special move data must remain immutable")
end
local function compatibilityCount(move)
  local count = 0
  for _, entry in ipairs(species) do
    for _, id in ipairs(first.pokemonMechanics[entry.id].tmhm) do
      if id == move then count = count + 1 end
    end
  end
  return count
end
assert(compatibilityCount("CUT") == 2)
assert(compatibilityCount("MEGA_DRAIN") == 2)

local function makeGame()
  local game = { data = { pokemon = {}, moves = {} } }
  for _, entry in ipairs(species) do
    game.data.pokemon[entry.id] = {
      baseStats = clone(entry.stats), evolutions = clone(entry.evolutions),
      types = clone(entry.types), level1Moves = clone(entry.level1Moves),
      learnset = clone(entry.learnset), tmhm = clone(entry.tmhm),
      externalField = { owner = "other-mod" },
    }
  end
  for id, move in pairs(moves) do game.data.moves[id] = clone(move) end
  return game
end

local game = makeGame()
-- A nil supported field must be removed again after an overlay introduces it.
game.data.pokemon.Z_ROOT.tmhm = nil
local pokemonRecord = game.data.pokemon.Z_ROOT
local moveRecord = game.data.moves.TACKLE
local externalField = pokemonRecord.externalField
local baseline = encode(game.data)
local runA = { enabled = true, mappings = first }
local runB = { enabled = true, mappings = alternate }

assert(Runtime.capture(game))
Runtime.apply(game, runA)
assert(game.data.pokemon.Z_ROOT.baseStats.hp
  == first.pokemonMechanics.Z_ROOT.baseStats.hp)
assert(game.data.pokemon.Z_ROOT.evolutions[1].species
  == first.pokemonMechanics.Z_ROOT.evolutions[1].species)
assert(game.data.moves.TACKLE.type == first.moveData.TACKLE.type)
assert(game.data.pokemon.Z_ROOT.tmhm ~= nil)
local appliedA = encode(game.data)

-- Repeated game.ready calls capture again; an already known data identity must
-- retain its pristine snapshot instead of promoting this overlay.
assert(Runtime.capture(game))
Runtime.apply(game, nil)
assert(encode(game.data) == baseline,
  "repeated capture promoted randomized mechanics into the baseline")
assert(game.data.pokemon.Z_ROOT.baseStats.hp == species[2].stats.hp)
assert(game.data.pokemon.Z_ROOT.evolutions[1].species
  == species[2].evolutions[1].species)
assert(game.data.moves.TACKLE.type == moves.TACKLE.type)
assert(game.data.pokemon.Z_ROOT.tmhm == nil,
  "restore did not remove an overlay-introduced optional field")

Runtime.apply(game, runA)
Runtime.apply(game, runA)
assert(encode(game.data) == appliedA, "repeated apply accumulated changes")
Runtime.apply(game, runB)
assert(encode(game.data) ~= appliedA,
  "switching to a second randomized save retained run A")
Runtime.apply(game, nil)
assert(encode(game.data) == baseline, "vanilla switch did not restore baseline")
Runtime.apply(game, runA)
assert(encode(game.data) == appliedA,
  "A -> B -> vanilla -> A did not reproduce run A")

for _, inactive in ipairs({
  { enabled = false, mappings = first },
  { enabled = true, quarantined = true, mappings = first },
  { enabled = true, valid = false, mappings = first },
  { enabled = true, mappings = {} },
  { enabled = true, mappings = { wildGlobal = { A = "B" } } },
}) do
  Runtime.apply(game, inactive)
  assert(encode(game.data) == baseline,
    "inactive or mechanics-free run did not restore baseline")
end

assert(game.data.pokemon.Z_ROOT == pokemonRecord
    and game.data.moves.TACKLE == moveRecord,
  "runtime replaced an entire merged content record")
assert(game.data.pokemon.Z_ROOT.externalField == externalField,
  "runtime replaced an unsupported cross-mod field")

-- Distinct merged data identities retain independent pristine snapshots.
local otherGame = makeGame()
otherGame.data.pokemon.Z_ROOT.baseStats.hp = 99
local otherBaseline = encode(otherGame.data)
Runtime.capture(otherGame)
Runtime.apply(otherGame, runA)
Runtime.apply(game, runB)
Runtime.restore(otherGame)
Runtime.restore(game)
assert(encode(otherGame.data) == otherBaseline,
  "second game.data identity restored the first identity's baseline")
assert(encode(game.data) == baseline,
  "first game.data identity lost its own baseline")

local full = Mechanics.generate({ entries = species }, source, {
  base_stats = "full_random", stat_family_consistency = "off",
}, streams("FULL STATS"))
for _, row in pairs(full.pokemonMechanics) do
  for _, value in pairs(row.baseStats) do
    assert(value >= 1 and value <= 255 and value == math.floor(value))
  end
end

io.write("mechanics_randomizer_test: ok\n")
