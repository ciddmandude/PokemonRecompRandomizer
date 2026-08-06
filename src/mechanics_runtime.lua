-- Projects saved mechanics into the active game's mutable merged tables.
-- Each distinct game.data identity owns one immutable post-merge baseline.
return function()
  local Runtime = {}
  local baselines = setmetatable({}, { __mode = "k" })
  local POKEMON_FIELDS = {
    "baseStats", "evolutions", "types", "level1Moves", "learnset", "tmhm",
  }
  local MOVE_FIELDS = { "type", "power", "accuracy", "pp" }

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

  local function restoreFields(records, snapshot, fields)
    local restored = 0
    for id, baselineRow in pairs(
        type(snapshot) == "table" and snapshot or {}) do
      local target = type(records) == "table" and records[id]
      if type(target) == "table" then
        for _, field in ipairs(fields) do
          -- Assignment is intentional even when the pristine value was nil:
          -- an overlay may have introduced that optional field.
          target[field] = copy(baselineRow[field])
        end
        restored = restored + 1
      end
    end
    return restored
  end

  local function gameData(game)
    return type(game) == "table" and type(game.data) == "table"
      and game.data or nil
  end

  function Runtime.capture(game)
    local data = gameData(game)
    if not data then return false end
    if baselines[data] then return true end
    baselines[data] = {
      pokemon = captureFields(data.pokemon, POKEMON_FIELDS),
      moves = captureFields(data.moves, MOVE_FIELDS),
    }
    return true
  end

  function Runtime.restore(game)
    local data = gameData(game)
    if not data then return 0 end
    if not baselines[data] then Runtime.capture(game) end
    local baseline = baselines[data]
    local pokemon = restoreFields(
      data.pokemon, baseline and baseline.pokemon, POKEMON_FIELDS)
    local moves = restoreFields(
      data.moves, baseline and baseline.moves, MOVE_FIELDS)
    return pokemon + moves
  end

  function Runtime.apply(game, run)
    Runtime.restore(game)
    local data = gameData(game)
    if not data then return 0 end
    if type(run) ~= "table" or run.enabled == false
        or run.quarantined == true or run.phase == "quarantined"
        or run.valid == false then return 0 end
    local mappings = type(run) == "table" and run.mappings or {}
    local pokemon = project(
      data.pokemon, mappings.pokemonMechanics, POKEMON_FIELDS)
    local moves = project(data.moves, mappings.moveData, MOVE_FIELDS)
    return pokemon + moves
  end

  return Runtime
end
