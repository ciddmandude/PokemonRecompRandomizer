-- Pure read-only index for the in-game spoiler browser.
return function(StableSort, StaticGiftCatalog, TradePrizeCatalog)
  local Browser = {}
  local indexCache = { key = nil, value = nil, builds = 0, hits = 0 }

  local DEFAULT_BUCKETS = { 51, 102, 141, 166, 191, 216, 229, 242, 253, 256 }
  local TERRAINS = { "grass", "water" }
  local RODS = { "OLD_ROD", "GOOD_ROD", "SUPER_ROD" }
  local ROD_TABS = {
    OLD_ROD = "old_rod",
    GOOD_ROD = "good_rod",
    SUPER_ROD = "super_rod",
  }
  local TABS = {
    "grass", "surf", "old_rod", "good_rod", "super_rod", "trainers",
    "starters", "statics", "gifts", "trades", "prizes",
    "items",
  }
  local TAB_LABELS = {
    grass = "GRASS", surf = "SURF", old_rod = "OLD ROD",
    good_rod = "GOOD ROD", super_rod = "SUPER ROD",
    trainers = "TRAINERS", starters = "STARTERS", statics = "STATICS",
    gifts = "GIFTS", trades = "TRADES", prizes = "PRIZES",
    items = "ITEMS",
  }
  local STARTERS = {
    { id = "LEFT", source = "CHARMANDER" },
    { id = "MIDDLE", source = "SQUIRTLE" },
    { id = "RIGHT", source = "BULBASAUR" },
  }
  local SCRIPTED_TRAINERS = {
    { mapId = "OAKS_LAB", classId = "OPP_RIVAL1", first = 1, last = 3 },
    { mapId = "ROUTE_22", classId = "OPP_RIVAL1", first = 4, last = 6 },
    { mapId = "CERULEAN_CITY", classId = "OPP_RIVAL1", first = 7, last = 9 },
    { mapId = "SS_ANNE_2F", classId = "OPP_RIVAL2", first = 1, last = 3 },
    { mapId = "POKEMON_TOWER_2F", classId = "OPP_RIVAL2", first = 4, last = 6 },
    { mapId = "SILPH_CO_7F", classId = "OPP_RIVAL2", first = 7, last = 9 },
    { mapId = "ROUTE_22", classId = "OPP_RIVAL2", first = 10, last = 12 },
    { mapId = "CHAMPIONS_ROOM", classId = "OPP_RIVAL3", first = 1, last = 3 },
    { mapId = "ROCKET_HIDEOUT_B4F", classId = "OPP_GIOVANNI",
      first = 1, last = 1 },
    { mapId = "CERULEAN_CITY", classId = "OPP_ROCKET",
      first = 5, last = 5 },
    { mapId = "CELADON_CHIEF_HOUSE", classId = "OPP_CHIEF",
      first = 1, last = 1 },
    { mapId = "PALLET_TOWN", classId = "OPP_PROF_OAK",
      first = 1, last = 3 },
  }

  local SPECIAL_NAMES = {
    FARFETCHD = "Farfetch'd", MR_MIME = "Mr. Mime",
    NIDORAN_F = "Nidoran F", NIDORAN_M = "Nidoran M",
  }

  local function words(id)
    local output = {}
    for token in tostring(id or ""):gmatch("[^_]+") do
      local upper = token:upper()
      if upper == "SS" then
        output[#output + 1] = "S.S."
      elseif upper == "CO" then
        output[#output + 1] = "Co."
      elseif upper:match("^%d+[FB]?$") then
        output[#output + 1] = upper
      else
        output[#output + 1] =
          upper:sub(1, 1) .. upper:sub(2):lower()
      end
    end
    return table.concat(output, " ")
  end

  local function speciesName(id, records)
    if SPECIAL_NAMES[id] then return SPECIAL_NAMES[id] end
    local row = type(records) == "table" and records[id]
    local name = type(row) == "table" and (row.name or row.label)
    return type(name) == "string" and name ~= "" and name or words(id)
  end

  local function mapName(mapId, maps, townLocations)
    if mapId == "*" then return "Any fishable area" end
    local town = type(townLocations) == "table" and townLocations[mapId]
    local map = type(maps) == "table" and maps[mapId]
    local explicit = type(map) == "table" and map.name
    if type(explicit) == "string" and explicit ~= "" then return explicit end
    if type(town) == "table" and type(town.name or town.label) == "string"
        and tostring(town.name or town.label) ~= "" then
      local townName = tostring(town.name or town.label)
      if mapId:find("_", 1, true) then return words(mapId) end
      return townName
    end
    return words(mapId)
  end

  local function copyArray(source)
    local output = {}
    for index, value in ipairs(source or {}) do output[index] = value end
    return output
  end

  local function townLocations(field)
    local town = type(field) == "table" and field.townMap
    if type(town) == "table" and type(town.locations) == "table" then
      return town.locations, town
    end
    return type(town) == "table" and town or {}, type(town) == "table" and town
      or {}
  end

  local function coords(entry)
    if type(entry) ~= "table" then return nil, nil end
    local source = entry.coords or entry
    return tonumber(source.x or source.col), tonumber(source.y or source.row)
  end

  local function hasRows(tabs)
    for _, tab in ipairs(TABS) do
      if type(tabs[tab]) == "table" and #tabs[tab] > 0 then return true end
    end
    return false
  end

  local function newMap(index, mapId)
    local hit = index.maps[mapId]
    if hit then return hit end
    local tabs = {}
    for _, tab in ipairs(TABS) do tabs[tab] = {} end
    hit = {
      id = mapId,
      label = mapName(mapId, index.sources.maps, index.townLocations),
      tabs = tabs,
    }
    index.maps[mapId] = hit
    return hit
  end

  local function addSpeciesLocation(index, species, mapId, category, row)
    if type(species) ~= "string" then return end
    index.locationsBySpecies[species] =
      index.locationsBySpecies[species] or {}
    local locations = index.locationsBySpecies[species]
    local location = locations[mapId]
    if not location then
      location = {
        mapId = mapId,
        label = mapName(mapId, index.sources.maps, index.townLocations),
        categories = {},
        rows = {},
      }
      locations[mapId] = location
    end
    location.categories[category] = true
    location.rows[#location.rows + 1] = row
  end

  local function addMapRow(index, mapId, tab, row, obtainableSpecies)
    local map = newMap(index, mapId)
    map.tabs[tab][#map.tabs[tab] + 1] = row
    if obtainableSpecies then
      addSpeciesLocation(index, obtainableSpecies, mapId, tab, row)
    end
  end

  local function itemName(id, records)
    local row = type(records) == "table" and records[id]
    local name = type(row) == "table" and (row.name or row.label)
    return type(name) == "string" and name ~= "" and name or words(id)
  end

  local function addItemRow(index, mapId, row)
    if type(row.item) ~= "string" or not index.sources.items[row.item] then return end
    row.kind = "item"
    row.label = itemName(row.item, index.sources.items)
    row.location = mapName(mapId, index.sources.maps, index.townLocations)
    addMapRow(index, mapId, "items", row)
    index.locationsByItem[row.item] = index.locationsByItem[row.item] or {}
    index.locationsByItem[row.item][#index.locationsByItem[row.item] + 1] = row
  end

  local function wildDestination(run, mapId, terrain, slotIndex, source)
    local settings = run.settings or {}
    local mappings = run.mappings or {}
    local area = mappings.wildAreaSlots
    area = type(area) == "table" and area[mapId]
    area = type(area) == "table" and area[terrain]
    local record = type(area) == "table" and area[slotIndex]
    if settings.wild_pokemon == "global_map" then
      local mapped = type(mappings.wildGlobal) == "table"
        and mappings.wildGlobal[source]
      return mapped or source,
        type(record) == "table" and record.level or nil,
        mapped == nil
    elseif settings.wild_pokemon == "area_slots" then
      return type(record) == "table" and record.species or source,
        type(record) == "table" and record.level or nil,
        not (type(record) == "table" and record.species)
    end
    return source, nil, true
  end

  local function fishingDestination(
      run, rod, mapId, slotIndex, source)
    local settings = run.settings or {}
    local fishing = type(run.mappings) == "table" and run.mappings.fishing
    local slots = type(fishing) == "table" and fishing.slots
    slots = type(slots) == "table" and slots[rod]
    slots = type(slots) == "table" and slots[mapId]
    local record = type(slots) == "table" and slots[slotIndex]
    if settings.fishing ~= "randomized" then return source, nil, true end
    if settings.wild_pokemon == "global_map" then
      local mapped = type(fishing) == "table"
        and type(fishing.global) == "table" and fishing.global[source]
      return mapped or source,
        type(record) == "table" and record.level or nil,
        mapped == nil
    elseif settings.wild_pokemon == "area_slots" then
      return type(record) == "table" and record.species or source,
        type(record) == "table" and record.level or nil,
        not (type(record) == "table" and record.species)
    end
    return source, nil, true
  end

  local function addWild(index)
    local raw = {}
    local function addSlot(row)
      local key = table.concat({
        row.mapId, row.category, row.method, row.species,
      }, "\0")
      local group = raw[key]
      if not group then
        group = {
          kind = "wild", mapId = row.mapId, method = row.method,
          category = row.category, species = row.species,
          chance = 0, minLevel = row.level,
          maxLevel = row.level, slots = {},
        }
        raw[key] = group
      end
      group.chance = group.chance + row.chance
      group.minLevel = math.min(group.minLevel, row.level)
      group.maxLevel = math.max(group.maxLevel, row.level)
      group.slots[#group.slots + 1] = row
    end

    for _, mapId in ipairs(StableSort.keys(index.sources.encounters or {})) do
      local encounter = index.sources.encounters[mapId]
      for _, terrain in ipairs(TERRAINS) do
        local definition = type(encounter) == "table" and encounter[terrain]
        local slots = type(definition) == "table" and definition.slots or {}
        local buckets = type(definition) == "table" and definition.buckets
          or DEFAULT_BUCKETS
        local previous = 0
        for slotIndex, slot in ipairs(slots or {}) do
          if type(slot) == "table" and type(slot.species) == "string"
              and type(slot.level) == "number" then
            local threshold = tonumber(buckets[slotIndex]) or previous
            local chance = math.max(0, threshold - previous) * 100 / 256
            previous = threshold
            local destination, level, vanilla = wildDestination(
              index.run, mapId, terrain, slotIndex, slot.species)
            addSlot({
              mapId = mapId,
              method = terrain == "water" and "SURF" or "GRASS",
              category = terrain == "water" and "surf" or "grass",
              source = slot.species,
              species = destination,
              level = level or slot.level,
              chance = chance,
              slot = slotIndex,
              vanilla = vanilla,
            })
          end
        end
      end
    end

    local field = index.sources.field or {}
    local fishableMaps = {}
    for mapId, encounter in pairs(index.sources.encounters or {}) do
      local water = type(encounter) == "table" and encounter.water
      if type(water) == "table" and type(water.slots) == "table"
          and #water.slots > 0 then
        fishableMaps[mapId] = true
      end
    end
    for _, rod in ipairs(RODS) do
      local definition = type(field.fishing) == "table" and field.fishing[rod]
      local perMap = type(definition) == "table" and definition.perMap
      local records = type(perMap) == "string" and field[perMap]
      if type(records) == "table" then
        for mapId in pairs(records) do fishableMaps[mapId] = true end
      end
    end
    for _, rod in ipairs(RODS) do
      local definition = type(field.fishing) == "table" and field.fishing[rod]
      if type(definition) == "table" then
        local groups = {}
        if type(definition.always) == "table" then
          groups["*"] = { definition.always }
        elseif type(definition.pool) == "table" then
          groups["*"] = definition.pool
        elseif type(definition.perMap) == "string"
            and type(field[definition.perMap]) == "table" then
          groups = field[definition.perMap]
        end
        for _, mapId in ipairs(StableSort.keys(groups)) do
          local slots = groups[mapId]
          local chance = definition.always and 100
            or 100 / (#slots + 4)
          local method = words(rod)
          local category = ROD_TABS[rod]
          for slotIndex, slot in ipairs(slots or {}) do
            if type(slot) == "table" and type(slot.species) == "string"
                and type(slot.level) == "number" then
              local destination, level, vanilla = fishingDestination(
                index.run, rod, mapId, slotIndex, slot.species)
              addSlot({
                mapId = mapId, method = method, category = category,
                source = slot.species, species = destination,
                level = level or slot.level, chance = chance,
                slot = slotIndex, vanilla = vanilla,
              })
            end
          end
          raw[table.concat({ mapId, category, method, "NO_BITE" }, "\0")] = {
            kind = "fishing_no_bite",
            mapId = mapId,
            category = category,
            method = method,
            chance = definition.always and 0 or (4 * chance),
          }
        end
      end
    end

    for _, key in ipairs(StableSort.keys(raw)) do
      local row = raw[key]
      if row.kind == "fishing_no_bite" then
        if row.mapId == "*" then
          for _, mapId in ipairs(StableSort.keys(fishableMaps)) do
            addMapRow(index, mapId, row.category, row)
          end
        else
          addMapRow(index, row.mapId, row.category, row)
        end
      elseif row.mapId == "*" then
        addSpeciesLocation(index, row.species, "*", row.category, row)
        for _, mapId in ipairs(StableSort.keys(fishableMaps)) do
          addMapRow(index, mapId, row.category, row)
        end
      else
        addMapRow(index, row.mapId, row.category, row, row.species)
      end
    end
  end

  local function mappedOrVanilla(mapping, source)
    if type(mapping) == "table" and type(mapping.species) == "string" then
      return mapping.species, mapping.level, false
    end
    return source.species, source.level, true
  end

  local function addStarters(index)
    local mappings = index.run.mappings.starters or {}
    local version = tostring(index.sources.gameVersion or "red"):lower()
    local sources = version == "yellow"
      and { { id = "YELLOW", source = "PIKACHU" } } or STARTERS
    for _, source in ipairs(sources) do
      local mapped = mappings[source.id]
      local species = type(mapped) == "table" and mapped.species or source.source
      local level = type(mapped) == "table" and mapped.level
        or tonumber(index.run.settings.starter_level) or 5
      addMapRow(index, "OAKS_LAB", "starters", {
        kind = "starter", label = version == "yellow"
          and "STARTER" or words(source.id) .. " BALL",
        source = source.source, species = species, level = level,
        vanilla = type(mapped) ~= "table",
      }, species)
    end
  end

  local function addStaticGifts(index)
    local mappings = index.run.mappings or {}
    local version = tostring(index.sources.gameVersion or "red"):lower()
    for _, source in ipairs(StaticGiftCatalog.staticsFor(version)) do
      local mapped = type(mappings.staticEncounters) == "table"
        and mappings.staticEncounters[source.id]
      local species, level, vanilla = mappedOrVanilla(mapped, source)
      addMapRow(index, source.mapId, "statics", {
        kind = "static", label = words(source.id),
        source = source.species, species = species,
        level = level or source.level, vanilla = vanilla,
      }, species)
    end
    for _, source in ipairs(StaticGiftCatalog.giftsFor(version)) do
      local mapped = type(mappings.gifts) == "table"
        and mappings.gifts[source.id]
      local species, level, vanilla = mappedOrVanilla(mapped, source)
      addMapRow(index, source.mapId, "gifts", {
        kind = "gift", label = words(source.id),
        source = source.species, species = species,
        level = level or source.level, price = source.price,
        vanilla = vanilla,
      }, species)
    end
  end

  local function fieldTrade(index, source)
    local trades = index.sources.field and index.sources.field.trades
    local row = type(trades) == "table" and trades[source.index]
    return {
      give = type(row) == "table" and row.give or source.give,
      get = type(row) == "table" and row.get or source.get,
    }
  end

  local function addTradesPrizes(index)
    local mappings = index.run.mappings or {}
    local version = tostring(index.sources.gameVersion or "red"):lower()
    for _, source in ipairs(TradePrizeCatalog.tradesFor(version)) do
      local vanilla = fieldTrade(index, source)
      local mapped = type(mappings.trades) == "table"
        and mappings.trades[source.id]
      local requested = type(mapped) == "table" and mapped.requested or {}
      local received = type(mapped) == "table" and mapped.received or {}
      local requestedSpecies = requested.species or vanilla.give
      local receivedSpecies = received.species or vanilla.get
      local row = {
        kind = "trade", label = words(source.id),
        requestedSource = vanilla.give, requested = requestedSpecies,
        receivedSource = vanilla.get, received = receivedSpecies,
        vanilla = type(mapped) ~= "table",
      }
      addMapRow(index, source.mapId, "trades", row, receivedSpecies)
    end

    local prizes = TradePrizeCatalog.prizesFor(version) or {}
    for _, source in ipairs(prizes) do
      local mapped = type(mappings.prizes) == "table"
        and mappings.prizes[source.id]
      local species, level, vanilla = mappedOrVanilla(mapped, source)
      addMapRow(index, "GAME_CORNER_PRIZE_ROOM", "prizes", {
        kind = "prize", label = words(source.id),
        source = source.species, species = species,
        level = level or source.level,
        sourceCost = source.cost,
        cost = type(mapped) == "table" and mapped.cost or source.cost,
        vanilla = vanilla,
      }, species)
    end
  end

  local function addFieldItems(index)
    local placements = type(index.run.mappings) == "table"
      and index.run.mappings.fieldItems or {}
    local mapped = { visible = {}, hidden = {}, scripted = {}, shop = {} }
    for _, row in ipairs(type(placements) == "table" and placements or {}) do
      if row.kind == "visible" then
        mapped.visible[row.mapId .. "\0" .. tostring(row.objectIndex)] = row
      elseif row.kind == "hidden" then
        mapped.hidden[row.mapId .. "\0" .. tostring(row.hiddenIndex)] = row
      elseif row.kind == "scripted" then
        mapped.scripted[row.id] = row
      elseif row.kind == "shop" then
        mapped.shop[(row.pointerId or row.mapId) .. "\0" .. row.talkKey
          .. "\0" .. tostring(row.slot)] = row
      end
    end

    for _, mapId in ipairs(StableSort.keys(index.sources.maps or {})) do
      local map = index.sources.maps[mapId]
      for arrayIndex, object in ipairs(type(map) == "table" and map.objects or {}) do
        if type(object) == "table" and type(object.item) == "string" then
          local objectIndex = object.index or arrayIndex
          local replacement = mapped.visible[mapId .. "\0" .. tostring(objectIndex)]
          addItemRow(index, mapId, { item = replacement and replacement.item or object.item,
            sourceKind = "visible", objectIndex = objectIndex })
        end
      end
    end
    local hidden = type(index.sources.field) == "table"
      and index.sources.field.hiddenItems or {}
    for _, mapId in ipairs(StableSort.keys(hidden or {})) do
      for hiddenIndex, object in ipairs(hidden[mapId] or {}) do
        local replacement = mapped.hidden[mapId .. "\0" .. tostring(hiddenIndex)]
        addItemRow(index, mapId, { item = replacement and replacement.item or object.item,
          sourceKind = "hidden", hidden = true, hiddenIndex = hiddenIndex,
          x = object.x, y = object.y })
      end
    end

    local pcFound = false
    for _, row in ipairs(type(placements) == "table" and placements or {}) do
      if row.kind == "pc" then
        pcFound = true
        addItemRow(index, row.mapId, { item = row.item,
          sourceKind = "pc", storage = true, quantity = row.quantity })
      end
    end
    if not pcFound then
      addItemRow(index, "REDS_HOUSE_2F", { item = "POTION",
        sourceKind = "pc", storage = true, quantity = 1 })
    end

    for _, source in ipairs(index.sources.scriptedItems or {}) do
      local replacement = mapped.scripted[source.id]
      addItemRow(index, source.mapId, {
        item = replacement and replacement.item or source.item,
        sourceKind = source.battle and "gym" or "gift",
        sourceId = source.id,
      })
    end

    local mapIdsByLabel = {}
    for mapId, map in pairs(index.sources.maps or {}) do
      if type(map) == "table" and type(map.label) == "string" then
        mapIdsByLabel[map.label] = mapId
      end
    end
    for _, pointerId in ipairs(StableSort.keys(index.sources.textPointers or {})) do
      local pointer = index.sources.textPointers[pointerId]
      for _, talkKey in ipairs(StableSort.keys(pointer or {})) do
        local mart = type(pointer[talkKey]) == "table" and pointer[talkKey].mart
        for slot, sourceItem in ipairs(type(mart) == "table" and mart or {}) do
          local replacement = mapped.shop[pointerId .. "\0" .. talkKey
            .. "\0" .. tostring(slot)]
          local item = replacement and replacement.item or sourceItem
          local definition = index.sources.items[item]
          addItemRow(index, replacement and replacement.mapId
              or mapIdsByLabel[pointerId] or pointerId, {
            item = item, sourceKind = "shop", shop = true,
            price = replacement and replacement.price
              or type(definition) == "table" and definition.price,
            talkKey = talkKey, slot = slot,
          })
        end
      end
    end

    local specials = {
      { mapId = "CELADON_MART_ROOF", talkKey = "vending",
        currency = "Y", rows = {
          { "FRESH_WATER", 200 }, { "SODA_POP", 300 }, { "LEMONADE", 350 },
        } },
      { mapId = "GAME_CORNER_PRIZE_ROOM", talkKey = "prize_tms",
        currency = "COINS", rows = {
          { "TM_DRAGON_RAGE", 3300 }, { "TM_HYPER_BEAM", 5500 },
          { "TM_SUBSTITUTE", 7700 },
        } },
    }
    for _, special in ipairs(specials) do
      for slot, source in ipairs(special.rows) do
        local key = special.mapId .. "\0" .. special.talkKey
          .. "\0" .. tostring(slot)
        local replacement = mapped.shop[key]
        addItemRow(index, special.mapId, {
          item = replacement and replacement.item or source[1],
          sourceKind = special.talkKey, shop = true,
          price = replacement and replacement.price or source[2],
          currency = special.currency, slot = slot,
        })
      end
    end
  end

  local function buildItems(index)
    for id, record in pairs(index.sources.items or {}) do
      if type(id) == "string" and type(record) == "table" then
        index.items[#index.items + 1] = {
          id = id, name = itemName(id, index.sources.items),
        }
      end
    end
    table.sort(index.items, function(a, b)
      if a.name ~= b.name then return a.name < b.name end
      return a.id < b.id
    end)
  end

  local function finalizeItems(index)
    for _, rows in pairs(index.locationsByItem) do
      table.sort(rows, function(a, b)
        if a.location ~= b.location then return a.location < b.location end
        if a.sourceKind ~= b.sourceKind then return a.sourceKind < b.sourceKind end
        return (a.slot or 0) < (b.slot or 0)
      end)
    end
  end

  local function trainerParty(index, classId, partyIndex)
    local sourceClass = index.sources.trainers[classId]
    local sourceParty = type(sourceClass) == "table"
      and type(sourceClass.parties) == "table"
      and sourceClass.parties[partyIndex]
    if type(sourceParty) ~= "table" then return nil end
    local mappedClass = index.run.mappings.trainerParties or {}
    mappedClass = mappedClass[classId]
    local mapped = type(mappedClass) == "table" and mappedClass[partyIndex]
    local party = {}
    if type(mapped) ~= "table" then
      for _, member in ipairs(sourceParty) do
        party[#party + 1] = {
          source = member.species, species = member.species,
          level = member.level, vanilla = true,
        }
      end
      return party, true
    end
    for slotIndex, member in ipairs(mapped) do
      local sourceIndex = tonumber(member.sourceSlot) or slotIndex
      local source = sourceParty[sourceIndex] or sourceParty[slotIndex]
      if member.fallback then
        party[#party + 1] = {
          source = source and source.species,
          species = source and source.species,
          level = source and source.level, vanilla = true,
        }
      else
        party[#party + 1] = {
          source = source and source.species,
          species = member.species,
          level = member.level,
          vanilla = false,
        }
      end
    end
    local rivalStarters = type(mappedClass) == "table"
      and mappedClass.rivalStarters
    local projected = type(rivalStarters) == "table"
      and rivalStarters[partyIndex]
    if #party > 0 and type(projected) == "table"
        and type(projected.species) == "string" then
      party[#party].species = projected.species
      party[#party].vanilla = false
    end
    return party, false
  end

  local function addTrainer(index, seen, mapId, classId, partyIndex)
    partyIndex = tonumber(partyIndex)
    if type(classId) ~= "string" or not partyIndex then return end
    local key = mapId .. "\0" .. classId .. "\0" .. tostring(partyIndex)
    if seen[key] then return end
    local party, vanilla = trainerParty(index, classId, partyIndex)
    if not party then return end
    seen[key] = true
    addMapRow(index, mapId, "trainers", {
      kind = "trainer", classId = classId, partyIndex = partyIndex,
      label = words(classId:gsub("^OPP_", "")) .. " - "
        .. tostring(partyIndex),
      party = party, vanilla = vanilla,
    })
  end

  local function addTrainers(index)
    local seen = {}
    for _, mapId in ipairs(StableSort.keys(index.sources.maps or {})) do
      local map = index.sources.maps[mapId]
      for _, object in ipairs(type(map) == "table" and map.objects or {}) do
        addTrainer(index, seen, mapId,
          object.trainerClass, object.trainerParty)
      end
    end
    for _, record in ipairs(SCRIPTED_TRAINERS) do
      for party = record.first, record.last do
        addTrainer(index, seen, record.mapId, record.classId, party)
      end
    end
  end

  local function buildSpecies(index)
    for id, record in pairs(index.sources.species or {}) do
      if type(id) == "string" and type(record) == "table" then
        index.species[#index.species + 1] = {
          id = id,
          name = speciesName(id, index.sources.species),
          dex = tonumber(record.dex),
        }
        index.names[id] = speciesName(id, index.sources.species)
      end
    end
    table.sort(index.species, function(a, b)
      if a.dex and b.dex and a.dex ~= b.dex then return a.dex < b.dex end
      if a.dex ~= nil and b.dex == nil then return true end
      if a.dex == nil and b.dex ~= nil then return false end
      if a.name ~= b.name then return a.name < b.name end
      return a.id < b.id
    end)
  end

  local function finalizeSpecies(index)
    for species, keyed in pairs(index.locationsBySpecies) do
      local rows = {}
      for _, mapId in ipairs(StableSort.keys(keyed)) do
        local row = keyed[mapId]
        local categories = {}
        for _, tab in ipairs(TABS) do
          if row.categories[tab] then
            if tab == "statics" then
              local identities, seen = {}, {}
              for _, entry in ipairs(row.rows) do
                if entry.kind == "static" and type(entry.source) == "string"
                    and not seen[entry.source] then
                  seen[entry.source] = true
                  identities[#identities + 1] =
                    speciesName(entry.source, index.sources.species):upper()
                end
              end
              table.sort(identities)
              for _, identity in ipairs(identities) do
                categories[#categories + 1] = "STATIC - " .. identity
              end
            else
              categories[#categories + 1] = TAB_LABELS[tab]
            end
          end
        end
        row.summary = table.concat(categories, "/")
        rows[#rows + 1] = row
      end
      table.sort(rows, function(a, b)
        if a.label ~= b.label then return a.label < b.label end
        return a.mapId < b.mapId
      end)
      index.locationsBySpecies[species] = rows
    end
  end

  local function buildAreas(index)
    local grouped = {}
    for mapId, entry in pairs(index.townLocations) do
      local x, y = coords(entry)
      if x and y then
        local name = tostring(entry.name or entry.label or words(mapId))
        local key = name .. "\0" .. tostring(x) .. "\0" .. tostring(y)
        local area = grouped[key]
        if not area then
          area = { key = key, name = name, x = x, y = y, maps = {} }
          grouped[key] = area
        end
        area.maps[#area.maps + 1] = newMap(index, mapId)
      end
    end
    for _, area in pairs(grouped) do
      local relevant = {}
      for _, map in ipairs(area.maps) do
        if hasRows(map.tabs) then relevant[#relevant + 1] = map end
      end
      if #relevant == 0 then
        local tabs = {}
        for _, tab in ipairs(TABS) do tabs[tab] = {} end
        relevant[1] = {
          id = area.key, label = area.name, tabs = tabs, empty = true,
        }
      end
      table.sort(relevant, function(a, b)
        if a.label ~= b.label then return a.label < b.label end
        return a.id < b.id
      end)
      area.maps = relevant
      index.areas[#index.areas + 1] = area
    end
    table.sort(index.areas, function(a, b)
      if a.y ~= b.y then return a.y < b.y end
      if a.x ~= b.x then return a.x < b.x end
      return a.name < b.name
    end)
  end

  function Browser.build(run, sources)
    assert(type(run) == "table", "active run is required")
    sources = type(sources) == "table" and sources or {}
    local locations, townMap = townLocations(sources.field or {})
    local index = {
      run = run,
      sources = sources,
      townLocations = locations,
      townMap = townMap,
      species = {},
      items = {},
      names = {},
      locationsBySpecies = {},
      locationsByItem = {},
      maps = {},
      areas = {},
      tabs = copyArray(TABS),
      tabLabels = TAB_LABELS,
    }
    buildSpecies(index)
    buildItems(index)
    addWild(index)
    addStarters(index)
    addStaticGifts(index)
    addTradesPrizes(index)
    addFieldItems(index)
    addTrainers(index)
    finalizeSpecies(index)
    finalizeItems(index)
    buildAreas(index)
    return index
  end

  local function identityPart(value)
    if value == nil then return "" end
    return tostring(value)
  end

  local function indexCacheKey(run, sources)
    local checksum = type(run.checksum) == "table"
      and run.checksum.value or run.checksum
    local seed = type(run.seed) == "table"
      and (run.seed.hash128 or run.seed.canonical) or run.seed
    local sourceIdentity = sources.cacheIdentity
      or table.concat({
        identityPart(sources.species),
        identityPart(sources.encounters),
        identityPart(sources.trainers),
        identityPart(sources.maps),
        identityPart(sources.field),
        identityPart(sources.items),
      }, "|")
    return table.concat({
      "spoiler-index-v1",
      identityPart(checksum or run),
      identityPart(seed),
      identityPart(sources.gameVersion),
      identityPart(sources.saveIdentity),
      identityPart(sourceIdentity),
    }, "\0")
  end

  function Browser.buildCached(run, sources)
    assert(type(run) == "table", "active run is required")
    sources = type(sources) == "table" and sources or {}
    local key = indexCacheKey(run, sources)
    if indexCache.key == key and indexCache.value then
      indexCache.hits = indexCache.hits + 1
      return indexCache.value
    end
    local value = Browser.build(run, sources)
    indexCache.key = key
    indexCache.value = value
    indexCache.builds = indexCache.builds + 1
    return value
  end

  function Browser.cacheStats()
    return {
      builds = indexCache.builds,
      hits = indexCache.hits,
      populated = indexCache.value ~= nil,
    }
  end

  function Browser.clearCache()
    indexCache.key = nil
    indexCache.value = nil
    indexCache.builds = 0
    indexCache.hits = 0
  end

  Browser.words = words
  Browser.speciesName = speciesName
  Browser.tabs = copyArray(TABS)
  Browser.tabLabels = TAB_LABELS
  return Browser
end
