-- Repeatable Round-3 Milestone-7 evolution and mechanics-baseline benchmark.
-- Run from the repository root with Lua 5.1.5.
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
local MechanicsRuntime = loadFactory("src/mechanics_runtime.lua")

local function speciesId(index)
  return ("MON_%04d"):format(index)
end

local function moveId(index)
  return ("MOVE_%04d"):format(index)
end

local function representativeFixture(size)
  local entries, edgeCount = {}, 0
  local sourceCount = math.floor(size * 0.36)
  local targetStart = sourceCount + 1
  for index = 1, size do
    local evolutions = {}
    if index <= sourceCount then
      local first = targetStart + ((index * 7) % (size - targetStart + 1))
      evolutions[1] = {
        species = speciesId(first), method = "LEVEL", level = 16,
      }
      edgeCount = edgeCount + 1
      if index % 17 == 0 then
        local second = targetStart
          + ((index * 13 + 1) % (size - targetStart + 1))
        if second == first then
          second = targetStart + ((second - targetStart + 1)
            % (size - targetStart + 1))
        end
        evolutions[2] = {
          species = speciesId(second), method = "LEVEL", level = 32,
        }
        edgeCount = edgeCount + 1
      end
    end
    entries[index] = {
      id = speciesId(index),
      stage = index <= sourceCount and "basic" or "final",
      bst = 250 + (index % 351),
      evolutions = evolutions,
    }
  end
  return entries, edgeCount, {
    evolutions = "full_random", evolution_repeats = "avoid",
    evolution_trade_safety = "vanilla", similar_strength = "20",
  }
end

local function constrainedFixture(size)
  local entries, edgeCount = {}, 0
  local finalCount = 3
  local sourceCount = math.floor(size * 0.32)
  local firstFinal = size - finalCount + 1
  for index = 1, size do
    local evolutions = {}
    if index <= sourceCount then
      evolutions[1] = {
        species = speciesId(firstFinal + (index % finalCount)),
        method = "LEVEL", level = 20,
      }
      edgeCount = edgeCount + 1
      if index % 19 == 0 then
        evolutions[2] = {
          species = speciesId(firstFinal + ((index + 1) % finalCount)),
          method = "ITEM", item = "MOON_STONE",
        }
        edgeCount = edgeCount + 1
      end
    end
    entries[index] = {
      id = speciesId(index),
      stage = index >= firstFinal and "final" or "basic",
      bst = index >= firstFinal and 500 or 250 + (index % 100),
      evolutions = evolutions,
    }
  end
  return entries, edgeCount, {
    evolutions = "preserve_stages", evolution_repeats = "avoid",
    evolution_trade_safety = "vanilla", similar_strength = "same_stage",
  }
end

local function evolutionStreams(seed)
  return {
    evolutions = Rng.fromSeed(seed, Constants.STREAMS.mechanics.evolutions),
    trades = Rng.fromSeed(seed, Constants.STREAMS.mechanics.tradeEvolutions),
  }
end

local function benchmarkEvolution(size, scenario, factory)
  local entries, edgeCount, settings = factory(size)
  local rngs = evolutionStreams(
    ("ROUND3 M7 %s %d"):format(string.upper(scenario), size))
  collectgarbage("collect")
  local started = os.clock()
  local result = Evolution.generate(entries, settings, rngs)
  local elapsed = os.clock() - started
  local counts = result.counts or {}
  local success = result.fallbackCount == 0
  local searchBudget = math.max(3000, edgeCount * size * 24)
  assert(success, scenario .. " fixture unexpectedly fell back")
  assert(type(counts.searchNodes) == "number"
      and counts.searchNodes <= searchBudget,
    scenario .. " search exceeded its explicit node budget")
  if scenario == "constrained" and edgeCount > 3 then
    assert((counts.repeatRelaxations or 0) > 0,
      "constrained fixture did not exercise uniqueness relaxation")
  end
  assert(elapsed < 30, scenario .. " evolution benchmark exceeded 30 seconds")
  print(("evolution_benchmark pool=%d scenario=%s edges=%d seconds=%.4f "
      .. "rngDraws=%d searchNodes=%d repeatRelaxations=%d "
      .. "softRelaxations=%d success=%s fallback=%s"):format(
    size, scenario, edgeCount, elapsed,
    rngs.evolutions.draws + rngs.trades.draws,
    counts.searchNodes or 0, counts.repeatRelaxations or 0,
    counts.softRelaxations or 0, tostring(success),
    tostring(result.fallbackCount > 0)))
end

local function mechanicsData(speciesCount, moveCount)
  local pokemon, moves = {}, {}
  for index = 1, speciesCount do
    local id = speciesId(index)
    local evolutions = {}
    if index < speciesCount and index % 3 ~= 0 then
      evolutions[1] = {
        species = speciesId(index + 1), method = "LEVEL", level = 16,
      }
    end
    local learnset, tmhm = {}, {}
    for slot = 1, 8 do
      learnset[slot] = {
        level = slot * 7, move = moveId(((index + slot) % moveCount) + 1),
      }
    end
    for slot = 1, 10 do
      tmhm[slot] = moveId(((index * 3 + slot) % moveCount) + 1)
    end
    pokemon[id] = {
      id = id,
      baseStats = {
        hp = 35 + index % 100, attack = 40 + index % 110,
        defense = 45 + index % 105, speed = 30 + index % 120,
        special = 50 + index % 100,
      },
      evolutions = evolutions,
      types = index % 2 == 0 and { "NORMAL" } or { "GRASS", "POISON" },
      level1Moves = { moveId((index % moveCount) + 1) },
      learnset = learnset,
      tmhm = tmhm,
      unsupported = { mustRemainShared = true },
    }
  end
  for index = 1, moveCount do
    local id = moveId(index)
    moves[id] = {
      id = id, type = index % 2 == 0 and "NORMAL" or "GRASS",
      power = index % 121, accuracy = 50 + index % 51,
      pp = 5 + index % 36, effect = "UNCHANGED_EFFECT",
    }
  end
  return { data = { pokemon = pokemon, moves = moves } }
end

local function benchmarkBaseline(speciesCount, moveCount, label)
  local game = mechanicsData(speciesCount, moveCount)
  local runtime = MechanicsRuntime
  collectgarbage("collect")
  local before = collectgarbage("count")
  local started = os.clock()
  assert(runtime.capture(game), "mechanics baseline capture failed")
  local elapsed = os.clock() - started
  collectgarbage("collect")
  local baselineKiB = math.max(0, collectgarbage("count") - before)
  assert(elapsed < 5, "mechanics baseline capture exceeded 5 seconds")
  assert(baselineKiB < 65536,
    "mechanics baseline exceeded the 64 MiB review guardrail")
  print(("mechanics_baseline fixture=%s species=%d moves=%d "
      .. "captureSeconds=%.4f baselineKiB=%.1f success=true"):format(
    label, speciesCount, moveCount, elapsed, baselineKiB))
end

for _, size in ipairs({ 151, 500, 1000 }) do
  benchmarkEvolution(size, "representative", representativeFixture)
  benchmarkEvolution(size, "constrained", constrainedFixture)
end

benchmarkBaseline(151, 165, "vanilla")
benchmarkBaseline(1000, 1000, "merged-1000")
print("round3_m7_benchmark: ok")
