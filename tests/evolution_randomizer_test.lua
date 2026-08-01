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

local function mon(id, stage, bst, evolutions)
  return { id = id, stage = stage, bst = bst, evolutions = evolutions or {} }
end
local entries = {
  mon("A", "basic", 250, {
    { species = "B", method = "LEVEL", level = 16 },
    { species = "C", method = "ITEM", item = "MOON_STONE" },
  }),
  mon("B", "middle", 350, {
    { species = "D", method = "LEVEL", level = 32 },
  }),
  mon("C", "middle", 360, {
    { species = "E", method = "LEVEL", level = 34 },
  }),
  mon("D", "final", 500), mon("E", "final", 510),
  mon("F", "basic", 300, { { species = "G", method = "TRADE" } }),
  mon("G", "final", 490), mon("H", "final", 520),
}

local function streams(seed)
  return {
    evolutions = Rng.fromSeed(seed, "mechanics.evolutions"),
    trades = Rng.fromSeed(seed, "mechanics.trade_evolutions"),
  }
end

local function encode(value)
  if type(value) ~= "table" then return tostring(value) end
  local parts = {}
  for _, key in ipairs(StableSort.keys(value)) do
    parts[#parts + 1] = tostring(key) .. "=" .. encode(value[key])
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

local function validate(result, mode)
  assert(result.fallbackCount == 0, "test pool must produce a complete graph")
  local adjacency, destinations = {}, {}
  local byId = {}
  for _, entry in ipairs(entries) do byId[entry.id] = entry end
  for _, source in ipairs(entries) do
    local rows = assert(result.evolutions[source.id])
    assert(#rows == #source.evolutions, "branch count changed for " .. source.id)
    adjacency[source.id] = {}
    local branch = {}
    for index, row in ipairs(rows) do
      assert(byId[row.species], "unknown evolution destination")
      assert(row.species ~= source.id, "self evolution")
      assert(not branch[row.species], "duplicate branch destination")
      assert(not destinations[row.species], "global repeat despite available pool")
      branch[row.species], destinations[row.species] = true, true
      adjacency[source.id][#adjacency[source.id] + 1] = row.species
      if mode == "preserve_stages" then
        local original = byId[source.evolutions[index].species]
        assert(byId[row.species].stage == original.stage,
          "stage-preserving mode changed destination stage")
      end
      assert(row.method == source.evolutions[index].method,
        "randomization changed evolution trigger")
      assert(row.level == source.evolutions[index].level,
        "randomization changed level parameter")
      assert(row.item == source.evolutions[index].item,
        "randomization changed item parameter")
    end
  end
  local state = {}
  local function visit(id)
    assert(state[id] ~= "visiting", "evolution cycle")
    if state[id] == "done" then return end
    state[id] = "visiting"
    for _, child in ipairs(adjacency[id] or {}) do visit(child) end
    state[id] = "done"
  end
  for id in pairs(adjacency) do visit(id) end
end

for seedIndex = 1, 50 do
  local seed = "EVOLUTION PROPERTY " .. seedIndex
  for _, mode in ipairs({ "preserve_stages", "full_random" }) do
    local settings = {
      evolutions = mode, evolution_repeats = "avoid",
      evolution_trade_safety = "vanilla", similar_strength = "20",
    }
    local first = Evolution.generate(entries, settings, streams(seed))
    local second = Evolution.generate(entries, settings, streams(seed))
    assert(encode(first) == encode(second), "evolution generation is not deterministic")
    validate(first, mode)
  end
end

local converted = Evolution.generate(entries, {
  evolutions = "vanilla", evolution_repeats = "avoid",
  evolution_trade_safety = "fixed_37", similar_strength = "20",
}, streams("TRADE SAFETY"))
for _, entry in ipairs(entries) do
  for index, row in ipairs(converted.evolutions[entry.id]) do
    assert(row.species == entry.evolutions[index].species,
      "trade safety changed a vanilla destination")
    if entry.evolutions[index].method == "TRADE" then
      assert(row.method == "LEVEL" and row.level == 37 and row.item == nil)
    end
  end
end

io.write("evolution_randomizer_test: ok (100 randomized graphs)\n")
