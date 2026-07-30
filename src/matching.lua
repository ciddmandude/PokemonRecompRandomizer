-- Deterministic one-to-one assignment with proof-based pool resets.
--
-- Each input unit must have a stable, unique `id`, a `source`, and a
-- `candidates` array of species manifest entries (or destination ids).
return function(StableSort)
  local Matching = {}

  local function candidateId(candidate)
    return type(candidate) == "table" and candidate.id or candidate
  end

  local function stablePreferences(candidates, rng)
    local found = {}
    for _, candidate in ipairs(candidates or {}) do
      local id = candidateId(candidate)
      if type(id) == "string" and id ~= "" then found[id] = true end
    end
    return rng:shuffle(StableSort.keys(found))
  end

  local function copyConstraints(constraints)
    local output = {}
    for _, key in ipairs(StableSort.keys(constraints or {})) do
      local value = constraints[key]
      if type(value) ~= "table" then output[key] = value end
    end
    return output
  end

  local function countKeys(value)
    local count = 0
    for _ in pairs(value) do count = count + 1 end
    return count
  end

  local function augment(index, preferences, assigned, owner, seen)
    for _, destination in ipairs(preferences[index]) do
      if not seen[destination] then
        seen[destination] = true
        local previous = owner[destination]
        if previous == nil
            or augment(previous, preferences, assigned, owner, seen) then
          assigned[index] = destination
          owner[destination] = index
          return true
        end
      end
    end
    return false
  end

  -- Assigns every matchable unit. A new uniqueness pool is opened only when
  -- augmenting-path search proves the current unit cannot join the existing
  -- pool while preserving all earlier assignments in that pool.
  function Matching.assign(units, rng, options)
    assert(type(units) == "table", "matching units are required")
    assert(type(rng) == "table" and type(rng.shuffle) == "function",
      "matching RNG stream with shuffle is required")
    options = options or {}

    local preferences, assignments = {}, {}
    local resets, unmatched = {}, {}
    for index, unit in ipairs(units) do
      preferences[index] = stablePreferences(unit.candidates, rng)
    end

    local poolStart = 1
    while poolStart <= #units do
      local assigned, owner = {}, {}
      local index = poolStart
      while index <= #units do
        if #preferences[index] == 0 then
          unmatched[#unmatched + 1] = {
            id = units[index].id,
            source = units[index].source,
            diagnostics = units[index].diagnostics,
          }
          index = index + 1
        elseif augment(index, preferences, assigned, owner, {}) then
          index = index + 1
        else
          local poolSize = countKeys(owner)
          for matchedIndex, destination in pairs(assigned) do
            assignments[units[matchedIndex].id] = destination
          end
          resets[#resets + 1] = {
            code = options.code or "UNIQUENESS_POOL_RESET",
            category = options.category or "unknown",
            poolSize = poolSize,
            exhaustedPoolSize = poolSize,
            affectedSource = units[index].source,
            affectedId = units[index].id,
            hardConstraints = copyConstraints(
              units[index].hardConstraints or options.hardConstraints),
          }
          poolStart = index
          break
        end
      end
      if index > #units then
        for matchedIndex, destination in pairs(assigned) do
          assignments[units[matchedIndex].id] = destination
        end
        poolStart = #units + 1
      end
    end
    return {
      assignments = assignments,
      resets = resets,
      unmatched = unmatched,
    }
  end

  function Matching.warning(reset, message)
    return {
      code = reset.code,
      message = message
        or "eligible destinations were exhausted; uniqueness pool restarted",
      category = reset.category,
      exhaustedPoolSize = reset.exhaustedPoolSize,
      affectedSource = reset.affectedSource,
      affectedId = reset.affectedId,
      hardConstraints = reset.hardConstraints,
    }
  end

  -- Streaming facade for generators that discover stable units while building
  -- other saved metadata. Call finish() before reading final assignments.
  function Matching.newSession(rng, options)
    options = options or {}
    local units, preferences = {}, {}
    local assigned, owner = {}, {}
    local output = { assignments = {}, resets = {}, unmatched = {} }

    local function commit()
      for index, destination in pairs(assigned) do
        output.assignments[units[index].id] = destination
      end
    end

    local session = {}
    function session:add(unit)
      local index = #units + 1
      units[index] = unit
      preferences[index] = stablePreferences(unit.candidates, rng)
      if #preferences[index] == 0 then
        output.unmatched[#output.unmatched + 1] = {
          id = unit.id, source = unit.source,
          diagnostics = unit.diagnostics,
        }
        return
      end
      if not augment(index, preferences, assigned, owner, {}) then
        local poolSize = countKeys(owner)
        commit()
        output.resets[#output.resets + 1] = {
          code = options.code or "UNIQUENESS_POOL_RESET",
          category = options.category or "unknown",
          poolSize = poolSize,
          exhaustedPoolSize = poolSize,
          affectedSource = unit.source,
          affectedId = unit.id,
          hardConstraints = copyConstraints(
            unit.hardConstraints or options.hardConstraints),
        }
        assigned, owner = {}, {}
        assert(augment(index, preferences, assigned, owner, {}),
          "non-empty candidate list must match an empty pool")
      end
    end
    function session:finish()
      commit()
      return output
    end
    return session
  end

  return Matching
end
