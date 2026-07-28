-- Deterministic global walking/surfing species mapping.
-- Fishing is intentionally a separate category and is not inspected here.
return function(StableSort, SpeciesFilters)
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

    local used = {}
    local unique = settings.duplicate_policy == "one_to_one"
    for _, sourceId in ipairs(sources) do
      local excluded = unique and used or nil
      local candidates, diagnostics = SpeciesFilters.candidates(
        manifest, sourceId, filterRules(settings, excluded))

      if #candidates == 0 and unique and manifest.byId[sourceId] then
        candidates, diagnostics = SpeciesFilters.candidates(
          manifest, sourceId, filterRules(settings, nil))
        if #candidates > 0 then
          used = {}
          result.warnings[#result.warnings + 1] = warning(
            "WILD_UNIQUENESS_POOL_RESET",
            "eligible destinations were exhausted; uniqueness pool restarted",
            sourceId)
        end
      end

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
        local selected = candidates[rng:nextInt(1, #candidates)].id
        result.mapping[sourceId] = selected
        result.mappedCount = result.mappedCount + 1
        if unique then used[selected] = true end
      end
    end
    return result
  end

  function WildGlobal.sourceSpecies(encounters)
    return sourceSpecies(encounters)
  end

  return WildGlobal
end
