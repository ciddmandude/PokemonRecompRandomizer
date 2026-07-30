local Harness = dofile("tests/generator_harness.lua")

local function loadFactory(path, ...)
  local chunk, err = loadfile(path)
  assert(chunk, err)
  return chunk()(...)
end

local Generator = {
  buildSpeciesManifest = function(records)
    local entries, byId = {}, {}
    for index, record in ipairs(records) do
      entries[index] = record
      byId[record.id] = record
    end
    return {
      entries = entries,
      byId = byId,
      poolHash = "entropy-test-pool",
    }
  end,
  generate = Harness.Generator.generate,
}
local Lifecycle = loadFactory(
  "src/save_lifecycle.lua",
  Harness.Constants, Generator, Harness.SaveState, Harness.General)

local function settings(seedMode)
  local result = Harness.request("ENTROPY TEST", "standard").settings
  result.randomizer = "off"
  result.seed_mode = seedMode
  result.seed_text = seedMode == "manual" and "MANUAL TEST" or ""
  return result
end

local function newLifecycle(seedMode, provider, diagnostics)
  return Lifecycle.new({
    records = function() return Harness.species end,
    metadata = function() return {} end,
    settings = function() return settings(seedMode) end,
    sources = function() return Harness.sources end,
    autoSeedEntropy = provider,
    log = {
      debug = function(_, format, ...)
        diagnostics[#diagnostics + 1] = format:format(...)
      end,
      warn = function(_, format, ...)
        diagnostics[#diagnostics + 1] = format:format(...)
      end,
      error = function() end,
    },
  })
end

local injectedCalls = 0
local function deterministicEntropy(save)
  injectedCalls = injectedCalls + 1
  return "fixed entropy\0" .. tostring(save.player.id)
end

local diagnostics = {}
local first = assert(newLifecycle(
  "auto", deterministicEntropy, diagnostics):onCreated({
    save = {
      version = "red",
      player = { id = "PLAYER-1" },
      meta = { engine = "0.1.38", mods = {} },
    },
  }))
local second = assert(newLifecycle(
  "auto", deterministicEntropy, diagnostics):onCreated({
    save = {
      version = "red",
      player = { id = "PLAYER-1" },
      meta = { engine = "0.1.38", mods = {} },
    },
  }))
assert(injectedCalls == 2)
assert(#first.seed.canonical == 26)
assert(first.seed.canonical == second.seed.canonical)
assert(first.seed.canonical:match("^[0-9A-HJKMNP-TV-Z]+$"))
assert(#diagnostics == 0)

local manualCalls = 0
local manual = assert(newLifecycle("manual", function()
  manualCalls = manualCalls + 1
  return "must not be used"
end, diagnostics):onCreated({
  save = {
    version = "red",
    player = { id = "PLAYER-2" },
    meta = { engine = "0.1.38", mods = {} },
  },
}))
assert(manualCalls == 0)
assert(manual.seed.display == "MANUAL TEST")

local previousLove = rawget(_G, "love")
local timerCalls, randomCalls = 0, 0
_G.love = {
  timer = {
    getTime = function()
      timerCalls = timerCalls + 1
      return 123.456789
    end,
  },
  math = {
    random = function(minimum, maximum)
      randomCalls = randomCalls + 1
      assert(minimum == 0 and maximum == 2147483647)
      return 1000 + randomCalls
    end,
  },
}
local loveDiagnostics = {}
local withLove = assert(newLifecycle(
  "auto", nil, loveDiagnostics):onCreated({
    save = {
      version = "red",
      player = { id = "PLAYER-LOVE", name = "RED" },
      meta = { engine = "0.1.38", mods = {} },
    },
  }))
assert(#withLove.seed.canonical == 26)
assert(timerCalls == 1)
assert(randomCalls == 4)
assert(#loveDiagnostics == 0)

_G.love = nil
local fallbackDiagnostics = {}
local fallback = assert(newLifecycle(
  "auto", nil, fallbackDiagnostics):onCreated({
    save = {
      version = "red",
      player = { id = "PLAYER-3", name = "RED" },
      meta = { engine = "0.1.38", mods = {} },
    },
  }))
_G.love = previousLove
assert(#fallback.seed.canonical == 26)
assert(#fallbackDiagnostics <= 1)

local failedDiagnostics = {}
local failed = assert(newLifecycle("auto", function()
  error("injected failure")
end, failedDiagnostics):onCreated({
  save = {
    version = "red",
    player = { id = "PLAYER-4" },
    meta = { engine = "0.1.38", mods = {} },
  },
}))
assert(#failed.seed.canonical == 26)
assert(#failedDiagnostics == 1)

print("save_lifecycle_entropy_test: ok")
