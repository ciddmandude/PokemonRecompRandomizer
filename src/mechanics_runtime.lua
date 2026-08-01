-- Projects saved mechanics into the active game's mutable merged tables.
-- A captured post-mod baseline is restored before every save switch.
return function()
  local Runtime = {}
  local baseline

  local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, child in pairs(value) do result[copy(key, seen)] = copy(child, seen) end
    return result
  end

  local function captureFields(records, fields)
    local result = {}
    for id, record in pairs(type(records) == "table" and records or {}) do
      if type(record) == "table" then
        local row = {}
        for _, field in ipairs(fields) do row[field] = copy(record[field]) end
        result[id] = row
      end
    end
    return result
  end

  local function project(records, mappings, fields)
    local applied = 0
    for id, overlay in pairs(type(mappings) == "table" and mappings or {}) do
      local target = type(records) == "table" and records[id]
      if type(target) == "table" and type(overlay) == "table" then
        for _, field in ipairs(fields) do
          if overlay[field] ~= nil then target[field] = copy(overlay[field]) end
        end
        applied = applied + 1
      end
    end
    return applied
  end

  function Runtime.capture(game)
    local data = type(game) == "table" and game.data or {}
    baseline = {
      pokemon = captureFields(data.pokemon, {
        "baseStats", "evolutions", "types", "level1Moves", "learnset", "tmhm",
      }),
      moves = captureFields(data.moves, { "type", "power", "accuracy", "pp" }),
    }
    return true
  end

  function Runtime.restore(game)
    if not baseline then Runtime.capture(game) end
    local data = type(game) == "table" and game.data or {}
    local pokemon = project(data.pokemon, baseline and baseline.pokemon, {
      "baseStats", "evolutions", "types", "level1Moves", "learnset", "tmhm",
    })
    local moves = project(data.moves, baseline and baseline.moves, {
      "type", "power", "accuracy", "pp",
    })
    return pokemon + moves
  end

  function Runtime.apply(game, run)
    Runtime.restore(game)
    local data = type(game) == "table" and game.data or {}
    local mappings = type(run) == "table" and run.mappings or {}
    local pokemon = project(data.pokemon, mappings.pokemonMechanics, {
      "baseStats", "evolutions", "types", "level1Moves", "learnset", "tmhm",
    })
    local moves = project(data.moves, mappings.moveData, {
      "type", "power", "accuracy", "pp",
    })
    return pokemon + moves
  end

  return Runtime
end
