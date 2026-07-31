-- Deterministic global walking/surfing species mapping.
-- Fishing is intentionally a separate category and is not inspected here.
return function(StableSort, SpeciesFilters, Matching)
  local WildGlobal = {}

  local TERRAIN_ORDER = { "grass", "water" }

  local function warning(code, message, sourceId)
    local row = { code = code, message = message }
    if sourceId then row.sourceId = sourceId end
    return row
  end

  local function sourceSpecies(encounters)
    local found = {}
    if type(encounters) ~= "table" then return {}, false end
    for _, mapId in ipairs(StableSort.keys(encounters)) do
      local record = encounters[mapId]
      if type(record) == "table" then
        for _, terrain in ipairs(TERRAIN_ORDER) do
          local definition = record[terrain]
          local slots = type(definition) == "table" and definition.slots
          if type(slots) == "table" then
            for _, slot in ipairs(slots) do
              if type(slot) == "table" and type(slot.species) == "string"
                  and slot.species ~= "" then
                found[slot.species] = true
              end
            end
          end
        end
      end
    end
    return StableSort.keys(found), true
  end

  local function filterRules(settings, excluded)
    return {
      strengthPercent = tonumber(settings.similar_strength),
      strengthPoints = settings.similar_strength == "bst_50" and 50
        or settings.similar_strength == "bst_100" and 100 or nil,
      sameStage = settings.similar_strength == "same_stage",
      legendary = settings.legendaries or "allow",
      excludeIds = excluded,
    }
  end

  -- Returns a category result even when individual source species cannot be
  -- mapped. Such sources remain vanilla and receive deterministic warnings.
  function WildGlobal.generate(manifest, encounters, settings, rng)
    assert(type(manifest) == "table", "species manifest is required")
    assert(type(settings) == "table", "settings are required")
    assert(type(rng) == "table" and type(rng.nextInt) == "function",
      "wild global RNG stream is required")

    local result = {
      mapping = {},
      warnings = {},
      fallbackCount = 0,
      sourceCount = 0,
      mappedCount = 0,
    }
    if settings.wild_pokemon ~= "global_map" then return result end

    local sources, available = sourceSpecies(encounters)
    result.sourceCount = #sources
    if not available then
      result.warnings[#result.warnings + 1] = warning(
        "WILD_SOURCE_UNAVAILABLE",
        "merged encounter registry is unavailable; wild encounters are vanilla")
      result.fallbackCount = 1
      return result
    end

    local unique = settings.duplicate_policy == "one_to_one"
    local units, diagnosticsBySource = {}, {}
    for _, sourceId in ipairs(sources) do
      local candidates, diagnostics = SpeciesFilters.candidates(
        manifest, sourceId, filterRules(settings, nil))
      diagnosticsBySource[sourceId] = diagnostics
      units[#units + 1] = {
        id = sourceId,
        source = sourceId,
        candidates = candidates,
        diagnostics = diagnostics,
        hardConstraints = {
          similarStrength = tonumber(settings.similar_strength),
          baseStatRange = settings.similar_strength == "bst_50" and 50
            or settings.similar_strength == "bst_100" and 100 or nil,
          sameStage = settings.similar_strength == "same_stage",
          legendary = settings.legendaries or "allow",
        },
      }
    end
    local matched
    if unique then
      matched = Matching.assign(units, rng, {
        category = "wild.global",
        code = "WILD_UNIQUENESS_POOL_RESET",
      })
      for _, reset in ipairs(matched.resets) do
        result.warnings[#result.warnings + 1] = Matching.warning(reset)
      end
    end
    for _, unit in ipairs(units) do
      local sourceId = unit.source
      local candidates = unit.candidates
      local diagnostics = diagnosticsBySource[sourceId]
      local selected = unique and matched.assignments[unit.id]
        or (#candidates > 0 and candidates[rng:nextInt(1, #candidates)].id)
      if #candidates == 0 then
        result.fallbackCount = result.fallbackCount + 1
        local code = diagnostics.error and diagnostics.error.code
          or "NO_CANDIDATES"
        result.warnings[#result.warnings + 1] = warning(
          "WILD_" .. code,
          diagnostics.error and diagnostics.error.message
            or "source species has no eligible destination",
          sourceId)
      else
        result.mapping[sourceId] = selected
        result.mappedCount = result.mappedCount + 1
      end
    end
    return result
  end

  function WildGlobal.sourceSpecies(encounters)
    return sourceSpecies(encounters)
  end

  return WildGlobal
end
