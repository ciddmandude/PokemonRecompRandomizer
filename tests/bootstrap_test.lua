-- Headless entry/bootstrap integration test with a minimal mod API-2 stub.
local callbacks = {}
local logs = {}
local migrations = {}
local hookCallbacks = {}
local screens = {}
local optionSchema
local pushedScreen
local saveBucket = {}
local options = {}

local mod = {
  id = "pokemon_randomizer",
  version = "0.5.0",
  path = ".",
  manifest = { api = 2 },
  content = {
    screens = {
      register = function(_, id, record)
        screens[id] = record
        return record
      end,
    },
    pokemon = {
      each = function()
        local yielded = false
        return function()
          if yielded then return nil end
          yielded = true
          return "TESTMON", {
            id = "TESTMON",
            dex = 1001,
            baseStats = {
              hp = 50, attack = 50, defense = 50, speed = 50, special = 50,
            },
            types = { "NORMAL" },
            growthRate = "MEDIUM",
            level1Moves = {},
            learnset = {},
            evolutions = {},
            spriteFront = "front.png",
            spriteBack = "back.png",
          }
        end
      end,
    },
  },
  exports = {},
  events = {
    on = function(_, name, callback)
      callbacks[name] = callback
      return function() callbacks[name] = nil end
    end,
    once = function(_, name, callback)
      callbacks[name] = callback
      return function() callbacks[name] = nil end
    end,
  },
  hooks = {
    wrap = function(_, name, callback)
      hookCallbacks[name] = callback
      return function() hookCallbacks[name] = nil end
    end,
  },
  save = {
    get = function(_, key, default)
      local value = saveBucket[key]
      if value == nil then return default end
      return value
    end,
    set = function(_, key, value) saveBucket[key] = value end,
  },
  options = {
    define = function(_, schema) optionSchema = schema return schema end,
    get = function(_, key) return options[key] end,
  },
  ui = {
    push = function(_, id) pushedScreen = id end,
  },
  migrations = {
    add = function(_, since, callback)
      migrations[#migrations + 1] = { since = since, callback = callback }
      return callback
    end,
  },
  log = {
    info = function(_, format, ...)
      logs[#logs + 1] = format:format(...)
    end,
    warn = function() end,
    error = function() end,
  },
}

function mod:read(relative)
  local file, err = io.open(relative, "rb")
  if not file then return nil, err end
  local contents = file:read("*a")
  file:close()
  return contents
end

local entry = assert(loadfile("main.lua"))()
assert(type(entry) == "function")
entry(mod)

assert(mod.exports.contractVersion == 1)
assert(mod.exports.algorithmVersion == "1.0.0-dev")
assert(mod.exports.hashVersion == "fnv1a32x4-v1")
assert(mod.exports.prngVersion == "xoshiro128ss-v1")
assert(mod.exports.generator.foundationAvailable == true)
assert(type(mod.exports.registerSpeciesMeta) == "function")
assert(mod.exports.species.manifestVersion == 1)
assert(mod.exports.save.checksumVersion == "fnv1a32x4-save-v1")
assert(type(mod.exports.preferences.snapshot) == "function")
assert(#mod.exports.preferences.schema() == 34)
assert(#optionSchema == 34)
assert(type(screens.PokemonRandomizerOptions.new) == "function")
assert(type(hookCallbacks["ui.options.rows"]) == "function")
assert(type(callbacks["mods.loaded"]) == "function")
assert(type(callbacks["save.created"]) == "function")
assert(type(callbacks["save.loading"]) == "function")
assert(type(callbacks["save.loaded"]) == "function")
assert(type(callbacks["save.writing"]) == "function")
assert(#migrations == 1 and migrations[1].since == "0.4.0")

mod.exports.registerSpeciesMeta("TESTMON", { legendary = true })
local manifest = mod.exports.species.buildManifest({ poolMode = "merged" })
assert(manifest.byId.TESTMON.legendary == true)
assert(not mod.exports.species.metadataFrozen())

local canonical = mod.exports.generator.normalizeSeed(" bootstrap  test ")
assert(canonical == "BOOTSTRAP TEST")
local stream = mod.exports.generator.newStream(canonical, "starters")
assert(type(stream:nextU32()) == "number")

callbacks["mods.loaded"]()
assert(#logs == 1)
assert(logs[1]:match("milestone 5 ready"))
assert(mod.exports.species.metadataFrozen())
local late = pcall(function()
  mod.exports.registerSpeciesMeta("LATE_MON", { legendary = false })
end)
assert(not late)

local optionRows = hookCallbacks["ui.options.rows"](
  function(_, rows) return rows end, {}, {})
assert(#optionRows == 1)
assert(optionRows[1].label == "RANDOMIZER")
assert(optionRows[1].value() == "OPEN")
optionRows[1].activate({})
assert(pushedScreen == "PokemonRandomizerOptions")

local save = {
  version = "red",
  meta = { engine = "1.0.0", mods = {} },
  player = { id = 1234 },
  modData = {},
}
callbacks["save.created"]({ save = save })
local run = save.modData.pokemon_randomizer
assert(type(run) == "table")
assert(run.schemaVersion == 1)
assert(run.enabled == false)
assert(run.checksum.version == "fnv1a32x4-save-v1")
assert(run.diagnostics.warnings[1].code == "GENERATOR_UNAVAILABLE")
assert(run.settings.randomizer == "on")
assert(run.settings.preset == "standard")
assert(run.settings.seed_text == "")

callbacks["save.loading"]({ raw = save })
assert(mod.exports.save.status().phase == "loading")
callbacks["save.loaded"]({ save = save, meta = save.meta, modsDiff = {} })
assert(mod.exports.save.status().phase == "loaded-vanilla")
assert(mod.exports.save.activeRun() == nil)

save.meta.mods = {
  { id = "pokemon_randomizer", version = "0.5.0", api = 2 },
  { id = "test_dependency", version = "1.2.3", api = 2 },
}
local wrote = callbacks["save.writing"]({ save = save, meta = save.meta })
assert(wrote == nil) -- event adapters intentionally do not consume payloads
run = save.modData.pokemon_randomizer
assert(run.compatibility.relevantMods[1].id == "test_dependency")
local checksum = run.checksum.value
callbacks["save.writing"]({ save = save, meta = save.meta })
assert(save.modData.pokemon_randomizer.checksum.value == checksum)

run = save.modData.pokemon_randomizer
run.settings.tampered = true
callbacks["save.loaded"]({ save = save, meta = save.meta, modsDiff = {} })
assert(mod.exports.save.status().phase == "quarantined")
assert(run.settings.tampered == true,
  "quarantine must retain original data for recovery")
local damagedChecksum = run.checksum.value
callbacks["save.writing"]({ save = save, meta = save.meta })
assert(save.modData.pokemon_randomizer == run,
  "invalid pre-write state must not be replaced")
assert(run.checksum.value == damagedChecksum,
  "invalid pre-write state must not receive a new checksum")

local legacy = {
  schemaVersion = 0,
  algorithmVersion = "1.0.0-dev",
  enabled = false,
  seed = "LEGACY",
  settings = {},
  compatibility = run.compatibility,
  mappings = run.mappings,
  diagnostics = { warnings = {}, fallbackCount = 0 },
  race = {
    enabled = false,
    unlockPolicy = "hall_of_fame",
    unlocked = false,
  },
  futureField = "keep",
}
migrations[1].callback(legacy)
assert(legacy.schemaVersion == 1)
assert(legacy.seed.canonical == "LEGACY")
assert(legacy.futureField == "keep")
assert(type(legacy.checksum.value) == "string")

io.write("bootstrap_test: ok\n")
