-- Projects saved item placements into live merged data and restores the
-- post-mod baseline when saves are switched in one application session.
return function(ItemSourceCatalog)
  local ItemRuntime, baseline, priceBaseline = {}, nil, nil

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
      elseif row.kind == "shop" and row.talkKey ~= "vending"
          and row.talkKey ~= "prize_tms" then
        local pointer = type(data.text_pointers) == "table"
          and data.text_pointers[row.pointerId or row.mapId]
        local talk = type(pointer) == "table" and pointer[row.talkKey]
        if type(talk) == "table" and type(talk.mart) == "table"
            and talk.mart[row.slot] ~= nil then
          object = { item = talk.mart[row.slot], shop = talk.mart }
        end
      end
      local definition = type(data.items) == "table" and data.items[row.item]
      local valid = not validateMapping or (
        type(definition) == "table" and object and object.item == row.original)
      if object and type(row.item) == "string" and valid then
        if object.shop then object.shop[row.slot] = row.item
        else object.item = row.item end
        if row.kind == "shop" and type(row.price) == "number"
            and type(definition) == "table" then definition.price = row.price end
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
    for mapId, pointer in pairs(type(data.text_pointers) == "table"
        and data.text_pointers or {}) do
      for talkKey, talk in pairs(type(pointer) == "table" and pointer or {}) do
        for slot, item in ipairs(type(talk) == "table" and talk.mart or {}) do
          rows[#rows + 1] = { kind = "shop", mapId = mapId,
            talkKey = talkKey, slot = slot, item = item }
        end
      end
    end
    priceBaseline = {}
    for itemId, definition in pairs(type(data.items) == "table"
        and data.items or {}) do
      if type(definition) == "table" then priceBaseline[itemId] = definition.price end
    end
    baseline = rows
    return #rows
  end

  function ItemRuntime.restore(game)
    if not baseline then ItemRuntime.capture(game) end
    local restored = project(game, baseline)
    local items = type(game) == "table" and type(game.data) == "table"
      and game.data.items or {}
    for itemId, price in pairs(priceBaseline or {}) do
      if type(items[itemId]) == "table" then items[itemId].price = price end
    end
    return restored
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
          and row.item ~= row.original
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

  local function scriptedMapping(run, itemId, mapId)
    local rows = type(run) == "table" and type(run.mappings) == "table"
      and run.mappings.fieldItems or {}
    local fallback
    for _, row in ipairs(type(rows) == "table" and rows or {}) do
      if row.kind == "scripted" and row.original == itemId then
        if row.mapId == mapId then return row.item end
        fallback = fallback or row.item
      end
    end
    return fallback
  end

  local function specialShopRows(run, mapId, talkKey)
    local output = {}
    local rows = type(run) == "table" and type(run.mappings) == "table"
      and run.mappings.fieldItems or {}
    for _, row in ipairs(type(rows) == "table" and rows or {}) do
      if row.kind == "shop" and row.mapId == mapId
          and row.talkKey == talkKey then output[row.slot] = row end
    end
    return output
  end

  local function replaceClaim(game, run, source)
    local flags, inventory = game.save.flags or {}, game.save.inventory or {}
    game.save.flags, game.save.inventory = flags, inventory
    local claim = "MOD_RANDOMIZER_ITEM_" .. source.id
    if not flags[source.flag] or flags[claim] then return false end
    local replacement = scriptedMapping(run, source.item, source.mapId)
    if not replacement then return false end
    if replacement ~= source.item
        and (inventory[source.item] or 0) > 0 then
      inventory[source.item] = inventory[source.item] - 1
      if inventory[source.item] == 0 then inventory[source.item] = nil end
      inventory[replacement] = (inventory[replacement] or 0) + 1
    end
    flags[claim] = true
    return true
  end

  function ItemRuntime.prepareBattleRewards(event, run)
    local battle = type(event) == "table" and event.battle
    if type(battle) ~= "table" or type(battle.onFinish) ~= "function" then return false end
    local original = battle.onFinish
    battle.onFinish = function(...)
      local result = original(...)
      if type(battle.game) == "table" then
        for _, source in ipairs(ItemSourceCatalog or {}) do
          if source.battle then replaceClaim(battle.game, run, source) end
        end
      end
      return result
    end
    return true
  end

  function ItemRuntime.install(mod, activeRun)
    local commands = mod.content.commands
    local baseGive = commands:get("give_item")
    if baseGive and type(commands.override) == "function" then
      commands:override("give_item", function(ctx, itemId, count, gotText)
        local mapId = ctx.overworld and ctx.overworld.map
          and ctx.overworld.map.id or nil
        local replacement = scriptedMapping(activeRun(), itemId, mapId)
        return baseGive(ctx, replacement or itemId, count, gotText)
      end)
    end

    local directByMap = {}
    for _, source in ipairs(ItemSourceCatalog or {}) do
      if source.command == false and source.talkKey and source.flag then
        directByMap[source.mapId] = directByMap[source.mapId] or {}
        local byTalk = directByMap[source.mapId]
        byTalk[source.talkKey] = byTalk[source.talkKey] or {}
        byTalk[source.talkKey][#byTalk[source.talkKey] + 1] = source
      end
    end
    local mapRegistry = mod.content.map_scripts
    if type(mapRegistry.get) == "function" then
      for mapId, talks in pairs(directByMap) do
        local baseMap = mapRegistry:get(mapId)
        local contribution = { priority = 120, talk = {} }
        for talkKey, sources in pairs(talks) do
          local wrappedSources = sources
          local original = type(baseMap) == "table" and type(baseMap.talk) == "table"
            and baseMap.talk[talkKey]
          if type(original) == "function" then
            local wrappedOriginal = original
            contribution.talk[talkKey] = function(game, overworld, npc, done)
              wrappedOriginal(game, overworld, npc, function(...)
                for _, source in ipairs(wrappedSources) do
                  replaceClaim(game, activeRun(), source)
                end
                done(...)
              end)
            end
          end
        end
        if next(contribution.talk) then mapRegistry:register(mapId, contribution) end
      end
    end

    local vanilla = {
      { item = "FRESH_WATER", price = 200 },
      { item = "SODA_POP", price = 300 },
      { item = "LEMONADE", price = 350 },
    }
    local roof = type(mapRegistry.get) == "function"
      and mapRegistry:get("CELADON_MART_ROOF") or nil
    local roofTalk = type(roof) == "table" and roof.talk or nil
    local baseVending = type(roofTalk) == "table"
      and roofTalk.TEXT_CELADONMARTROOF_VENDING_MACHINE1 or nil
    local function vending(game, overworld, npc, done)
      local Bag = require("src.inventory.Bag")
      local mapped = specialShopRows(activeRun(), "CELADON_MART_ROOF", "vending")
      if next(mapped) == nil and type(baseVending) == "function" then
        return baseVending(game, overworld, npc, done)
      end
      local entries = {}
      for slot, source in ipairs(vanilla) do
        local row = mapped[slot]
        local itemId = row and row.item or source.item
        local definition = game.data.items[itemId]
        local price = row and row.price or source.price
        entries[#entries + 1] = { value = { item = itemId, price = price },
          label = ("%s Y%d"):format(definition and definition.name or itemId, price) }
      end
      local list
      list = mod.ui.ListMenu.new(game, "VENDING MACHINE", entries, {
        onChoose = function(entry)
          local value = entry.value
          if (game.save.money or 0) < value.price then
            list.footer = "Not enough money!"
            return
          end
          if not Bag.add(game.save, value.item, 1, game.data) then
            list.footer = "No room in BAG!"
            return
          end
          game.save.money = game.save.money - value.price
          list.footer = "Item purchased!"
        end,
        onCancel = done,
      })
      game.stack:push(list)
    end
    mod.content.map_scripts:register("CELADON_MART_ROOF", {
      priority = 110,
      talk = {
        TEXT_CELADONMARTROOF_VENDING_MACHINE1 = vending,
        TEXT_CELADONMARTROOF_VENDING_MACHINE2 = vending,
        TEXT_CELADONMARTROOF_VENDING_MACHINE3 = vending,
      },
    })
  end

  ItemRuntime.scriptedMapping = scriptedMapping
  ItemRuntime.specialShopRows = specialShopRows

  return ItemRuntime
end
