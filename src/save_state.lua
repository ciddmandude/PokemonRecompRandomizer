-- Pure saved-run schema, checksumming, validation, and migration helpers.
return function(Constants, Seed, Hash128, Canonical, StableSort, Contracts)
  local SaveState = {}

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
  }

  local function addError(errors, path, code, message)
    errors[#errors + 1] = {
      path = path,
      code = code,
      message = message,
    }
  end

  local function clone(value, active)
    local kind = type(value)
    if kind ~= "table" then
      assert(kind == "nil" or kind == "boolean"
          or kind == "number" or kind == "string",
        "saved state must contain data-only values")
      return value
    end
    active = active or {}
    assert(not active[value], "saved state cannot contain cycles")
    active[value] = true
    local copy = {}
    for key, child in pairs(value) do
      copy[clone(key, active)] = clone(child, active)
    end
    active[value] = nil
    return copy
  end

  local function emptyMappings()
    local mappings = {}
    for _, key in ipairs(MAPPING_KEYS) do mappings[key] = {} end
    return mappings
  end

  local function checksumPayload(namespace)
    return {
      schemaVersion = namespace.schemaVersion,
      algorithmVersion = namespace.algorithmVersion,
      enabled = namespace.enabled,
      seed = namespace.seed,
      settings = namespace.settings,
      compatibility = namespace.compatibility,
      mappings = namespace.mappings,
      diagnostics = namespace.diagnostics,
      race = namespace.race,
    }
  end

  local function hashValue(domain, value)
    return Hash128.digest(
      "pokemon_randomizer\0" .. domain .. "\0" .. Canonical.encode(value)).hex
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

  local function validateSeed(seed, errors)
    if type(seed) ~= "table" then
      addError(errors, "seed", "TYPE", "seed must be a table")
      return
    end
    if seed.mode ~= "auto" and seed.mode ~= "manual" then
      addError(errors, "seed.mode", "VALUE", "seed mode must be auto or manual")
    end
    if type(seed.display) ~= "string" or seed.display == "" then
      addError(errors, "seed.display", "REQUIRED",
        "display seed must be a non-empty string")
    end
    if not Seed.isCanonical(seed.canonical) then
      addError(errors, "seed.canonical", "INVALID",
        "canonical seed is not normalized")
    elseif seed.hash128 ~= Hash128.seed(seed.canonical).hex then
      addError(errors, "seed.hash128", "HASH_MISMATCH",
        "seed hash does not match the canonical seed")
    end
  end

  local function behaviorSettings(settings)
    local result = {}
    for key, value in pairs(settings or {}) do
      if key ~= "preset" and key ~= "seed_mode" and key ~= "seed_text" then
        result[key] = clone(value)
      end
    end
    return result
  end

  local function validateCompatibility(value, settings, errors)
    if type(value) ~= "table" then
      addError(errors, "compatibility", "TYPE",
        "compatibility must be a table")
      return
    end
    for _, field in ipairs({
      "gameVersion", "engineVersion", "poolHash", "settingsHash",
    }) do
      if type(value[field]) ~= "string" or value[field] == "" then
        addError(errors, "compatibility." .. field, "REQUIRED",
          field .. " must be a non-empty string")
      end
    end
    if value.modApi ~= Constants.MOD_API then
      addError(errors, "compatibility.modApi", "UNSUPPORTED_VERSION",
        ("expected mod API %d"):format(Constants.MOD_API))
    end
    if type(settings) == "table" and type(value.settingsHash) == "string"
        and value.settingsHash
          ~= hashValue("settings-v1", behaviorSettings(settings)) then
      addError(errors, "compatibility.settingsHash", "HASH_MISMATCH",
        "settings hash does not match behavior-affecting settings")
    end
    if not isDenseArray(value.relevantMods) then
      addError(errors, "compatibility.relevantMods", "TYPE",
        "relevantMods must be a dense array")
    else
      local previous
      for index, row in ipairs(value.relevantMods) do
        local path = ("compatibility.relevantMods[%d]"):format(index)
        if type(row) ~= "table" or type(row.id) ~= "string"
            or row.id == "" or type(row.version) ~= "string" then
          addError(errors, path, "TYPE",
            "mod rows require string id and version")
        elseif previous and row.id <= previous then
          addError(errors, path .. ".id", "ORDER",
            "relevant mods must be unique and sorted by id")
        else
          previous = row.id
        end
      end
    end
  end

  local function checkSpeciesId(id, path, speciesSet, errors)
    if type(id) ~= "string" or id == "" then
      addError(errors, path, "INVALID_SPECIES",
        "mapped species id must be a non-empty string")
    elseif speciesSet and not speciesSet[id] then
      addError(errors, path, "MISSING_SPECIES",
        "mapped species is not present in merged content")
    end
  end

  local function inspectMapping(value, path, speciesSet, errors, directSpecies)
    if directSpecies and type(value) == "string" then
      checkSpeciesId(value, path, speciesSet, errors)
      return
    end
    if type(value) ~= "table" then return end
    for key, child in pairs(value) do
      local childPath = path .. "." .. tostring(key)
      if key == "species" or key == "give" or key == "get" then
        checkSpeciesId(child, childPath, speciesSet, errors)
      else
        inspectMapping(child, childPath, speciesSet, errors,
          directSpecies == "all" and "all" or false)
      end
    end
  end

  local function validateMappings(mappings, speciesSet, errors)
    if type(mappings) ~= "table" then
      addError(errors, "mappings", "TYPE", "mappings must be a table")
      return
    end
    for _, key in ipairs(MAPPING_KEYS) do
      if type(mappings[key]) ~= "table" then
        addError(errors, "mappings." .. key, "TYPE",
          "mapping category must be a table")
      else
        local direct
        if key == "wildGlobal" or key == "wildAreaSlots"
            or key == "fishing" then
          direct = "all"
        elseif key == "starters" then
          direct = "top"
        end
        inspectMapping(mappings[key], "mappings." .. key,
          speciesSet, errors, direct)
      end
    end
  end

  local function validateAuxiliary(namespace, errors)
    if type(namespace.settings) ~= "table" then
      addError(errors, "settings", "TYPE", "settings must be a table")
    end
    if type(namespace.diagnostics) ~= "table"
        or not isDenseArray(namespace.diagnostics.warnings)
        or type(namespace.diagnostics.fallbackCount) ~= "number"
        or namespace.diagnostics.fallbackCount < 0 then
      addError(errors, "diagnostics", "TYPE",
        "diagnostics require warnings and fallbackCount")
    end
    local race = namespace.race
    if type(race) ~= "table" or type(race.enabled) ~= "boolean"
        or type(race.unlocked) ~= "boolean"
        or type(race.unlockPolicy) ~= "string" then
      addError(errors, "race", "TYPE", "race state is malformed")
    end
  end

  function SaveState.hashSettings(settings)
    return hashValue("settings-v1", settings)
  end

  function SaveState.behaviorSettings(settings)
    return behaviorSettings(settings)
  end

  function SaveState.hashBehaviorSettings(settings)
    return hashValue("settings-v1", behaviorSettings(settings))
  end

  function SaveState.checksum(namespace)
    return hashValue("save-checksum-v1", checksumPayload(namespace))
  end

  function SaveState.makeSeed(mode, display)
    local canonical, err = Seed.normalize(display)
    if not canonical then return nil, err end
    return {
      mode = mode,
      display = display,
      canonical = canonical,
      hash128 = Hash128.seed(canonical).hex,
    }
  end

  function SaveState.makeAutoSeed(entropy)
    assert(type(entropy) == "string" and entropy ~= "",
      "auto seed entropy must be a non-empty string")
    local hex = Hash128.digest(
      "pokemon_randomizer\0auto-seed-v1\0" .. entropy).hex
    local alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
    -- Treat the digest as a 128-bit integer. Two leading zero padding bits
    -- make the conventional 26-character Crockford representation.
    local bits = { 0, 0 }
    for index = 1, #hex do
      local nibble = tonumber(hex:sub(index, index), 16)
      for shift = 3, 0, -1 do
        bits[#bits + 1] = math.floor(nibble / (2 ^ shift)) % 2
      end
    end
    local encoded = {}
    for first = 1, #bits, 5 do
      local value = 0
      for offset = 0, 4 do value = value * 2 + bits[first + offset] end
      encoded[#encoded + 1] = alphabet:sub(value + 1, value + 1)
    end
    local canonical = table.concat(encoded)
    return {
      mode = "auto",
      display = canonical,
      canonical = canonical,
      hash128 = Hash128.seed(canonical).hex,
    }
  end

  function SaveState.validate(namespace, speciesSet, requireChecksum)
    local errors = {}
    if type(namespace) ~= "table" then
      addError(errors, "$", "TYPE", "randomizer namespace must be a table")
      return false, errors
    end
    if namespace.schemaVersion ~= Constants.SAVE_SCHEMA_VERSION then
      addError(errors, "schemaVersion", "UNSUPPORTED_VERSION",
        ("expected save schema %d"):format(Constants.SAVE_SCHEMA_VERSION))
    end
    if type(namespace.algorithmVersion) ~= "string"
        or namespace.algorithmVersion == "" then
      addError(errors, "algorithmVersion", "REQUIRED",
        "algorithmVersion must be a non-empty string")
    end
    if type(namespace.enabled) ~= "boolean" then
      addError(errors, "enabled", "TYPE", "enabled must be boolean")
    end
    validateSeed(namespace.seed, errors)
    validateCompatibility(namespace.compatibility, namespace.settings, errors)
    validateMappings(namespace.mappings, speciesSet, errors)
    validateAuxiliary(namespace, errors)

    local encoded = pcall(Canonical.encode, checksumPayload(namespace))
    if not encoded then
      addError(errors, "$", "NON_DATA_VALUE",
        "saved configuration must contain finite data-only values")
    end

    if requireChecksum then
      if type(namespace.checksum) ~= "table"
          or namespace.checksum.version ~= Constants.SAVE_CHECKSUM_VERSION
          or type(namespace.checksum.value) ~= "string" then
        addError(errors, "checksum", "TYPE",
          "checksum record is missing or unsupported")
      elseif #errors == 0
          and namespace.checksum.value ~= SaveState.checksum(namespace) then
        addError(errors, "checksum.value", "CHECKSUM_MISMATCH",
          "saved randomizer configuration was modified or damaged")
      end
    end
    return #errors == 0, errors
  end

  function SaveState.stamp(namespace, speciesSet)
    local valid, errors = SaveState.validate(namespace, speciesSet, false)
    if not valid then return nil, errors end
    namespace.checksum = {
      version = Constants.SAVE_CHECKSUM_VERSION,
      value = SaveState.checksum(namespace),
    }
    return namespace, nil
  end

  local function relevantMods(rows)
    local byId = {}
    for _, row in ipairs(rows or {}) do
      if type(row) == "table" and type(row.id) == "string"
          and row.id ~= Constants.MOD_ID then
        byId[row.id] = {
          id = row.id,
          version = tostring(row.version or ""),
        }
      end
    end
    local result = {}
    for _, id in ipairs(StableSort.keys(byId)) do
      result[#result + 1] = byId[id]
    end
    return result
  end

  function SaveState.compatibility(
      save, poolHash, settings, modRows, settingsHash)
    return {
      gameVersion = tostring(save and save.version or "unknown"),
      engineVersion = tostring(
        save and save.meta and save.meta.engine or "unknown"),
      modApi = Constants.MOD_API,
      poolHash = poolHash,
      settingsHash = settingsHash or SaveState.hashBehaviorSettings(settings),
      relevantMods = relevantMods(modRows),
    }
  end

  local function baseNamespace(input, enabled, mappings, diagnostics)
    return {
      schemaVersion = Constants.SAVE_SCHEMA_VERSION,
      algorithmVersion = Constants.ALGORITHM_VERSION,
      enabled = enabled,
      seed = clone(input.seed),
      settings = clone(input.settings),
      compatibility = clone(input.compatibility),
      mappings = mappings,
      diagnostics = diagnostics,
      race = {
        enabled = false,
        unlockPolicy = "hall_of_fame",
        unlocked = false,
        encryptedSpoilerDigest = nil,
      },
    }
  end

  local function disabledNamespace(input, failure)
    return baseNamespace(input, false, emptyMappings(), {
      warnings = {{
        code = failure.code or "GENERATION_FAILED",
        message = failure.message or "generation failed; using vanilla content",
      }},
      fallbackCount = 1,
    })
  end

  function SaveState.create(input, generate)
    assert(type(input) == "table", "save creation input must be a table")
    assert(type(generate) == "function", "generate callback must be a function")

    if input.enabled == false then
      local warningRows = {}
      local fallbackCount = 0
      if input.disableReason then
        warningRows[1] = clone(input.disableReason)
        fallbackCount = 1
      end
      local namespace = baseNamespace(input, false, emptyMappings(), {
        warnings = warningRows,
        fallbackCount = fallbackCount,
      })
      local stamped, errors = SaveState.stamp(namespace, input.speciesSet)
      if not stamped then
        return nil, {
          generated = false,
          disabled = true,
          error = {
            code = "INVALID_DISABLED_CONFIGURATION",
            message = "disabled run configuration failed validation",
            details = errors,
          },
        }
      end
      return stamped, {
        generated = false,
        disabled = true,
        error = input.disableReason and clone(input.disableReason) or nil,
      }
    end

    local request = {
      contractVersion = Constants.CONTRACT_VERSION,
      seed = clone(input.seed),
      settings = clone(input.settings),
      species = clone(input.species),
      sources = clone(input.sources or {}),
    }
    local ok, result, generationError = pcall(generate, request)
    local namespace
    local report = { generated = false, error = nil }
    if not ok then
      report.error = {
        code = "GENERATOR_ERROR",
        message = "generator raised an error; using vanilla content",
      }
      namespace = disabledNamespace(input, report.error)
    elseif result == nil then
      report.error = generationError or {
        code = "GENERATION_FAILED",
        message = "generation failed; using vanilla content",
      }
      namespace = disabledNamespace(input, report.error)
    else
      local valid, errors = Contracts.validateGenerationResult(result)
      if not valid then
        report.error = {
          code = "INVALID_GENERATION_RESULT",
          message = "generator returned invalid data; using vanilla content",
          details = errors,
        }
        namespace = disabledNamespace(input, report.error)
      else
        namespace = baseNamespace(input, true, clone(result.mappings),
          clone(result.diagnostics))
        report.generated = true
      end
    end

    local stamped, errors = SaveState.stamp(namespace, input.speciesSet)
    if not stamped then
      return nil, {
        generated = false,
        error = {
          code = "INVALID_RUN_CONFIGURATION",
          message = "run configuration failed validation",
          details = errors,
        },
      }
    end
    return stamped, report
  end

  -- First migration harness. It recognizes the development schema used
  -- before 0.4.0 and returns a copy so a failed migration is atomic.
  function SaveState.migrate(namespace)
    if type(namespace) ~= "table" or namespace.schemaVersion ~= 0 then
      return namespace
    end
    local migrated = clone(namespace)
    if type(migrated.seed) == "string" then
      local seed = SaveState.makeSeed("manual", migrated.seed)
      if seed then migrated.seed = seed end
    end
    migrated.schemaVersion = Constants.SAVE_SCHEMA_VERSION
    migrated.algorithmVersion =
      migrated.algorithmVersion or Constants.ALGORITHM_VERSION
    if type(migrated.enabled) ~= "boolean" then migrated.enabled = false end
    migrated.settings = migrated.settings or {}
    migrated.mappings = migrated.mappings or emptyMappings()
    for _, key in ipairs(MAPPING_KEYS) do
      if type(migrated.mappings[key]) ~= "table" then
        migrated.mappings[key] = {}
      end
    end
    migrated.diagnostics = migrated.diagnostics
      or { warnings = {}, fallbackCount = 0 }
    migrated.race = migrated.race or {
      enabled = false,
      unlockPolicy = "hall_of_fame",
      unlocked = false,
      encryptedSpoilerDigest = nil,
    }
    return migrated
  end

  SaveState.clone = clone
  SaveState.emptyMappings = emptyMappings
  SaveState.mappingKeys = function()
    local copy = {}
    for index, key in ipairs(MAPPING_KEYS) do copy[index] = key end
    return copy
  end

  return SaveState
end
