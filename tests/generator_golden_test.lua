-- Remediation-M4 locked vectors for the real combined generator.
local Harness = assert(loadfile("tests/generator_harness.lua"))()
local Vectors = assert(loadfile("tests/generator_golden_vectors.lua"))()
local Expected = assert(loadfile("tests/generator_golden_expected.lua"))()
local GoldenRequest = assert(loadfile("tests/generator_golden_request.lua"))()

local MAPPING_KEYS = Harness.Contracts.mappingKeys()
local MAPPING_KEY_SET = {}
for _, key in ipairs(MAPPING_KEYS) do MAPPING_KEY_SET[key] = true end

local function equal(actual, expected, label)
  assert(actual == expected,
    ("%s: expected %s, got %s"):format(
      label, tostring(expected), tostring(actual)))
end

local function equalArray(actual, expected, label)
  equal(#actual, #expected, label .. " length")
  for index = 1, #expected do
    equal(actual[index], expected[index],
      ("%s[%d]"):format(label, index))
  end
end

assert(#Vectors >= 20, "at least 20 combined vectors are required")
local participated, participationCount = {}, {}
local manifestHash = Harness.hash(Harness.species)
local sourceHashes = {}
local start = os.clock()
for _, vector in ipairs(Vectors) do
  local expected = assert(Expected[vector.id],
    "missing expectation for " .. vector.id)
  local request = GoldenRequest(Harness, vector)
  equal(Harness.hash(request), expected.input, vector.id .. " input")
  equal(manifestHash, expected.manifest, vector.id .. " manifest")
  local sourceVariant = Harness.hash(vector.sourceOverrides or {})
  if not sourceHashes[sourceVariant] then
    sourceHashes[sourceVariant] = Harness.hash(request.sources)
  end
  equal(sourceHashes[sourceVariant], expected.sources,
    vector.id .. " sources")

  local result, generationError = Harness.Generator.generate(request)
  assert(result, generationError and generationError.message)
  assert(Harness.Contracts.validateGenerationResult(result))
  for _, key in ipairs(MAPPING_KEYS) do
    equal(Harness.hash(result.mappings[key]),
      expected.mappings[key], vector.id .. " " .. key)
    if next(result.mappings[key]) ~= nil then
      participated[key] = true
      participationCount[key] = (participationCount[key] or 0) + 1
    end
  end
  for key in pairs(expected.mappings) do
    assert(MAPPING_KEY_SET[key],
      vector.id .. " expectation has unknown mapping key " .. tostring(key))
  end
  equal(Harness.hash(result.mappings),
    expected.combined, vector.id .. " combined mappings")
  equalArray(Harness.warningCodes(result),
    expected.warnings, vector.id .. " warnings")
  equal(result.diagnostics.fallbackCount,
    expected.fallback, vector.id .. " fallback count")
  local validation = assert(result.diagnostics.validation)
  equalArray({
    validation.repairSwaps,
    validation.reachableSpecies,
    validation.mappingEntries,
    #Harness.Canonical.encode(result.mappings),
  }, expected.validation, vector.id .. " validation")
  if vector.id == "R3_ALL_ENABLED" then
    for _, key in ipairs(MAPPING_KEYS) do
      local mutuallyExclusiveWildBucket =
        key == "wildAreaSlots"
          and request.settings.wild_pokemon ~= "area_slots"
        or key == "wildGlobalMap"
          and request.settings.wild_pokemon ~= "global_map"
      if not mutuallyExclusiveWildBucket then
        assert(next(result.mappings[key]) ~= nil,
          "R3_ALL_ENABLED has no data in " .. key)
      end
    end
  end
  collectgarbage("collect")
end

for _, key in ipairs(MAPPING_KEYS) do
  assert(participated[key], key .. " never participates in a golden vector")
end
for _, key in ipairs({ "fieldItems", "pokemonMechanics", "moveData" }) do
  assert((participationCount[key] or 0) >= 2,
    key .. " must participate in multiple golden vectors")
end

-- Insertion-order changes in every nested input map must not change output.
local ordered = Harness.request("M4 ORDER INVARIANT", "standard")
local reordered = Harness.reversedMaps(ordered)
local first = assert(Harness.Generator.generate(ordered))
local second = assert(Harness.Generator.generate(reordered))
equal(Harness.hash(first), Harness.hash(second),
  "input map insertion order")

local elapsed = os.clock() - start
assert(elapsed < 60, "golden vector runtime exceeded 60-second CI budget")
io.write(("generator_golden_test: ok (%d vectors, %.2fs)\n")
  :format(#Vectors, elapsed))
