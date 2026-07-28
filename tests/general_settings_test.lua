-- Milestone-6 preset, seed, behavior-hash, and run-code tests.
local function loadFactory(path, ...)
  local chunk, err = loadfile(path)
  assert(chunk, err)
  local value = chunk()
  if type(value) == "function" then return value(...) end
  return value
end

local function equal(actual, expected, label)
  assert(actual == expected,
    ("%s: expected %s, got %s"):format(
      label, tostring(expected), tostring(actual)))
end

local Constants = loadFactory("src/constants.lua")
local UInt32 = loadFactory("src/uint32.lua")
local Seed = loadFactory("src/seed.lua")
local Hash128 = loadFactory("src/hash128.lua", Constants, UInt32)
local StableSort = loadFactory("src/stable_sort.lua")
local Canonical = loadFactory("src/canonical.lua", StableSort)
local Contracts = loadFactory("src/contracts.lua", Constants)
local SaveState = loadFactory("src/save_state.lua",
  Constants, Seed, Hash128, Canonical, StableSort, Contracts)
local General = loadFactory("src/general_settings.lua", SaveState)
local Schema = loadFactory("src/options_schema.lua")

local defaults = {}
for _, group in ipairs(Schema.groups) do
  for _, row in ipairs(group.rows) do defaults[row.key] = row.default end
end

equal(General.detectPreset(defaults), "standard", "defaults are standard")
local casual = General.applyPreset(defaults, "casual")
equal(casual.preset, "casual", "casual preset marker")
equal(casual.similar_strength, "10", "casual strength")
equal(casual.trade_fairness, "no_downgrade", "casual trades")
equal(casual.boss_trainers, "vanilla", "casual bosses")

local chaos = General.applyPreset(defaults, "chaos")
equal(chaos.species_pool, "merged", "chaos merged pool")
equal(chaos.legendaries, "allow", "chaos legendaries")
equal(chaos.catchability_guard, "off", "chaos catch guard")
equal(chaos.party_size, "random_1_6", "chaos party size")
equal(General.detectPreset(chaos), "chaos", "chaos detection")
chaos.party_size = "unchanged"
equal(General.detectPreset(chaos), "custom", "custom detection")

local hashA = General.settingsHash(defaults)
local cosmetic = SaveState.clone(defaults)
cosmetic.preset = "custom"
cosmetic.seed_mode = "manual"
cosmetic.seed_text = "DISPLAY ONLY"
equal(General.settingsHash(cosmetic), hashA,
  "display-only fields excluded from settings hash")
cosmetic.race_mode = "on"
assert(General.settingsHash(cosmetic) ~= hashA,
  "race state changes settings hash")

local manual, seedError = General.resolveSeed({
  seed_mode = "manual",
  seed_text = "  shared   seed ",
}, "unused")
assert(not seedError)
equal(manual.display, "  shared   seed ", "manual display preserved")
equal(manual.canonical, "SHARED SEED", "manual canonical")

