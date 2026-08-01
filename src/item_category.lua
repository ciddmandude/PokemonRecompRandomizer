-- Deterministic item-location and shop randomization. Each enabled field
-- category is a closed shuffle, so no item is created or lost.
return function(StableSort, Progression)
  local ItemCategory = {}

  local BADGES = {
    BOULDERBADGE = true, CASCADEBADGE = true, THUNDERBADGE = true,
    RAINBOWBADGE = true, SOULBADGE = true, MARSHBADGE = true,
    VOLCANOBADGE = true, EARTHBADGE = true,
  }

  local OPTIONAL_SOURCES = {
    dome_fossil = true,
    helix_fossil = true,
  }

  local function category(itemId, items)
    if BADGES[itemId] then return "badge" end
    local definition = type(items) == "table" and items[itemId]
    if type(definition) ~= "table" then return nil end
    local machine = definition.machine
    if type(machine) == "table" and machine.kind == "HM" then return "hm" end
    if type(machine) == "table" and machine.kind == "TM" then return "tm" end
    if definition.keyItem == true then return "key" end
    return "non_key"
  end

  local function enabled(kind, settings)
    if kind == "non_key" then return settings.non_key_items == "on" end
    if kind == "tm" then return settings.tms == "on" end
    if kind == "hm" then return settings.hms ~= nil and settings.hms ~= "off" end
    if kind == "key" then
      return settings.key_items ~= nil and settings.key_items ~= "off"
    end
    if kind == "badge" then
      return settings.badges ~= nil and settings.badges ~= "vanilla"
    end
    return false
  end

  local function collectFieldRows(sources)
    local items = sources.items or {}
    local rows = {}
    local function add(row)
      local kind = category(row.original, items)
      if kind then
        row.category = kind
        rows[#rows + 1] = row
      end
    end
    for _, mapId in ipairs(StableSort.keys(sources.maps or {})) do
      local map = sources.maps[mapId]
      for arrayIndex, object in ipairs(type(map) == "table" and map.objects or {}) do
        if type(object) == "table" and type(object.item) == "string" then
          add({ kind = "visible", mapId = mapId,
            objectIndex = object.index or arrayIndex, original = object.item })
        end
      end
    end
    local hidden = type(sources.field) == "table" and sources.field.hiddenItems or {}
    for _, mapId in ipairs(StableSort.keys(hidden or {})) do
      for arrayIndex, object in ipairs(hidden[mapId] or {}) do
        if type(object) == "table" and type(object.item) == "string" then
          add({ kind = "hidden", mapId = mapId, hiddenIndex = arrayIndex,
            x = object.x, y = object.y, original = object.item })
        end
      end
    end
    for _, itemId in ipairs(StableSort.keys(sources.startingPcItems or {})) do
      local quantity = sources.startingPcItems[itemId]
      if type(quantity) == "number" and quantity > 0 and quantity % 1 == 0 then
        add({ kind = "pc", mapId = "REDS_HOUSE_2F",
          original = itemId, quantity = quantity })
      end
    end
    for _, source in ipairs(sources.scriptedItems or {}) do
      if type(source) == "table" and type(source.item) == "string"
          and type(source.id) == "string" and type(source.mapId) == "string" then
        add({ kind = "scripted", id = source.id, mapId = source.mapId,
          original = source.item, requiredStage = source.requiredStage,
          command = source.command ~= false, flag = source.flag,
          talkKey = source.talkKey, battle = source.battle == true,
          badge = source.badge == true })
      end
    end
    return rows
  end

  local function stage(row, version)
    local access = Progression.access(row.mapId, "walk", nil, version)
    return access.available and access.stage or Progression.STAGES.POSTGAME
  end

  local function requiredStage(itemId, fallback)
    local S = Progression.STAGES
    local required = {
      OAKS_PARCEL = S.START, S_S_TICKET = S.CERULEAN,
      HM_CUT = S.VERMILION, POKE_FLUTE = S.LAVENDER_CELADON,
      SILPH_SCOPE = S.LAVENDER_CELADON, LIFT_KEY = S.LAVENDER_CELADON,
      HM_SURF = S.FUCHSIA, GOLD_TEETH = S.FUCHSIA,
      HM_STRENGTH = S.VICTORY_ROAD, CARD_KEY = S.SAFFRON,
      SECRET_KEY = S.SURF,
      BOULDERBADGE = S.PEWTER,
      CASCADEBADGE = S.CERULEAN,
      THUNDERBADGE = S.LATE_STORY or S.VICTORY_ROAD,
      RAINBOWBADGE = S.LATE_STORY or S.VICTORY_ROAD,
      SOULBADGE = S.FUCHSIA,
      MARSHBADGE = S.LATE_STORY or S.VICTORY_ROAD,
      VOLCANOBADGE = S.LATE_STORY or S.VICTORY_ROAD,
      EARTHBADGE = S.LATE_STORY or S.VICTORY_ROAD,
    }
    return required[itemId] or fallback
  end

  local function rowKey(row)
    return table.concat({ row.kind or "", row.mapId or "", row.id or "",
      tostring(row.objectIndex or ""), tostring(row.hiddenIndex or "") }, "\0")
  end

  local function copyRow(row)
    local output = {}
    for key, value in pairs(row) do output[key] = value end
    return output
  end

  local function badgeCandidate(row, version, allowPostgame)
    if row.kind == "shop" then return false end
    if row.kind == "scripted" and OPTIONAL_SOURCES[row.id] then return false end
    local access = Progression.access(row.mapId, "walk", nil, version)
    return access.available and (allowPostgame or not access.postgame)
  end

  local function assignItems(items, destinations, rng, version, constrained)
    local pending = {}
    for _, item in ipairs(items) do
      pending[#pending + 1] = {
        id = item,
        required = requiredStage(item, Progression.STAGES.VICTORY_ROAD),
        tie = rng:nextU32(),
      }
    end
    table.sort(pending, function(a, b)
      if constrained and a.required ~= b.required then
        return a.required < b.required
      end
      return a.tie < b.tie
    end)
    local available = {}
    for _, row in ipairs(destinations) do
      available[#available + 1] = {
        row = row, stage = stage(row, version), tie = rng:nextU32(),
      }
    end
    local output = {}
    for _, item in ipairs(pending) do
      local choices = {}
      for index, destination in ipairs(available) do
        if not constrained or destination.stage <= item.required then
          choices[#choices + 1] = index
        end
      end
      if #choices == 0 then return nil end
      local selected = choices[rng:nextInt(1, #choices)]
      local destination = table.remove(available, selected)
      local row = copyRow(destination.row)
      row.item = item.id
      output[#output + 1] = row
    end
    return output
  end

  local function badgePlacements(rows, settings, rng, version)
    local badges, candidates = {}, {}
    for _, row in ipairs(rows) do
      if row.category == "badge" then
        badges[#badges + 1] = row
      elseif badgeCandidate(row, version,
          settings.ensure_beatable ~= "on") then
        candidates[#candidates + 1] = row
      end
    end
    if settings.badges == nil or settings.badges == "vanilla"
        or #badges == 0 then return {}, {} end

    local consumed, warnings = {}, {}
    if settings.badges == "shuffled" then
      local items = {}
      for _, row in ipairs(badges) do
        items[#items + 1] = row.original
        consumed[rowKey(row)] = true
      end
      local placements = assignItems(items, badges, rng, version,
        settings.ensure_beatable == "on")
      if not placements then
        warnings[#warnings + 1] = {
          code = "BADGE_BEATABILITY_FALLBACK",
          message = "no provably beatable badge shuffle was found; badges are vanilla",
        }
        return {}, {}, warnings
      end
      return placements, consumed, warnings
    end

    candidates = rng:shuffle(candidates)
    if #candidates < #badges then
      warnings[#warnings + 1] = {
        code = "BADGE_LOCATION_SHORTAGE",
        message = "fewer than eight supported one-time item locations were available",
      }
      return {}, {}, warnings
    end

    local selected, badgeItems = {}, {}
    if settings.ensure_beatable == "on" then
      local ordered = {}
      for _, row in ipairs(badges) do
        ordered[#ordered + 1] = { row = row,
          required = requiredStage(row.original, Progression.STAGES.VICTORY_ROAD),
          tie = rng:nextU32() }
      end
      table.sort(ordered, function(a, b)
        return a.required == b.required and a.tie < b.tie
          or a.required < b.required
      end)
      local remaining = {}
      for index, row in ipairs(candidates) do remaining[index] = row end
      for _, badge in ipairs(ordered) do
        local choices = {}
        for index, row in ipairs(remaining) do
          if stage(row, version) <= badge.required then choices[#choices + 1] = index end
        end
        if #choices == 0 then
          warnings[#warnings + 1] = {
            code = "BADGE_BEATABILITY_FALLBACK",
            message = "no provably beatable random badge placement was found; badges are vanilla",
          }
          return {}, {}, warnings
        end
        local choice = choices[rng:nextInt(1, #choices)]
        local destination = table.remove(remaining, choice)
        selected[#selected + 1] = destination
        badgeItems[#badgeItems + 1] = badge.row.original
      end
    else
      for index = 1, #badges do selected[index] = candidates[index] end
      for _, row in ipairs(badges) do badgeItems[#badgeItems + 1] = row.original end
      badgeItems = rng:shuffle(badgeItems)
    end

    local placements = {}
    for index, destination in ipairs(selected) do
      local row = copyRow(destination)
      row.item = badgeItems[index]
      placements[#placements + 1] = row
      consumed[rowKey(destination)] = true
    end
    local displaced = {}
    for _, destination in ipairs(selected) do displaced[#displaced + 1] = destination.original end
    local returns = assignItems(displaced, badges, rng, version,
      settings.ensure_beatable == "on")
    if not returns then
      warnings[#warnings + 1] = {
        code = "BADGE_BEATABILITY_FALLBACK",
        message = "displaced progression items could not be placed safely; badges are vanilla",
      }
      return {}, {}, warnings
    end
    for _, row in ipairs(returns) do placements[#placements + 1] = row end
    for _, row in ipairs(badges) do consumed[rowKey(row)] = true end
    return placements, consumed, warnings
  end

  local function shuffleCategory(rows, mode, rng, version)
    local output = {}
    if mode ~= "safe" then
      local items = {}
      for index, row in ipairs(rows) do items[index] = row.original end
      items = rng:shuffle(items)
      for index, row in ipairs(rows) do row.item = items[index]; output[#output + 1] = row end
      return output
    end

    -- Earliest-required items are placed first. Choosing the latest eligible
    -- remaining location preserves earlier locations for other constrained
    -- progression items and is deterministic.
    local pending, destinations = {}, {}
    for index, row in ipairs(rows) do
      pending[index] = { item = row.original,
        required = row.requiredStage
          or requiredStage(row.original, stage(row, version)),
        tie = rng:nextU32() }
      destinations[index] = { row = row, available = stage(row, version),
        tie = rng:nextU32() }
    end
    table.sort(pending, function(a, b)
      return a.required == b.required and a.tie < b.tie or a.required < b.required
    end)
    for _, item in ipairs(pending) do
      local best
      for index, destination in ipairs(destinations) do
        if destination.available <= item.required and (not best
            or destination.available > destinations[best].available
            or (destination.available == destinations[best].available
              and destination.tie < destinations[best].tie)) then best = index end
      end
      if not best then return nil end
      local destination = table.remove(destinations, best)
      destination.row.item = item.item
      output[#output + 1] = destination.row
    end
    return output
  end

  local function shopRows(sources, settings, rng)
    if settings.shops ~= "on" then return {} end
    local candidates = {}
    local shoppableKeys = {
      BICYCLE = true, BIKE_VOUCHER = true, CARD_KEY = true,
      COIN_CASE = true, DOME_FOSSIL = true, EXP_ALL = true,
      GOLD_TEETH = true, GOOD_ROD = true, HELIX_FOSSIL = true,
      ITEMFINDER = true, LIFT_KEY = true, OAKS_PARCEL = true,
      OLD_AMBER = true, OLD_ROD = true, POKE_FLUTE = true,
      SECRET_KEY = true, SILPH_SCOPE = true, SUPER_ROD = true,
      S_S_TICKET = true, TOWN_MAP = true,
    }
    for _, itemId in ipairs(StableSort.keys(sources.items or {})) do
      local kind = category(itemId, sources.items)
      if kind == "non_key" or (kind == "tm" and settings.tms == "on")
          or (kind == "key" and settings.key_items == "full_random"
            and shoppableKeys[itemId]) then
        candidates[#candidates + 1] = itemId
      end
    end
    if #candidates == 0 then return {} end
    candidates = rng:shuffle(candidates)
    local rows, cursor, prices, mapIdsByLabel = {}, 1, {}, {}
    for mapId, map in pairs(sources.maps or {}) do
      if type(map) == "table" and type(map.label) == "string" then
        mapIdsByLabel[map.label] = mapId
      end
    end
    local function selectedPrice(item)
      if settings.shop_prices == "cheap" then return 100 end
      if settings.shop_prices == "random" then
        if not prices[item] then prices[item] = rng:nextInt(1, 50) * 100 end
        return prices[item]
      end
    end
    for _, pointerId in ipairs(StableSort.keys(sources.textPointers or {})) do
      local pointer = sources.textPointers[pointerId]
      for _, talkKey in ipairs(StableSort.keys(pointer or {})) do
        local mart = type(pointer[talkKey]) == "table" and pointer[talkKey].mart
        for slot, original in ipairs(type(mart) == "table" and mart or {}) do
          local item = candidates[cursor]
          cursor = cursor % #candidates + 1
          rows[#rows + 1] = { kind = "shop",
            mapId = mapIdsByLabel[pointerId] or pointerId,
            pointerId = pointerId,
            talkKey = talkKey, slot = slot, original = original, item = item,
            price = selectedPrice(item), category = category(item, sources.items) }
        end
      end
    end
    for _, special in ipairs({
      { "CELADON_MART_ROOF", "vending", {
        "FRESH_WATER", "SODA_POP", "LEMONADE" } },
      { "GAME_CORNER_PRIZE_ROOM", "prize_tms", {
        "TM_DRAGON_RAGE", "TM_HYPER_BEAM", "TM_SUBSTITUTE" } },
    }) do
      for slot, original in ipairs(special[3]) do
        local item = candidates[cursor]
        cursor = cursor % #candidates + 1
        rows[#rows + 1] = { kind = "shop", mapId = special[1],
          talkKey = special[2], slot = slot, original = original, item = item,
          price = selectedPrice(item), category = category(item, sources.items) }
      end
    end
    return rows
  end

  function ItemCategory.generate(sources, settings, rng)
    assert(type(rng) == "table" and type(rng.shuffle) == "function",
      "item RNG is required")
    sources, settings = sources or {}, settings or {}
    local version = sources.gameVersion or sources.version or "red"
    local rows = collectFieldRows(sources)
    local placements, consumed, warnings = badgePlacements(
      rows, settings, rng, version)
    local rowsByCategory = {
      non_key = {}, tm = {}, hm = {}, key = {}, badge = {},
    }
    for _, row in ipairs(rows) do
      if not consumed[rowKey(row)] and enabled(row.category, settings) then
        rowsByCategory[row.category][#rowsByCategory[row.category] + 1] = row
      end
    end
    for _, kind in ipairs({ "non_key", "tm", "hm", "key" }) do
      local mode = kind == "hm" and settings.hms
        or kind == "key" and settings.key_items or "full_random"
      if settings.ensure_beatable == "on"
          and (kind == "hm" or kind == "key") then mode = "safe" end
      local shuffled = shuffleCategory(rowsByCategory[kind], mode, rng, version)
      if not shuffled then
        warnings = warnings or {}
        warnings[#warnings + 1] = {
          code = "PROGRESSION_ITEM_FALLBACK",
          message = kind:upper()
            .. " items could not be proven beatable and remain vanilla",
        }
      else
        for _, row in ipairs(shuffled) do placements[#placements + 1] = row end
      end
    end
    for _, row in ipairs(shopRows(sources, settings, rng)) do
      placements[#placements + 1] = row
    end
    return {
      placements = placements,
      warnings = warnings or {},
      fallbackCount = #(warnings or {}),
    }
  end

  ItemCategory.category = category
  return ItemCategory
end
