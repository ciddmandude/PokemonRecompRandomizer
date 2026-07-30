-- Standalone milestone-4 saved-run schema and lifecycle primitives test.
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

local seed = assert(SaveState.makeSeed("manual", "  lifecycle   test "))
equal(seed.canonical, "LIFECYCLE TEST", "manual canonical seed")
equal(#seed.hash128, 32, "seed hash length")

local autoA = SaveState.makeAutoSeed("fixed entropy")
local autoB = SaveState.makeAutoSeed("fixed entropy")
equal(autoA.canonical, autoB.canonical, "auto seed determinism")
equal(#autoA.canonical, 26, "auto seed width")

local settings = {
  randomizer = "on",
  wild = "global_map",
}
local compatibility = SaveState.compatibility({
  version = "red",
  meta = { engine = "1.0.0" },
}, "POOL-HASH", settings, {
  { id = "z_mod", version = "2.0.0" },
  { id = "pokemon_randomizer", version = "0.4.0" },
  { id = "a_mod", version = "1.0.0" },
})
equal(compatibility.relevantMods[1].id, "a_mod", "sorted relevant mod")
equal(compatibility.relevantMods[2].id, "z_mod", "self mod omitted")
assert(type(compatibility.relevantMods[1].fingerprint) == "string",
  "relevant mods receive deterministic fingerprints")
local unchangedMods = SaveState.compareRelevantMods(
  compatibility.relevantMods, {
    { id = "pokemon_randomizer", version = "9.9.9", api = 2 },
    { id = "a_mod", version = "1.0.0", api = 0 },
    { id = "z_mod", version = "2.0.0", api = 0 },
  })
equal(unchangedMods.code, "OK", "matching relevant mod snapshot")
local changedMods = SaveState.compareRelevantMods(
  compatibility.relevantMods, {
    { id = "a_mod", version = "1.1.0", api = 0 },
    { id = "new_mod", version = "3.0.0", api = 2 },
  })
equal(changedMods.code, "RELEVANT_MODS_CHANGED",
  "changed relevant mod report")
equal(changedMods.changed[1].id, "a_mod", "version change attributed")
equal(changedMods.removed[1].id, "z_mod", "removed mod attributed")
equal(changedMods.added[1].id, "new_mod", "added mod attributed")

local species = {
  { id = "BULBASAUR" },
  { id = "CHARMANDER" },
}
local set = { BULBASAUR = true, CHARMANDER = true }
local input = {
  seed = seed,
  settings = settings,
  compatibility = compatibility,
  species = species,
  speciesSet = set,
  sources = {},
}

local generated = Contracts.newGenerationResult()
generated.mappings.wildGlobal.BULBASAUR = "CHARMANDER"
local namespace, report = SaveState.create(input, function(request)
  equal(request.seed.canonical, "LIFECYCLE TEST", "generator seed")
  request.settings.randomizer = "mutated copy"
  return generated
end)
assert(namespace, report.error and report.error.message)
assert(report.generated)
assert(namespace.enabled)
equal(namespace.settings.randomizer, "on", "settings snapshot immutable")
equal(namespace.mappings.wildGlobal.BULBASAUR,
  "CHARMANDER", "saved mapping")
equal(namespace.checksum.version,
  Constants.SAVE_CHECKSUM_VERSION, "checksum version")
equal(namespace.checksum.value, SaveState.checksum(namespace),
  "checksum value")
equal(namespace.diagnostics.validation.mappingBytes,
  #Canonical.encode(namespace.mappings), "mapping byte measurement")
equal(namespace.diagnostics.validation.namespaceBytes,
  #Canonical.encode(namespace), "complete namespace byte measurement")
equal(namespace.diagnostics.validation.budgetBytes,
  262144, "authoritative 256 KiB budget")

local valid, errors = SaveState.validate(namespace, set, true)
assert(valid, errors[1] and errors[1].message)

local reordered = SaveState.clone(namespace)
reordered.settings = {
  wild = "global_map",
  randomizer = "on",
}
equal(SaveState.checksum(reordered), SaveState.checksum(namespace),
  "checksum ignores insertion order")

local tampered = SaveState.clone(namespace)
tampered.settings.wild = "area_slots"
valid, errors = SaveState.validate(tampered, set, true)
assert(not valid)
equal(errors[#errors].code, "HASH_MISMATCH", "settings tamper detection")

local missing = SaveState.clone(namespace)
missing.mappings.wildGlobal.BULBASAUR = "MISSINGMON"
missing = assert(SaveState.stamp(missing))
valid, errors = SaveState.validate(missing, set, true)
assert(not valid)
equal(errors[1].code, "MISSING_SPECIES", "missing species detection")

local disabled, failed = SaveState.create(input, function()
  error("synthetic generator failure")
end)
assert(disabled and not disabled.enabled)
assert(not failed.generated)
equal(failed.error.code, "GENERATOR_ERROR", "generator error isolation")
equal(disabled.diagnostics.fallbackCount, 1, "whole-run fallback")
for _, key in ipairs(SaveState.mappingKeys()) do
  equal(next(disabled.mappings[key]), nil, "atomic empty " .. key)
end
valid, errors = SaveState.validate(disabled, set, true)
assert(valid, errors[1] and errors[1].message)

local switchedOff, offReport = SaveState.create({
  seed = seed,
  settings = settings,
  compatibility = compatibility,
  species = species,
  speciesSet = set,
  sources = {},
  enabled = false,
}, function()
  error("disabled generation must not run")
end)
assert(switchedOff and not switchedOff.enabled)
assert(offReport.disabled and not offReport.error)
equal(#switchedOff.diagnostics.warnings, 0, "master-off warnings")
equal(switchedOff.diagnostics.fallbackCount, 0, "master-off fallback count")

local legacy = SaveState.clone(namespace)
legacy.schemaVersion = 0
legacy.seed = "OLD SEED"
legacy.checksum = nil
legacy.futureField = { preserved = true }
local migrated = SaveState.migrate(legacy)
assert(migrated ~= legacy, "migration works on a copy")
equal(legacy.schemaVersion, 0, "migration input untouched")
equal(migrated.schemaVersion, 1, "migration schema")
equal(migrated.seed.canonical, "OLD SEED", "migration seed")
assert(migrated.futureField.preserved, "unknown field preserved")
migrated = assert(SaveState.stamp(migrated, set))
valid, errors = SaveState.validate(migrated, set, true)
assert(valid, errors[1] and errors[1].message)

local preM14 = SaveState.clone(namespace)
for _, row in ipairs(preM14.compatibility.relevantMods) do
  row.fingerprint = nil
end
preM14.race = {
  enabled = false, unlockPolicy = "hall_of_fame", unlocked = false,
}
local upgraded = SaveState.upgradeM14(preM14)
assert(upgraded ~= preM14 and upgraded.race.unlocked,
  "M14 migration copies and unlocks non-race saves")
assert(type(upgraded.compatibility.relevantMods[1].fingerprint) == "string",
  "M14 migration adds relevant-mod fingerprints")
upgraded = assert(SaveState.stamp(upgraded, set))
assert(SaveState.validate(upgraded, set, true))

local largeInput = SaveState.clone(input)
largeInput.settings.padding =
  string.rep("X", Constants.SAVE_SIZE_BUDGET_BYTES)
largeInput.compatibility = SaveState.compatibility({
  version = "red",
  meta = { engine = "1.0.0" },
}, "POOL-HASH", largeInput.settings, {})
local oversized = assert(SaveState.create(largeInput, function()
  return Contracts.newGenerationResult()
end))
local sizeWarning
for _, warning in ipairs(oversized.diagnostics.warnings) do
  if warning.code == "SAVE_SIZE_BUDGET_EXCEEDED" then
    sizeWarning = warning
  end
end
assert(sizeWarning, "oversized namespace records a warning")
equal(sizeWarning.budgetBytes, 262144, "size warning budget attribution")
equal(sizeWarning.measuredBytes,
  oversized.diagnostics.validation.namespaceBytes,
  "size warning measured-byte attribution")
assert(sizeWarning.message:find("256 KiB", 1, true),
  "size warning identifies the authoritative budget")
equal(oversized.diagnostics.validation.mappingBytes,
  #Canonical.encode(oversized.mappings),
  "oversized run retains separate mapping measurement")
equal(oversized.diagnostics.validation.namespaceBytes,
  #Canonical.encode(oversized),
  "oversized complete namespace measurement")

io.write("save_state_test: ok\n")
