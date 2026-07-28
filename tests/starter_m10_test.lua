-- Milestone-10 deterministic starter generation and rival projection tests.
local function loadFactory(path, ...)
  local chunk, err = loadfile(path)
  assert(chunk, err)
  local value = chunk()
  if type(value) == "function" then return value(...) end
  return value
end

local Constants = loadFactory("src/constants.lua")
local UInt32 = loadFactory("src/uint32.lua")
local Seed = loadFactory("src/seed.lua")
local Hash128 = loadFactory("src/hash128.lua", Constants, UInt32)
local StableSort = loadFactory("src/stable_sort.lua")
local Rng = loadFactory("src/rng.lua", Constants, UInt32, Hash128)
local Canonical = loadFactory("src/canonical.lua", StableSort)
local Contracts = loadFactory("src/contracts.lua", Constants)
local SaveState = loadFactory("src/save_state.lua",
  Constants, Seed, Hash128, Canonical, StableSort, Contracts)
local StarterCategory = loadFactory(
  "src/starter_category.lua", StableSort)
local StarterOffer = loadFactory("src/starter_offer.lua")
local StarterCompat = loadFactory(
  "src/starter_compat.lua", StarterOffer)
local StarterRuntime = loadFactory("src/starter_runtime.lua")

local function entry(id, typeId, stage, legendary, secondary)
  return {
    id = id,
    types = secondary and { typeId, secondary } or { typeId },
    primaryType = typeId,
    stage = stage or "basic",
    legendary = legendary == true,
  }
end

local entries = {
  entry("BUGA", "BUG"),
  entry("ELECTRICA", "ELECTRIC"),
  entry("EVOLVED_FIRE", "FIRE", "final"),
  entry("FIREA", "FIRE"),
  entry("GRASSA", "GRASS"),
  entry("LEGEND_WATER", "WATER", "basic", true),
  entry("NORMALA", "NORMAL"),
  entry("WATERA", "WATER"),
}
local manifest = { entries = entries, byId = {} }
for _, row in ipairs(entries) do manifest.byId[row.id] = row end

local function streams(seed)
  return {
    starters = Rng.fromSeed(seed, "starters"),
    rival = Rng.fromSeed(seed, "rival.counterpick"),
  }
end

local randomSettings = {
  starters = "random",
  starter_stage = "basic_only",
  starter_level = 12,
  rival_counterpick = "type_advantage",
  legendaries = "exclude",
}
local randomA = StarterCategory.generate(
  manifest, randomSettings, streams("M10 RANDOM"))
local randomB = StarterCategory.generate(
  manifest, randomSettings, streams("M10 RANDOM"))
local seen = {}
for _, slotId in ipairs({ "LEFT", "MIDDLE", "RIGHT" }) do
  local left, right = randomA.starters[slotId], randomB.starters[slotId]
  assert(left.species == right.species and left.rivalSlot == right.rivalSlot,
    "same seed must reproduce starter and rival choices")
  assert(left.level == 12)
  assert(not seen[left.species], "player starters must be unique")
  seen[left.species] = true
  assert(left.species ~= "EVOLVED_FIRE",
    "basic-only must exclude evolved forms")
  assert(left.species ~= "LEGEND_WATER",
    "legendary exclusion must apply to starters")
  assert(left.rivalSlot ~= slotId)
  assert(left.rivalSpecies
    == randomA.starters[left.rivalSlot].species)
end

local triadSettings = {
  starters = "type_triad",
  starter_stage = "basic_only",
  starter_level = 5,
  rival_counterpick = "type_advantage",
  legendaries = "exclude",
}
local triad = StarterCategory.generate(
  manifest, triadSettings, streams("M10 TRIAD"))
local order = { "LEFT", "MIDDLE", "RIGHT" }
for index, slotId in ipairs(order) do
  local nextSlot = order[index % 3 + 1]
  local attack = triad.starters[slotId].species
  local defend = triad.starters[nextSlot].species
  assert(StarterCategory.effectiveness(
      manifest.byId[attack].primaryType,
      manifest.byId[defend].primaryType) > 1,
    "type-triad primary types must form a directional cycle")
  local rival = triad.starters[slotId]
  assert(StarterCategory.matchup(
      manifest.byId[rival.rivalSpecies],
      manifest.byId[rival.species]) > 1,
    "type-advantage rival must select the winning unchosen starter")
end

local ballSettings = {}
for key, value in pairs(randomSettings) do ballSettings[key] = value end
ballSettings.rival_counterpick = "ball_order"
local ball = StarterCategory.generate(
  manifest, ballSettings, streams("M10 BALL"))
assert(ball.starters.LEFT.rivalSlot == "MIDDLE")
assert(ball.starters.MIDDLE.rivalSlot == "RIGHT")
assert(ball.starters.RIGHT.rivalSlot == "LEFT")

local randomOtherSettings = {}
for key, value in pairs(randomSettings) do randomOtherSettings[key] = value end
randomOtherSettings.rival_counterpick = "random_other"
local otherA = StarterCategory.generate(
  manifest, randomOtherSettings, streams("M10 OTHER"))
local otherB = StarterCategory.generate(
  manifest, randomOtherSettings, streams("M10 OTHER"))
for _, slotId in ipairs(order) do
  assert(otherA.starters[slotId].rivalSlot
    == otherB.starters[slotId].rivalSlot)
  assert(otherA.starters[slotId].rivalSlot ~= slotId)
