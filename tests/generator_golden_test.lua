-- Remediation-M4 locked vectors for the real combined generator.
local Harness = assert(loadfile("tests/generator_harness.lua"))()
local Vectors = assert(loadfile("tests/generator_golden_vectors.lua"))()
local Expected = assert(loadfile("tests/generator_golden_expected.lua"))()

local MAPPING_KEYS = {
  "wildGlobal", "wildAreaSlots", "fishing", "starters", "starterFlags",
  "staticEncounters", "gifts", "trades", "prizes", "trainerParties",
}

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
local participated = {}
local start = os.clock()
for _, vector in ipairs(Vectors) do
  local expected = assert(Expected[vector.id],
    "missing expectation for " .. vector.id)
  local request = Harness.request(
    vector.seed, vector.profile, vector.overrides, vector.sourceOverrides)
  equal(Harness.hash(request), expected.input, vector.id .. " input")
  equal(Harness.hash(request.species),
    expected.manifest, vector.id .. " manifest")
  equal(Harness.hash(request.sources),
    expected.sources, vector.id .. " sources")

  local result, generationError = Harness.Generator.generate(request)
  assert(result, generationError and generationError.message)
  assert(Harness.Contracts.validateGenerationResult(result))
  for index, key in ipairs(MAPPING_KEYS) do
    equal(Harness.hash(result.mappings[key]),
      expected.mappings[index], vector.id .. " " .. key)
    if next(result.mappings[key]) ~= nil then participated[key] = true end
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
    validation.mappingBytes,
  }, expected.validation, vector.id .. " validation")
end

for _, key in ipairs(MAPPING_KEYS) do
  assert(participated[key], key .. " never participates in a golden vector")
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
