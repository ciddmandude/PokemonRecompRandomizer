-- Headless mod-load and trainer-hook check against a Recomp checkout.
-- Run with the engine checkout as cwd and POKEPORT_DATA_DIR set to extracted
-- generated data for the complete trainer assertions. Without generated
-- data, the ROM-free engine fixture still validates that the mod loads.
package.path = "./?.lua;./?/init.lua;" .. package.path

local modRoot = arg[1] or "E:/PokemonRecompRandomizer"
local engineVersion = arg[2] or "0.1.38"
local modVersion = arg[3] or "0.46.3"
require("src.core.Version").engine = engineVersion
local T = require("tests.modkit")
local Runtime = require("src.mods.Runtime")
local Data = require("src.core.Data")
local hasGeneratedData = pcall(Data.load, Data)
if not hasGeneratedData then
  Data = require("tests.modkit.fixtures").fresh()
  Data.trainers.OPP_FIX_MIXED = {
    id = "OPP_FIX_MIXED",
    parties = {
      {
        { species = "FIXMON_A", level = 8 },
        { species = "MOD_ONLY_SOURCE", level = 9,
          moves = { "MOD_MOVE" } },
      },
    },
  }
end

local alias = "mods/pokemon_randomizer"
local function mapped(path)
  if path == alias then return modRoot end
  if path:sub(1, #alias + 1) == alias .. "/" then
    return modRoot .. path:sub(#alias + 1)
  end
  return path
end
local fs = {
  read = function(path)
    local handle = io.open(mapped(path), "rb")
    if not handle then return nil, "nofile" end
    local body = handle:read("*a")
    handle:close()
    return body
  end,
  load = function(path)
    return loadfile(mapped(path))
  end,
  getInfo = function(path)
    if path == "mods" or path == alias then return { type = "directory" } end
    local handle = io.open(mapped(path), "rb")
    if not handle then return nil end
    local byte = handle:read(1)
    handle:close()
    return { type = byte == nil and "directory" or "file" }
  end,
  getDirectoryItems = function(path)
    if path == "mods" then return { "pokemon_randomizer" } end
    return {}
  end,
}
local loaded = T.sdk.loadMod(alias, { data = Data, fs = fs })
assert(#loaded.errors == 0,
  "mod load failed: " .. tostring(loaded.errors[1]))
if not (loaded.mod and loaded.mod.state == "loaded") then
  for id, mod in pairs(loaded.loader.mods or {}) do
    print(("discovered %s: state=%s error=%s"):format(
      tostring(id), tostring(mod.state), tostring(mod.error)))
  end
  error("mod was not loaded", 0)
end

if not hasGeneratedData then
  -- The ROM-free fixture uses FIXMON ids rather than the vanilla 151.
  -- Exercise generation/runtime with the merged pool instead of stopping
  -- after the entry chunk loads.
  loaded.loader.modOptions.pokemon_randomizer = {
    species_pool = "merged",
    similar_strength = "100",
    wild_pokemon = "area_slots",
  }
end

local save = {
  version = "red",
  meta = {
    engine = engineVersion,
    mods = {
      { id = "pokemon_randomizer", version = modVersion, api = 2 },
    },
  },
  player = { id = 1234 },
  options = { modOptions = {} },
  modData = {},
}
if not hasGeneratedData then
  -- The mandatory New Game chooser intentionally defers generation until
  -- Oak's intro begins.  Give the ROM-free fixture a selectable preset that
  -- keeps its synthetic species and area-slot encounter data in scope.
  save.options.modOptions.pokemon_randomizer = {
    saved_presets = {
      {
        name = "INTEGRATION",
        settings = {
          species_pool = "merged",
          similar_strength = "100",
          wild_pokemon = "area_slots",
        },
      },
    },
  }
end

local stack = { states = {} }
function stack:push(value) self.states[#self.states + 1] = value end
function stack:pop() return table.remove(self.states) end
function stack:top() return self.states[#self.states] end

local game = {
  save = save,
  data = Data,
  mods = loaded.loader,
  stack = stack,
}
Runtime.emit("game.ready", { game = game })
Runtime.emit("save.created", { save = save })
local steps = Runtime.call("intro.oak_speech.build",
  function(value) return value end,
  { { id = "oak_welcome", kind = "say" } },
  { game = game })
assert(type(steps) == "table"
    and type(steps[1]) == "table"
    and steps[1].id == "pokemon_randomizer:new_game_setup",
  "New Game randomizer setup was not inserted before Oak's intro")
local introContinued = false
steps[1].run({}, function() introContinued = true end)
local enableQuestion = assert(stack:top(),
  "New Game randomizer enable question was not shown")
assert(type(enableQuestion.choice) == "function",
  "New Game randomizer enable question has no choice callback")
enableQuestion.choice(true)
local presetQuestion = assert(stack:top(),
  "New Game randomizer preset question was not shown")
assert(type(presetQuestion.choice) == "function",
  "New Game randomizer preset question has no choice callback")
presetQuestion.choice(true)
local presetPicker = assert(stack:top(),
  "New Game randomizer preset picker was not shown")
local wantedPreset = hasGeneratedData and "standard" or "saved:INTEGRATION"
local selectedPreset
for _, item in ipairs(presetPicker.items or {}) do
  if item.value == wantedPreset then selectedPreset = item break end
end
assert(selectedPreset,
  "New Game randomizer preset picker omitted " .. wantedPreset)
presetPicker.onChoose(selectedPreset)
assert(introContinued, "New Game randomizer setup did not resume Oak's intro")
local run = assert(save.modData.pokemon_randomizer,
  "New Game setup did not create randomizer state")

if not hasGeneratedData then
  local encounterDef = Data.encounters.FIX_ROUTE
  local rolls, rollIndex = { 0, 0 }, 0
  local context = {
    mapId = "FIX_ROUTE",
    terrain = "grass",
    rng = function()
      rollIndex = rollIndex + 1
      return rolls[rollIndex]
    end,
  }
  local selected = Runtime.call("encounter.roll",
    function(definition, ctx)
      if ctx.rng(0, 255) >= definition.grass.rate then return nil end
      local pick = ctx.rng(0, 255)
      local thresholds = definition.grass.buckets or { 128, 256 }
      for index, threshold in ipairs(thresholds) do
        if pick < threshold then
          local slot = definition.grass.slots[index]
          return { species = slot.species, level = slot.level }
        end
      end
    end,
    encounterDef, context)
  assert(selected.slotIndex == 1 and rollIndex == 2,
    "0.1.38 encounter.roll did not expose the selected area slot")
  local wild = Runtime.call("encounter.species", function(encounter)
    return encounter
  end, selected, context)
  local expected = run.mappings.wildAreaSlots.FIX_ROUTE.grass[1]
  assert(wild.species == expected.species and wild.level == expected.level,
    "fixture area-slot encounter did not use its saved mapping")
  local savedParty = run.mappings.trainerParties.OPP_FIX_MIXED[1]
  assert(type(savedParty[1].species) == "string"
      and savedParty[2].fallback == true
      and savedParty[2].species == nil,
    "fixture trainer did not isolate its out-of-pool source")
  local priorParty = {
    { species = "FIXMON_A", level = 8 },
    { species = "MOD_ONLY_SOURCE", level = 9,
      moves = { "MOD_MOVE" } },
  }
  local hookedParty = Runtime.call("trainer.party",
    function(_, _, party) return party end,
    "OPP_FIX_MIXED", 1, priorParty)
  assert(hookedParty[1].species == savedParty[1].species,
    "eligible fixture trainer slot did not use its saved mapping")
  assert(hookedParty[2].species == "MOD_ONLY_SOURCE"
      and hookedParty[2].level == 9
      and hookedParty[2].moves[1] == "MOD_MOVE",
    "out-of-pool fixture trainer slot did not preserve the prior result")
  print("engine integration: fixture wild and isolated trainer mappings pass")
  loaded.release()
  return
end
local sourceSpecies = "RATTATA"
local destinationSpecies = assert(run.mappings.wildGlobal[sourceSpecies],
  "save has no wild global mapping for " .. sourceSpecies)
local wild = Runtime.call("encounter.species", function(encounter)
  return encounter
end, { species = sourceSpecies, level = 3 },
  { mapId = "ROUTE_1", terrain = "grass" })
assert(wild.species == destinationSpecies,
  "wild runtime did not use the saved global mapping")
local bugCatchers = assert(run.mappings.trainerParties.OPP_BUG_CATCHER,
  "save has no Bug Catcher mappings")

for partyIndex = 1, 3 do
  local vanilla = Data.trainers.OPP_BUG_CATCHER.parties[partyIndex]
  local hooked = Runtime.call("trainer.party", function(_, _, party)
    return party
  end, "OPP_BUG_CATCHER", partyIndex, vanilla)
  assert(#hooked == #bugCatchers[partyIndex],
    "hooked party has the wrong size")
  for slotIndex, slot in ipairs(hooked) do
    local expected = bugCatchers[partyIndex][slotIndex]
    assert(slot.species == expected.species
        and slot.level == expected.level,
      ("forest hook mismatch at party %d slot %d"):format(
        partyIndex, slotIndex))
  end
end

print("engine trainer integration: Forest parties 1-3 use saved mappings")
loaded.release()
