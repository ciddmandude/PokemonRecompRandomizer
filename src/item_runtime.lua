-- Projects saved item placements into live merged data and restores the
-- post-mod baseline when saves are switched in one application session.
return function()
  local ItemRuntime, baseline = {}, nil

  local function findVisible(data, row)
    local map = type(data.maps) == "table" and data.maps[row.mapId]
    for arrayIndex, object in ipairs(
        type(map) == "table" and map.objects or {}) do
      if (object.index or arrayIndex) == row.objectIndex then return object end
    end
  end

  local function findHidden(data, row)
    local hidden = type(data.field) == "table" and data.field.hiddenItems
    local objects = type(hidden) == "table" and hidden[row.mapId]
    local indexed = type(objects) == "table" and objects[row.hiddenIndex]
    if type(indexed) == "table" and indexed.x == row.x
        and indexed.y == row.y then return indexed end
    for _, object in ipairs(objects or {}) do
      if object.x == row.x and object.y == row.y then return object end
    end
  end

  local function project(game, rows, validateMapping)
    local data = type(game) == "table" and game.data
    if type(data) ~= "table" then return 0 end
    local applied = 0
    for _, row in ipairs(rows or {}) do
      local object
      if row.kind == "hidden" then
        object = findHidden(data, row)
      elseif row.kind == "visible" then
        object = findVisible(data, row)
      end
      local definition = type(data.items) == "table" and data.items[row.item]
      local valid = not validateMapping or (
        type(definition) == "table" and definition.keyItem ~= true
          and object and object.item == row.original)
      if object and type(row.item) == "string" and valid then
        object.item = row.item
        applied = applied + 1
      end
    end
    return applied
  end

  function ItemRuntime.capture(game)
    local data = type(game) == "table" and game.data or {}
    local rows = {}
    for mapId, map in pairs(type(data.maps) == "table" and data.maps or {}) do
      for arrayIndex, object in ipairs(
          type(map) == "table" and map.objects or {}) do
        if type(object) == "table" and object.item ~= nil then
          rows[#rows + 1] = {
            kind = "visible", mapId = mapId,
            objectIndex = object.index or arrayIndex, item = object.item,
          }
        end
      end
    end
    local hidden = type(data.field) == "table" and data.field.hiddenItems or {}
    for mapId, objects in pairs(type(hidden) == "table" and hidden or {}) do
      for arrayIndex, object in ipairs(objects or {}) do
        if type(object) == "table" and object.item ~= nil then
          rows[#rows + 1] = {
            kind = "hidden", mapId = mapId, hiddenIndex = arrayIndex,
            x = object.x, y = object.y, item = object.item,
          }
        end
      end
    end
    baseline = rows
    return #rows
  end

  function ItemRuntime.restore(game)
    if not baseline then ItemRuntime.capture(game) end
    return project(game, baseline)
  end

  function ItemRuntime.apply(game, run)
    ItemRuntime.restore(game)
    local mappings = type(run) == "table" and run.mappings
    local rows = type(mappings) == "table" and mappings.fieldItems
    return type(rows) == "table" and project(game, rows, true) or 0
  end

  -- The player's starting PC contents belong to the save rather than the
  -- merged content tables.  Apply these rows exactly once, while the New
  -- Game save is being created; loading and battle repair must never replace
  -- items the player later deposits or withdraws.
  function ItemRuntime.initializeSave(save, run)
    local pc = type(save) == "table" and save.pcItems
    local mappings = type(run) == "table" and run.mappings
    local rows = type(mappings) == "table" and mappings.fieldItems
    if type(pc) ~= "table" or type(rows) ~= "table" then return 0 end
    local applied = 0
    for _, row in ipairs(rows) do
      if row.kind == "pc" and type(row.original) == "string"
          and type(row.item) == "string" and type(row.quantity) == "number"
          and row.quantity > 0 and row.quantity % 1 == 0
          and (pc[row.original] or 0) >= row.quantity then
        pc[row.original] = pc[row.original] - row.quantity
        if pc[row.original] == 0 then pc[row.original] = nil end
        pc[row.item] = (pc[row.item] or 0) + row.quantity
        applied = applied + 1
      end
    end
    return applied
  end

  -- A battle temporarily replaces the overworld state.  Some renderer/NPC
  -- combinations can return without the live item-ball actors even though
  -- their save flags still say they are uncollected.  Restrict the repair to
  -- maps that actually contain an outstanding randomized visible item.
  function ItemRuntime.needsMapRefresh(run, save, mapId)
    if type(mapId) ~= "string" or mapId == "" then return false end
    local mappings = type(run) == "table" and run.mappings
    local rows = type(mappings) == "table" and mappings.fieldItems
    local taken = type(save) == "table" and save.itemsTaken or nil
    for _, row in ipairs(type(rows) == "table" and rows or {}) do
      if row.kind == "visible" and row.mapId == mapId
          and type(row.objectIndex) == "number"
          and not (type(taken) == "table"
            and taken[mapId .. "_obj_" .. row.objectIndex]) then
        return true
      end
    end
    return false
  end

  function ItemRuntime.afterBattle(game, run, world)
    local applied = ItemRuntime.apply(game, run)
    local current = type(world) == "table" and type(world.current) == "function"
      and world:current() or nil
    if type(current) == "table"
        and ItemRuntime.needsMapRefresh(run,
          type(game) == "table" and game.save, current.mapId)
        and type(world.invalidateMap) == "function" then
      world:invalidateMap(current.mapId)
      return applied, true
    end
    return applied, false
  end

  return ItemRuntime
end
