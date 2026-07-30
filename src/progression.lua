return function(StableSort)
  local Progression = {}

  Progression.STAGES = {
    START = 0,
    PEWTER = 1,
    CERULEAN = 2,
    VERMILION = 3,
    LAVENDER_CELADON = 4,
    FUCHSIA = 5,
    SURF = 6,
    LATE_STORY = 7,
    VICTORY_ROAD = 8,
    POSTGAME = 9,
  }
  Progression.PRE_ELITE_FOUR_MAX = Progression.STAGES.VICTORY_ROAD

  Progression.GRAPH = {
    [0] = { id = "START", previous = nil, gates = {} },
    [1] = { id = "PEWTER", previous = 0, gates = {} },
    [2] = { id = "CERULEAN", previous = 1, gates = { "BOULDER_BADGE" } },
    [3] = {
      id = "VERMILION", previous = 2,
      gates = { "CASCADE_BADGE", "HM01_CUT", "S_S_ANNE_CLEARED" },
    },
    [4] = {
      id = "LAVENDER_CELADON", previous = 3,
      gates = { "HM05_FLASH", "ROCK_TUNNEL_CROSSED" },
    },
    [5] = {
      id = "FUCHSIA", previous = 4,
      gates = { "POKE_FLUTE", "SAFARI_PASS" },
    },
    [6] = {
      id = "SURF", previous = 5,
      gates = { "HM03_SURF", "SOUL_BADGE" },
    },
    [7] = {
      id = "LATE_STORY", previous = 6,
      gates = { "SILPH_CO_CLEARED" },
    },
    [8] = {
      id = "VICTORY_ROAD", previous = 7,
      gates = { "ALL_EIGHT_BADGES", "HM04_STRENGTH" },
    },
    [9] = {
      id = "POSTGAME", previous = 8,
      gates = { "ELITE_FOUR_DEFEATED" },
    },
  }

  local STAGE_NAMES = {
    [0] = "Pallet/Viridian",
    [1] = "Pewter",
    [2] = "Cerulean",
    [3] = "Vermilion/Cut",
    [4] = "Lavender/Celadon",
    [5] = "Fuchsia/Safari",
    [6] = "Surf/Cinnabar",
    [7] = "Late story",
    [8] = "Victory Road",
    [9] = "Postgame",
  }

  local SUPPORTED_VERSIONS = {
    red = true,
    blue = true,
  }

  local EXACT_MAPS = {
    PALLET_TOWN = { stage = 0 },
    ROUTE_1 = { stage = 0 },
    VIRIDIAN_CITY = { stage = 0 },
    ROUTE_22 = { stage = 0 },
    ROUTE_2 = { stage = 0 },
    VIRIDIAN_FOREST = { stage = 0 },

    PEWTER_CITY = { stage = 1 },
    ROUTE_3 = { stage = 1, requirements = { "BOULDER_BADGE" } },
    MT_MOON_1F = { stage = 1, requirements = { "BOULDER_BADGE" } },
    MT_MOON_B1F = { stage = 1, requirements = { "BOULDER_BADGE" } },
    MT_MOON_B2F = { stage = 1, requirements = { "BOULDER_BADGE" } },

    ROUTE_4 = { stage = 2 },
    CERULEAN_CITY = { stage = 2 },
    ROUTE_24 = { stage = 2 },
    ROUTE_25 = { stage = 2 },

    ROUTE_5 = { stage = 2 },
    UNDERGROUND_PATH_ROUTE_5 = { stage = 2 },
    ROUTE_6 = { stage = 3 },
    VERMILION_CITY = { stage = 3 },
    ROUTE_11 = { stage = 3 },
    DIGLETTS_CAVE = { stage = 3 },
    DIGLETTS_CAVE_ENTRANCE_ROUTE_2 = { stage = 3, requirements = { "HM01_CUT" } },
    DIGLETTS_CAVE_ENTRANCE_ROUTE_11 = { stage = 3 },

    ROUTE_7 = { stage = 4 },
    ROUTE_8 = { stage = 4 },
    ROUTE_9 = { stage = 4, requirements = { "HM01_CUT" } },
    ROUTE_10 = { stage = 4, requirements = { "HM01_CUT" } },
    ROCK_TUNNEL_1F = { stage = 4, requirements = { "HM05_FLASH" } },
    ROCK_TUNNEL_B1F = { stage = 4, requirements = { "HM05_FLASH" } },
    LAVENDER_TOWN = { stage = 4 },
    POKEMON_TOWER_3F = { stage = 4, requirements = { "SILPH_SCOPE" } },
    POKEMON_TOWER_4F = { stage = 4, requirements = { "SILPH_SCOPE" } },
    POKEMON_TOWER_5F = { stage = 4, requirements = { "SILPH_SCOPE" } },
    POKEMON_TOWER_6F = { stage = 4, requirements = { "SILPH_SCOPE" } },
    POKEMON_TOWER_7F = { stage = 4, requirements = { "SILPH_SCOPE" } },
    CELADON_CITY = { stage = 4 },
    CELADON_MANSION_ROOF_HOUSE = { stage = 4 },
    MT_MOON_POKECENTER = { stage = 1 },

    ROUTE_12 = { stage = 5, requirements = { "POKE_FLUTE" } },
    ROUTE_13 = { stage = 5, requirements = { "POKE_FLUTE" } },
    ROUTE_14 = { stage = 5 },
    ROUTE_15 = { stage = 5 },
    ROUTE_16 = { stage = 5, requirements = { "POKE_FLUTE" } },
    ROUTE_17 = { stage = 5, requirements = { "POKE_FLUTE" } },
    ROUTE_18 = { stage = 5 },
    FUCHSIA_CITY = { stage = 5 },
    FIGHTING_DOJO = {
      stage = 4,
      requirements = { "SAFFRON_ACCESS" },
    },
    SILPH_CO_7F = { stage = 7, requirements = { "SILPH_CO_ACCESS" } },

    ROUTE_19 = { stage = 6, requirements = { "HM03_SURF", "SOUL_BADGE" } },
    ROUTE_20 = { stage = 6, requirements = { "HM03_SURF", "SOUL_BADGE" } },
    ROUTE_21 = { stage = 6, requirements = { "HM03_SURF", "SOUL_BADGE" } },
    SEAFOAM_ISLANDS_1F = { stage = 6, requirements = { "HM03_SURF", "SOUL_BADGE" } },
    SEAFOAM_ISLANDS_B1F = { stage = 6, requirements = { "HM03_SURF", "SOUL_BADGE" } },
    SEAFOAM_ISLANDS_B2F = { stage = 6, requirements = { "HM03_SURF", "SOUL_BADGE" } },
    SEAFOAM_ISLANDS_B3F = { stage = 6, requirements = { "HM03_SURF", "SOUL_BADGE" } },
    SEAFOAM_ISLANDS_B4F = { stage = 6, requirements = { "HM03_SURF", "SOUL_BADGE" } },
    POWER_PLANT = { stage = 6, requirements = { "HM03_SURF", "SOUL_BADGE" } },
    CINNABAR_ISLAND = { stage = 6, requirements = { "HM03_SURF", "SOUL_BADGE" } },
    CINNABAR_LAB_FOSSIL_ROOM = { stage = 6, requirements = { "HM03_SURF", "SOUL_BADGE" } },
    POKEMON_MANSION_1F = { stage = 6, requirements = { "HM03_SURF", "SOUL_BADGE" } },
    POKEMON_MANSION_2F = { stage = 6, requirements = { "HM03_SURF", "SOUL_BADGE" } },
    POKEMON_MANSION_3F = { stage = 6, requirements = { "HM03_SURF", "SOUL_BADGE" } },
    POKEMON_MANSION_B1F = { stage = 6, requirements = { "HM03_SURF", "SOUL_BADGE" } },

    ROUTE_23 = {
      stage = 8,
      requirements = { "ALL_EIGHT_BADGES", "HM03_SURF", "HM04_STRENGTH" },
    },
    VICTORY_ROAD_1F = {
      stage = 8,
      requirements = { "ALL_EIGHT_BADGES", "HM04_STRENGTH" },
    },
    VICTORY_ROAD_2F = {
      stage = 8,
      requirements = { "ALL_EIGHT_BADGES", "HM04_STRENGTH" },
    },
    VICTORY_ROAD_3F = {
      stage = 8,
      requirements = { "ALL_EIGHT_BADGES", "HM04_STRENGTH" },
    },
  }

  local TRADE_STAGES = {
    ROUTE_11_GATE_2F = 3,
    ROUTE_2_TRADE_HOUSE = 3,
    CINNABAR_LAB_FOSSIL_ROOM = 6,
    VERMILION_TRADE_HOUSE = 3,
    ROUTE_18_GATE_2F = 5,
    CERULEAN_TRADE_HOUSE = 2,
    CINNABAR_LAB_TRADE_ROOM = 6,
    UNDERGROUND_PATH_ROUTE_5 = 2,
  }

  local ROD_REQUIREMENTS = {
    OLD_ROD = { stage = 3, requirement = "OLD_ROD" },
    GOOD_ROD = { stage = 5, requirement = "GOOD_ROD" },
    SUPER_ROD = { stage = 5, requirement = "SUPER_ROD" },
  }

  local function copyArray(values)
    local result = {}
    for index, value in ipairs(values or {}) do
      result[index] = value
    end
    return result
  end

  local function appendUnique(target, value)
    for _, existing in ipairs(target) do
      if existing == value then
        return
      end
    end
    target[#target + 1] = value
  end

  local function normalizedVersion(version)
    return string.lower(tostring(version or "red"))
  end

  function Progression.locationName(mapId)
    if mapId == "*" then return "Any fishable area" end
    local words = {}
    for token in string.gmatch(tostring(mapId or ""), "[^_]+") do
      if token == "POKEMON" then
        words[#words + 1] = "Pokémon"
      elseif token == "MT" then
        words[#words + 1] = "Mt."
      elseif string.match(token, "^%d+F$") or string.match(token, "^B%d+F$") then
        words[#words + 1] = token
      else
        words[#words + 1] =
          string.upper(string.sub(token, 1, 1))
          .. string.lower(string.sub(token, 2))
      end
    end
    return #words > 0 and table.concat(words, " ") or "Unknown location"
  end

  local function safariRule(mapId)
    if string.match(mapId, "^SAFARI_ZONE_") then
      return {
        stage = Progression.STAGES.FUCHSIA,
        requirements = { "SAFARI_PASS" },
      }
    end
    return nil
  end

  local function postgameRule(mapId)
    if string.match(mapId, "^CERULEAN_CAVE") or string.match(mapId, "^UNKNOWN_DUNGEON") then
      return {
        stage = Progression.STAGES.POSTGAME,
        requirements = { "ELITE_FOUR_DEFEATED" },
        postgame = true,
      }
    end
    return nil
  end

  local function fallbackRule(mapId)
    local route = tonumber(string.match(mapId, "^ROUTE_(%d+)"))
    if route then
      if route <= 2 or route == 22 then return { stage = 0 } end
      if route == 3 then return { stage = 1, requirements = { "BOULDER_BADGE" } } end
      if route == 4 or route == 24 or route == 25 then return { stage = 2 } end
      if route == 5 then return { stage = 2 } end
      if route == 6 or route == 11 then return { stage = 3 } end
      if route >= 7 and route <= 10 then return { stage = 4 } end
      if route >= 12 and route <= 18 then return { stage = 5 } end
      if route >= 19 and route <= 21 then
        return { stage = 6, requirements = { "HM03_SURF", "SOUL_BADGE" } }
      end
      if route == 23 then
        return {
          stage = 8,
          requirements = { "ALL_EIGHT_BADGES", "HM03_SURF", "HM04_STRENGTH" },
        }
      end
    end

    if string.match(mapId, "^MT_MOON") then
      return { stage = 1, requirements = { "BOULDER_BADGE" } }
    end
    if string.match(mapId, "^ROCK_TUNNEL") then
      return { stage = 4, requirements = { "HM05_FLASH" } }
    end
    if string.match(mapId, "^POKEMON_TOWER") then
      return { stage = 4, requirements = { "SILPH_SCOPE" } }
    end
    if string.match(mapId, "^SAFARI_ZONE") then
      return { stage = 5, requirements = { "SAFARI_PASS" } }
    end
    if string.match(mapId, "^SEAFOAM_ISLANDS") or string.match(mapId, "^POKEMON_MANSION") then
      return { stage = 6, requirements = { "HM03_SURF", "SOUL_BADGE" } }
    end
    if string.match(mapId, "^VICTORY_ROAD") then
      return { stage = 8, requirements = { "ALL_EIGHT_BADGES", "HM04_STRENGTH" } }
    end
    return nil
  end

  local function baseMapRule(mapId)
    return EXACT_MAPS[mapId] or safariRule(mapId) or postgameRule(mapId) or fallbackRule(mapId)
  end

  function Progression.stageName(stage)
    return STAGE_NAMES[stage] or ("Stage " .. tostring(stage))
  end

  function Progression.access(mapId, method, rod, version)
    mapId = tostring(mapId or "")
    method = string.lower(tostring(method or "walk"))
    local gameVersion = normalizedVersion(version)
    local supported = SUPPORTED_VERSIONS[gameVersion] == true
    local rule

    if mapId == "*" and method == "fish" then
      rule = { stage = 0 }
    else
      rule = baseMapRule(mapId)
    end

    if not supported then
      return {
        available = false,
        known = rule ~= nil,
        mapId = mapId,
        locationName = Progression.locationName(mapId),
        method = method,
        rod = rod,
        version = gameVersion,
        reason = "unsupported version",
        requirements = {},
      }
    end
    if not rule then
      return {
        available = false,
        known = false,
        mapId = mapId,
        locationName = Progression.locationName(mapId),
        method = method,
        rod = rod,
        version = gameVersion,
        reason = "map is not present in the Red/Blue progression model",
        requirements = {},
      }
    end

    local stage = rule.stage
    local requirements = copyArray(rule.requirements)
    if method == "surf" then
      stage = math.max(stage, Progression.STAGES.SURF)
      appendUnique(requirements, "HM03_SURF")
      appendUnique(requirements, "SOUL_BADGE")
    elseif method == "fish" then
      local rodRule = ROD_REQUIREMENTS[tostring(rod or "")]
      if not rodRule then
        return {
          available = false,
          known = true,
          mapId = mapId,
          locationName = Progression.locationName(mapId),
          method = method,
          rod = rod,
          version = gameVersion,
          reason = "unknown fishing rod",
          requirements = requirements,
        }
      end
      stage = math.max(stage, rodRule.stage)
      appendUnique(requirements, rodRule.requirement)
    end

    requirements = StableSort.sort(
      requirements, function(a, b) return a < b end)
    return {
      available = true,
      known = true,
      mapId = mapId,
      locationName = Progression.locationName(mapId),
      method = method,
      rod = rod,
      version = gameVersion,
      stage = stage,
      stageName = Progression.stageName(stage),
      requirements = requirements,
      postgame = rule.postgame == true or stage > Progression.PRE_ELITE_FOUR_MAX,
    }
  end

  function Progression.tradeAccess(record, version)
    local mapId = tostring(record and record.mapId or "")
    local stage = TRADE_STAGES[mapId]
    local gameVersion = normalizedVersion(version)
    if not SUPPORTED_VERSIONS[gameVersion] then
      return {
        available = false,
        known = stage ~= nil,
        mapId = mapId,
        locationName = Progression.locationName(mapId),
        version = gameVersion,
        reason = "unsupported version",
      }
    end
    if stage == nil then
      return {
        available = false,
        known = false,
        mapId = mapId,
        locationName = Progression.locationName(mapId),
        version = gameVersion,
        reason = "trade location is not present in the progression model",
      }
    end
    return {
      available = true,
      known = true,
      mapId = mapId,
      locationName = Progression.locationName(mapId),
      version = gameVersion,
      stage = stage,
      stageName = Progression.stageName(stage),
    }
  end

  function Progression.isPreEliteFour(access)
    return access ~= nil
      and access.available == true
      and access.stage ~= nil
      and access.stage <= Progression.PRE_ELITE_FOUR_MAX
  end

  function Progression.isAvailableAt(access, stage)
    return access ~= nil
      and access.available == true
      and access.stage ~= nil
      and access.stage <= stage
  end

  function Progression.describe(access)
    if not access then
      return "unknown access"
    end
    if not access.available then
      return tostring(access.locationName or access.mapId or "unknown")
        .. ": " .. tostring(access.reason or "unavailable")
    end
    local suffix = ""
    if #(access.requirements or {}) > 0 then
      suffix = " [" .. table.concat(access.requirements, ", ") .. "]"
    end
    return tostring(access.locationName or access.mapId or "*")
      .. " via " .. tostring(access.method or "trade")
      .. " at " .. tostring(access.stageName)
      .. suffix
  end

  return Progression
end
