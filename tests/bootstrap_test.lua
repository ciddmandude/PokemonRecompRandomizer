-- Headless entry/bootstrap integration test with a minimal mod API-2 stub.
local callbacks = {}
local logs = {}
local migrations = {}
local hookCallbacks = {}
local screens = {}
local mapScriptContributions = {}
local optionSchema
local pushedScreen
local saveBucket = {}
local options = {}

local mod = {
  id = "pokemon_randomizer",
  version = "0.9.1",
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
        local index = 0
        local rows = {
          {
            "TESTMON",
            {
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
            },
          },
          {
            "BULBASAUR",
            {
              id = "BULBASAUR",
              dex = 1,
              baseStats = {
                hp = 45, attack = 49, defense = 49, speed = 45, special = 65,
              },
              types = { "GRASS", "POISON" },
              growthRate = "MEDIUM_SLOW",
              level1Moves = {},
              learnset = {},
              evolutions = {},
              spriteFront = "bulbasaur.png",
              spriteBack = "bulbasaurb.png",
            },
          },
        }
        return function()
          index = index + 1
          local row = rows[index]
          if not row then return nil end
          return row[1], row[2]
        end
      end,
    },
    encounters = {
      each = function()
        local yielded = false
        return function()
          if yielded then return nil end
          yielded = true
          return "TEST_MAP", {
            grass = {
              rate = 30,
              slots = {{ level = 5, species = "BULBASAUR" }},
            },
          }
        end
      end,
    },
    field = {
      get = function(_, key)
        if key == "fishing" then
          return {
            OLD_ROD = {
              always = { species = "BULBASAUR", level = 5 },
            },
          }
        end
        return nil
      end,
    },
    map_scripts = {
      register = function(_, id, contribution)
        mapScriptContributions[id] = contribution
        return contribution
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
assert(mod.exports.generator.available == true)
assert(type(mod.exports.registerSpeciesMeta) == "function")
assert(mod.exports.species.manifestVersion == 1)
assert(mod.exports.save.checksumVersion == "fnv1a32x4-save-v1")
assert(type(mod.exports.preferences.snapshot) == "function")
assert(#mod.exports.preferences.schema() == 34)
assert(#optionSchema == 34)
assert(type(screens.PokemonRandomizerOptions.new) == "function")
assert(type(screens.PokemonRandomizerReview.new) == "function")
assert(type(hookCallbacks["ui.options.rows"]) == "function")
assert(type(hookCallbacks["encounter.species"]) == "function")
assert(type(hookCallbacks["encounter.roll"]) == "function")
assert(type(hookCallbacks["encounter.fishing"]) == "function")
assert(type(mapScriptContributions.OAKS_LAB) == "table")
assert(type(mapScriptContributions.OAKS_LAB.talk
  .TEXT_OAKSLAB_CHARMANDER_POKE_BALL) == "function")
assert(type(callbacks["mods.loaded"]) == "function")
assert(type(callbacks["save.created"]) == "function")
assert(type(callbacks["save.loading"]) == "function")
assert(type(callbacks["save.loaded"]) == "function")
assert(type(callbacks["save.writing"]) == "function")
assert(#migrations == 2)
assert(migrations[1].since == "0.4.0")
assert(migrations[2].since == "0.6.0")

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
assert(logs[1]:match("milestone 9 ready"))
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
assert(run.enabled == true)
assert(run.checksum.version == "fnv1a32x4-save-v1")
assert(run.mappings.wildGlobal.BULBASAUR == "BULBASAUR")
assert(run.mappings.fishing.global.BULBASAUR == "BULBASAUR")
assert(#run.diagnostics.warnings == 0)
assert(run.settings.randomizer == "on")
assert(run.settings.preset == "standard")
assert(run.settings.seed_text == "")
assert(#run.seed.canonical == 26)
assert(type(mod.exports.runCode(run)) == "string")

local nextCalled = false
local vanillaEncounter = { species = "BULBASAUR", level = 7, marker = true }
local resolvedEncounter = hookCallbacks["encounter.species"](
  function(encounter, context)
    nextCalled = context.terrain == "grass"
    return encounter
  end,
  vanillaEncounter,
  { mapId = "TEST_MAP", terrain = "grass" })
assert(nextCalled, "encounter.species must call the next hook first")
assert(resolvedEncounter ~= vanillaEncounter,
  "a mapped encounter must copy the prior hook result")
assert(resolvedEncounter.species == "BULBASAUR")
assert(resolvedEncounter.level == 7 and resolvedEncounter.marker == true)

local rollCalls = 0
local rolled = hookCallbacks["encounter.roll"](
  function()
    rollCalls = rollCalls + 1
    return { species = "BULBASAUR", level = 5 }
  end,
  { grass = { slots = {{ species = "BULBASAUR", level = 5 }} } },
  { mapId = "TEST_MAP", terrain = "grass" })
assert(rollCalls == 1 and rolled.species == "BULBASAUR",
  "unchanged global levels must preserve the vanilla roll exactly")

local fishCalls = 0
local fish = hookCallbacks["encounter.fishing"](
  function()
    fishCalls = fishCalls + 1
    return { species = "BULBASAUR", level = 5 }
  end,
  "OLD_ROD", "TEST_MAP", nil)
assert(fishCalls == 1 and fish.species == "BULBASAUR" and fish.level == 5)

local starterRows
mapScriptContributions.OAKS_LAB.talk
  .TEXT_OAKSLAB_CHARMANDER_POKE_BALL({
    save = save,
    data = {
      pokemon = {
        CHARMANDER = {}, SQUIRTLE = {}, BULBASAUR = {},
      },
    },
  }, {
    runner = {
      run = function(_, rows) starterRows = rows end,
    },
  }, nil, function() end)
assert(starterRows[5][3].species == "CHARMANDER")
assert(starterRows[9][2] == "CHARMANDER" and starterRows[9][3] == 5)
assert(starterRows[16][3] == "OAKSLAB_SQUIRTLE_POKE_BALL")

callbacks["save.loading"]({ raw = save })
assert(mod.exports.save.status().phase == "loading")
callbacks["save.loaded"]({ save = save, meta = save.meta, modsDiff = {} })
assert(mod.exports.save.status().phase == "loaded")
assert(type(mod.exports.save.activeRun()) == "table")

save.meta.mods = {
  { id = "pokemon_randomizer", version = "0.9.1", api = 2 },
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
local legacyHash = legacy.compatibility.settingsHash
migrations[2].callback(legacy)
assert(type(legacy.compatibility.settingsHash) == "string")
assert(legacy.compatibility.settingsHash == legacyHash)
local migratedValid = mod.exports.save.validate(legacy, nil, true)
assert(migratedValid)

io.write("bootstrap_test: ok\n")
