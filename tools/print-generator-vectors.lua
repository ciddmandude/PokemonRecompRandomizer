-- Developer helper: print locked M4 expectations after an intentional,
-- reviewed algorithm-version change. Pass an optional output path to replace
-- the generated expectation file directly.
local emit = print
if type(arg) == "table" and type(arg[1]) == "string" and arg[1] ~= "" then
  local output = assert(io.open(arg[1], "w"))
  emit = function(value)
    output:write(tostring(value), "\n")
    output:flush()
  end
end
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

emit("return {")
for _, vector in ipairs(Vectors) do
  local request = Harness.request(
    vector.seed, vector.profile, vector.overrides, vector.sourceOverrides)
  local result, err = Harness.Generator.generate(request)
  assert(result, err and err.message)
  emit(("  %s = {"):format(vector.id))
  emit(("    input = %s, manifest = %s, sources = %s,"):format(
    quote(Harness.hash(request)), quote(Harness.hash(request.species)),
    quote(Harness.hash(request.sources))))
  local mappingHashes = {}
  for _, key in ipairs(KEYS) do
    mappingHashes[#mappingHashes + 1] =
      quote(Harness.hash(result.mappings[key]))
  end
  emit(("    mappings = { %s },"):format(table.concat(mappingHashes, ", ")))
  emit(("    combined = %s, warnings = %s, fallback = %d,"):format(
    quote(Harness.hash(result.mappings)),
    array(Harness.warningCodes(result)),
    result.diagnostics.fallbackCount))
  local validation = result.diagnostics.validation or {}
  emit(("    validation = { %d, %d, %d, %d },"):format(
    validation.repairSwaps, validation.reachableSpecies,
    validation.mappingEntries, validation.mappingBytes))
  emit("  },")
end
emit("}")
