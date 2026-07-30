-- Plaintext spoiler generation, repair, fallback, and export tests.
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
local Progression = loadFactory("src/progression.lua", StableSort)
local TradeCatalog = loadFactory("src/trade_prize_catalog.lua")
local Canonical = loadFactory("src/canonical.lua", StableSort)
local Rng = loadFactory("src/rng.lua", Constants, UInt32, Hash128)
local Spoiler = loadFactory("src/spoiler_log.lua")
local Controller = loadFactory(
  "src/spoiler_controller.lua", Constants, Spoiler)
local Validation = loadFactory(
  "src/validation_category.lua",
  StableSort, Canonical, Progression, TradeCatalog)
local WildRuntime = loadFactory("src/wild_runtime.lua")
local TrainerRuntime = loadFactory("src/trainer_runtime.lua")

local run = {
  schemaVersion = 1,
  algorithmVersion = "1.3.0-dev",
  enabled = true,
  seed = { canonical = "SPOILER TEST", hash128 = ("A"):rep(32) },
  settings = { generate_spoiler_log = "on" },
  compatibility = {
    settingsHash = ("B"):rep(32),
    poolHash = ("C"):rep(32),
  },
  mappings = {
    wildGlobal = { RAT = "CAT" },
    wildAreaSlots = {
      CERULEAN_CAVE_B1F = {
        grass = {
          [1] = { species = "MR_MIME", level = 42 },
        },
      },
    },
    fishing = { global = {}, slots = {} },
    starters = {
      LEFT = {
        species = "CAT", level = 5, rivalSpecies = "RAT",
      },
    },
    staticEncounters = {
      MEWTWO = {
        sourceSpecies = "MEWTWO", sourceLevel = 70,
        species = "CAT", level = 70, mapId = "CERULEAN_CAVE_B1F",
      },
    },
    gifts = {
      SILPH_LAPRAS = {
        sourceSpecies = "LAPRAS", sourceLevel = 15,
        species = "RAT", level = 15, mapId = "SILPH_CO_7F",
      },
    },
    trades = {
      TRADE_01_TERRY = {
        requested = { sourceSpecies = "NIDORINO", species = "RAT" },
        received = { sourceSpecies = "NIDORINA", species = "CAT" },
      },
    },
    prizes = {
      GAME_CORNER_RED_1 = {
        version = "red", sourceSpecies = "ABRA", sourceLevel = 9,
        sourceCost = 180, species = "CAT", level = 9, cost = 180,
      },
    },
    trainerParties = {
      OPP_FIX = {
        [1] = {
          { species = "CAT", level = 5 },
          { fallback = true, sourceSlot = 2 },
        },
      },
    },
  },
  diagnostics = { warnings = {}, fallbackCount = 0 },
}

local plaintext = Spoiler.text(run)
assert(plaintext:find("SPOILER LOG %- READABLE FORMAT V2"))
assert(plaintext:find("\n\n=== SETTINGS ===\n", 1, true))
assert(plaintext:find("Enable Spoiler Log", 1, true)
  and plaintext:find("On", 1, true))
assert(plaintext:find("Cerulean Cave B1F", 1, true))
assert(plaintext:find("Mr. Mime Lv.42", 1, true))
assert(plaintext:find("Location: Route 11 Gate 2F", 1, true))
assert(plaintext:find("Party 1   Cat Lv.5", 1, true))
assert(plaintext:find("Vanilla source slot 2", 1, true))
assert(not plaintext:find("MAPPINGS=", 1, true))

local written = {}
local fs = {
  createDirectory = function() return true end,
  write = function(path, data)
    written.path, written.data = path, data
    return true
  end,
}
local exported = assert(Controller.export(run, fs))
assert(exported.encrypted == false)
assert(written.path == "pokemon_randomizer/spoilers/AAAAAAAA.txt")
assert(written.data == plaintext)
assert(Controller.canAccess(run) == true)
assert(Controller.text(run) == plaintext)
local viewerLines = assert(Controller.lines(run))
assert(viewerLines[1] == "POKEMON GEN 1 RECOMP RANDOMIZER")
local viewerText = table.concat(viewerLines, "\n")
assert(viewerText:find("Cerulean Cave B1F", 1, true))
assert(not viewerText:find("=== SETTINGS ===", 1, true))
assert(not viewerText:find("Enable Spoiler Log", 1, true))

