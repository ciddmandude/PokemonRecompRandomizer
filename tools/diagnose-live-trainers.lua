-- Developer diagnostic: run M13 trainer generation against an extracted
-- v0.1.30 data directory. Usage: lua tools/diagnose-live-trainers.lua PATH
local root = assert(arg[1], "generated data directory is required")
local seed = arg[2] or "LIVE TRAINER DIAGNOSTIC"
local function loadFactory(path, ...)
  local value = assert(loadfile(path))()
  if type(value) == "function" then return value(...) end
  return value
end
local Constants = loadFactory("src/constants.lua")
local UInt32 = loadFactory("src/uint32.lua")
local Hash128 = loadFactory("src/hash128.lua", Constants, UInt32)
local StableSort = loadFactory("src/stable_sort.lua")
local Canonical = loadFactory("src/canonical.lua", StableSort)
local Vanilla = loadFactory("src/vanilla_species.lua")
local Manifest = loadFactory("src/species_manifest.lua",
  Constants, StableSort, Canonical, Hash128, Vanilla)
local Filters = loadFactory("src/species_filters.lua")
local Rng = loadFactory("src/rng.lua", Constants, UInt32, Hash128)
local Category = loadFactory(
  "src/trainer_category.lua", StableSort, Filters)
local pokemon = assert(loadfile(root .. "/pokemon.lua"))()
local trainers = assert(loadfile(root .. "/trainers.lua"))()
local manifest = Manifest.build(pokemon, { poolMode = "vanilla151" })
local settings = {
  trainer_pokemon = "by_slot", trainer_levels = "unchanged",
  boss_trainers = "themed", party_size = "unchanged",
  progression_guard = "on", duplicate_policy = "one_to_one",
  legendaries = "match", similar_strength = "20", starter_level = 5,
}
local ok, result = pcall(Category.generate, manifest,
  { trainers = trainers }, settings, {
    species = Rng.fromSeed(seed, "trainers.species"),
    levels = Rng.fromSeed(seed, "trainers.levels"),
    sizes = Rng.fromSeed(seed, "trainers.sizes"),
  })
if not ok then error(result, 0) end
local classes, parties = 0, 0
for _, class in pairs(result.trainerParties) do
  classes = classes + 1
  for key in pairs(class) do if type(key) == "number" then parties = parties + 1 end end
end
print(("trainer diagnostic: %d classes, %d parties, BUG_CATCHER=%s")
  :format(classes, parties,
    tostring(result.trainerParties.OPP_BUG_CATCHER ~= nil)))
for partyIndex = 1, 3 do
  local source = trainers.OPP_BUG_CATCHER.parties[partyIndex]
  local mapped = result.trainerParties.OPP_BUG_CATCHER[partyIndex]
  local pairs = {}
  for slotIndex, slot in ipairs(source) do
    pairs[#pairs + 1] = ("%s>%s"):format(
      slot.species, mapped[slotIndex].species)
  end
  print(("forest party %d: %s"):format(
    partyIndex, table.concat(pairs, ", ")))
end
