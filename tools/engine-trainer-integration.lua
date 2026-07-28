-- Headless end-to-end trainer hook check against a Recomp v0.1.30 checkout.
-- Run with the engine checkout as cwd and POKEPORT_DATA_DIR set to extracted
-- generated data. The first argument is the drive/root containing this mod.
package.path = "./?.lua;./?/init.lua;" .. package.path

local modRoot = arg[1] or "E:/PokemonRecompRandomizer"
local T = require("tests.modkit")
local Runtime = require("src.mods.Runtime")
local Data = require("src.core.Data")
Data:load()

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

local save = {
  version = "red",
  meta = {
    engine = "0.1.30",
    mods = {
      { id = "pokemon_randomizer", version = "0.14.1", api = 2 },
    },
  },
  player = { id = 1234 },
  modData = {},
}
Runtime.emit("save.created", { save = save })
local run = assert(save.modData.pokemon_randomizer,
  "save.created did not create randomizer state")
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
