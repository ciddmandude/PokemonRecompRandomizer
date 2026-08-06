-- Headless entry/bootstrap integration test with a minimal mod API-2 stub.
local callbacks = {}
local logs = {}
local debugLogs = {}
local warnings = {}
local migrations = {}
local hookCallbacks = {}
local screens = {}
local mapScriptContributions = {}
local commandRecords = {
  show_text = function() end,
  ask = function() end,
  play_cry = function() end,
  static_battle = function() end,
  give_pokemon = function() end,
  trade = function() end,
}
local optionSchema
local pushedScreen
local pushedModel
local setupQuestions = {}
local setupPicker
local saveBucket = {}
local options = {}

local function deepCopy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local copy = {}
  seen[value] = copy
  for key, child in pairs(value) do
    copy[deepCopy(key, seen)] = deepCopy(child, seen)
  end
  return copy
end

local function deepEqual(left, right, seen)
  if type(left) ~= type(right) then return false end
  if type(left) ~= "table" then return left == right end
  seen = seen or {}
  if seen[left] == right then return true end
  seen[left] = right
  for key, value in pairs(left) do
    if not deepEqual(value, right[key], seen) then return false end
  end
  for key in pairs(right) do
    if left[key] == nil then return false end
  end
  return true
end

local mod = {
  id = "pokemon_randomizer",
  version = "0.46.4",
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
          {
            "CHARMANDER",
            {
              id = "CHARMANDER",
              dex = 4,
              baseStats = {
                hp = 39, attack = 52, defense = 43, speed = 65, special = 50,
              },
              types = { "FIRE" },
              growthRate = "MEDIUM_SLOW",
              level1Moves = {},
              learnset = {},
              evolutions = {},
              spriteFront = "charmander.png",
              spriteBack = "charmanderb.png",
            },
          },
          {
            "SQUIRTLE",
            {
              id = "SQUIRTLE",
              dex = 7,
              baseStats = {
                hp = 44, attack = 48, defense = 65, speed = 43, special = 50,
              },
              types = { "WATER" },
              growthRate = "MEDIUM_SLOW",
              level1Moves = {},
              learnset = {},
              evolutions = {},
              spriteFront = "squirtle.png",
              spriteBack = "squirtleb.png",
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
    trainers = {
      each = function()
        local yielded = false
        return function()
          if yielded then return nil end
          yielded = true
          return "OPP_FIX_YOUNGSTER", {
            id = "OPP_FIX_YOUNGSTER",
            parties = {
              {
                { species = "BULBASAUR", level = 5 },
                { species = "CHARMANDER", level = 6 },
                { species = "MOD_ADDED", level = 7 },
              },
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
    commands = {
      get = function(_, id) return commandRecords[id] end,
      register = function(_, id, command)
        commandRecords[id] = command
        return command
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
    push = function(_, id, model)
      pushedScreen, pushedModel = id, model
    end,
    insertBefore = function(items, anchor, item)
      for index, row in ipairs(items) do
        if row.label == anchor then
          table.insert(items, index, item)
          return items
        end
      end
      items[#items + 1] = item
      return items
    end,
    insertStepBefore = function(steps, anchor, step)
      for index, row in ipairs(steps) do
        if row.id == anchor then
          table.insert(steps, index, step)
          return steps
        end
      end
      steps[#steps + 1] = step
      return steps
    end,
    TextBox = {
      new = function(_, text, _, options)
        local row = { text = text, options = options }
        setupQuestions[#setupQuestions + 1] = row
        return row
      end,
    },
    ListMenu = {
      new = function(_, title, items, options)
        setupPicker = { title = title, items = items, options = options }
        return setupPicker
      end,
    },
  },
  migrations = {
    add = function(_, since, callback)
      migrations[#migrations + 1] = { since = since, callback = callback }
      return callback
    end,
  },
  log = {
    debug = function(_, format, ...)
      debugLogs[#debugLogs + 1] = format:format(...)
    end,
    info = function(_, format, ...)
      logs[#logs + 1] = format:format(...)
    end,
    warn = function(_, format, ...)
      warnings[#warnings + 1] = format:format(...)
    end,
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
assert(mod.exports.algorithmVersion == "1.19.0-dev")
assert(mod.exports.hashVersion == "fnv1a32x4-v1")
assert(mod.exports.prngVersion == "xoshiro128ss-v1")
assert(mod.exports.generator.foundationAvailable == true)
assert(mod.exports.generator.available == true)
local facadeMutation = pcall(function()
  mod.exports.generator.generate = function() return nil end
end)
assert(not facadeMutation, "generator export must be read-only")
facadeMutation = pcall(function()
  mod.exports.contracts.mappingKeys = function() return {} end
end)
assert(not facadeMutation, "contract export must be read-only")
local facadeKeys = {
  species = "buildManifest",
  save = "status",
  preferences = "snapshot",
  spoilers = "format",
}
for facadeName, key in pairs(facadeKeys) do
  facadeMutation = pcall(function()
    mod.exports[facadeName][key] = function() return nil end
  end)
  assert(not facadeMutation,
    facadeName .. " export must be read-only")
  assert(getmetatable(mod.exports[facadeName]) == "read-only")
end
assert(type(mod.exports.registerSpeciesMeta) == "function")
assert(mod.exports.species.manifestVersion == 1)
assert(mod.exports.save.checksumVersion == "fnv1a32x4-save-v1")
assert(type(mod.exports.preferences.snapshot) == "function")
assert(type(mod.exports.spoilers.canAccess) == "function")
assert(type(mod.exports.spoilers.format) == "function")
assert(type(mod.exports.spoilers.export) == "function")
assert(#mod.exports.preferences.schema() == 57)
local exportedSchema = mod.exports.preferences.schema()
exportedSchema[1].label = "MUTATED"
assert(mod.exports.preferences.schema()[1].label ~= "MUTATED")
local exportedPages = mod.exports.preferences.pages()
exportedPages[1].rows[1].key = "mutated"
assert(mod.exports.preferences.pages()[1].rows[1].key ~= "mutated")
local exportedSettings = mod.exports.preferences.snapshot()
exportedSettings.randomizer = "MUTATED"
assert(mod.exports.preferences.snapshot().randomizer ~= "MUTATED")
assert(#optionSchema == 57)
assert(type(screens.PokemonRandomizerOptions.new) == "function")
assert(type(screens.PokemonRandomizerReview.new) == "function")
assert(type(screens.PokemonRandomizerSpoilerBrowser.new) == "function")
assert(type(hookCallbacks["ui.options.rows"]) == "function")
assert(type(hookCallbacks["ui.start_menu.items"]) == "function")
assert(type(hookCallbacks["intro.oak_speech.build"]) == "function")
assert(type(hookCallbacks["encounter.species"]) == "function")
assert(type(hookCallbacks["encounter.roll"]) == "function")
assert(type(hookCallbacks["encounter.fishing"]) == "function")
assert(type(hookCallbacks["trainer.party"]) == "function")
assert(type(mapScriptContributions.OAKS_LAB) == "table")
assert(type(mapScriptContributions.POWER_PLANT) == "table")
assert(type(mapScriptContributions.CELADON_MANSION_ROOF_HOUSE) == "table")
assert(type(commandRecords["pokemon_randomizer:static_m11_battle"])
  == "function")
assert(type(commandRecords["pokemon_randomizer:give_m11_pokemon"])
  == "function")
assert(type(commandRecords["pokemon_randomizer:trade_m12"])
  == "function")
assert(type(screens.PokemonRandomizerGameCornerPrizes.new) == "function")
assert(type(mapScriptContributions.GAME_CORNER_PRIZE_ROOM) == "table")
assert(type(mapScriptContributions.OAKS_LAB.talk
  .TEXT_OAKSLAB_CHARMANDER_POKE_BALL) == "function")
assert(type(callbacks["mods.loaded"]) == "function")
assert(type(callbacks["game.ready"]) == "function")
assert(type(callbacks["save.created"]) == "function")
assert(type(callbacks["save.loading"]) == "function")
assert(type(callbacks["save.loaded"]) == "function")
assert(type(callbacks["save.writing"]) == "function")
assert(type(callbacks["battle.ended"]) == "function")
assert(#migrations == 4)
assert(migrations[1].since == "0.4.0")
assert(migrations[2].since == "0.6.0")
assert(migrations[3].since == "0.40.0")
assert(migrations[4].since == "0.45.0")

mod.exports.registerSpeciesMeta("TESTMON", { legendary = true })
mod.exports.registerSpeciesMeta("TESTMON", {
  legendary = false, stage = "basic",
})
local manifest = mod.exports.species.buildManifest({ poolMode = "merged" })
assert(manifest.byId.TESTMON.legendary == true)
assert(manifest.byId.TESTMON.stage == "basic")
local metadataDiagnostics = mod.exports.species.metadataDiagnostics()
assert(#metadataDiagnostics == 1)
assert(metadataDiagnostics[1].code
  == "SPECIES_METADATA_CONFLICT_RESOLVED")
metadataDiagnostics[1].resolved = false
assert(mod.exports.species.metadataDiagnostics()[1].resolved == true)
assert(not mod.exports.species.metadataFrozen())

local canonical = mod.exports.generator.normalizeSeed(" bootstrap  test ")
assert(canonical == "BOOTSTRAP TEST")
local stream = mod.exports.generator.newStream(canonical, "starters")
assert(type(stream:nextU32()) == "number")

callbacks["mods.loaded"]()
assert(#logs == 1)
assert(#warnings == 1)
assert(warnings[1]:find("SPECIES_METADATA_CONFLICT_RESOLVED", 1, true))
assert(logs[1]:match("milestone 14 ready"))
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

local unavailableStartRows = hookCallbacks["ui.start_menu.items"](
  function(_, rows) return rows end, {}, {
    { label = "OPTION" }, { label = "MODS" }, { label = "QUIT" },
  })
assert(#unavailableStartRows == 3,
  "pause menu must hide SPOILER until an eligible run is active")

local bootPlaceholder = {
  version = "red",
  meta = { engine = "1.0.0", mods = {} },
  player = { id = 999 },
  modData = {},
}
local warningsBeforeBoot = #warnings
local pushedBeforeBoot = pushedScreen
callbacks["save.created"]({ save = bootPlaceholder })
callbacks["save.created"]({ save = bootPlaceholder })
assert(bootPlaceholder.modData.pokemon_randomizer == nil,
  "the pre-game.ready boot skeleton must not generate a run")
assert(optionRows[1].value() == "OPEN",
  "the title-screen randomizer must remain open after application boot")
assert(#debugLogs == 1
    and debugLogs[1]:find("suppressed", 1, true)
    and debugLogs[1]:find("pre%-game.ready"),
  "boot skeleton suppression must emit exactly one debug diagnostic")
assert(#warnings == warningsBeforeBoot and pushedScreen == pushedBeforeBoot,
  "normal boot suppression must not warn or show a user-facing error")

callbacks["game.ready"]({})
local automaticSpoiler
local oldLove = love
love = {
  filesystem = {
    createDirectory = function() return true end,
    write = function(path, contents)
      automaticSpoiler = { path = path, contents = contents }
      return true
    end,
  },
}
options.generate_spoiler_log = "on"
local save = {
  version = "red",
  meta = { engine = "1.0.0", mods = {} },
  player = { id = 1234 },
  modData = {},
}
callbacks["save.created"]({ save = save })
assert(save.modData.pokemon_randomizer == nil,
  "New Game generation must wait for the intro chooser")
local introStack = {
  values = {},
  push = function(self, value) self.values[#self.values + 1] = value end,
  pop = function(self) table.remove(self.values) end,
}
local introGame = {
  save = save,
  data = {
    pokemon = {
      BULBASAUR = {
        baseStats = {
          hp = 45, attack = 49, defense = 49, speed = 45, special = 65,
        },
        evolutions = {}, types = { "GRASS", "POISON" },
        level1Moves = {}, learnset = {}, tmhm = {},
      },
    },
    moves = {},
  },
  stack = introStack,
}
-- Recomp may repeat game.ready. The first event for this data identity captures
-- the pristine merged mechanics tables.
callbacks["game.ready"]({ game = introGame })
local steps = hookCallbacks["intro.oak_speech.build"](
  function(value) return value end,
  { { id = "oak_welcome", kind = "say" } },
  { game = introGame })
assert(#steps == 2
    and steps[1].id == "pokemon_randomizer:new_game_setup"
    and steps[2].id == "oak_welcome",
  "New Game setup must run before Oak's first line")
local introContinued = false
steps[1].run({}, function() introContinued = true end)
assert(setupQuestions[1].text == "TURN ON THE\nRANDOMIZER?"
    and setupQuestions[1].options.defaultNo == true,
  "the first prompt must offer a safe vanilla default")
setupQuestions[1].options.choice(true)
assert(setupQuestions[2].text == "USE A SETTINGS\nPRESET?"
    and setupQuestions[2].options.defaultNo == false,
  "enabled New Games must offer the preset picker")
setupQuestions[2].options.choice(true)
assert(setupPicker and setupPicker.title == "RANDOMIZER PRESET")
local standard
for _, item in ipairs(setupPicker.items) do
  assert(item.value ~= "custom",
    "the preset picker must not include the custom editor sentinel")
  if item.value == "standard" then standard = item end
end
assert(standard, "the preset picker must include STANDARD")
setupPicker.options.onChoose(standard)
love = oldLove
local run = save.modData.pokemon_randomizer
assert(type(run) == "table")
assert(introContinued,
  "Oak's intro must resume immediately after selecting a preset")
assert(run.schemaVersion == 1)
assert(run.enabled == true)
assert(run.settings.generate_spoiler_log == "on")
assert(automaticSpoiler == nil,
  "New Game must wait for an explicit spoiler export request")
assert(run.checksum.version == "fnv1a32x4-save-v1")
assert(run.diagnostics.validation.mappingBytes > 0)
assert(run.diagnostics.validation.namespaceBytes
  < run.diagnostics.validation.budgetBytes)
assert(run.diagnostics.validation.budgetBytes == 262144)
assert(type(run.mappings.wildGlobal.BULBASAUR) == "string")
assert(type(run.mappings.fishing.global.BULBASAUR) == "string")
assert(#run.diagnostics.warnings >= 2,
  "minimal fixture must record scoped M11 vanilla fallbacks")
assert(type(run.mappings.starters.LEFT) == "table")
assert(type(run.mappings.starters.MIDDLE) == "table")
assert(type(run.mappings.starters.RIGHT) == "table")
assert(run.mappings.trainerParties.OPP_FIX_YOUNGSTER[1][3].fallback
    == true,
  "an out-of-pool trainer source must save a vanilla fallback marker")
assert(run.settings.randomizer == "on")
assert(run.settings.preset == "standard")
assert(run.settings.seed_text == "")
assert(#run.seed.canonical == 26)
assert(type(mod.exports.runCode(run)) == "string")
assert(optionRows[1].value() == "LOCKED",
  "an actual New Game must lock its generated run")

introGame.data.pokemon.BULBASAUR.baseStats.hp = 222
callbacks["game.ready"]({ game = introGame })
callbacks["save.loaded"]({ save = save, meta = save.meta, modsDiff = {} })
assert(introGame.data.pokemon.BULBASAUR.baseStats.hp == 45,
  "repeated game.ready promoted active mechanics into the baseline")

local pauseGame = { data = {}, save = save }
local startRows = hookCallbacks["ui.start_menu.items"](
  function(_, rows) return rows end, pauseGame, {
    { label = "OPTION" }, { label = "MODS" }, { label = "QUIT" },
  })
assert(#startRows == 4 and startRows[2].label == "SPOILER"
    and startRows[3].label == "MODS",
  "eligible runs add SPOILER immediately before MODS")
startRows[2].onSelect()
assert(pushedScreen == "PokemonRandomizerSpoilerBrowser"
    and type(pushedModel.onCancel) == "function",
  "pause-menu SPOILER opens the existing browser with return navigation")
pushedModel.onCancel(pauseGame)
assert(pushedScreen == "StartMenu",
  "closing the pause-menu spoiler browser reopens the Start menu")

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
assert(resolvedEncounter.species == run.mappings.wildGlobal.BULBASAUR)
assert(resolvedEncounter.level == 7 and resolvedEncounter.marker == true)

local rollCalls = 0
local rolled = hookCallbacks["encounter.roll"](
  function()
    rollCalls = rollCalls + 1
    return { species = "BULBASAUR", level = 5 }
  end,
  { grass = { slots = {{ species = "BULBASAUR", level = 5 }} } },
  { mapId = "TEST_MAP", terrain = "grass" })
assert(rollCalls == 1
  and rolled.species == "BULBASAUR",
  "unchanged global levels must preserve the vanilla roll exactly")

local fishCalls = 0
local fish = hookCallbacks["encounter.fishing"](
  function()
    fishCalls = fishCalls + 1
    return { species = "BULBASAUR", level = 5 }
  end,
  "OLD_ROD", "TEST_MAP", nil)
assert(fishCalls == 1
  and fish.species == run.mappings.fishing.global.BULBASAUR
  and fish.level == 5)

local starterRows
mapScriptContributions.OAKS_LAB.talk
  .TEXT_OAKSLAB_CHARMANDER_POKE_BALL({
    save = save,
    data = {
      pokemon = {
        CHARMANDER = {}, SQUIRTLE = {}, BULBASAUR = {}, TESTMON = {},
      },
    },
  }, {
    runner = {
      run = function(_, rows) starterRows = rows end,
    },
  }, nil, function() end)
local leftOffer = run.mappings.starters.LEFT
assert(starterRows[5][3].species == leftOffer.species)
assert(starterRows[9][2] == leftOffer.species
  and starterRows[9][3] == leftOffer.level)
assert(starterRows[16][3] == leftOffer.rivalBall)

local rivalParty = hookCallbacks["trainer.party"](
  function(_, _, party) return party end,
  "OPP_RIVAL1", 1, {{ species = "SQUIRTLE", level = 5 }})
assert(rivalParty[1].species == leftOffer.rivalSpecies)
assert(rivalParty[1].level == 5)

callbacks["save.loading"]({ raw = save })
assert(mod.exports.save.status().phase == "loading")
callbacks["save.loaded"]({ save = save, meta = save.meta, modsDiff = {} })
assert(mod.exports.save.status().phase == "loaded")
assert(type(mod.exports.save.activeRun()) == "table")
local exposedRun = mod.exports.save.activeRun()
local exposedSeed = exposedRun.seed.canonical
local exposedWild = exposedRun.settings.wild_pokemon
exposedRun.seed.canonical = "MUTATED BY OTHER MOD"
exposedRun.settings.wild_pokemon = "off"
exposedRun.mappings.wildGlobal.__EXTERNAL = "MEW"
local isolatedRun = mod.exports.save.activeRun()
assert(isolatedRun.seed.canonical == exposedSeed)
assert(isolatedRun.settings.wild_pokemon == exposedWild)
assert(isolatedRun.mappings.wildGlobal.__EXTERNAL == nil)

save.meta.mods = {
  { id = "pokemon_randomizer", version = "0.46.4", api = 2 },
  { id = "test_dependency", version = "1.2.3", api = 2 },
}
callbacks["save.loaded"]({ save = save, meta = save.meta, modsDiff = {} })
local drift = mod.exports.save.status().report
assert(drift.code == "COMPATIBILITY_CHANGED")
assert(drift.compatibility.added[1].id == "test_dependency")
local wrote = callbacks["save.writing"]({ save = save, meta = save.meta })
assert(wrote == nil) -- event adapters intentionally do not consume payloads
run = save.modData.pokemon_randomizer
assert(#run.compatibility.relevantMods == 0,
  "save writes must preserve the New Game relevant-mod snapshot")
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
  race = { enabled = true, unlockPolicy = "never", unlocked = false },
  futureField = "keep",
}
migrations[1].callback(legacy)
assert(legacy.schemaVersion == 1)
assert(legacy.seed.canonical == "LEGACY")
assert(legacy.algorithmVersion == "1.0.0-dev",
  "migration must retain the algorithm that produced stored mappings")
assert(legacy.futureField == "keep")
assert(type(legacy.checksum.value) == "string")
local legacyHash = legacy.compatibility.settingsHash
migrations[2].callback(legacy)
assert(type(legacy.compatibility.settingsHash) == "string")
assert(legacy.compatibility.settingsHash == legacyHash)
local migratedValid = mod.exports.save.validate(legacy, nil, true)
assert(migratedValid)

local function assertMigrationStamp(namespace, staleHash, label)
  assert(namespace.compatibility.settingsHash ~= staleHash,
    label .. " must recompute the settings hash")
  assert(namespace.checksum.version == "fnv1a32x4-save-v1"
      and type(namespace.checksum.value) == "string",
    label .. " must stamp the checksum")
  assert(namespace.checksum.value == mod.exports.save.checksum(namespace),
    label .. " checksum must match migrated contents")
  assert(mod.exports.save.validate(namespace, nil, true),
    label .. " must produce a valid namespace")
end

local function assertMappingsPreserved(actual, expected, excluded, label)
  for _, key in ipairs(mod.exports.contracts.mappingKeys()) do
    if not excluded[key] then
      assert(deepEqual(actual[key], expected[key]),
        label .. " changed existing mapping bucket " .. key)
    end
  end
end

local preItems = deepCopy(legacy)
preItems.settings.field_items = nil
preItems.mappings.fieldItems = nil
preItems.mappings.wildGlobal.MIGRATION_SENTINEL = "BULBASAUR"
local itemMappingsBefore = deepCopy(preItems.mappings)
local staleItemHash = "STALE-FIELD-ITEM-HASH"
preItems.compatibility.settingsHash = staleItemHash
preItems.checksum = { version = "stale", value = "stale" }
migrations[3].callback(preItems)
assert(preItems.settings.field_items == "off")
assert(type(preItems.mappings.fieldItems) == "table"
  and next(preItems.mappings.fieldItems) == nil)
assertMappingsPreserved(preItems.mappings, itemMappingsBefore,
  { fieldItems = true }, "field-item migration")
assert(preItems.futureField == "keep",
  "field-item migration must preserve unknown fields")
assertMigrationStamp(preItems, staleItemHash, "field-item migration")
local onceItems = deepCopy(preItems)
migrations[3].callback(preItems)
assert(deepEqual(preItems, onceItems),
  "field-item migration must be idempotent")

local mechanicsDefaults = {
  base_stats = "vanilla", stat_family_consistency = "on",
  evolutions = "vanilla", evolution_repeats = "avoid",
  evolution_trade_safety = "vanilla",
  pokemon_types = "vanilla", type_family_consistency = "on",
  pokemon_movesets = "vanilla", early_damage = "on",
  learnset_levels = "vanilla", tmhm_compatibility = "vanilla",
  move_types = "vanilla", move_data = "vanilla", move_safety = "on",
}
local preMechanics = deepCopy(preItems)
for key in pairs(mechanicsDefaults) do preMechanics.settings[key] = nil end
preMechanics.settings.MIGRATION_UNKNOWN = "keep"
preMechanics.mappings.pokemonMechanics = nil
preMechanics.mappings.moveData = nil
local mechanicsMappingsBefore = deepCopy(preMechanics.mappings)
local staleMechanicsHash = "STALE-MECHANICS-HASH"
preMechanics.compatibility.settingsHash = staleMechanicsHash
preMechanics.checksum = { version = "stale", value = "stale" }
migrations[4].callback(preMechanics)
for key, expected in pairs(mechanicsDefaults) do
  assert(preMechanics.settings[key] == expected,
    "mechanics migration default mismatch for " .. key)
end
assert(preMechanics.settings.MIGRATION_UNKNOWN == "keep",
  "mechanics migration must preserve existing settings")
assert(type(preMechanics.mappings.pokemonMechanics) == "table"
    and next(preMechanics.mappings.pokemonMechanics) == nil,
  "mechanics migration must add an empty Pokemon bucket")
assert(type(preMechanics.mappings.moveData) == "table"
    and next(preMechanics.mappings.moveData) == nil,
  "mechanics migration must add an empty move bucket")
assertMappingsPreserved(preMechanics.mappings, mechanicsMappingsBefore,
  { pokemonMechanics = true, moveData = true }, "mechanics migration")
assert(preMechanics.futureField == "keep",
  "mechanics migration must preserve unknown fields")
assertMigrationStamp(preMechanics, staleMechanicsHash,
  "mechanics migration")
local onceMechanics = deepCopy(preMechanics)
migrations[4].callback(preMechanics)
assert(deepEqual(preMechanics, onceMechanics),
  "mechanics migration must be idempotent")

io.write("bootstrap_test: ok\n")
