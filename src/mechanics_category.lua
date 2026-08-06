-- Deterministic, data-only generation for per-save Pokemon and move mechanics.
-- Effects, evolution records, and every unlisted source field remain immutable.
return function(StableSort, EvolutionCategory)
  local Mechanics = {}
  local STAT_KEYS = { "hp", "attack", "defense", "speed", "special" }

  local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = copy(child) end
    return result
  end

  local function sortedSpecies(entries)
    local rows = {}
    for _, row in ipairs(entries or {}) do
      if type(row) == "table" and type(row.id) == "string" then
        rows[#rows + 1] = row
      end
    end
    return StableSort.sort(rows, function(a, b) return a.id < b.id end)
  end

  local function sortedMoves(records)
    local rows = {}
    for _, id in ipairs(StableSort.keys(records or {})) do
      local source = records[id]
      if type(id) == "string" and type(source) == "table"
          and type(source.type) == "string"
          and type(source.power) == "number"
          and type(source.accuracy) == "number"
          and type(source.pp) == "number" then
        local row = copy(source)
        row.id = id
        rows[#rows + 1] = row
      end
    end
    return rows
  end

  local function uniqueTypes(species, moves, supplied)
    local seen = {}
    for _, id in ipairs(supplied or {}) do
      if type(id) == "string" and id ~= "" then seen[id] = true end
    end
    for _, row in ipairs(species) do
      for _, id in ipairs(row.types or {}) do seen[id] = true end
    end
    for _, row in ipairs(moves) do seen[row.type] = true end
    return StableSort.keys(seen)
  end

  local function parentMap(species, evolutionMapping)
    local available, candidates = {}, {}
    for _, row in ipairs(species) do available[row.id] = true end
    for _, row in ipairs(species) do
      local evolutions = type(evolutionMapping) == "table"
        and evolutionMapping[row.id] or row.evolutions
      for _, evolution in ipairs(evolutions or {}) do
        local target = type(evolution) == "table" and evolution.species
        if available[target] and target ~= row.id then
          candidates[target] = candidates[target] or {}
          candidates[target][#candidates[target] + 1] = row.id
        end
      end
    end
    local parents = {}
    for target, ids in pairs(candidates) do
      table.sort(ids)
      parents[target] = ids[1]
    end
    return parents
  end

  local function familyRoot(id, parents)
    local seen = {}
    while parents[id] and not seen[id] do
      seen[id], id = true, parents[id]
    end
    return id
  end

  local function familyOrder(species, parents)
    local byId, state, result = {}, {}, {}
    for _, entry in ipairs(species) do byId[entry.id] = entry end
    local function visit(id)
      if state[id] == "done" then return end
      if state[id] == "visiting" then
        parents[id] = nil
        return
      end
      state[id] = "visiting"
      if parents[id] then visit(parents[id]) end
      state[id] = "done"
      result[#result + 1] = byId[id]
    end
    for _, entry in ipairs(species) do visit(entry.id) end
    return result
  end

  local function statsFor(entry, mode, rng, family, familyState)
    local source = entry.stats
    if mode == "shuffled" then
      local permutation = familyState[family]
      if not permutation then
        permutation = rng:shuffle({ 1, 2, 3, 4, 5 })
        familyState[family] = permutation
      end
      local values, result = {}, {}
      for index, key in ipairs(STAT_KEYS) do values[index] = source[key] end
      for index, key in ipairs(STAT_KEYS) do
        result[key] = values[permutation[index]]
      end
      return result
    end
    if mode == "redistributed" then
      local weights = familyState[family]
      if not weights then
        weights = {}
        for index = 1, 5 do weights[index] = rng:nextInt(1, 1000) end
        familyState[family] = weights
      end
      local total, weightTotal = entry.bst, 0
      for index = 1, 5 do weightTotal = weightTotal + weights[index] end
      local result, used, remainders = {}, 0, {}
      for index, key in ipairs(STAT_KEYS) do
        local raw = math.floor((total - 5) * weights[index] / weightTotal)
        result[key] = math.min(255, 1 + raw)
        used = used + result[key]
        remainders[#remainders + 1] = {
          key = key, value = ((total - 5) * weights[index]) % weightTotal,
        }
      end
      table.sort(remainders, function(a, b)
        if a.value ~= b.value then return a.value > b.value end
        return a.key < b.key
      end)
      local cursor = 1
      while used < total do
        local row = remainders[cursor]
        if result[row.key] < 255 then
          result[row.key], used = result[row.key] + 1, used + 1
        end
        cursor = cursor % #remainders + 1
      end
      return result
    end
    local result = {}
    for _, key in ipairs(STAT_KEYS) do result[key] = rng:nextInt(1, 255) end
    return result
  end

  local function generateStats(species, settings, rng, parents)
    local mode = settings.base_stats
    if mode == nil or mode == "vanilla" then return {} end
    local result, familyState = {}, {}
    local ordered = settings.stat_family_consistency == "on"
      and familyOrder(species, parents) or species
    for _, entry in ipairs(ordered) do
      local family = settings.stat_family_consistency == "on"
        and familyRoot(entry.id, parents) or entry.id
      result[entry.id] = statsFor(entry, mode, rng, family, familyState)
    end
    return result
  end

  local function otherType(types, primary, rng)
    if #types < 2 then return nil end
    local choices = {}
    for _, id in ipairs(types) do
      if id ~= primary then choices[#choices + 1] = id end
    end
    return choices[rng:nextInt(1, #choices)]
  end

  local function generateTypes(species, typeIds, settings, rng, parents)
    local mode = settings.pokemon_types
    if mode == nil or mode == "vanilla" or #typeIds == 0 then return {} end
    local result = {}
    if mode == "shuffled" then
      local shuffled, mapping = rng:shuffle(typeIds), {}
      for index, id in ipairs(typeIds) do mapping[id] = shuffled[index] end
      for _, entry in ipairs(species) do
        result[entry.id] = {}
        for index, id in ipairs(entry.types or {}) do
          result[entry.id][index] = mapping[id] or id
        end
      end
      return result
    end
    local ordered = settings.type_family_consistency == "on"
      and familyOrder(species, parents) or species
    for _, entry in ipairs(ordered) do
      local inherited = settings.type_family_consistency == "on"
        and parents[entry.id] and result[parents[entry.id]] or nil
      if inherited then
        local nextTypes = copy(inherited)
        if #nextTypes == 1 and rng:nextInt(1, 2) == 1 then
          nextTypes[2] = otherType(typeIds, nextTypes[1], rng)
        elseif #nextTypes == 2 and rng:nextInt(1, 3) == 1 then
          nextTypes[2] = otherType(typeIds, nextTypes[1], rng)
        end
        result[entry.id] = nextTypes
      else
        local primary = typeIds[rng:nextInt(1, #typeIds)]
        result[entry.id] = { primary }
        if #(entry.types or {}) > 1 and #typeIds > 1 then
          result[entry.id][2] = otherType(typeIds, primary, rng)
        end
      end
    end
    return result
  end

  local SPECIAL_MOVES = {
    BIDE = true, COUNTER = true, DRAGON_RAGE = true, FISSURE = true,
    GUILLOTINE = true, HORN_DRILL = true, NIGHT_SHADE = true,
    PSYWAVE = true, SEISMIC_TOSS = true, SONICBOOM = true,
    SUPER_FANG = true, TRANSFORM = true, STRUGGLE = true,
  }

  local function moveData(species, moves, typeIds, settings, rngs)
    local typeMode, dataMode = settings.move_types, settings.move_data
    if (typeMode == nil or typeMode == "vanilla")
        and (dataMode == nil or dataMode == "vanilla") then return {} end
    local typeMap
    if typeMode == "shuffled" and #typeIds > 0 then
      typeMap = {}
      local shuffled = rngs.types:shuffle(typeIds)
      for index, id in ipairs(typeIds) do typeMap[id] = shuffled[index] end
    end
    local damageRows, accuracyRows, ppRows = {}, {}, {}
    for _, row in ipairs(moves) do
      if row.power > 0 and not row.fixedDamage and not SPECIAL_MOVES[row.id] then
        damageRows[#damageRows + 1] = row.power
      end
      if row.accuracy > 0 and not SPECIAL_MOVES[row.id] then
        accuracyRows[#accuracyRows + 1] = row.accuracy
      end
      if row.pp > 0 and not SPECIAL_MOVES[row.id] then ppRows[#ppRows + 1] = row.pp end
    end
    if dataMode == "shuffled" then
      damageRows = rngs.power:shuffle(damageRows)
      accuracyRows = rngs.accuracy:shuffle(accuracyRows)
      ppRows = rngs.pp:shuffle(ppRows)
    end
    local di, ai, pi, result = 1, 1, 1, {}
    for _, row in ipairs(moves) do
      local final = {
        type = row.type, power = row.power,
        accuracy = row.accuracy, pp = row.pp,
      }
      if typeMode == "shuffled" then final.type = typeMap[row.type] or row.type
      elseif typeMode == "randomized" and #typeIds > 0 then
        final.type = typeIds[rngs.types:nextInt(1, #typeIds)]
      end
      local mutable = not SPECIAL_MOVES[row.id] and row.fixedDamage == nil
      if mutable and dataMode == "shuffled" then
        if row.power > 0 then final.power, di = damageRows[di], di + 1 end
        if row.accuracy > 0 then final.accuracy, ai = accuracyRows[ai], ai + 1 end
        if row.pp > 0 then final.pp, pi = ppRows[pi], pi + 1 end
      elseif mutable and dataMode == "balanced" then
        if row.power > 0 then final.power = rngs.power:nextInt(2, 24) * 5 end
        if row.accuracy > 0 then final.accuracy = rngs.accuracy:nextInt(14, 20) * 5 end
        if row.pp > 0 then final.pp = rngs.pp:nextInt(1, 8) * 5 end
      elseif mutable and dataMode == "full_random" then
        if row.power > 0 then final.power = rngs.power:nextInt(1, 255) end
        if row.accuracy > 0 then final.accuracy = rngs.accuracy:nextInt(1, 100) end
        if row.pp > 0 then final.pp = rngs.pp:nextInt(1, 64) end
      end
      if settings.move_safety == "on" and final.power >= 100 then
        final.accuracy = math.min(final.accuracy, 90)
        final.pp = math.min(final.pp, 15)
      end
      result[row.id] = final
    end
    return result
  end

  local function finalMoveRows(moves, overlay)
    local rows, byId = {}, {}
    for _, source in ipairs(moves) do
      if source.id ~= "STRUGGLE" then
        local row = copy(source)
        for key, value in pairs(overlay[source.id] or {}) do row[key] = value end
        rows[#rows + 1], byId[row.id] = row, row
      end
    end
    return rows, byId
  end

  local function pickMove(pool, entryTypes, typeAware, used, rng)
    local candidates = {}
    if typeAware and rng:nextInt(1, 10) <= 7 then
      local typeSet = {}
      for _, id in ipairs(entryTypes or {}) do typeSet[id] = true end
      for _, row in ipairs(pool) do
        if typeSet[row.type] and not used[row.id] then candidates[#candidates + 1] = row end
      end
    end
    if #candidates == 0 then
      for _, row in ipairs(pool) do
        if not used[row.id] then candidates[#candidates + 1] = row end
      end
    end
    if #candidates == 0 then candidates = pool end
    return candidates[rng:nextInt(1, #candidates)].id
  end

  local function generateMovesets(species, moves, finalMoves, finalTypes,
      settings, rng)
    local mode = settings.pokemon_movesets
    if mode == nil or mode == "vanilla" or #moves == 0 then return {} end
    local pool, byId = finalMoveRows(moves, finalMoves)
    if mode == "randomized" then
      local sourceLearnable, filtered = {}, {}
      for _, entry in ipairs(species) do
        for _, id in ipairs(entry.level1Moves or {}) do sourceLearnable[id] = true end
        for _, learned in ipairs(entry.learnset or {}) do
          sourceLearnable[learned.move] = true
        end
      end
      for _, move in ipairs(pool) do
        if sourceLearnable[move.id] then filtered[#filtered + 1] = move end
      end
      if #filtered > 0 then pool = filtered end
    end
    local result = {}
    for _, entry in ipairs(species) do
      local used, row = {}, { level1Moves = {}, learnset = {} }
      local function add(level)
        local id = pickMove(pool, finalTypes[entry.id] or entry.types,
          mode == "type_aware", used, rng)
        used[id] = true
        if level == 1 then row.level1Moves[#row.level1Moves + 1] = id
        else row.learnset[#row.learnset + 1] = { level = level, move = id } end
      end
      for _ = 1, #entry.level1Moves do add(1) end
      local levels = {}
      for index, learned in ipairs(entry.learnset or {}) do levels[index] = learned.level end
      if settings.learnset_levels == "shuffled" then levels = rng:shuffle(levels) end
      table.sort(levels)
      for _, level in ipairs(levels) do add(level) end
      if settings.early_damage == "on" then
        local function safe(id)
          local move = byId[id]
          return move and move.power > 0 and not SPECIAL_MOVES[id]
        end
        local protected = false
        for _, id in ipairs(row.level1Moves) do protected = protected or safe(id) end
        for _, learned in ipairs(row.learnset) do
          if learned.level <= 5 then protected = protected or safe(learned.move) end
        end
        if not protected then
          local damage = {}
          for _, move in ipairs(pool) do
            if move.power > 0 and not SPECIAL_MOVES[move.id] then damage[#damage + 1] = move end
          end
          if #damage > 0 then
            local replacement = damage[rng:nextInt(1, #damage)].id
            if #row.level1Moves > 0 then row.level1Moves[1] = replacement
            elseif #row.learnset > 0 and row.learnset[1].level <= 5 then
              row.learnset[1].move = replacement
            else row.level1Moves[1] = replacement end
          end
        end
      end
      result[entry.id] = row
    end
    return result
  end

  local function shuffledCompatibility(species, rng, protectedSpecies)
    local machines, source = {}, {}
    for index, entry in ipairs(species) do
      source[index] = {}
      for _, move in ipairs(entry.tmhm or {}) do
        machines[move], source[index][move] = true, true
      end
    end
    local result = {}
    for _, entry in ipairs(species) do result[entry.id] = {} end
    for _, move in ipairs(StableSort.keys(machines)) do
      local column = {}
      for index = 1, #species do column[index] = source[index][move] == true end
      column = rng:shuffle(column)
      for index, compatible in ipairs(column) do
        if compatible then
          local list = result[species[index].id]
          list[#list + 1] = move
        end
      end
    end
    local requiredHms = { "CUT", "FLASH", "STRENGTH", "SURF" }
    for _, speciesId in ipairs(protectedSpecies or {}) do
      local list = result[speciesId]
      if list then
        local present = {}
        for _, move in ipairs(list) do present[move] = true end
        for _, move in ipairs(requiredHms) do
          if machines[move] and not present[move] then
            list[#list + 1] = move
            present[move] = true
          end
        end
        table.sort(list)
      end
    end
    return result
  end

  function Mechanics.generate(manifest, sources, settings, rngs, context)
    local species = sortedSpecies(manifest.entries)
    local moves = sortedMoves(sources.moves or {})
    local types = uniqueTypes(species, moves, sources.typeIds)
    local evolutionResult
    if (settings.evolutions ~= nil and settings.evolutions ~= "vanilla")
        or (settings.evolution_trade_safety ~= nil
          and settings.evolution_trade_safety ~= "vanilla") then
      evolutionResult = EvolutionCategory.generate(species, settings, {
        evolutions = rngs.evolutions,
        trades = rngs.tradeEvolutions,
      })
    end
    local finalEvolutions = evolutionResult and evolutionResult.evolutions or nil
    local parents = parentMap(species, finalEvolutions)
    local stats = generateStats(species, settings, rngs.stats, parents)
    local pokemonTypes = generateTypes(
      species, types, settings, rngs.pokemonTypes, parents)
    local movesData = moveData(
      species, moves, types, settings, rngs.moveData)
    local movesets = generateMovesets(
      species, moves, movesData, pokemonTypes, settings, rngs.movesets)
    local compatibility = settings.tmhm_compatibility == "shuffled"
      and shuffledCompatibility(species, rngs.compatibility,
        settings.ensure_beatable == "on" and context
          and context.progressionSpecies or nil) or {}
    local pokemon = {}
    for _, entry in ipairs(species) do
      local row = {}
      if stats[entry.id] then row.baseStats = stats[entry.id] end
      if finalEvolutions and finalEvolutions[entry.id] ~= nil then
        row.evolutions = finalEvolutions[entry.id]
      end
      if pokemonTypes[entry.id] then row.types = pokemonTypes[entry.id] end
      if movesets[entry.id] then
        row.level1Moves = movesets[entry.id].level1Moves
        row.learnset = movesets[entry.id].learnset
      end
      if compatibility[entry.id] then row.tmhm = compatibility[entry.id] end
      if next(row) then pokemon[entry.id] = row end
    end
    return {
      pokemonMechanics = pokemon,
      moveData = movesData,
      warnings = evolutionResult and evolutionResult.warnings or {},
      fallbackCount = evolutionResult and evolutionResult.fallbackCount or 0,
    }
  end

  return Mechanics
end
