-- Pure construction of deterministic eligible-species manifests.
return function(Constants, StableSort, Canonical, Hash128, VanillaSpecies)
  local SpeciesManifest = {}

  local MANIFEST_SCHEMA_VERSION = Constants.SPECIES_MANIFEST_VERSION
  local STAT_KEYS = { "hp", "attack", "defense", "speed", "special" }
  local BUILTIN_LEGENDARIES = {
    ARTICUNO = true,
    ZAPDOS = true,
    MOLTRES = true,
    MEWTWO = true,
    MEW = true,
  }
  local VANILLA_SET = {}
  for dex, id in ipairs(VanillaSpecies) do VANILLA_SET[id] = dex end

  local function denseArray(value)
    if type(value) ~= "table" then return false end
    local count = 0
    for key in pairs(value) do
      if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then return false end
      count = count + 1
    end
    for index = 1, count do if value[index] == nil then return false end end
    return true
  end

  local function addReason(reasons, code, field, message)
    reasons[#reasons + 1] = { code = code, field = field, message = message }
  end

  local function validateRecord(id, record)
    local reasons = {}
    if type(id) ~= "string" or id == "" then
      addReason(reasons, "INVALID_ID", "$",
        "registry key must be a non-empty string")
    end
    if type(record) ~= "table" then
      addReason(reasons, "TYPE", "$", "species record must be a table")
      return reasons
    end
    if record.id ~= id then
      addReason(reasons, "ID_MISMATCH", "id",
        "record id must match its registry key")
    end
    if type(record.dex) ~= "number" or record.dex < 1
        or record.dex ~= math.floor(record.dex) then
      addReason(reasons, "INVALID_DEX", "dex",
        "dex must be a positive integer")
    end

    if type(record.baseStats) ~= "table" then
      addReason(reasons, "MISSING_STATS", "baseStats",
        "five base stats are required")
    else
      for _, key in ipairs(STAT_KEYS) do
        local value = record.baseStats[key]
        if type(value) ~= "number" or value < 1 or value > 255
            or value ~= math.floor(value) then
          addReason(reasons, "INVALID_STAT", "baseStats." .. key,
            "base stat must be an integer from 1 through 255")
        end
      end
    end

    if not denseArray(record.types) or #record.types < 1 then
      addReason(reasons, "INVALID_TYPES", "types",
        "at least one type id is required")
    else
      for index, typeId in ipairs(record.types) do
        if type(typeId) ~= "string" or typeId == "" then
          addReason(reasons, "INVALID_TYPE", ("types[%d]"):format(index),
            "type id must be a non-empty string")
        end
      end
    end

    if type(record.growthRate) ~= "string" or record.growthRate == "" then
      addReason(reasons, "MISSING_GROWTH_RATE", "growthRate",
        "growth rate id is required")
    end
    if not denseArray(record.level1Moves) then
      addReason(reasons, "INVALID_LEVEL1_MOVES", "level1Moves",
        "level1Moves must be a dense array")
    end
    if not denseArray(record.learnset) then
      addReason(reasons, "INVALID_LEARNSET", "learnset",
        "learnset must be a dense array")
    end
    if record.tmhm ~= nil and not denseArray(record.tmhm) then
      addReason(reasons, "INVALID_TMHM", "tmhm",
        "tmhm must be a dense array when present")
    end
    if not denseArray(record.evolutions) then
      addReason(reasons, "INVALID_EVOLUTIONS", "evolutions",
        "evolutions must be a dense array")
    end
    if type(record.spriteFront) ~= "string" or record.spriteFront == "" then
      addReason(reasons, "MISSING_SPRITE", "spriteFront",
        "front battle sprite path is required")
    end
    if type(record.spriteBack) ~= "string" or record.spriteBack == "" then
      addReason(reasons, "MISSING_SPRITE", "spriteBack",
        "back battle sprite path is required")
    end
    return reasons
  end

  local function copyArray(source)
    local copy = {}
    for index, value in ipairs(source or {}) do copy[index] = value end
    return copy
  end

  local function evolutionData(record, included)
    local output = {}
    for _, evolution in ipairs(record.evolutions or {}) do
      if type(evolution) == "table" and included[evolution.species] then
        output[#output + 1] = {
          species = evolution.species,
          method = evolution.method,
          level = evolution.level,
          item = evolution.item,
        }
      end
    end
    return StableSort.sort(output, function(a, b)
      if a.species ~= b.species then return a.species < b.species end
      if tostring(a.method) ~= tostring(b.method) then
        return tostring(a.method) < tostring(b.method)
      end
      if (a.level or -1) ~= (b.level or -1) then
        return (a.level or -1) < (b.level or -1)
      end
      return tostring(a.item or "") < tostring(b.item or "")
    end)
  end

  local function sourceIds(records, mode)
    if mode == "vanilla151" then
      local ids = {}
      for index, id in ipairs(VanillaSpecies) do ids[index] = id end
      return ids
    end
    return StableSort.keys(records)
  end

  function SpeciesManifest.build(records, options)
    assert(type(records) == "table", "species records must be a table")
    options = options or {}
    local mode = options.poolMode or "vanilla151"
    assert(mode == "vanilla151" or mode == "merged",
      "poolMode must be vanilla151 or merged")
    local metadata = options.metadata or {}
    assert(type(metadata) == "table", "metadata snapshot must be a table")

    local diagnostics = {
      warnings = {},
      exclusions = {},
      counts = { considered = 0, eligible = 0, excluded = 0 },
    }
    local valid = {}
    for _, id in ipairs(sourceIds(records, mode)) do
      diagnostics.counts.considered = diagnostics.counts.considered + 1
      local record = records[id]
      local reasons
      if record == nil then
        reasons = {}
        addReason(reasons, "MISSING_SPECIES", "$",
          "species is absent from the merged registry")
      else
        reasons = validateRecord(id, record)
      end
      if #reasons == 0 then
        valid[id] = record
      else
        diagnostics.exclusions[#diagnostics.exclusions + 1] = {
          id = id,
          reasons = reasons,
        }
        diagnostics.counts.excluded = diagnostics.counts.excluded + 1
      end
    end

    local included = {}
    for id in pairs(valid) do included[id] = true end
    local inbound = {}
    local outgoing = {}
    for id, record in pairs(valid) do
      local evolutions = evolutionData(record, included)
      outgoing[id] = evolutions
      for _, evolution in ipairs(evolutions) do
        inbound[evolution.species] = (inbound[evolution.species] or 0) + 1
      end
    end

    local ids = StableSort.keys(valid)
    local entries, byId = {}, {}
    for _, id in ipairs(ids) do
      local record = valid[id]
      local bst = 0
      local stats = {}
      for _, key in ipairs(STAT_KEYS) do
        stats[key] = record.baseStats[key]
        bst = bst + stats[key]
      end
      local stage
      if not inbound[id] then
        stage = "basic"
      elseif #outgoing[id] > 0 then
        stage = "middle"
      else
        stage = "final"
      end
      if metadata[id] and metadata[id].stage then stage = metadata[id].stage end
      local legendary = BUILTIN_LEGENDARIES[id] == true
      if metadata[id] and metadata[id].legendary ~= nil then
        legendary = metadata[id].legendary
      end

      local relevant = {
        id = id,
        dex = record.dex,
        stats = stats,
        types = copyArray(record.types),
        growthRate = record.growthRate,
        level1Moves = copyArray(record.level1Moves),
        tmhm = copyArray(record.tmhm),
        learnset = copyArray(record.learnset),
        evolutions = outgoing[id],
        spriteFront = record.spriteFront,
        spriteBack = record.spriteBack,
        stage = stage,
        legendary = legendary,
      }
      local fingerprint = Hash128.digest(Canonical.encode(relevant)).hex
      local entry = {
        id = id,
        dex = record.dex,
        bst = bst,
        stats = stats,
        types = copyArray(record.types),
        primaryType = record.types[1],
        secondaryType = record.types[2],
        stage = stage,
        legendary = legendary,
        vanilla = VANILLA_SET[id] ~= nil,
        level1Moves = copyArray(record.level1Moves),
        tmhm = copyArray(record.tmhm),
        learnset = copyArray(record.learnset),
        evolutions = outgoing[id],
        fingerprint = fingerprint,
      }
      entries[#entries + 1] = entry
      byId[id] = entry
    end

    diagnostics.counts.eligible = #entries
    if #entries == 0 then
      diagnostics.warnings[#diagnostics.warnings + 1] = {
        code = "EMPTY_POOL",
        message = "no eligible species remain",
      }
    elseif mode == "vanilla151" and #entries ~= #VanillaSpecies then
      diagnostics.warnings[#diagnostics.warnings + 1] = {
        code = "INCOMPLETE_VANILLA_POOL",
        message = ("%d of %d vanilla species are eligible")
          :format(#entries, #VanillaSpecies),
      }
    end

    local poolRows = {}
    for index, entry in ipairs(entries) do
      poolRows[index] = { id = entry.id, fingerprint = entry.fingerprint }
    end
    local poolHash = Hash128.digest(Canonical.encode({
      schemaVersion = MANIFEST_SCHEMA_VERSION,
      mode = mode,
      entries = poolRows,
    })).hex

    return {
      schemaVersion = MANIFEST_SCHEMA_VERSION,
      mode = mode,
      entries = entries,
      byId = byId,
      poolHash = poolHash,
      diagnostics = diagnostics,
    }
  end

  SpeciesManifest.schemaVersion = MANIFEST_SCHEMA_VERSION
  SpeciesManifest.vanillaCount = #VanillaSpecies

  return SpeciesManifest
end
