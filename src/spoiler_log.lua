-- Readable plaintext spoiler serialization and export.
return function()
  local Spoiler = {}

  local SETTING_GROUPS = {
    {
      "GENERAL",
      {
        "randomizer", "preset", "seed_mode", "seed_text", "species_pool",
        "similar_strength", "legendaries", "duplicate_policy",
        "generate_spoiler_log",
      },
    },
    {
      "WILD POKEMON",
      { "wild_pokemon", "fishing", "wild_levels", "catchability_guard" },
    },
    {
      "STARTERS",
      { "starters", "starter_stage", "starter_level", "rival_counterpick" },
    },
    {
      "STATIC ENCOUNTERS AND GIFTS",
      {
        "static_pokemon", "static_levels", "gift_pokemon", "gift_levels",
        "gift_uniqueness",
      },
    },
    {
      "IN-GAME TRADES",
      { "in_game_trades", "trade_fairness", "trade_evolution_safety" },
    },
    {
      "CELADON GAME CORNER",
      { "game_corner_pokemon", "prize_levels", "prize_prices" },
    },
    {
      "ITEMS",
      { "non_key_items", "tms", "hms", "key_items", "badges",
        "hidden_items",
        "ensure_beatable", "shops", "shop_prices" },
    },
    {
      "TRAINERS",
      {
        "trainer_pokemon", "trainer_levels", "boss_trainers",
        "rival_pokemon", "rival_keep_pokemon", "party_size",
        "progression_guard",
      },
    },
  }

  local SETTING_LABELS = {
    catchability_guard = "Pokemon Coverage",
    duplicate_policy = "Duplicate Policy",
    game_corner_pokemon = "Prize Pokemon",
    gift_pokemon = "Gift Pokemon",
    non_key_items = "Non-key Location",
    tms = "TM Location",
    hms = "HM Location",
    key_items = "Key Item Location",
    badges = "Badge Location",
    hidden_items = "Hidden Items",
    ensure_beatable = "Progression Safety",
    shops = "Shops",
    shop_prices = "Shop Prices",
    in_game_trades = "In-game Trades",
    legendaries = "Legendaries",
    party_size = "Party Size",
    prize_levels = "Prize Levels",
    prize_prices = "Prize Prices",
    progression_guard = "Trainer Safety",
    randomizer = "Randomizer",
    generate_spoiler_log = "Enable Spoiler Log",
    rival_counterpick = "Rival Counterpick",
    rival_keep_pokemon = "Rival Keep Pokemon",
    rival_pokemon = "Rival Pokemon",
    seed_mode = "Seed Mode",
    seed_text = "Seed Text",
    similar_strength = "Similar Strength",
    species_pool = "Species Pool",
    starter_level = "Starter Level",
    starter_stage = "Starter Stage",
    static_pokemon = "Static Pokemon",
    trade_evolution_safety = "Trade Validity",
    trainer_pokemon = "Trainer Pokemon",
    wild_pokemon = "Wild Pokemon",
  }

  local SPECIAL_NAMES = {
    FARFETCHD = "Farfetch'd",
    MR_MIME = "Mr. Mime",
    NIDORAN_F = "Nidoran F",
    NIDORAN_M = "Nidoran M",
  }

  local ENCOUNTER_LABELS = {
    POWER_PLANT_VOLTORB_0 = "Fake item #1",
    POWER_PLANT_VOLTORB_1 = "Fake item #2",
    POWER_PLANT_VOLTORB_2 = "Fake item #3",
    POWER_PLANT_ELECTRODE_3 = "Fake item #4",
    POWER_PLANT_VOLTORB_4 = "Fake item #5",
    POWER_PLANT_VOLTORB_5 = "Fake item #6",
    POWER_PLANT_ELECTRODE_6 = "Fake item #7",
    POWER_PLANT_VOLTORB_7 = "Fake item #8",
    ZAPDOS = "Zapdos encounter",
    MEWTWO = "Mewtwo encounter",
    ARTICUNO = "Articuno encounter",
    MOLTRES = "Moltres encounter",
    SNORLAX_ROUTE_12 = "Route 12 Snorlax",
    SNORLAX_ROUTE_16 = "Route 16 Snorlax",
  }

  local GIFT_LABELS = {
    CELADON_EEVEE = "Celadon Mansion gift",
    MAGIKARP_SALE = "Route 4 Pokemon Center salesman",
    DOJO_LEFT = "Fighting Dojo left prize",
    DOJO_RIGHT = "Fighting Dojo right prize",
    SILPH_LAPRAS = "Silph Co. employee gift",
    FOSSIL_HELIX = "Cinnabar Lab - Helix Fossil",
    FOSSIL_DOME = "Cinnabar Lab - Dome Fossil",
    FOSSIL_OLD_AMBER = "Cinnabar Lab - Old Amber",
  }

  local TRADE_LABELS = {
    TRADE_01_TERRY = "Terry",
    TRADE_02_MARCEL = "Marcel",
    TRADE_04_SAILOR = "Sailor",
    TRADE_05_DUX = "Dux",
    TRADE_06_MARC = "Marc",
    TRADE_07_LOLA = "Lola",
    TRADE_08_DORIS = "Doris",
    TRADE_09_CRINKLES = "Crinkles",
    TRADE_10_SPOT = "Spot",
  }

  local TRADE_LOCATIONS = {
    TRADE_01_TERRY = "ROUTE_11_GATE_2F",
    TRADE_02_MARCEL = "ROUTE_2_TRADE_HOUSE",
    TRADE_04_SAILOR = "CINNABAR_LAB_FOSSIL_ROOM",
    TRADE_05_DUX = "VERMILION_TRADE_HOUSE",
    TRADE_06_MARC = "ROUTE_18_GATE_2F",
    TRADE_07_LOLA = "CERULEAN_TRADE_HOUSE",
    TRADE_08_DORIS = "CINNABAR_LAB_TRADE_ROOM",
    TRADE_09_CRINKLES = "CINNABAR_LAB_TRADE_ROOM",
    TRADE_10_SPOT = "UNDERGROUND_PATH_ROUTE_5",
    TRADE_01_GURIO = "ROUTE_11_GATE_2F",
    TRADE_02_MILES = "ROUTE_2_TRADE_HOUSE",
    TRADE_04_STICKY = "CINNABAR_LAB_FOSSIL_ROOM",
    TRADE_05_BART = "VERMILION_TRADE_HOUSE",
    TRADE_06_SPIKE = "ROUTE_18_GATE_2F",
    TRADE_07_MARTY = "CERULEAN_TRADE_HOUSE",
    TRADE_08_BUFFY = "CINNABAR_LAB_TRADE_ROOM",
    TRADE_09_CEZANNE = "CINNABAR_LAB_TRADE_ROOM",
    TRADE_10_RICKY = "UNDERGROUND_PATH_ROUTE_5",
  }

  local WORD_NAMES = {
    CO = "Co.",
    JR = "Jr.",
    LT = "Lt.",
    MT = "Mt.",
    OAKS = "Oak's",
    OPP = "",
    POKECENTER = "Pokemon Center",
    POKEMON = "Pokemon",
    PROF = "Prof.",
    SS = "S.S.",
  }

  local function sortedKeys(value)
    local keys = {}
    for key in pairs(type(value) == "table" and value or {}) do
      keys[#keys + 1] = key
    end
    table.sort(keys, function(left, right)
      if type(left) == type(right)
          and (type(left) == "string" or type(left) == "number") then
        return left < right
      end
      return tostring(left) < tostring(right)
    end)
    return keys
  end

  local function titleWord(word)
    if WORD_NAMES[word] ~= nil then return WORD_NAMES[word] end
    if word:match("^B%d+F$") or word:match("^%d+F$") then return word end
    local letters, number = word:match("^([A-Z]+)(%d+)$")
    if letters then
      return letters:sub(1, 1) .. letters:sub(2):lower() .. " " .. number
    end
    return word:sub(1, 1):upper() .. word:sub(2):lower()
  end

  local function readableId(value)
    value = tostring(value or "")
    if value == "" then return "(none)" end
    local words = {}
    for word in value:gmatch("[^_]+") do
      local formatted = titleWord(word)
      if formatted ~= "" then words[#words + 1] = formatted end
    end
    return table.concat(words, " ")
  end

  local function speciesName(value)
    if value == nil or value == "" then return "(none)" end
    return SPECIAL_NAMES[value] or readableId(value)
  end

  local function settingValue(value)
    if value == nil or value == "" then return "(blank)" end
    if type(value) == "boolean" then return value and "On" or "Off" end
    if type(value) == "number" then return tostring(value) end
    local names = {
      plus_minus_2 = "+/-2",
      plus_minus_10 = "+/-10%",
      random_5 = "Random +/-5",
      random_25 = "Random +/-25%",
      random_1_6 = "1-6 Random",
      vanilla151 = "Vanilla 151",
      fixed_15 = "Fixed 15",
      one_to_one = "One-to-one",
      ["10"] = "+/-10%",
      ["20"] = "+/-20%",
    }
    return names[value] or readableId(tostring(value):upper())
  end

  local function add(lines, value)
    lines[#lines + 1] = value or ""
  end

  local function section(lines, title)
    if #lines > 0 and lines[#lines] ~= "" then add(lines, "") end
    add(lines, ("=== %s ==="):format(title))
  end

  local function count(value)
    local total = 0
    for _ in pairs(type(value) == "table" and value or {}) do
      total = total + 1
    end
    return total
  end

  local function mappingLine(source, destination)
    return ("  %-20s -> %s"):format(
      speciesName(source), speciesName(destination))
  end

  local function levelText(value)
    return value ~= nil and (" Lv.%s"):format(tostring(value)) or ""
  end

  local function locationText(mapId)
    return mapId and readableId(mapId) or "Unknown location"
  end

  local function slotResult(row)
    if row.species then
      return speciesName(row.species) .. levelText(row.level)
    end
    if row.level then return "level override: Lv." .. tostring(row.level) end
    return "(no saved change)"
  end

  local function formatSettings(lines, settings)
    section(lines, "SETTINGS")
    local documented = {}
    for _, group in ipairs(SETTING_GROUPS) do
      add(lines, "")
      add(lines, group[1])
      for _, key in ipairs(group[2]) do
        documented[key] = true
        if settings[key] ~= nil then
          add(lines, ("  %-24s %s"):format(
            SETTING_LABELS[key] or readableId(key:upper()),
            settingValue(settings[key])))
        end
      end
    end
    local extra = {}
    for _, key in ipairs(sortedKeys(settings)) do
      if not documented[key]
          and key ~= "race_mode" and key ~= "spoiler_unlock" then
        extra[#extra + 1] = key
      end
    end
    if #extra > 0 then
      add(lines, "")
      add(lines, "OTHER")
      for _, key in ipairs(extra) do
        add(lines, ("  %-24s %s"):format(
          SETTING_LABELS[key] or readableId(tostring(key):upper()),
          settingValue(settings[key])))
      end
    end
  end

  local function formatWild(lines, mappings)
    section(lines, "WILD POKEMON - GLOBAL SPECIES")
    local global = mappings.wildGlobal or {}
    add(lines, ("Entries: %d"):format(count(global)))
    if next(global) == nil then
      add(lines, "  No global wild species mappings.")
    else
      for _, source in ipairs(sortedKeys(global)) do
        add(lines, mappingLine(source, global[source]))
      end
    end

    section(lines, "WILD POKEMON - AREA SLOTS")
    local areas = mappings.wildAreaSlots or {}
    local areaCount = 0
    local areaLines = {}
    for _, mapId in ipairs(sortedKeys(areas)) do
      for _, terrain in ipairs(sortedKeys(areas[mapId])) do
        for _, slot in ipairs(sortedKeys(areas[mapId][terrain])) do
          local row = areas[mapId][terrain][slot]
          if type(row) == "table" then
            add(areaLines, ("  %-28s %-8s slot %-2s -> %s"):format(
              locationText(mapId), readableId(terrain),
              tostring(slot), slotResult(row)))
            areaCount = areaCount + 1
          end
        end
      end
    end
    add(lines, ("Entries: %d"):format(areaCount))
    if areaCount == 0 then
      add(lines, "  No area-slot mappings or level overrides.")
    else
      for _, row in ipairs(areaLines) do add(lines, row) end
    end

    section(lines, "FISHING")
    local fishing = mappings.fishing or {}
    local fishGlobal = fishing.global or {}
    add(lines, "Global species mappings:")
    if next(fishGlobal) == nil then
      add(lines, "  None.")
    else
      for _, source in ipairs(sortedKeys(fishGlobal)) do
        add(lines, mappingLine(source, fishGlobal[source]))
      end
    end
    add(lines, "")
    add(lines, "Area slots and level overrides:")
    local fishCount = 0
    for _, rod in ipairs(sortedKeys(fishing.slots or {})) do
      for _, mapId in ipairs(sortedKeys(fishing.slots[rod])) do
        for _, slot in ipairs(sortedKeys(fishing.slots[rod][mapId])) do
          local row = fishing.slots[rod][mapId][slot]
          if type(row) == "table" then
            add(lines, ("  %-12s %-28s slot %-2s -> %s"):format(
              readableId(rod), locationText(mapId), tostring(slot),
              slotResult(row)))
            fishCount = fishCount + 1
          end
        end
      end
    end
    if fishCount == 0 then add(lines, "  None.") end
  end

  local function formatStarters(lines, mappings)
    section(lines, "STARTERS")
    local starters = mappings.starters or {}
    if next(starters) == nil then
      add(lines, "  Starters are vanilla.")
      return
    end
    local slots = starters.YELLOW and { "YELLOW" }
      or { "LEFT", "MIDDLE", "RIGHT" }
    for _, slot in ipairs(slots) do
      local row = starters[slot]
      if type(row) == "table" then
        local rival = row.rivalSpecies
          and ("; rival counterpick: " .. speciesName(row.rivalSpecies)) or ""
        add(lines, ("  %-12s %s%s%s"):format(
          (slot == "YELLOW" and "Yellow:" or readableId(slot) .. " ball:"),
          speciesName(row.species),
          levelText(row.level), rival))
      end
    end
  end

  local function formatEncounterGroup(lines, title, mappings, labels)
    section(lines, title)
    if next(mappings or {}) == nil then
      add(lines, "  No randomized entries.")
      return
    end
    for _, id in ipairs(sortedKeys(mappings)) do
      local row = mappings[id]
      if type(row) == "table" then
        local source = row.sourceSpecies
        local destination = row.species
        add(lines, ("  [%s] %s"):format(
          locationText(row.mapId), labels[id] or readableId(id)))
        add(lines, ("    %s%s -> %s%s%s"):format(
          speciesName(source), levelText(row.sourceLevel),
          speciesName(destination), levelText(row.level),
          row.price and ("; price: " .. tostring(row.price)) or ""))
      end
    end
  end

  local function formatTrades(lines, trades)
    section(lines, "IN-GAME TRADES")
    if next(trades or {}) == nil then
      add(lines, "  Trades are vanilla.")
      return
    end
    for _, id in ipairs(sortedKeys(trades)) do
      local row = trades[id]
      if type(row) == "table" then
        add(lines, ("  %s"):format(TRADE_LABELS[id] or readableId(id)))
        local mapId = row.mapId or TRADE_LOCATIONS[id]
        if mapId then
          add(lines, "    Location: " .. locationText(mapId))
        end
        local requested = row.requested or {}
        local received = row.received or {}
        add(lines, ("    Give:    %s -> %s"):format(
          speciesName(requested.sourceSpecies),
          speciesName(requested.species)))
        add(lines, ("    Receive: %s -> %s"):format(
          speciesName(received.sourceSpecies),
          speciesName(received.species)))
      end
    end
  end

  local function formatPrizes(lines, prizes)
    section(lines, "CELADON GAME CORNER PRIZES")
    if next(prizes or {}) == nil then
      add(lines, "  Pokemon prizes are vanilla.")
      return
    end
    for _, id in ipairs(sortedKeys(prizes)) do
      local row = prizes[id]
      if type(row) == "table" then
        local slot = id:match("_(%d+)$") or "?"
        add(lines, ("  %s slot %s"):format(
          readableId((row.version or "game"):upper()), slot))
        add(lines, ("    %s%s, %s coins -> %s%s, %s coins"):format(
          speciesName(row.sourceSpecies), levelText(row.sourceLevel),
          tostring(row.sourceCost or "?"), speciesName(row.species),
          levelText(row.level), tostring(row.cost or "?")))
      end
    end
  end

  local function formatTrainers(lines, trainers)
    section(lines, "TRAINER PARTIES")
    if next(trainers or {}) == nil then
      add(lines, "  Trainer parties are vanilla.")
      return
    end
    add(lines,
      "Each party number matches the party variant used by the game.")
    for _, classId in ipairs(sortedKeys(trainers)) do
      local class = trainers[classId]
      if type(class) == "table" then
        local theme = class.theme
          and (" (theme: " .. readableId(class.theme) .. ")") or ""
        add(lines, "")
        add(lines, ("  %s%s"):format(readableId(classId), theme))
        for _, partyIndex in ipairs(sortedKeys(class)) do
          if type(partyIndex) == "number"
              and type(class[partyIndex]) == "table" then
            local members = {}
            local party = class[partyIndex]
            local rivalStarters = type(class.rivalStarters) == "table"
              and class.rivalStarters[partyIndex]
            for memberIndex, member in ipairs(party) do
              if memberIndex == #party and type(rivalStarters) == "table"
                  and type(rivalStarters.species) == "string" then
                members[#members + 1] = speciesName(rivalStarters.species)
              elseif member.fallback == true then
                members[#members + 1] = ("Vanilla source slot %s"):format(
                  tostring(member.sourceSlot or "?"))
              else
                members[#members + 1] =
                  speciesName(member.species) .. levelText(member.level)
              end
            end
            local branch = ((partyIndex - 1) % 3) + 1
            local partyTheme = type(class.themes) == "table"
              and class.themes[branch]
            local themeText = partyTheme
              and (" (theme: " .. readableId(partyTheme) .. ")") or ""
            add(lines, ("    Party %-3s%s %s"):format(
              tostring(partyIndex), themeText,
              table.concat(members, ", ")))
          end
        end
      end
    end
  end

  local function formatFieldItems(lines, placements)
    section(lines, "ITEM LOCATIONS AND SHOPS")
    if #placements == 0 then
      add(lines, "  Items and shops are vanilla.")
      return
    end
    for _, row in ipairs(placements) do
      local position = row.kind == "hidden"
        and ("hidden at " .. tostring(row.x) .. "," .. tostring(row.y))
        or row.kind == "pc" and "starting PC storage"
        or row.kind == "scripted" and row.badge and "Gym badge reward"
        or row.kind == "scripted" and ("scripted gift " .. tostring(row.id))
        or row.kind == "shop" and ("shop " .. tostring(row.talkKey)
          .. " slot " .. tostring(row.slot))
        or ("object " .. tostring(row.objectIndex or "?"))
      local price = type(row.price) == "number"
        and ("; price " .. tostring(row.price)) or ""
      add(lines, ("  [%s; %s%s] %s -> %s"):format(
        locationText(row.mapId), position, price,
        readableId(row.original), readableId(row.item)))
    end
  end

  local function formatDiagnostics(lines, diagnostics)
    section(lines, "DIAGNOSTICS")
    diagnostics = diagnostics or {}
    local warnings = diagnostics.warnings or {}
    add(lines, ("Warnings: %d"):format(#warnings))
    add(lines, ("Fallbacks: %s"):format(
      tostring(diagnostics.fallbackCount or 0)))
    local validation = diagnostics.validation
    if type(validation) == "table" then
      add(lines, "")
      add(lines, "Validation summary:")
      if validation.mappingEntries ~= nil then
        add(lines, ("  Mapping entries:        %s"):format(
          tostring(validation.mappingEntries)))
      end
      if validation.reachableSpecies ~= nil then
        add(lines, ("  Reachable species:      %s"):format(
          tostring(validation.reachableSpecies)))
      end
      if validation.repairSwaps ~= nil then
        add(lines, ("  Reachability repairs:   %s"):format(
          tostring(validation.repairSwaps)))
      end
      if validation.mappingBytes ~= nil then
        add(lines, ("  Mapping bytes:           %s"):format(
          tostring(validation.mappingBytes)))
      end
      if validation.namespaceBytes ~= nil then
        add(lines, ("  Randomizer state bytes: %s / %s"):format(
          tostring(validation.namespaceBytes),
          tostring(validation.budgetBytes or 262144)))
      end
    end
    for index, warning in ipairs(warnings) do
      if type(warning) == "table" then
        local identity = warning.id and (" [" .. readableId(warning.id) .. "]")
          or ""
        add(lines, ("  %d. %s%s"):format(
          index, readableId(warning.code or "warning"), identity))
        if warning.message then add(lines, "     " .. warning.message) end
      else
        add(lines, ("  %d. %s"):format(index, tostring(warning)))
      end
    end
  end

  function Spoiler.text(run, options)
    assert(type(run) == "table", "active run is required")
    options = options or {}
    local lines = {
      "POKEMON GEN 1 RECOMP RANDOMIZER",
      "SPOILER LOG - READABLE FORMAT V2",
      "",
      "This file contains spoilers for the entire randomized run.",
    }
    local seed = run.seed or {}
    local compatibility = run.compatibility or {}
    section(lines, "RUN SUMMARY")
    add(lines, ("Seed:          %s"):format(
      tostring(seed.canonical or seed.display or "")))
    add(lines, ("Seed hash:     %s"):format(tostring(seed.hash128 or "")))
    add(lines, ("Algorithm:     %s"):format(
      tostring(run.algorithmVersion or "")))
    if compatibility.gameVersion then
      add(lines, ("Game version:  %s"):format(
        readableId(tostring(compatibility.gameVersion):upper())))
    end
    if compatibility.engineVersion then
      add(lines, ("Engine version: %s"):format(
        tostring(compatibility.engineVersion)))
    end
    add(lines, ("Settings hash: %s"):format(
      tostring(compatibility.settingsHash or "")))
    add(lines, ("Pool hash:     %s"):format(
      tostring(compatibility.poolHash or "")))
    if options.includeSettings ~= false then
      formatSettings(lines, run.settings or {})
    end
    local mappings = run.mappings or {}
    formatWild(lines, mappings)
    formatStarters(lines, mappings)
    formatEncounterGroup(lines, "STATIC ENCOUNTERS",
      mappings.staticEncounters or {}, ENCOUNTER_LABELS)
    formatEncounterGroup(lines, "GIFT POKEMON",
      mappings.gifts or {}, GIFT_LABELS)
    formatTrades(lines, mappings.trades or {})
    formatPrizes(lines, mappings.prizes or {})
    formatTrainers(lines, mappings.trainerParties or {})
    formatFieldItems(lines, mappings.fieldItems or {})
    formatDiagnostics(lines, run.diagnostics or {})
    add(lines, "")
    add(lines, "END OF SPOILER LOG")
    add(lines, "")
    return table.concat(lines, "\n")
  end

  local function filesystem(fs)
    fs = fs or (love and love.filesystem)
    if not (fs and type(fs.write) == "function") then
      return nil, "filesystem export is unavailable"
    end
    return fs
  end

  local function filename(run, suffix)
    local seed = tostring(run.seed and run.seed.hash128 or "UNKNOWN"):sub(1, 8)
    return "pokemon_randomizer/spoilers/" .. seed .. suffix
  end

  function Spoiler.export(run, options)
    options = options or {}
    local fs, fsError = filesystem(options.filesystem)
    if not fs then return nil, fsError end
    if fs.createDirectory then
      local ok, err = fs.createDirectory("pokemon_randomizer/spoilers")
      if ok == false then return nil, tostring(err) end
    end
    local content = Spoiler.text(run)
    local path = filename(run, ".txt")
    local ok, err = fs.write(path, content)
    if not ok then return nil, tostring(err or "spoiler write failed") end
    return { path = path, encrypted = false }, nil
  end

  function Spoiler.publicRun(run)
    if type(run) ~= "table" then return nil end
    local function clone(value, seen)
      if type(value) ~= "table" then return value end
      seen = seen or {}
      if seen[value] then return seen[value] end
      local output = {}
      seen[value] = output
      for key, child in pairs(value) do
        output[clone(key, seen)] = clone(child, seen)
      end
      return output
    end
    local output = clone(run)
    output.race = nil
    for key in pairs(output) do
      if type(key) == "string" and key:sub(1, 1) == "_" then
        output[key] = nil
      end
    end
    if type(output.settings) == "table" then
      output.settings.race_mode = nil
      output.settings.spoiler_unlock = nil
    end
    return output
  end

  return Spoiler
end
