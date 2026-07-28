-- Deterministic candidate filtering with explicit, bounded soft relaxation.
local SpeciesFilters = {}

local function containsType(entry, requiredType)
  if not requiredType then return true end
  for _, typeId in ipairs(entry.types) do
    if typeId == requiredType then return true end
  end
  return false
end

local function exclusions(value)
  local result = {}
  if value == nil then return result end
  assert(type(value) == "table", "excludeIds must be a table")
  for key, item in pairs(value) do
    if type(key) == "number" then
      assert(type(item) == "string", "excluded array values must be ids")
      result[item] = true
    else
      assert(type(key) == "string", "excluded map keys must be ids")
      if item then result[key] = true end
    end
  end
  return result
end

local function hardEligible(entry, source, rules, excluded)
  if excluded[entry.id] then return false end
  if rules.stage == "basic" and entry.stage ~= "basic" then return false end
  local legendary = rules.legendary or "allow"
  if legendary == "exclude" and entry.legendary then return false end
  if legendary == "match" and entry.legendary ~= source.legendary then
    return false
  end
  return true
end

local function strengthEligible(entry, source, percent)
  if percent == nil then return true end
  return math.abs(entry.bst - source.bst) * 100 <= source.bst * percent
end

local function collect(manifest, source, rules, excluded, percent, typeRequired)
  local output = {}
  for _, entry in ipairs(manifest.entries) do
    if hardEligible(entry, source, rules, excluded)
        and strengthEligible(entry, source, percent)
        and (not typeRequired or containsType(entry, rules.requiredType)) then
      output[#output + 1] = entry
    end
  end
  return output
end

function SpeciesFilters.candidates(manifest, sourceId, rules)
  assert(type(manifest) == "table" and type(manifest.entries) == "table"
      and type(manifest.byId) == "table", "species manifest is required")
  assert(type(sourceId) == "string", "source species id is required")
  rules = rules or {}
  local source = manifest.byId[sourceId]
  if not source then
    return {}, {
      error = {
        code = "UNKNOWN_SOURCE",
        message = ("source species %s is not eligible"):format(sourceId),
      },
      relaxations = {},
    }
  end

  local legendary = rules.legendary or "allow"
  assert(legendary == "exclude" or legendary == "match"
      or legendary == "allow",
    "legendary rule must be exclude, match, or allow")
  assert(rules.stage == nil or rules.stage == "any" or rules.stage == "basic",
    "stage rule must be any or basic")
  local percent = rules.strengthPercent
  assert(percent == nil or (type(percent) == "number" and percent >= 0
      and percent <= 100 and percent == math.floor(percent)),
    "strengthPercent must be an integer from 0 through 100")
  if rules.requiredType ~= nil then
    assert(type(rules.requiredType) == "string" and rules.requiredType ~= "",
      "requiredType must be a non-empty type id")
  end

  local diagnostics = {
    sourceId = sourceId,
    requestedStrengthPercent = percent,
    appliedStrengthPercent = percent,
    requiredType = rules.requiredType,
    typeRelaxed = false,
    relaxations = {},
  }
  local excluded = exclusions(rules.excludeIds)
  local typeRequired = rules.requiredType ~= nil
  local output = collect(
    manifest, source, rules, excluded, percent, typeRequired)

  while #output == 0 and percent ~= nil and percent < 100 do
    local nextPercent = math.min(100, percent + 5)
    diagnostics.relaxations[#diagnostics.relaxations + 1] = {
      code = "WIDEN_STRENGTH",
      from = percent,
      to = nextPercent,
    }
    percent = nextPercent
    diagnostics.appliedStrengthPercent = percent
    output = collect(
      manifest, source, rules, excluded, percent, typeRequired)
  end

  if #output == 0 and percent ~= nil then
    diagnostics.relaxations[#diagnostics.relaxations + 1] = {
      code = "DROP_STRENGTH",
      from = percent,
    }
    percent = nil
    diagnostics.appliedStrengthPercent = nil
    output = collect(
      manifest, source, rules, excluded, percent, typeRequired)
  end

  if #output == 0 and typeRequired and rules.allowTypeRelaxation then
    diagnostics.relaxations[#diagnostics.relaxations + 1] = {
      code = "DROP_TYPE",
      type = rules.requiredType,
    }
    typeRequired = false
    diagnostics.typeRelaxed = true
    output = collect(
      manifest, source, rules, excluded, percent, typeRequired)
  end

  diagnostics.candidateCount = #output
  if #output == 0 then
    diagnostics.error = {
      code = "NO_CANDIDATES",
      message = "hard filters excluded every species",
    }
  end
  return output, diagnostics
end

return SpeciesFilters
