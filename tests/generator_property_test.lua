-- Remediation-M4 bounded properties over the real combined generator.
local Harness = assert(loadfile("tests/generator_harness.lua"))()

local function containsCode(result, code)
  for _, warning in ipairs(result.diagnostics.warnings or {}) do
    if warning.code == code then return true end
  end
  return false
end

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
    local reachable = Harness.Validation.reachableSpecies(mappings)
    for _, row in pairs(mappings.trades) do
      if not reachable[row.requested.species] then
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

local elapsed = os.clock() - start
assert(elapsed < 45, "property suite exceeded 45-second CI budget")
io.write(("generator_property_test: ok (%d real generations, %.2fs)\n")
  :format(cases + 5, elapsed))
