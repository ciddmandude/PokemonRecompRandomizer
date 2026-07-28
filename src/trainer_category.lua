-- Deterministic saved trainer-party generation for milestone 13.
return function(StableSort, SpeciesFilters)
  local Category = {}

  local BOSSES = {
    OPP_BROCK = true, OPP_MISTY = true, OPP_LT_SURGE = true,
    OPP_ERIKA = true, OPP_KOGA = true, OPP_SABRINA = true,
    OPP_BLAINE = true, OPP_GIOVANNI = true, OPP_LORELEI = true,
    OPP_BRUNO = true, OPP_AGATHA = true, OPP_LANCE = true,
    OPP_RIVAL1 = true, OPP_RIVAL2 = true, OPP_RIVAL3 = true,
  }

  local LONE_MOVES = {
    OPP_BROCK = { slot = 2, move = "BIDE" },
    OPP_MISTY = { slot = 2, move = "BUBBLEBEAM" },
    OPP_LT_SURGE = { slot = 3, move = "THUNDERBOLT" },
    OPP_ERIKA = { slot = 3, move = "MEGA_DRAIN" },
    OPP_KOGA = { slot = 4, move = "TOXIC" },
    OPP_SABRINA = { slot = 4, move = "PSYWAVE" },
    OPP_BLAINE = { slot = 4, move = "FIRE_BLAST" },
  }
  local TEAM_MOVES = {
    OPP_LORELEI = "BLIZZARD", OPP_BRUNO = "FISSURE",
    OPP_AGATHA = "TOXIC", OPP_LANCE = "BARRIER",
  }

  local function copyArray(source)
    local output = {}
    for index, value in ipairs(source or {}) do output[index] = value end
    return output
  end

  local function clamp(value)
    return math.max(2, math.min(100, math.floor(value + 0.5)))
  end

  local function movesAtLevel(entry, level)
    local moves = {}
    local function add(move)
      if type(move) ~= "string" or move == "" then return end
      for _, present in ipairs(moves) do if present == move then return end end
      moves[#moves + 1] = move
    end
    for _, move in ipairs(entry.level1Moves or {}) do add(move) end
    for _, row in ipairs(entry.learnset or {}) do
      if type(row) == "table" and type(row.level) == "number"
          and row.level <= level then add(row.move) end
    end
    while #moves > 4 do table.remove(moves, 1) end
    return moves
  end

  local function moveLegal(entry, move)
    for _, candidate in ipairs(entry.level1Moves or {}) do
      if candidate == move then return true end
    end
    for _, candidate in ipairs(entry.tmhm or {}) do
      if candidate == move then return true end
    end
    for _, row in ipairs(entry.learnset or {}) do
      if type(row) == "table" and row.move == move then return true end
    end
    return false
  end

  local function specialMove(classId, partyIndex, slotIndex, species)
    local lone = LONE_MOVES[classId]
    if lone and lone.slot == slotIndex then return lone.move end
    if classId == "OPP_GIOVANNI" and partyIndex == 3
        and slotIndex == 5 then return "FISSURE" end
    if TEAM_MOVES[classId] and slotIndex == 5 then
      return TEAM_MOVES[classId]
    end
    if classId == "OPP_RIVAL3" and slotIndex == 1 then
      return "SKY_ATTACK"
    end
    if classId == "OPP_RIVAL3" and slotIndex == 6 then
      if species == "VENUSAUR" then return "MEGA_DRAIN" end
      if species == "CHARIZARD" then return "FIRE_BLAST" end
      if species == "BLASTOISE" then return "BLIZZARD" end
    end
  end

  local function partyMaximum(party)
    local maximum = 2
    for _, slot in ipairs(party or {}) do
      if type(slot) == "table" and type(slot.level) == "number" then
        maximum = math.max(maximum, slot.level)
      end
    end
    return maximum
  end

  local function adjustedLevel(level, maximum, mode, rng)
    if mode == "plus_minus_10" then
      return clamp(level * rng:nextInt(90, 110) / 100)
    end
    if mode == "progressive" then
      local percent = maximum <= 15 and -20
        or maximum <= 30 and -10
        or maximum <= 45 and 0
        or maximum <= 60 and 10 or 20
      return clamp(level * (100 + percent) / 100)
    end
    return clamp(level)
  end

  local function allTypes(manifest)
    local found = {}
    for _, entry in ipairs(manifest.entries) do
      for _, typeId in ipairs(entry.types or {}) do found[typeId] = true end
    end
    return StableSort.keys(found)
  end

  local function rules(settings, theme, excluded, early)
    return {
      strengthPercent = tonumber(settings.similar_strength),
      legendary = early and settings.progression_guard == "on"
        and "exclude" or (settings.legendaries or "allow"),
      requiredType = theme,
      allowTypeRelaxation = theme ~= nil,
      excludeIds = excluded,
    }
  end

  local function earlyCandidates(candidates, early)
    if not early then return candidates end
    local output = {}
    for _, entry in ipairs(candidates) do
      if not entry.legendary and entry.bst <= 450
          and #movesAtLevel(entry, 14) > 0 then
        output[#output + 1] = entry
      end
    end
    return output
  end

  local function withoutSource(candidates, source)
    local output = {}
    for _, entry in ipairs(candidates) do
      if entry.id ~= source then output[#output + 1] = entry end
    end
    return output
  end

  local function choose(manifest, source, settings, theme, rng, used, early)
    local unique = settings.duplicate_policy == "one_to_one"
    local candidates, diagnostics = SpeciesFilters.candidates(
      manifest, source, rules(settings, theme, unique and used or nil, early))
    candidates = earlyCandidates(candidates, early)
    if #candidates == 0 and unique then
      candidates, diagnostics = SpeciesFilters.candidates(
        manifest, source, rules(settings, theme, nil, early))
      candidates = earlyCandidates(candidates, early)
      if #candidates > 0 then
        for id in pairs(used) do used[id] = nil end
      end
    end
    if #candidates == 0 and theme then
      candidates, diagnostics = SpeciesFilters.candidates(
        manifest, source, rules(
          settings, nil, unique and used or nil, early))
      candidates = earlyCandidates(candidates, early)
    end
    if #candidates == 0 then return nil, diagnostics end
    -- A randomizer result that selects the source species is technically
    -- valid but visibly indistinguishable from vanilla. Prefer a real
    -- replacement whenever the active constraints leave any alternative.
    local replacements = withoutSource(candidates, source)
    if #replacements == 0 and unique then
      local restarted = SpeciesFilters.candidates(
        manifest, source, rules(settings, theme, nil, early))
      restarted = earlyCandidates(restarted, early)
      replacements = withoutSource(restarted, source)
      if #replacements > 0 then
        for id in pairs(used) do used[id] = nil end
      end
    end
    if #replacements > 0 then candidates = replacements end
    local chosen = candidates[rng:nextInt(1, #candidates)].id
    if unique then used[chosen] = true end
    return chosen, diagnostics
  end

  local function globalMap(manifest, trainers, settings, rng)
    local sources = {}
    for _, classId in ipairs(StableSort.keys(trainers)) do
      for _, party in ipairs(trainers[classId].parties or {}) do
        for _, slot in ipairs(party) do
          if manifest.byId[slot.species] then sources[slot.species] = true end
        end
      end
    end
    local mapping, used = {}, {}
    for _, source in ipairs(StableSort.keys(sources)) do
      local species = choose(
        manifest, source, settings, nil, rng, used,
        settings.progression_guard == "on")
      assert(species, "global trainer species has no candidate")
      mapping[source] = species
    end
    return mapping
  end

  function Category.generate(manifest, sources, settings, rngs)
    assert(type(manifest) == "table", "species manifest is required")
    assert(type(settings) == "table", "trainer settings are required")
    assert(type(rngs) == "table", "trainer RNG streams are required")
    local result = { trainerParties = {}, warnings = {}, fallbackCount = 0 }
    if settings.trainer_pokemon == nil
        or settings.trainer_pokemon == "off" then return result end
    local trainers = type(sources) == "table" and sources.trainers or nil
    assert(type(trainers) == "table", "merged trainer registry is required")
    local themes = allTypes(manifest)
    assert(#themes > 0, "trainer type theme pool is empty")
    local global = settings.trainer_pokemon == "global_map"
      and globalMap(manifest, trainers, settings, rngs.species) or nil
    local used = {}

    for _, classId in ipairs(StableSort.keys(trainers)) do
      local trainer = trainers[classId]
      local parties = type(trainer) == "table" and trainer.parties
      if type(parties) == "table"
          and not (BOSSES[classId] and settings.boss_trainers == "vanilla") then
        local themed = settings.trainer_pokemon == "type_themed"
          or (BOSSES[classId] and settings.boss_trainers == "themed")
        local theme = themed
          and themes[rngs.species:nextInt(1, #themes)] or nil
        local classMappings = {}
        if theme then classMappings.theme = theme end
        for partyIndex, sourceParty in ipairs(parties) do
          assert(type(sourceParty) == "table" and #sourceParty > 0,
            "trainer parties must be non-empty arrays")
          local maximum = partyMaximum(sourceParty)
          local early = settings.progression_guard == "on" and maximum <= 14
          local size = #sourceParty
          if settings.party_size == "random_1_6" then
            size = rngs.sizes:nextInt(1, early and 3 or 6)
          end
          if BOSSES[classId] and settings.boss_trainers == "themed" then
            size = #sourceParty
          end
          if classId == "OPP_RIVAL1" and maximum <= 5 then size = 1 end
          local mappedParty = {}
          for slotIndex = 1, size do
            local sourceSlot = sourceParty[
              ((slotIndex - 1) % #sourceParty) + 1]
            assert(type(sourceSlot) == "table"
                and manifest.byId[sourceSlot.species],
              ("trainer source species is not eligible: %s party %d "
                .. "slot %d species %s"):format(
                classId, partyIndex, slotIndex,
                tostring(type(sourceSlot) == "table"
                  and sourceSlot.species or nil)))
            local level = adjustedLevel(
              sourceSlot.level, maximum, settings.trainer_levels, rngs.levels)
            if classId == "OPP_RIVAL1" and maximum <= 5
                and settings.progression_guard == "on" then
              local starterLevel = tonumber(settings.starter_level) or 5
              level = math.min(level, clamp(starterLevel + 3))
            end
            local species = global and global[sourceSlot.species]
              or choose(manifest, sourceSlot.species, settings, theme,
                rngs.species, used, early)
            assert(species, "trainer slot has no candidate")
            local row = { species = species, level = level }
            if type(sourceSlot.moves) == "table" then
              row.moves = copyArray(sourceSlot.moves)
            else
              local special = specialMove(
                classId, partyIndex, slotIndex, species)
              local entry = manifest.byId[species]
              if special and not moveLegal(entry, special) then
                row.moves = movesAtLevel(entry, level)
              end
            end
            mappedParty[slotIndex] = row
          end
          classMappings[partyIndex] = mappedParty
        end
        result.trainerParties[classId] = classMappings
      end
    end
    return result
  end

  Category.bosses = BOSSES
  Category.movesAtLevel = movesAtLevel
  Category.moveLegal = moveLegal
  return Category
end
