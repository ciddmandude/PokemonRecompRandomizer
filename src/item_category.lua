-- Deterministic item-location and shop randomization. Location modes control
-- pool scope; progression safety is an independent post-generation policy.
return function(StableSort, Progression, ItemFilter)
  local ItemCategory = {}

  local BADGES = {
    BOULDERBADGE = true, CASCADEBADGE = true, THUNDERBADGE = true,
    RAINBOWBADGE = true, SOULBADGE = true, MARSHBADGE = true,
    VOLCANOBADGE = true, EARTHBADGE = true,
  }
  local OPTIONAL_SOURCES = { dome_fossil = true, helix_fossil = true }

  local LEGACY_MODES = {
    non_key = { off = "vanilla", on = "shuffled" },
    tm = { off = "vanilla", on = "shuffled" },
    hm = { off = "vanilla", safe = "shuffled", full_random = "shuffled" },
    key = { off = "vanilla", safe = "shuffled", full_random = "shuffled" },
    badge = { random = "mixed" },
  }
  local SETTING_KEYS = {
    non_key = "non_key_items", tm = "tms", hm = "hms",
    key = "key_items", badge = "badges",
  }

  local function category(itemId, items)
    if BADGES[itemId] then return "badge" end
    local definition = type(items) == "table" and items[itemId]
    if type(definition) ~= "table" then return nil end
    if ItemFilter and not ItemFilter.isUsable(itemId, definition) then return nil end
    local machine = definition.machine
    if type(machine) == "table" and machine.kind == "HM" then return "hm" end
    if type(machine) == "table" and machine.kind == "TM" then return "tm" end
    if definition.keyItem == true then return "key" end
    return "non_key"
  end

  local function mode(kind, settings)
    local value = settings[SETTING_KEYS[kind]]
    return (LEGACY_MODES[kind] and LEGACY_MODES[kind][value])
      or value or "vanilla"
  end

  local function hiddenMode(settings)
    return settings.hidden_items or "vanilla"
  end

  local function safetyOn(settings)
    -- Preserve direct callers and old presets that still carry per-category
    -- SAFE even though the UI now exposes one global progression policy.
    return settings.ensure_beatable == "on"
      or settings.hms == "safe" or settings.key_items == "safe"
  end

  local function collectRows(sources)
    local items, rows = sources.items or {}, {}
    local function add(row)
      local kind = category(row.original, items)
      if kind then row.category = kind; rows[#rows + 1] = row end
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

  local function rowKey(row)
    return table.concat({ row.kind or "", row.mapId or "", row.id or "",
      tostring(row.objectIndex or ""), tostring(row.hiddenIndex or "") }, "\0")
  end

  local function copyRow(row)
    local output = {}
    for key, value in pairs(row) do output[key] = value end
    return output
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
      BOULDERBADGE = S.PEWTER, CASCADEBADGE = S.CERULEAN,
      THUNDERBADGE = S.LATE_STORY or S.VICTORY_ROAD,
      RAINBOWBADGE = S.LATE_STORY or S.VICTORY_ROAD,
      SOULBADGE = S.FUCHSIA,
      MARSHBADGE = S.LATE_STORY or S.VICTORY_ROAD,
      VOLCANOBADGE = S.LATE_STORY or S.VICTORY_ROAD,
      EARTHBADGE = S.LATE_STORY or S.VICTORY_ROAD,
    }
    return required[itemId] or fallback
  end

  local function assignItems(items, destinations, rng, version, constrained)
    local pending, available = {}, {}
    for _, item in ipairs(items) do
      pending[#pending + 1] = {
        id = item,
        required = requiredStage(item, Progression.STAGES.VICTORY_ROAD),
        tie = rng:nextU32(),
      }
    end
    table.sort(pending, function(a, b)
      if constrained and a.required ~= b.required then return a.required < b.required end
      return a.tie < b.tie
    end)
    for _, row in ipairs(destinations) do
      available[#available + 1] = { row = row, stage = stage(row, version) }
    end
    local output = {}
    for _, item in ipairs(pending) do
      local choices, nonmatching = {}, {}
      for index, destination in ipairs(available) do
        if not constrained or destination.stage <= item.required then
          choices[#choices + 1] = index
          if destination.row.original ~= item.id then
            nonmatching[#nonmatching + 1] = index
          end
        end
      end
      if #choices == 0 then return nil end
      if #nonmatching > 0 then choices = nonmatching end
      local selected = choices[rng:nextInt(1, #choices)]
      local destination = table.remove(available, selected)
      local row = copyRow(destination.row)
      row.item = item.id
      output[#output + 1] = row
    end
    return output
  end

  local function closedShuffle(rows, rng, version, constrained)
    local items = {}
    for _, row in ipairs(rows) do items[#items + 1] = row.original end
    if not constrained then
      local best, bestFixed
      local attempts = math.max(8, math.min(64, #rows * 2))
      for _ = 1, attempts do
        local candidate = rng:shuffle(items)
        local fixed = 0
        for index, source in ipairs(rows) do
          if candidate[index] == source.original then fixed = fixed + 1 end
        end
        if bestFixed == nil or fixed < bestFixed then
          best, bestFixed = candidate, fixed
        end
        if fixed == 0 then break end
      end
      items = best or items
      local output = {}
      for index, source in ipairs(rows) do
        local row = copyRow(source)
        row.item = items[index]
        output[#output + 1] = row
      end
      return output
    end
    local best, bestFixed
    local attempts = math.max(8, math.min(64, #rows * 2))
    for _ = 1, attempts do
      local candidate = assignItems(items, rows, rng, version, constrained)
      if candidate then
        local fixed = 0
        for _, row in ipairs(candidate) do
          if row.item == row.original then fixed = fixed + 1 end
        end
        if bestFixed == nil or fixed < bestFixed then
          best, bestFixed = candidate, fixed
        end
        if fixed == 0 then break end
      end
    end
    return best
  end

  local function supportedMixedDestination(row, version, constrained, hidden)
    if row.kind == "shop" then return false end
    if row.kind == "hidden" and hidden ~= "mixed" then return false end
    if row.kind == "scripted" and OPTIONAL_SOURCES[row.id] then return false end
    if not constrained then return true end
    local access = Progression.access(row.mapId, "walk", nil, version)
    return access.available and not access.postgame
  end

  local function mixedPlacements(rows, consumed, settings, rng, version)
    local sources, sourceSet, pool = {}, {}, {}
    local hidden = hiddenMode(settings)
    for _, row in ipairs(rows) do
      if not consumed[rowKey(row)] and (mode(row.category, settings) == "mixed"
          or row.kind == "hidden" and hidden == "mixed") then
        sources[#sources + 1] = row
        sourceSet[rowKey(row)] = true
      end
    end
    if #sources == 0 then return {}, {}, {} end
    local constrained = safetyOn(settings)
    for _, row in ipairs(rows) do
      local key = rowKey(row)
      if not consumed[key]
          and not (row.kind == "scripted" and OPTIONAL_SOURCES[row.id])
          and supportedMixedDestination(
            row, version, constrained, hidden)
          and (sourceSet[key]
            or row.category == "non_key") then
        pool[#pool + 1] = row
      end
    end
    local placements = closedShuffle(pool, rng, version, constrained)
    if not placements then
      return {}, {}, {{
        code = "MIXED_BEATABILITY_FALLBACK",
        message = "the mixed item pool could not be proven beatable and remains vanilla",
      }}
    end
    local used = {}
    for _, row in ipairs(pool) do used[rowKey(row)] = true end
    return placements, used, {}
  end

  local function shopRows(sources, settings, rng)
    if settings.shops ~= "randomized" and settings.shops ~= "on" then return {} end
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
      if kind == "non_key"
          or kind == "tm" and mode("tm", settings) ~= "vanilla"
          or kind == "key"
            and (mode("key", settings) == "mixed"
              or settings.key_items == "full_random")
            and shoppableKeys[itemId] then
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
    local function addShop(mapId, pointerId, talkKey, slot, original)
      local item = candidates[cursor]
      cursor = cursor % #candidates + 1
      rows[#rows + 1] = { kind = "shop", mapId = mapId,
        pointerId = pointerId, talkKey = talkKey, slot = slot,
        original = original, item = item, price = selectedPrice(item),
        category = category(item, sources.items) }
    end
    for _, pointerId in ipairs(StableSort.keys(sources.textPointers or {})) do
      local pointer = sources.textPointers[pointerId]
      for _, talkKey in ipairs(StableSort.keys(pointer or {})) do
        local mart = type(pointer[talkKey]) == "table" and pointer[talkKey].mart
        for slot, original in ipairs(type(mart) == "table" and mart or {}) do
          addShop(mapIdsByLabel[pointerId] or pointerId,
            pointerId, talkKey, slot, original)
        end
      end
    end
    for _, special in ipairs({
      { "CELADON_MART_ROOF", "vending",
        { "FRESH_WATER", "SODA_POP", "LEMONADE" } },
      { "GAME_CORNER_PRIZE_ROOM", "prize_tms",
        { "TM_DRAGON_RAGE", "TM_HYPER_BEAM", "TM_SUBSTITUTE" } },
    }) do
      for slot, original in ipairs(special[3]) do
        addShop(special[1], nil, special[2], slot, original)
      end
    end
    return rows
  end

  function ItemCategory.generate(sources, settings, rng)
    assert(type(rng) == "table" and type(rng.shuffle) == "function",
      "item RNG is required")
    sources, settings = sources or {}, settings or {}
    local version = sources.gameVersion or sources.version or "red"
    local rows, placements, warnings, consumed = collectRows(sources), {}, {}, {}
    local constrained, hidden = safetyOn(settings), hiddenMode(settings)

    local hiddenRows = {}
    for _, row in ipairs(rows) do
      if row.kind == "hidden" then hiddenRows[#hiddenRows + 1] = row end
    end
    if hidden == "vanilla" or hidden == "shuffled" then
      if hidden == "shuffled" then
        local shuffled = closedShuffle(hiddenRows, rng, version, constrained)
        if shuffled then
          for _, row in ipairs(shuffled) do placements[#placements + 1] = row end
        else
          warnings[#warnings + 1] = {
            code = "HIDDEN_ITEM_FALLBACK",
            message = "hidden items could not be proven beatable and remain vanilla",
          }
        end
      end
      for _, row in ipairs(hiddenRows) do consumed[rowKey(row)] = true end
    end

    local mixed, mixedUsed, mixedWarnings = mixedPlacements(
      rows, consumed, settings, rng, version)
    for _, row in ipairs(mixed) do placements[#placements + 1] = row end
    for key in pairs(mixedUsed) do consumed[key] = true end
    for _, warning in ipairs(mixedWarnings) do warnings[#warnings + 1] = warning end

    for _, kind in ipairs({ "non_key", "tm", "hm", "key", "badge" }) do
      if mode(kind, settings) == "shuffled" then
        local categoryRows = {}
        for _, row in ipairs(rows) do
          if row.category == kind and not consumed[rowKey(row)] then
            categoryRows[#categoryRows + 1] = row
          end
        end
        local shuffled = closedShuffle(categoryRows, rng, version,
          constrained and (kind == "hm" or kind == "key" or kind == "badge"))
        if shuffled then
          for _, row in ipairs(shuffled) do placements[#placements + 1] = row end
        else
          warnings[#warnings + 1] = {
            code = "PROGRESSION_ITEM_FALLBACK",
            message = kind:upper()
              .. " locations could not be proven beatable and remain vanilla",
          }
        end
      end
    end
    for _, row in ipairs(shopRows(sources, settings, rng)) do
      placements[#placements + 1] = row
    end
    return { placements = placements, warnings = warnings,
      fallbackCount = #warnings }
  end

  ItemCategory.category = category
  ItemCategory.mode = mode
  return ItemCategory
end