end

local fallback = StarterCategory.generate({
  entries = { entry("ONLY_A", "NORMAL"), entry("ONLY_B", "FIRE") },
  byId = {},
}, randomSettings, streams("M10 FALLBACK"))
assert(next(fallback.starters) == nil)
assert(fallback.fallbackCount == 1)
assert(fallback.warnings[1].code == "STARTER_GENERATION_FAILED")

local noCycle = StarterCategory.generate({
  entries = {
    entry("NORMAL_1", "NORMAL"),
    entry("NORMAL_2", "NORMAL"),
    entry("NORMAL_3", "NORMAL"),
  },
  byId = {},
}, triadSettings, streams("M10 NO CYCLE"))
assert(noCycle.warnings[1].code == "STARTER_TRIAD_UNAVAILABLE")
assert(noCycle.fallbackCount == 0)
assert(noCycle.starters.LEFT and noCycle.starters.MIDDLE
  and noCycle.starters.RIGHT,
  "type-triad must fall back to unique random choices when possible")

local customManifest = {
  entries = {
    entry("CUSTOM_A", "CUSTOM_A_TYPE"),
    entry("CUSTOM_B", "CUSTOM_B_TYPE"),
    entry("CUSTOM_C", "CUSTOM_C_TYPE"),
  },
  byId = {},
}
local customChart = {
  CUSTOM_A_TYPE = { CUSTOM_B_TYPE = 2 },
  CUSTOM_B_TYPE = { CUSTOM_C_TYPE = 2 },
  CUSTOM_C_TYPE = { CUSTOM_A_TYPE = 2 },
}
local customTriad = StarterCategory.generate(
  customManifest, triadSettings, streams("M10 CUSTOM"), customChart)
assert(#customTriad.warnings == 0 and customTriad.starters.LEFT,
  "merged custom type matchups must participate in triad generation")

local run = {
  mappings = {
    starters = triad.starters,
    starterFlags = triad.starterFlags,
  },
}
local base = StarterCompat.offers.LEFT
local resolved = StarterOffer.resolve(base, { slotId = "LEFT" }, run)
assert(resolved.species == triad.starters.LEFT.species)
assert(resolved.level == 5)
assert(resolved ~= triad.starters.LEFT,
  "runtime offer resolution must return a copy")

local pokemon = {}
for _, row in ipairs(entries) do pokemon[row.id] = {} end
pokemon.CHARMANDER, pokemon.SQUIRTLE, pokemon.BULBASAUR = {}, {}, {}
local rows = StarterCompat.rows(base, {
  save = {},
  data = { pokemon = pokemon },
}, run)
assert(rows[5][3].species == triad.starters.LEFT.species,
  "Dex preview must use the saved starter")
assert(rows[9][2] == triad.starters.LEFT.species
  and rows[9][3] == 5,
  "gift must match the saved preview and level")
assert(rows[17][3].RAM == triad.starters.LEFT.rivalSpecies,
  "rival pickup text must use the saved counterpick")

local vanillaParty = {
  { species = "PIDGEY", level = 18 },
  { species = "WARTORTLE", level = 20, moves = { "TACKLE" } },
}
local projected = StarterRuntime.party(
  vanillaParty, "OPP_RIVAL2", 4, run)
assert(projected ~= vanillaParty and projected[2] ~= vanillaParty[2])
assert(projected[1].species == "PIDGEY")
assert(projected[2].species == triad.starters.LEFT.rivalSpecies)
assert(projected[2].level == 20 and projected[2].moves[1] == "TACKLE")
assert(vanillaParty[2].species == "WARTORTLE",
  "rival projection must not mutate the prior hook result")
assert(StarterRuntime.party(vanillaParty, "OPP_YOUNGSTER", 1, run)
  == vanillaParty, "non-rival trainers must pass through")

local settingsForSave = {
  randomizer = "on",
  starters = "type_triad",
  starter_stage = "basic_only",
  starter_level = 5,
  rival_counterpick = "type_advantage",
}
local seed = assert(SaveState.makeSeed("manual", "M10 SAVE"))
local speciesSet, speciesRows = {}, {}
for _, row in ipairs(entries) do
  speciesSet[row.id] = true
  speciesRows[#speciesRows + 1] = { id = row.id }
end
local generated = Contracts.newGenerationResult()
generated.mappings.starters = triad.starters
generated.mappings.starterFlags = triad.starterFlags
local namespace = assert(SaveState.create({
  seed = seed,
  settings = settingsForSave,
  compatibility = SaveState.compatibility({
    version = "red", meta = { engine = "0.1.30" },
  }, "M10-POOL", settingsForSave),
  species = speciesRows,
  speciesSet = speciesSet,
  sources = {},
}, function() return generated end))
local valid, errors = SaveState.validate(namespace, speciesSet, true)
assert(valid, errors[1] and errors[1].message)
local damaged = SaveState.clone(namespace)
damaged.mappings.starters.LEFT.rivalSpecies =
  damaged.mappings.starters.LEFT.species
local stamped, structuralErrors = SaveState.stamp(damaged, speciesSet)
assert(not stamped and #structuralErrors > 0,
  "inconsistent saved rival projection must fail validation")

io.write("starter_m10_test: ok\n")
