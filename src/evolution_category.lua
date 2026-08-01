-- Deterministic acyclic evolution graph generation with independent trade safety.
return function(StableSort)
  local Evolution = {}

  local function sortedEntries(entries)
    local rows = {}
    for _, entry in ipairs(entries or {}) do
      if type(entry) == "table" and type(entry.id) == "string" then
        rows[#rows + 1] = entry
      end
    end
    return StableSort.sort(rows, function(a, b) return a.id < b.id end)
  end

  local function copyRow(source)
    local result = {}
    for key, value in pairs(source or {}) do result[key] = value end
    return result
  end

  local function sourceMapping(rows)
    local mapping = {}
    for _, entry in ipairs(rows) do
      mapping[entry.id] = {}
      for _, evolution in ipairs(entry.evolutions or {}) do
        mapping[entry.id][#mapping[entry.id] + 1] = copyRow(evolution)
      end
    end
    return mapping
  end

  local function normalizedMethod(value)
    return type(value) == "string" and string.lower(value) or ""
  end

  local function levelMethod(rows)
    for _, entry in ipairs(rows) do
      for _, evolution in ipairs(entry.evolutions or {}) do
        if normalizedMethod(evolution.method) == "level" then
          return evolution.method
        end
      end
    end
    return "LEVEL"
  end

  local function convertTrades(mapping, rows, setting, rng)
    if setting == nil or setting == "vanilla" then return 0 end
    local method, converted = levelMethod(rows), 0
    for _, entry in ipairs(rows) do
      for _, evolution in ipairs(mapping[entry.id] or {}) do
        if normalizedMethod(evolution.method):find("trade", 1, true) then
          evolution.method = method
          evolution.item = nil
          evolution.level = setting == "fixed_37"
            and 37 or rng:nextInt(30, 40)
          converted = converted + 1
        end
      end
    end
    return converted
  end

  local function createsCycle(adjacency, source, target)
    local seen = {}
    local function reachesSource(id)
      if id == source then return true end
      if seen[id] then return false end
      seen[id] = true
      for _, child in ipairs(adjacency[id] or {}) do
        if reachesSource(child) then return true end
      end
      return false
    end
    return reachesSource(target)
  end

  local function similar(candidate, original, setting)
    if setting == "same_stage" then return candidate.stage == original.stage end
    local absolute = setting == "bst_50" and 50
      or setting == "bst_100" and 100 or nil
    if absolute then return math.abs(candidate.bst - original.bst) <= absolute end
    local percent = tonumber(setting)
    if percent then
      return math.abs(candidate.bst - original.bst) * 100
        <= original.bst * percent
    end
    return true
  end

  local function softMatch(mode, candidate, original, settings)
    if mode == "preserve_stages" then return candidate.stage == original.stage end
    if mode == "similar_strength" then
      return similar(candidate, original, settings.similar_strength)
    end
    return true
  end

  local function randomizedMapping(rows, byId, settings, rng)
    local mapping, edges = {}, {}
    for _, entry in ipairs(rows) do
      mapping[entry.id] = {}
      for index, original in ipairs(entry.evolutions or {}) do
        local originalTarget = byId[original.species]
        if not originalTarget then return nil, "unknown source target", 0 end
        edges[#edges + 1] = {
          source = entry.id, index = index, original = original,
          originalTarget = originalTarget, order = rng:shuffle(rows),
        }
      end
    end

    local adjacency, globallyUsed = {}, {}
    local budget = math.max(3000, #edges * #rows * 24)
    local visited, repeatRelaxations, softRelaxations = 0, 0, 0
    local function assign(edgeIndex)
      if edgeIndex > #edges then return true end
      if visited >= budget then return false end
      local edge = edges[edgeIndex]
      local branchUsed = {}
      for _, row in ipairs(mapping[edge.source]) do branchUsed[row.species] = true end

      -- Hard rules are never relaxed. Global uniqueness is relaxed before
      -- the selected stage/strength preference.
      for tier = 1, 4 do
        local requireUnique = settings.evolution_repeats == "avoid"
          and (tier == 1 or tier == 3)
        local requireSoft = tier == 1 or tier == 2
        for _, candidate in ipairs(edge.order) do
          visited = visited + 1
          if visited > budget then return false end
          local id = candidate.id
          if id ~= edge.source and not branchUsed[id]
              and (not requireUnique or not globallyUsed[id])
              and (not requireSoft or softMatch(
                settings.evolutions, candidate, edge.originalTarget, settings))
              and not createsCycle(adjacency, edge.source, id) then
            local row = copyRow(edge.original)
            row.species = id
            mapping[edge.source][#mapping[edge.source] + 1] = row
            adjacency[edge.source] = adjacency[edge.source] or {}
            adjacency[edge.source][#adjacency[edge.source] + 1] = id
            local wasUsed = globallyUsed[id]
            globallyUsed[id] = true
            if assign(edgeIndex + 1) then
              if tier == 2 or tier == 4 then
                repeatRelaxations = repeatRelaxations + 1
              end
              if tier >= 3 then softRelaxations = softRelaxations + 1 end
              return true
            end
            mapping[edge.source][#mapping[edge.source]] = nil
            adjacency[edge.source][#adjacency[edge.source]] = nil
            if not wasUsed then globallyUsed[id] = nil end
          end
        end
      end
      return false
    end

    if not assign(1) then
      return nil, "bounded graph search exhausted", visited
    end
    return mapping, nil, visited, repeatRelaxations, softRelaxations
  end

  function Evolution.generate(entries, settings, rngs)
    assert(type(settings) == "table", "evolution settings required")
    assert(type(rngs) == "table" and type(rngs.evolutions) == "table"
      and type(rngs.trades) == "table", "evolution RNG streams required")
    local rows, byId = sortedEntries(entries), {}
    for _, entry in ipairs(rows) do byId[entry.id] = entry end

    local mapping, failure, visited, repeatRelaxations, softRelaxations
    if settings.evolutions == nil or settings.evolutions == "vanilla" then
      mapping = sourceMapping(rows)
      visited, repeatRelaxations, softRelaxations = 0, 0, 0
    else
      mapping, failure, visited, repeatRelaxations, softRelaxations =
        randomizedMapping(rows, byId, settings, rngs.evolutions)
    end
    if not mapping then
      return {
        evolutions = {}, fallbackCount = 1,
        warnings = {{
          code = "EVOLUTION_GRAPH_FALLBACK",
          message = "no complete acyclic evolution graph was found; evolutions are vanilla",
          detail = failure,
        }},
      }
    end

    local warnings = {}
    if (repeatRelaxations or 0) > 0 then
      warnings[#warnings + 1] = {
        code = "EVOLUTION_REPEATS_RELAXED",
        count = repeatRelaxations,
        message = "global evolution destination uniqueness was relaxed",
      }
    end
    if (softRelaxations or 0) > 0 then
      warnings[#warnings + 1] = {
        code = "EVOLUTION_MODE_RELAXED",
        count = softRelaxations,
        message = "the selected evolution preference was relaxed for a hard-valid graph",
      }
    end
    local converted = convertTrades(
      mapping, rows, settings.evolution_trade_safety, rngs.trades)
    return {
      evolutions = mapping, warnings = warnings, fallbackCount = 0,
      counts = {
        searchNodes = visited or 0,
        repeatRelaxations = repeatRelaxations or 0,
        softRelaxations = softRelaxations or 0,
        convertedTrades = converted,
      },
    }
  end

  return Evolution
end
