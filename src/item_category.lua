-- Deterministic, progression-safe non-key field-item shuffling.
return function(StableSort)
  local ItemCategory = {}

  local function eligible(itemId, items)
    if type(itemId) ~= "string" or itemId == "" or itemId == "0" then
      return false
    end
    local definition = type(items) == "table" and items[itemId]
    return type(definition) == "table" and definition.keyItem ~= true
  end

  function ItemCategory.generate(sources, settings, rng)
    if type(settings) ~= "table" or settings.field_items ~= "shuffled" then
      return { placements = {}, warnings = {}, fallbackCount = 0 }
    end
    assert(type(rng) == "table" and type(rng.shuffle) == "function",
      "field-item RNG is required")
    sources = sources or {}
    local items, placements = sources.items or {}, {}
    for _, mapId in ipairs(StableSort.keys(sources.maps or {})) do
      local map = sources.maps[mapId]
      for arrayIndex, object in ipairs(
          type(map) == "table" and map.objects or {}) do
        if type(object) == "table" and eligible(object.item, items) then
          placements[#placements + 1] = {
            kind = "visible", mapId = mapId,
            objectIndex = object.index or arrayIndex,
            original = object.item,
          }
        end
      end
    end
    local hidden = type(sources.field) == "table"
      and sources.field.hiddenItems or {}
    for _, mapId in ipairs(StableSort.keys(hidden or {})) do
      for arrayIndex, object in ipairs(hidden[mapId] or {}) do
        if type(object) == "table" and eligible(object.item, items) then
          placements[#placements + 1] = {
            kind = "hidden", mapId = mapId, hiddenIndex = arrayIndex,
            x = object.x, y = object.y, original = object.item,
          }
        end
      end
    end
    for _, itemId in ipairs(StableSort.keys(sources.startingPcItems or {})) do
      local quantity = sources.startingPcItems[itemId]
      if type(quantity) == "number" and quantity > 0
          and quantity % 1 == 0 and eligible(itemId, items) then
        placements[#placements + 1] = {
          kind = "pc", mapId = "REDS_HOUSE_2F",
          original = itemId, quantity = quantity,
        }
      end
    end
    local shuffled = {}
    for index, row in ipairs(placements) do shuffled[index] = row.original end
    shuffled = rng:shuffle(shuffled)
    for index, row in ipairs(placements) do row.item = shuffled[index] end
    return { placements = placements, warnings = {}, fallbackCount = 0 }
  end

  return ItemCategory
end
