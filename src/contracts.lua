-- Pure input/output contracts for the future deterministic generator.
-- No LÖVE or gen1recomp modules are required here.
return function(Constants)
  local Contracts = {}

  local CATEGORY_KEYS = {
    "wild",
    "starters",
    "staticEncounters",
    "gifts",
    "trades",
    "prizes",
    "trainers",
  }

  -- Serialized mapping buckets from saved-data contract Section 7.
  local MAPPING_KEYS = {
    "wildGlobal",
    "wildAreaSlots",
    "fishing",
    "starters",
    "starterFlags",
    "staticEncounters",
    "gifts",
    "trades",
    "prizes",
    "trainerParties",
    "fieldItems",
  }

  local function addError(errors, path, code, message)
    errors[#errors + 1] = {
      path = path,
      code = code,
      message = message,
    }
  end

  local function isDenseArray(value)
    if type(value) ~= "table" then return false end
    local count = 0
    for key in pairs(value) do
      if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
        return false
      end
      count = count + 1
    end
    for index = 1, count do
      if value[index] == nil then return false end
    end
    return true
  end

  function Contracts.categoryKeys()
    local copy = {}
    for index, key in ipairs(CATEGORY_KEYS) do copy[index] = key end
    return copy
  end

  function Contracts.mappingKeys()
    local copy = {}
    for index, key in ipairs(MAPPING_KEYS) do copy[index] = key end
    return copy
  end

  -- Generation request v1:
  -- {
  --   contractVersion = 1,
  --   seed = { canonical = non-empty string },
  --   settings = table,
  --   species = dense array of { id = non-empty string, ... },
  --   sources = table (optional category source data)
  -- }
  --
  -- Returns true, {} for a valid request or false, ordered error rows.
  -- Validation never mutates the request.
  function Contracts.validateGenerationRequest(request)
    local errors = {}
    if type(request) ~= "table" then
      addError(errors, "$", "TYPE", "generation request must be a table")
      return false, errors
    end

    if request.contractVersion ~= Constants.CONTRACT_VERSION then
      addError(errors, "contractVersion", "UNSUPPORTED_VERSION",
        ("expected contract version %d"):format(Constants.CONTRACT_VERSION))
    end

    if type(request.seed) ~= "table" then
      addError(errors, "seed", "TYPE", "seed must be a table")
    elseif type(request.seed.canonical) ~= "string"
        or request.seed.canonical == "" then
      addError(errors, "seed.canonical", "REQUIRED",
        "canonical seed must be a non-empty string")
    end

    if type(request.settings) ~= "table" then
      addError(errors, "settings", "TYPE", "settings must be a table")
    end

    if not isDenseArray(request.species) then
      addError(errors, "species", "TYPE",
        "species must be a dense array")
    else
      local seen = {}
      for index, species in ipairs(request.species) do
        local path = ("species[%d].id"):format(index)
        if type(species) ~= "table" or type(species.id) ~= "string"
            or species.id == "" then
          addError(errors, path, "REQUIRED",
            "species id must be a non-empty string")
        elseif seen[species.id] then
          addError(errors, path, "DUPLICATE",
            "species ids must be unique")
        else
          seen[species.id] = true
        end
      end
    end

    if request.sources ~= nil and type(request.sources) ~= "table" then
      addError(errors, "sources", "TYPE", "sources must be a table when present")
    end

    return #errors == 0, errors
  end

  -- Result shape reserved by contract v1. Category mapping values remain
  -- deliberately unspecified until their milestones define them.
  function Contracts.newGenerationResult()
    local mappings = {}
    for _, key in ipairs(MAPPING_KEYS) do mappings[key] = {} end
    return {
      contractVersion = Constants.CONTRACT_VERSION,
      algorithmVersion = Constants.ALGORITHM_VERSION,
      mappings = mappings,
      diagnostics = {
        warnings = {},
        fallbackCount = 0,
      },
    }
  end

  function Contracts.validateGenerationResult(result)
    local errors = {}
    if type(result) ~= "table" then
      addError(errors, "$", "TYPE", "generation result must be a table")
      return false, errors
    end
    if result.contractVersion ~= Constants.CONTRACT_VERSION then
      addError(errors, "contractVersion", "UNSUPPORTED_VERSION",
        ("expected contract version %d"):format(Constants.CONTRACT_VERSION))
    end
    if type(result.algorithmVersion) ~= "string" then
      addError(errors, "algorithmVersion", "TYPE",
        "algorithmVersion must be a string")
    end
    if type(result.mappings) ~= "table" then
      addError(errors, "mappings", "TYPE", "mappings must be a table")
    else
      for _, key in ipairs(MAPPING_KEYS) do
        if type(result.mappings[key]) ~= "table" then
          addError(errors, "mappings." .. key, "TYPE",
            "category mapping must be a table")
        end
      end
    end
    if type(result.diagnostics) ~= "table" then
      addError(errors, "diagnostics", "TYPE", "diagnostics must be a table")
    end
    return #errors == 0, errors
  end

  return Contracts
end