local invalid
invalid, seedError = General.resolveSeed({
  seed_mode = "manual",
  seed_text = "",
}, "unused")
equal(seedError.code, "INVALID_MANUAL_SEED", "manual rejection")
equal(invalid.mode, "manual", "invalid seed fallback mode")
equal(#invalid.canonical, 26, "invalid fallback seed width")

local autoA = General.resolveSeed({ seed_mode = "auto" }, "fixed entropy")
local autoB = General.resolveSeed({ seed_mode = "auto" }, "fixed entropy")
equal(autoA.canonical, autoB.canonical, "auto seed determinism")
equal(#autoA.canonical, 26, "Crockford auto seed width")
assert(autoA.canonical:match("^[0-9A-HJKMNP-TV-Z]+$"),
  "Crockford alphabet")
assert(autoA.canonical:sub(1, 1):match("^[0-7]$"),
  "128-bit Crockford leading digit")

equal(General.poolMode(defaults), "vanilla151", "standard pool mode")
equal(General.poolMode(General.applyPreset(defaults, "chaos")),
  "merged", "chaos pool mode")
local rules = General.filterRules(defaults)
equal(rules.strengthPercent, 20, "normalized strength")
equal(rules.legendary, "match", "normalized legendary")
equal(rules.duplicatePolicy, "one_to_one", "normalized duplicates")

local run = {
  seed = { hash128 = "0123456789ABCDEF0123456789ABCDEF" },
  compatibility = {
    settingsHash = "AABBCCDDEEFF00112233445566778899",
    poolHash = "99887766554433221100FFEEDDCCBBAA",
  },
}
equal(General.runCode(run),
  "R1-01234567-AABBCCDD-99887766", "compact run code")

local warnings = General.reviewWarnings({
  seed_mode = "manual",
  seed_text = "",
})
equal(warnings[1].code, "INVALID_MANUAL_SEED", "review seed warning")
equal(#General.reviewWarnings({ seed_mode = "auto" }), 0,
  "auto seed review valid")

-- Lifecycle consumes saved general settings without depending on gameplay.
local generatedCalls, seenPool = 0
local FakeGenerator = {
  buildSpeciesManifest = function(_, options)
    seenPool = options.poolMode
    return {
      entries = {{ id = "TESTMON" }},
      byId = { TESTMON = { id = "TESTMON" } },
      poolHash = "1234567890ABCDEF1234567890ABCDEF",
    }
  end,
  generate = function()
    generatedCalls = generatedCalls + 1
    return Contracts.newGenerationResult()
  end,
}
local Lifecycle = loadFactory(
  "src/save_lifecycle.lua", Constants, FakeGenerator, SaveState, General)
local liveSettings = {
  randomizer = "on",
  seed_mode = "manual",
  seed_text = " lifecycle seed ",
  species_pool = "merged",
  race_mode = "off",
}
local log = {
  warn = function() end,
  error = function() end,
}
local lifecycle = Lifecycle.new({
  records = function() return {} end,
  metadata = function() return {} end,
  settings = function() return liveSettings end,
  log = log,
})
local save = {
  version = "red",
  meta = { engine = "1.0.0", mods = {} },
  player = { id = 7 },
  modData = {},
}
local created = lifecycle:onCreated({ save = save })
assert(created and created.enabled)
equal(created.seed.canonical, "LIFECYCLE SEED", "lifecycle manual seed")
equal(seenPool, "merged", "lifecycle merged pool")
equal(generatedCalls, 1, "enabled run invokes generator")
equal(created.compatibility.settingsHash,
  General.settingsHash(created.settings), "behavior settings hash stored")
liveSettings.seed_text = "CHANGED GLOBALLY"
equal(lifecycle:activeRun().seed.canonical,
  "LIFECYCLE SEED", "active run ignores global preferences")

liveSettings = {
  randomizer = "off",
  seed_mode = "auto",
  seed_text = "",
  species_pool = "vanilla151",
}
local offSave = {
  version = "red",
  meta = { engine = "1.0.0", mods = {} },
  player = { id = 8 },
  modData = {},
}
local off = lifecycle:onCreated({ save = offSave })
assert(off and not off.enabled)
equal(generatedCalls, 1, "master off bypasses generator")
equal(off.diagnostics.fallbackCount, 0, "master off is not fallback")

liveSettings = {
  randomizer = "on",
  seed_mode = "manual",
  seed_text = "",
  species_pool = "vanilla151",
}
local badSave = {
  version = "red",
  meta = { engine = "1.0.0", mods = {} },
  player = { id = 9 },
  modData = {},
}
local bad = lifecycle:onCreated({ save = badSave })
assert(bad and not bad.enabled)
equal(generatedCalls, 1, "invalid seed bypasses generator")
equal(bad.diagnostics.warnings[1].code,
  "INVALID_MANUAL_SEED", "invalid seed saved diagnostic")

io.write("general_settings_test: ok\n")
