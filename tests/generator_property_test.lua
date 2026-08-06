-- Remediation-M4 bounded properties over the real combined generator.
local Harness = assert(loadfile("tests/generator_harness.lua"))()

local function containsCode(result, code)
  for _, warning in ipairs(result.diagnostics.warnings or {}) do
    if warning.code == code then return true end
  end
  return false
end

<<<<<<< Updated upstream
=======
local ALL_NEW_SETTINGS = {
  non_key_items = "mixed", tms = "mixed", hms = "mixed",
  key_items = "mixed", badges = "mixed", hidden_items = "mixed",
  ensure_beatable = "on", shops = "randomized", shop_prices = "cheap",
  base_stats = "full_random", stat_family_consistency = "off",
  evolutions = "full_random", evolution_repeats = "avoid",
  evolution_trade_safety = "random_30_40",
  pokemon_types = "randomized", type_family_consistency = "off",
  pokemon_movesets = "randomized", early_damage = "off",
  learnset_levels = "shuffled", tmhm_compatibility = "shuffled",
  move_types = "randomized", move_data = "full_random",
  move_safety = "off",
}

local Streams = Harness.Constants.STREAMS
local ACTIVE_STREAMS = Harness.Constants.STREAM_NAMES

local ACTIVE_STREAM_SET = {}
for _, name in ipairs(ACTIVE_STREAMS) do
  assert(not ACTIVE_STREAM_SET[name], "duplicate expected stream " .. name)
  ACTIVE_STREAM_SET[name] = true
end

local function copyMap(values)
  local result = {}
  for key, value in pairs(values or {}) do result[key] = value end
  return result
end

local function assertStreamCalls(calls)
  for name in pairs(calls) do
    assert(ACTIVE_STREAM_SET[name], "unexpected stream name " .. tostring(name))
  end
  for _, name in ipairs(ACTIVE_STREAMS) do
    local count = calls[name]
    assert(count ~= nil, "missing stream " .. name)
    assert(count == 1, "reused stream " .. name)
  end
end

local function generateWithStreamTransform(request, transform)
  local original = Harness.Rng.fromSeed
  Harness.Rng.fromSeed = function(seed, name)
    local nextSeed, nextName = transform(seed, name)
    return original(nextSeed or seed, nextName or name)
  end
  local ok, result, generationError = pcall(
    Harness.Generator.generate, request)
  Harness.Rng.fromSeed = original
  assert(ok, "instrumented generator did not terminate safely")
  assert(result, generationError and generationError.message)
  return result
end

local ITEM_REQUIRED_STAGE = {
  OAKS_PARCEL = 0, S_S_TICKET = 2, HM_CUT = 3,
  POKE_FLUTE = 4, SILPH_SCOPE = 4, LIFT_KEY = 4,
  HM_SURF = 5, GOLD_TEETH = 5, HM_STRENGTH = 8,
  CARD_KEY = 7, SECRET_KEY = 6,
  BOULDERBADGE = 1, CASCADEBADGE = 2, THUNDERBADGE = 7,
  RAINBOWBADGE = 7, SOULBADGE = 5, MARSHBADGE = 7,
  VOLCANOBADGE = 7, EARTHBADGE = 7,
}

local function itemDestinationExists(row, sources)
  if row.kind == "visible" then
    local map = sources.maps and sources.maps[row.mapId]
    for index, object in ipairs(map and map.objects or {}) do
      if (object.index or index) == row.objectIndex
          and object.item == row.original then return true end
    end
  elseif row.kind == "hidden" then
    local hidden = sources.field and sources.field.hiddenItems
    local object = hidden and hidden[row.mapId]
      and hidden[row.mapId][row.hiddenIndex]
    return object and object.item == row.original
      and object.x == row.x and object.y == row.y
  elseif row.kind == "pc" then
    return row.mapId == "REDS_HOUSE_2F"
      and sources.startingPcItems
      and sources.startingPcItems[row.original] == row.quantity
  elseif row.kind == "scripted" then
    for _, source in ipairs(sources.scriptedItems or {}) do
      if source.id == row.id and source.mapId == row.mapId
          and source.item == row.original then return true end
    end
  elseif row.kind == "shop" then
    if row.pointerId then
      local pointer = sources.textPointers and sources.textPointers[row.pointerId]
      local mart = pointer and pointer[row.talkKey] and pointer[row.talkKey].mart
      return mart and mart[row.slot] == row.original
    end
    local special = row.talkKey == "vending" and {
      "FRESH_WATER", "SODA_POP", "LEMONADE",
    } or row.talkKey == "prize_tms" and {
      "TM_DRAGON_RAGE", "TM_HYPER_BEAM", "TM_SUBSTITUTE",
    }
    return special and special[row.slot] == row.original
  end
  return false
