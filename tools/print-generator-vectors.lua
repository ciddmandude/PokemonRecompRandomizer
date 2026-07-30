-- Developer helper: print locked M4 expectations after an intentional,
-- reviewed algorithm-version change. It never edits the vector files.
local Harness = assert(loadfile("tests/generator_harness.lua"))()
local Vectors = assert(loadfile("tests/generator_golden_vectors.lua"))()

local KEYS = {
  "wildGlobal", "wildAreaSlots", "fishing", "starters", "starterFlags",
  "staticEncounters", "gifts", "trades", "prizes", "trainerParties",
}

local function quote(value)
  return string.format("%q", value)
end

local function array(values)
  local parts = {}
  for index, value in ipairs(values or {}) do
    parts[index] = quote(value)
  end
  return "{ " .. table.concat(parts, ", ") .. " }"
end

print("return {")
for _, vector in ipairs(Vectors) do
  local request = Harness.request(
    vector.seed, vector.profile, vector.overrides, vector.sourceOverrides)
  local result, err = Harness.Generator.generate(request)
  assert(result, err and err.message)
  print(("  %s = {"):format(vector.id))
  print(("    input = %s, manifest = %s, sources = %s,"):format(
    quote(Harness.hash(request)), quote(Harness.hash(request.species)),
    quote(Harness.hash(request.sources))))
  local mappingHashes = {}
  for _, key in ipairs(KEYS) do
    mappingHashes[#mappingHashes + 1] =
      quote(Harness.hash(result.mappings[key]))
  end
  print(("    mappings = { %s },"):format(table.concat(mappingHashes, ", ")))
  print(("    combined = %s, warnings = %s, fallback = %d,"):format(
    quote(Harness.hash(result.mappings)),
    array(Harness.warningCodes(result)),
    result.diagnostics.fallbackCount))
  local validation = result.diagnostics.validation or {}
  print(("    validation = { %d, %d, %d, %d },"):format(
    validation.repairSwaps, validation.reachableSpecies,
    validation.mappingEntries, validation.mappingBytes))
  print("  },")
end
print("}")
