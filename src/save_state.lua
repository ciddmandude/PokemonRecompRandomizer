-- Pure saved-run schema, checksumming, validation, and migration helpers.
return function(Constants, Seed, Hash128, Canonical, StableSort, Contracts)
  local SaveState = {}
  local measureNamespace

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
      if key ~= "preset" and key ~= "seed_mode" and key ~= "seed_text"
          and key ~= "generate_spoiler_log" then
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
            or row.id == "" or type(row.version) ~= "string"
            or type(row.fingerprint) ~= "string"
            or row.fingerprint == "" then
          addError(errors, path, "TYPE",
            "mod rows require string id, version, and fingerprint")
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
      if key == "species" or key == "rivalSpecies"
          or key == "give" or key == "get" then
        checkSpeciesId(child, childPath, speciesSet, errors)
      else
        inspectMapping(child, childPath, speciesSet, errors,
          directSpecies == "all" and "all" or false)
      end
    end
  end

  local function validateStarterMappings(mappings, errors)
    local starters = mappings.starters
    local flags = mappings.starterFlags
    if next(starters) == nil and next(flags) == nil then return end
    if starters.YELLOW ~= nil or flags.gameVersion == "yellow" then
      local offer = starters.YELLOW
      local path = "mappings.starters.YELLOW"
      if type(offer) ~= "table" then
        addError(errors, path, "REQUIRED",
          "the saved Yellow starter offer is required")
      else
        if offer.slotId ~= "YELLOW"
            or offer.starterIndex ~= 1
            or offer.choseFlag ~= "EVENT_CHOSE_PIKACHU"
            or offer.ballObject ~= "YELLOW_STARTER_GIFT"
            or offer.rivalBall ~= "OAKSLAB_EEVEE_POKE_BALL"
            or offer.rivalSlot ~= "YELLOW_RIVAL"
            or offer.gameVersion ~= "yellow" then
          addError(errors, path, "PROJECTION",
            "saved Yellow starter must preserve the Yellow lab projection")
        end
        if type(offer.level) ~= "number" or offer.level % 1 ~= 0
            or offer.level < 2 or offer.level > 20 then
          addError(errors, path .. ".level", "VALUE",
            "starter level must be an integer from 2 through 20")
        end
        if type(offer.species) == "string"
            and offer.species == offer.rivalSpecies then
          addError(errors, path .. ".rivalSpecies", "DUPLICATE",
            "the Yellow player and rival starters must be distinct")
        end
      end
      for slotId in pairs(starters) do
        if slotId ~= "YELLOW" then
          addError(errors, "mappings.starters." .. tostring(slotId),
            "VALUE", "Yellow saves may contain only the Yellow starter slot")
        end
      end
      local offsets = flags.partyOffsetSlots
      if not isDenseArray(offsets) or #offsets ~= 3
          or offsets[1] ~= "YELLOW" or offsets[2] ~= "YELLOW"
          or offsets[3] ~= "YELLOW" then
        addError(errors, "mappings.starterFlags.partyOffsetSlots", "VALUE",
          "Yellow rival party offsets must use the Yellow starter slot")
      end
      if type(flags.choiceFlags) ~= "table"
          or flags.choiceFlags.YELLOW ~= "EVENT_CHOSE_PIKACHU" then
        addError(errors, "mappings.starterFlags.choiceFlags.YELLOW", "VALUE",
          "Yellow starter choice must preserve EVENT_CHOSE_PIKACHU")
      end
      return
    end
    local slots = { "LEFT", "MIDDLE", "RIGHT" }
    local expected = {
      LEFT = {
        index = 1,
        flag = "EVENT_CHOSE_CHARMANDER",
        ball = "OAKSLAB_CHARMANDER_POKE_BALL",
      },
      MIDDLE = {
        index = 2,
        flag = "EVENT_CHOSE_SQUIRTLE",
        ball = "OAKSLAB_SQUIRTLE_POKE_BALL",
      },
      RIGHT = {
        index = 3,
        flag = "EVENT_CHOSE_BULBASAUR",
        ball = "OAKSLAB_BULBASAUR_POKE_BALL",
      },
    }
    local seen = {}
    for _, slotId in ipairs(slots) do
      local offer = starters[slotId]
      local path = "mappings.starters." .. slotId
      if type(offer) ~= "table" then
        addError(errors, path, "REQUIRED",
          "all three saved starter offers are required")
      else
        if offer.slotId ~= slotId then
          addError(errors, path .. ".slotId", "VALUE",
            "saved starter slot identity does not match its key")
        end
        if offer.starterIndex ~= expected[slotId].index
            or offer.choseFlag ~= expected[slotId].flag
            or offer.ballObject ~= expected[slotId].ball then
          addError(errors, path, "PROJECTION",
            "saved starter must preserve its physical ball projection")
        end
        if type(offer.level) ~= "number" or offer.level % 1 ~= 0
            or offer.level < 2 or offer.level > 20 then
          addError(errors, path .. ".level", "VALUE",
            "starter level must be an integer from 2 through 20")
        end
        if seen[offer.species] then
          addError(errors, path .. ".species", "DUPLICATE",
            "saved player starter choices must be unique")
        elseif type(offer.species) == "string" then
          seen[offer.species] = true
        end
        if offer.rivalSlot == slotId
            or (offer.rivalSlot ~= "LEFT"
              and offer.rivalSlot ~= "MIDDLE"
              and offer.rivalSlot ~= "RIGHT") then
          addError(errors, path .. ".rivalSlot", "VALUE",
            "rival slot must be one of the other starter choices")
        end
        local rival = starters[offer.rivalSlot]
        if type(rival) == "table"
            and offer.rivalSpecies ~= rival.species then
          addError(errors, path .. ".rivalSpecies", "MISMATCH",
            "rival species must match the saved rival slot")
        end
        if type(rival) == "table"
            and offer.rivalBall ~= rival.ballObject then
          addError(errors, path .. ".rivalBall", "MISMATCH",
            "rival ball must match the saved rival slot")
        end
      end
    end
    local offsets = type(flags) == "table" and flags.partyOffsetSlots
    if not isDenseArray(offsets) or #offsets ~= 3
        or offsets[1] ~= "LEFT" or offsets[2] ~= "MIDDLE"
        or offsets[3] ~= "RIGHT" then
      addError(errors, "mappings.starterFlags.partyOffsetSlots", "VALUE",
        "rival party offsets must project LEFT, MIDDLE, RIGHT")
    end
    local choices = type(flags) == "table" and flags.choiceFlags
    for _, slotId in ipairs(slots) do
      if type(choices) ~= "table"
          or choices[slotId] ~= expected[slotId].flag then
        addError(errors, "mappings.starterFlags.choiceFlags." .. slotId,
          "VALUE", "choice flag projection does not match the physical ball")
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
    if type(mappings.starters) == "table"
        and type(mappings.starterFlags) == "table" then
      validateStarterMappings(mappings, errors)
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
    if measureNamespace then
      measureNamespace(namespace)
      valid, errors = SaveState.validate(namespace, speciesSet, false)
      if not valid then return nil, errors end
    end
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
          fingerprint = hashValue("relevant-mod-v1", {
            id = row.id,
            version = tostring(row.version or ""),
            api = tonumber(row.api) or 0,
          }),
        }
      end
    end
    local result = {}
    for _, id in ipairs(StableSort.keys(byId)) do
      result[#result + 1] = byId[id]
    end
    return result
  end

  local function modsById(rows)
    local result = {}
    for _, row in ipairs(rows or {}) do
      if type(row) == "table" and type(row.id) == "string" then
        result[row.id] = row
      end
    end
    return result
  end

  function SaveState.compareRelevantMods(savedRows, currentModRows)
    -- Saved rows are already snapshots and must retain their original
    -- fingerprints. relevantMods() is only appropriate for live loader rows.
    local saved = clone(savedRows or {})
    local current = relevantMods(currentModRows)
    local savedById, currentById = modsById(saved), modsById(current)
    local report = {
      code = "OK",
      added = {},
      removed = {},
      changed = {},
      savedCount = #saved,
      currentCount = #current,
    }
    for _, id in ipairs(StableSort.keys(savedById)) do
      local before, after = savedById[id], currentById[id]
      if not after then
        report.removed[#report.removed + 1] = clone(before)
      elseif before.fingerprint ~= after.fingerprint then
        report.changed[#report.changed + 1] = {
          id = id,
          savedVersion = before.version,
          currentVersion = after.version,
          savedFingerprint = before.fingerprint,
          currentFingerprint = after.fingerprint,
        }
      end
    end
    for _, id in ipairs(StableSort.keys(currentById)) do
      if not savedById[id] then
        report.added[#report.added + 1] = clone(currentById[id])
      end
    end
    if #report.added > 0 or #report.removed > 0
        or #report.changed > 0 then
      report.code = "RELEVANT_MODS_CHANGED"
    end
    return report
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
    }
  end

  local function removeSizeWarnings(warnings)
    local kept = {}
    for _, warning in ipairs(warnings or {}) do
      if type(warning) ~= "table"
          or warning.code ~= "SAVE_SIZE_BUDGET_EXCEEDED" then
        kept[#kept + 1] = warning
      end
    end
    return kept
  end

  measureNamespace = function(namespace)
    namespace.diagnostics = namespace.diagnostics or {
      warnings = {}, fallbackCount = 0,
    }
    namespace.diagnostics.warnings =
      removeSizeWarnings(namespace.diagnostics.warnings)
    namespace.diagnostics.validation =
      namespace.diagnostics.validation or {}
    local validation = namespace.diagnostics.validation
    validation.mappingBytes = #Canonical.encode(namespace.mappings or {})
    validation.namespaceBytes = 0
    validation.budgetBytes = Constants.SAVE_SIZE_BUDGET_BYTES
    namespace.checksum = {
      version = Constants.SAVE_CHECKSUM_VERSION,
      value = string.rep("0", 32),
    }

    local function settle()
      for _ = 1, 8 do
        local measured = #Canonical.encode(namespace)
        if validation.namespaceBytes == measured then return measured end
        validation.namespaceBytes = measured
      end
      return #Canonical.encode(namespace)
    end

    local measured = settle()
    if measured > Constants.SAVE_SIZE_BUDGET_BYTES then
      local warning = {
        code = "SAVE_SIZE_BUDGET_EXCEEDED",
        measuredBytes = measured,
        budgetBytes = Constants.SAVE_SIZE_BUDGET_BYTES,
      }
      namespace.diagnostics.warnings[
        #namespace.diagnostics.warnings + 1] = warning
      for _ = 1, 8 do
        warning.measuredBytes = measured
        warning.message = ("canonical randomizer state is %d bytes; "
          .. "the budget is %d bytes (256 KiB)"):format(
            measured, Constants.SAVE_SIZE_BUDGET_BYTES)
        local nextMeasured = settle()
        if nextMeasured == measured then break end
        measured = nextMeasured
      end
    end
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
    if type(migrated.compatibility) == "table"
        and type(migrated.compatibility.relevantMods) == "table" then
      for _, row in ipairs(migrated.compatibility.relevantMods) do
        if type(row) == "table" and type(row.id) == "string"
            and type(row.fingerprint) ~= "string" then
          row.fingerprint = hashValue("relevant-mod-v1", {
            id = row.id,
            version = tostring(row.version or ""),
            api = tonumber(row.api) or 0,
          })
        end
      end
    end
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
