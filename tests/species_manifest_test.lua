-- Standalone milestone-3 species manifest/filter test.
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

local function hasId(entries, id)
  for _, entry in ipairs(entries) do
    if entry.id == id then return true end
  end
  return false
end

local Constants = loadFactory("src/constants.lua")
local UInt32 = loadFactory("src/uint32.lua")
local Hash128 = loadFactory("src/hash128.lua", Constants, UInt32)
local StableSort = loadFactory("src/stable_sort.lua")
local Canonical = loadFactory("src/canonical.lua", StableSort)
local VanillaSpecies = loadFactory("src/vanilla_species.lua")
local Metadata = loadFactory("src/species_metadata.lua", StableSort)
local Manifest = loadFactory("src/species_manifest.lua",
  Constants, StableSort, Canonical, Hash128, VanillaSpecies)
local Filters = loadFactory("src/species_filters.lua")
local Fixture = loadFactory("tests/species_fixture.lua")

equal(#VanillaSpecies, 151, "vanilla species count")
equal(VanillaSpecies[1], "BULBASAUR", "first vanilla id")
equal(VanillaSpecies[83], "FARFETCHD", "engine Farfetch'd id")
equal(VanillaSpecies[151], "MEW", "last vanilla id")

local metadata = Metadata.new()
metadata:register("MODMON", { legendary = true })
metadata:register("IVYSAUR", { stage = "final" })
local ok = pcall(function()
  metadata:register("MODMON", { stage = "basic" })
end)
assert(not ok, "duplicate metadata must fail")
local snapshot = metadata:snapshot()
equal(snapshot.MODMON.legendary, true, "metadata legendary")
equal(snapshot.IVYSAUR.stage, "final", "metadata stage")

local merged = Manifest.build(Fixture.records, {
  poolMode = "merged",
  metadata = snapshot,
})
equal(merged.schemaVersion, 1, "manifest version")
equal(merged.mode, "merged", "manifest mode")
equal(merged.diagnostics.counts.considered, 9, "considered count")
equal(merged.diagnostics.counts.eligible, 8, "eligible count")
equal(merged.diagnostics.counts.excluded, 1, "excluded count")
equal(merged.diagnostics.exclusions[1].id, "BROKENMON", "excluded id")
equal(merged.diagnostics.exclusions[1].reasons[1].code,
  "MISSING_SPRITE", "exclusion reason")
equal(#merged.poolHash, 32, "pool hash length")

local malformedId = Manifest.build({ [123] = Fixture.records.MEW }, {
  poolMode = "merged",
})
equal(malformedId.diagnostics.counts.eligible, 0,
  "non-string registry id excluded")
equal(malformedId.diagnostics.exclusions[1].reasons[1].code,
  "INVALID_ID", "non-string registry id diagnostic")

equal(merged.byId.BULBASAUR.bst, 253, "five-stat BST")
equal(merged.byId.BULBASAUR.stage, "basic", "derived basic stage")
equal(merged.byId.IVYSAUR.stage, "final", "metadata stage override")
equal(merged.byId.VENUSAUR.stage, "final", "derived final stage")
equal(merged.byId.MEW.legendary, true, "built-in legendary")
equal(merged.byId.MODMON.legendary, true, "metadata legendary")
equal(merged.byId.MODMON.vanilla, false, "merged species provenance")
equal(merged.byId.BULBASAUR.vanilla, true, "vanilla provenance")
equal(merged.entries[1].id, "BULBASAUR", "entries sort first")
equal(merged.entries[#merged.entries].id, "VENUSAUR", "entries sort last")

-- Registry insertion order cannot change fingerprints.
local reordered = Manifest.build(Fixture.cloneRecords(), {
  poolMode = "merged",
  metadata = snapshot,
})
equal(reordered.poolHash, merged.poolHash, "pool hash insertion independence")
for id, entry in pairs(merged.byId) do
  equal(reordered.byId[id].fingerprint, entry.fingerprint,
    "species fingerprint " .. id)
end

-- A generation-relevant stat change must change both hashes.
local changedRecords = Fixture.cloneRecords()
local changed = {}
for key, value in pairs(changedRecords.MODMON) do changed[key] = value end
changed.baseStats = {}
for key, value in pairs(changedRecords.MODMON.baseStats) do
  changed.baseStats[key] = value
end
changed.baseStats.speed = changed.baseStats.speed + 1
changedRecords.MODMON = changed
local changedManifest = Manifest.build(changedRecords, {
  poolMode = "merged",
  metadata = snapshot,
})
assert(changedManifest.poolHash ~= merged.poolHash,
  "pool hash must change with stats")
assert(changedManifest.byId.MODMON.fingerprint
    ~= merged.byId.MODMON.fingerprint,
  "species fingerprint must change with stats")

local vanilla = Manifest.build(Fixture.records, {
  poolMode = "vanilla151",
  metadata = snapshot,
})
equal(vanilla.diagnostics.counts.considered, 151, "vanilla considered")
equal(vanilla.diagnostics.counts.eligible, 7, "present vanilla eligible")
equal(vanilla.diagnostics.counts.excluded, 144, "missing vanilla exclusions")
equal(vanilla.diagnostics.warnings[1].code,
  "INCOMPLETE_VANILLA_POOL", "vanilla warning")
assert(not vanilla.byId.MODMON, "merged-only species excluded from vanilla")

-- Similar-strength widening retains type until a candidate appears.
local candidates, diagnostics = Filters.candidates(
  merged, "BULBASAUR", {
    strengthPercent = 5,
    requiredType = "GRASS",
    excludeIds = { "BULBASAUR" },
    legendary = "allow",
  })
equal(#candidates, 1, "widened candidate count")
equal(candidates[1].id, "IVYSAUR", "widened candidate")
equal(diagnostics.appliedStrengthPercent, 30, "widened percentage")
equal(diagnostics.relaxations[#diagnostics.relaxations].code,
  "WIDEN_STRENGTH", "widening diagnostic")

candidates = Filters.candidates(merged, "MEW", {
  legendary = "match",
  excludeIds = { MEW = true },
})
equal(#candidates, 1, "legendary match count")
equal(candidates[1].id, "MODMON", "metadata legendary match")

candidates = Filters.candidates(merged, "BULBASAUR", {
  legendary = "exclude",
})
assert(not hasId(candidates, "MEW"), "built-in legendary excluded")
assert(not hasId(candidates, "MODMON"), "metadata legendary excluded")

candidates = Filters.candidates(merged, "BULBASAUR", {
  stage = "basic",
  legendary = "exclude",
})
assert(hasId(candidates, "BULBASAUR"), "basic stage includes Bulbasaur")
assert(hasId(candidates, "CHARMANDER"), "basic stage includes Charmander")
assert(not hasId(candidates, "VENUSAUR"), "basic stage excludes final")

candidates, diagnostics = Filters.candidates(
  merged, "BULBASAUR", {
    requiredType = "FAIRY",
    allowTypeRelaxation = true,
    legendary = "exclude",
  })
assert(#candidates > 0, "type relaxation produces candidates")
equal(diagnostics.typeRelaxed, true, "type relaxation flag")
equal(diagnostics.relaxations[1].code, "DROP_TYPE",
  "type relaxation diagnostic")

candidates, diagnostics = Filters.candidates(
  merged, "BULBASAUR", {
    excludeIds = {
      "BULBASAUR", "IVYSAUR", "VENUSAUR", "CHARMANDER",
      "CHARMELEON", "CHARIZARD", "MEW", "MODMON",
    },
  })
equal(#candidates, 0, "hard exclusion empty result")
equal(diagnostics.error.code, "NO_CANDIDATES", "empty result diagnostic")

metadata:freeze()
assert(metadata:isFrozen(), "metadata freezes")
ok = pcall(function()
  metadata:register("LATE_MON", { legendary = false })
end)
assert(not ok, "metadata registration after freeze must fail")

io.write("species_manifest_test: ok\n")