end

local function itemProperties(request, result, label)
  local seen, sources = {}, request.sources
  for index, row in ipairs(result.mappings.fieldItems or {}) do
    local context = label .. " fieldItems[" .. index .. "]"
    assert(type(row) == "table" and type(row.item) == "string",
      context .. " has no mapped item")
    local definition = sources.items and sources.items[row.item]
    assert(definition and Harness.ItemFilter.isUsable(row.item, definition),
      context .. " references an invalid item " .. tostring(row.item))
    assert(itemDestinationExists(row, sources),
      context .. " references an unsupported destination")
    local destination = table.concat({ row.kind or "", row.mapId or "",
      row.id or "", tostring(row.objectIndex or ""),
      tostring(row.hiddenIndex or ""), row.pointerId or "",
      row.talkKey or "", tostring(row.slot or "") }, "\0")
    assert(not seen[destination], context .. " duplicates a destination")
    seen[destination] = true

    if request.settings.ensure_beatable == "on" and row.kind ~= "shop" then
      local access = Harness.Progression.itemAccess(row, sources.gameVersion)
      assert(access.available, context .. " has unknown progression access")
      local required = ITEM_REQUIRED_STAGE[row.item]
        or Harness.Progression.STAGES.VICTORY_ROAD
      assert(access.stage <= required,
        context .. " violates progression safety")
    end

    if row.kind == "shop" then
      local kind = Harness.ItemCategory.category(row.item, sources.items)
      assert(kind == "non_key" or kind == "tm" or kind == "key",
        context .. " has a forbidden shop category " .. tostring(kind))
      assert(kind ~= "hm", context .. " placed an HM in a shop")
      if kind == "tm" then
        assert(request.settings.tms ~= "vanilla",
          context .. " stocked a TM while TM locations are vanilla")
      elseif kind == "key" then
        assert(request.settings.key_items == "mixed"
            or request.settings.key_items == "full_random",
          context .. " stocked a key item outside the enabled pool")
      end
      if request.settings.shop_prices == "cheap" then
        assert(row.price == 100, context .. " violates cheap pricing")
      elseif request.settings.shop_prices == "random" then
        assert(type(row.price) == "number" and row.price >= 100
            and row.price <= 5000 and row.price % 100 == 0,
          context .. " has an invalid random price")
      else
        assert(row.price == nil, context .. " changed a vanilla price")
      end
    end
  end
end