local public = Spoiler.publicRun(run)
assert(public.seed.canonical == "SPOILER TEST")
assert(public.mappings.wildGlobal.RAT == "CAT")
run.race = { enabled = true, unlockPolicy = "never", unlocked = false }
run.settings.race_mode = "on"
run.settings.spoiler_unlock = "never"
public = Spoiler.publicRun(run)
assert(public.race == nil and public.settings.race_mode == nil
    and public.settings.spoiler_unlock == nil,
  "retired race metadata is hidden from the public active-run view")
assert(public.seed.canonical == "SPOILER TEST"
    and public.mappings.wildGlobal.RAT == "CAT",
  "retired race metadata cannot redact the seed or mappings")

local pushed = {}
local actionMod = {
  ui = {
    push = function(_, screenId, model)
      model.screenId = screenId
      pushed[#pushed + 1] = model
    end,
  },
  log = {
    error = function() error("spoiler action unexpectedly failed") end,
  },
}
local lifecycle = {
  activeRun = function() return run end,
}
assert(Controller.viewAction(actionMod, lifecycle)({}) == "SPOILER LOG")
assert(pushed[#pushed].screenId == Constants.SPOILER_BROWSER_SCREEN_ID)
assert(pushed[#pushed].run == run)

run.settings.generate_spoiler_log = "off"
written.path, written.data = nil, nil
local allowed, accessError = Controller.canAccess(run)
assert(allowed == false)
assert(accessError == "spoiler log is disabled for this run")
local hidden, hiddenError = Controller.text(run)
assert(hidden == nil and hiddenError == accessError)
local blocked, blockedError = Controller.export(run, fs)
assert(blocked == nil and blockedError == accessError)
assert(written.path == nil and written.data == nil,
  "disabled spoiler access must not write a file")
assert(Controller.viewAction(actionMod, lifecycle)({})
  == "SPOILERS DISABLED")
assert(pushed[#pushed].title == "SPOILER ACCESS")
assert(pushed[#pushed].lines[1] == "SPOILERS DISABLED")
assert(Controller.exportAction(actionMod, lifecycle)({})
  == "SPOILERS DISABLED")
assert(written.path == nil and written.data == nil)
run.settings.generate_spoiler_log = "on"

local mappings = {
  wildGlobal = { A = "CAT", B = "CAT" },
  wildAreaSlots = {}, fishing = {}, starters = {},
  starterFlags = {}, staticEncounters = {}, gifts = {},
  prizes = {}, trainerParties = {},
  trades = {
    TRADE_07_LOLA = {
      requested = { species = "DOG" },
      received = { species = "BIRD" },
    },
  },
}
local repairSources = {
  version = "red",
  encounters = {
    ROUTE_1 = {
      grass = { slots = {
        { species = "A", level = 3 },
        { species = "B", level = 4 },
      } },
    },
  },
}
local repaired = Validation.apply(mappings, {
  catchability_guard = "on",
}, Rng.fromSeed("M14 REPAIR", "validation.swaps"), {
  sources = repairSources,
})
assert(repaired.repairSwaps == 1)
local reach = Validation.reachableSpecies(mappings, repairSources)
assert(reach[mappings.trades.TRADE_07_LOLA.requested.species] <= 2)
assert(repaired.mappingBytes == #Canonical.encode(mappings))

local missingRun = {
  enabled = true,
  settings = { wild_pokemon = "global_map", wild_levels = "unchanged" },
  mappings = {
    wildGlobal = { RAT = "MISSING" },
    wildAreaSlots = {},
    trainerParties = {
      OPP_FIX = { [1] = {{ species = "MISSING", level = 9 }} },
    },
  },
  _speciesSet = { RAT = true, CAT = true },
}
local encounter = { species = "RAT", level = 4 }
assert(WildRuntime.resolve(encounter,
  { terrain = "grass", mapId = "MAP" }, missingRun) == encounter)
local party = {{ species = "RAT", level = 5 }}
assert(TrainerRuntime.party(
  party, "OPP_FIX", 1, missingRun) == party)
assert(missingRun.mappings.wildGlobal.RAT == "MISSING")

print("spoiler_validation_test: ok")