local function mechanicsProperties(request, result, label, byId)
  local moves, types, machines = request.sources.moves or {}, {}, {}
  for _, id in ipairs(request.sources.typeIds or {}) do types[id] = true end
  for _, entry in ipairs(request.species) do
    for _, id in ipairs(entry.tmhm or {}) do machines[id] = true end
  end
  local adjacency = {}
  for id, row in pairs(result.mappings.pokemonMechanics or {}) do
    local source = byId[id]
    assert(source, label .. " mechanics references invalid species " .. id)
    if row.baseStats then
      local total = 0
      for _, key in ipairs({ "hp", "attack", "defense", "speed", "special" }) do
        local value = row.baseStats[key]
        assert(type(value) == "number" and value == math.floor(value)
            and value >= 1 and value <= 255,
          label .. " invalid base stat " .. id .. "." .. key)
        total = total + value
      end
      if request.settings.base_stats ~= "full_random" then
        assert(total == source.bst, label .. " changed BST for " .. id)
      end
    end
    if row.types then
      assert(#row.types >= 1 and #row.types <= 2,
        label .. " invalid type count for " .. id)
      assert(types[row.types[1]], label .. " invalid primary type for " .. id)
      if row.types[2] then
        assert(types[row.types[2]] and row.types[2] ~= row.types[1],
          label .. " invalid secondary type for " .. id)
      end
    end
    for _, move in ipairs(row.level1Moves or {}) do
      assert(moves[move], label .. " invalid starting move " .. tostring(move))
    end
    for _, learned in ipairs(row.learnset or {}) do
      assert(moves[learned.move], label .. " invalid learned move")
      assert(type(learned.level) == "number"
          and learned.level == math.floor(learned.level)
          and learned.level >= 1 and learned.level <= 100,
        label .. " invalid learn level for " .. id)
    end
    local compatible = {}
    for _, move in ipairs(row.tmhm or {}) do
      assert(machines[move] and moves[move],
        label .. " invalid TM/HM compatibility " .. tostring(move))
      assert(not compatible[move], label .. " duplicate compatibility " .. move)
      compatible[move] = true
    end
    if row.evolutions then
      assert(#row.evolutions == #(source.evolutions or {}),
        label .. " changed evolution branch count for " .. id)
      adjacency[id] = {}
      local siblings = {}
      for index, evolution in ipairs(row.evolutions) do
        local original = source.evolutions[index]
        assert(byId[evolution.species] and evolution.species ~= id,
          label .. " invalid evolution destination for " .. id)
        assert(not siblings[evolution.species],
          label .. " duplicate sibling evolution for " .. id)
        siblings[evolution.species] = true
        adjacency[id][#adjacency[id] + 1] = evolution.species
        local originalTrade = tostring(original.method):upper():find(
          "TRADE", 1, true) ~= nil
        if originalTrade
            and request.settings.evolution_trade_safety ~= "vanilla" then
          assert(tostring(evolution.method):upper() == "LEVEL"
              and evolution.item == nil and evolution.level >= 30
              and evolution.level <= 40,
            label .. " invalid converted trade evolution for " .. id)
        else
          assert(evolution.method == original.method
              and evolution.level == original.level
              and evolution.item == original.item,
            label .. " changed evolution trigger for " .. id)
        end
      end
    end
  end
  local state = {}
  local function visit(id)
    assert(state[id] ~= "visiting", label .. " evolution cycle at " .. id)
    if state[id] == "done" then return end
    state[id] = "visiting"
    for _, child in ipairs(adjacency[id] or {}) do visit(child) end
    state[id] = "done"
  end
  for id in pairs(adjacency) do visit(id) end

  for id, row in pairs(result.mappings.moveData or {}) do
    local source = moves[id]
    assert(source, label .. " move data references invalid move " .. id)
    assert(types[row.type], label .. " move data has invalid type for " .. id)
    assert(type(row.power) == "number" and row.power == math.floor(row.power)
        and row.power >= 0 and row.power <= 255,
      label .. " move power out of range for " .. id)
    assert(type(row.accuracy) == "number"
        and row.accuracy == math.floor(row.accuracy)
        and row.accuracy >= 0 and row.accuracy <= 100,
      label .. " move accuracy out of range for " .. id)
    assert(type(row.pp) == "number" and row.pp == math.floor(row.pp)
        and row.pp >= 1 and row.pp <= 64,
      label .. " move PP out of range for " .. id)
    if source.power == 0 then
      assert(row.power == 0, label .. " status move gained power for " .. id)
    end
    assert(row.effect == nil and row.fixedDamage == nil,
      label .. " mutable overlay exposed protected move fields for " .. id)
    if request.settings.move_safety == "on" and row.power >= 100 then
      assert(row.accuracy <= 90 and row.pp <= 15,
        label .. " move safety failed for " .. id)
    end
  end
end

>>>>>>> Stashed changes
local function propertyCheck(request, result, label)
  local byId = {}
  for _, entry in ipairs(request.species) do byId[entry.id] = entry end
  local mappings = result.mappings

  local function species(id, context)
    assert(type(id) == "string" and byId[id],
      label .. " invalid mapped species at " .. context)
    if request.settings.legendaries == "exclude" then
      assert(not byId[id].legendary,
        label .. " legendary hard filter failed at " .. context)
    end
  end

  local function level(value, context)
    assert(type(value) == "number" and value == math.floor(value)
        and value >= 2 and value <= 100,
      label .. " invalid level at " .. context)
  end

  local function match(sourceId, destinationId, context)
    species(destinationId, context)
    if request.settings.legendaries == "match" then
      assert(byId[sourceId].legendary == byId[destinationId].legendary,
        label .. " legendary match failed at " .. context)
    end
  end

  for source, destination in pairs(mappings.wildGlobal) do
    match(source, destination, "wildGlobal." .. source)
  end
  for mapId, terrains in pairs(mappings.wildAreaSlots) do
    for terrain, slots in pairs(terrains) do
      for index, row in pairs(slots) do
        if row.species then
          local source = request.sources.encounters[mapId][terrain]
            .slots[index].species
          match(source, row.species,
            ("wildAreaSlots.%s.%s.%s"):format(mapId, terrain, index))
        end
        if row.level then level(row.level, "wild area") end
      end
    end
  end
  local fishing = mappings.fishing or {}
  for source, destination in pairs(fishing.global or {}) do
    match(source, destination, "fishing.global." .. source)
  end
  local function fishingRows(value)
    if type(value) ~= "table" then return end
    if value.species then species(value.species, "fishing slot") end
    if value.level then level(value.level, "fishing slot") end
    for _, child in pairs(value) do
      if type(child) == "table" then fishingRows(child) end
    end
  end
  fishingRows(fishing.slots)

  local starterSeen, starterCount = {}, 0
  for slotId, row in pairs(mappings.starters) do
    starterCount = starterCount + 1
    species(row.species, "starter." .. slotId)
    species(row.rivalSpecies, "starter rival." .. slotId)
    level(row.level, "starter." .. slotId)
    assert(not starterSeen[row.species], label .. " duplicate starter")
    starterSeen[row.species] = true
    if request.settings.starter_stage == "basic_only" then
      assert(byId[row.species].stage == "basic",
        label .. " starter stage hard filter failed")
    end
  end
  if request.settings.starters ~= "off" then
    assert(starterCount == 3, label .. " starter count")
  end

  for id, row in pairs(mappings.staticEncounters) do
    match(row.sourceSpecies, row.species, "static." .. id)
    level(row.level, "static." .. id)
  end
  for id, row in pairs(mappings.gifts) do
    match(row.sourceSpecies, row.species, "gift." .. id)
    level(row.level, "gift." .. id)
  end
  for id, row in pairs(mappings.trades) do
    match(row.requested.sourceSpecies,
      row.requested.species, "trade request." .. id)
    species(row.received.species, "trade received." .. id)
    if request.settings.legendaries == "match" then
      assert(byId[row.requested.species].legendary
          == byId[row.received.species].legendary,
        label .. " trade received legendary match failed")
    end
  end
  for id, row in pairs(mappings.prizes) do
    match(row.sourceSpecies, row.species, "prize." .. id)
    level(row.level, "prize." .. id)
  end

  for classId, classMappings in pairs(mappings.trainerParties) do
    for partyIndex, party in pairs(classMappings) do
      if type(partyIndex) == "number" then
        assert(#party >= 1 and #party <= 6,
          label .. " trainer party size " .. classId)
        local sourceParty =
          request.sources.trainers[classId].parties[partyIndex]
        for slotIndex, row in ipairs(party) do
          if not row.fallback then
            local source = sourceParty[row.sourceSlot]
            match(source.species, row.species,
              ("%s.%d.%d"):format(classId, partyIndex, slotIndex))
            level(row.level, "trainer " .. classId)
          end
        end
      end
    end
  end

  local function unique(values, context)
    local seen = {}
    for _, value in ipairs(values) do
      assert(not seen[value], label .. " duplicate before exhaustion: " .. context)
      seen[value] = true
    end
  end
  if request.settings.duplicate_policy == "one_to_one" then
    local values = {}
    for _, value in pairs(mappings.wildGlobal) do values[#values + 1] = value end
    unique(values, "wild global")
    values = {}
    for _, row in pairs(mappings.staticEncounters) do
      values[#values + 1] = row.species
    end
    unique(values, "statics")
    values = {}
    for _, row in pairs(mappings.prizes) do values[#values + 1] = row.species end
    unique(values, "prizes")
    values = {}
    for _, row in pairs(mappings.trades) do
      values[#values + 1] = row.received.species
    end
    unique(values, "trade receipts")
  end
  if request.settings.gift_uniqueness == "unique" then
    local values = {}
    for _, row in pairs(mappings.gifts) do values[#values + 1] = row.species end
    unique(values, "gifts")
  end

  if request.settings.catchability_guard == "on" then
    local reachable = Harness.Validation.reachableSpecies(
      mappings, request.sources)
    local records = {}
    for _, record in ipairs(Harness.TradeCatalog.trades) do
      records[record.id] = record
    end
    for tradeId, row in pairs(mappings.trades) do
      local access = Harness.Progression.tradeAccess(
        records[tradeId], request.sources.gameVersion)
      local stage = reachable[row.requested.species]
      if stage == nil or stage > access.stage then
        assert(containsCode(result, "TRADE_REACHABILITY_UNSATISFIED"),
          label .. " unreachable guarded trade lacked attribution")
      end
    end
  end

  local encoded = Harness.Canonical.encode(result)
  local decoded = Harness.Canonical.decode(encoded)
  assert(Harness.hash(decoded) == Harness.hash(result),
    label .. " canonical round-trip hash")
end

local start = os.clock()
local cases = 0
for _, profile in ipairs({ "casual", "standard", "chaos" }) do
  for seedIndex = 1, 6 do
    cases = cases + 1
    local label = ("%s/%d"):format(profile, seedIndex)
    local request = Harness.request(
      ("M4 PROPERTY %s %02d"):format(profile:upper(), seedIndex), profile)
    local ok, result, generationError = pcall(
      Harness.Generator.generate, request)
    assert(ok, label .. " generator did not terminate safely")
    assert(result, generationError and generationError.message)
    propertyCheck(request, result, label)
  end
end

-- Named streams isolate categories from unrelated option toggles.
local baseRequest = Harness.request(
  "M4 STREAM ISOLATION", "standard", { catchability_guard = "off" })
local base = assert(Harness.Generator.generate(baseRequest))
local function isolated(overrides, unchanged)
  local request = Harness.request(
    "M4 STREAM ISOLATION", "standard", overrides)
  request.settings.catchability_guard = "off"
  local changed = assert(Harness.Generator.generate(request))
  for _, key in ipairs(unchanged) do
    assert(Harness.hash(base.mappings[key])
        == Harness.hash(changed.mappings[key]),
      key .. " changed when an unrelated category was toggled")
  end
end
isolated({ trainer_pokemon = "off" }, {
  "wildGlobal", "wildAreaSlots", "fishing", "starters", "starterFlags",
  "staticEncounters", "gifts", "trades", "prizes",
})
isolated({ gift_pokemon = "off" }, { "staticEncounters" })
isolated({ game_corner_pokemon = "off" }, { "trades" })
isolated({ fishing = "vanilla" }, { "wildGlobal", "wildAreaSlots" })

-- Gift reachability can influence guarded trade requests, but its named
-- streams must not perturb unrelated mapping categories.
local guardedWithGifts = Harness.request(
  "ROUND 2 DOJO ISOLATION", "standard", {
    catchability_guard = "on",
  })
local guardedWithoutGifts = Harness.request(
  "ROUND 2 DOJO ISOLATION", "standard", {
    catchability_guard = "on",
    gift_pokemon = "off",
  })
local withGifts = assert(Harness.Generator.generate(guardedWithGifts))
local withoutGifts = assert(Harness.Generator.generate(guardedWithoutGifts))
for _, key in ipairs({
    "wildGlobal", "wildAreaSlots", "fishing", "starters", "starterFlags",
    "staticEncounters", "prizes", "trainerParties",
}) do
  assert(Harness.hash(withGifts.mappings[key])
      == Harness.hash(withoutGifts.mappings[key]),
    key .. " changed when only gift reachability was removed")
end

local elapsed = os.clock() - start
assert(elapsed < 45, "property suite exceeded 45-second CI budget")
io.write(("generator_property_test: ok (%d real generations, %.2fs)\n")
  :format(cases + 7, elapsed))
