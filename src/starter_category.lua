-- Milestone-10 deterministic starter choice and rival projection generation.
return function(StableSort)
  local StarterCategory = {}

  local SLOT_ORDER = { "LEFT", "MIDDLE", "RIGHT" }
  local BASE = {
    LEFT = {
      species = "CHARMANDER",
      choseFlag = "EVENT_CHOSE_CHARMANDER",
      ballObject = "OAKSLAB_CHARMANDER_POKE_BALL",
    },
    MIDDLE = {
      species = "SQUIRTLE",
      choseFlag = "EVENT_CHOSE_SQUIRTLE",
      ballObject = "OAKSLAB_SQUIRTLE_POKE_BALL",
    },
    RIGHT = {
      species = "BULBASAUR",
      choseFlag = "EVENT_CHOSE_BULBASAUR",
      ballObject = "OAKSLAB_BULBASAUR_POKE_BALL",
    },
  }
  local BALL_ORDER = {
    LEFT = "MIDDLE",
    MIDDLE = "RIGHT",
    RIGHT = "LEFT",
  }
  local YELLOW_SLOT = "YELLOW"

  -- Generation-I attacking type effectiveness. Missing pairs are neutral.
  local SUPER = {
    FIRE = { GRASS = true, ICE = true, BUG = true },
    WATER = { FIRE = true, GROUND = true, ROCK = true },
    ELECTRIC = { WATER = true, FLYING = true },
    GRASS = { WATER = true, GROUND = true, ROCK = true },
    ICE = { GRASS = true, GROUND = true, FLYING = true, DRAGON = true },
    FIGHTING = { NORMAL = true, ICE = true, ROCK = true },
    POISON = { GRASS = true, BUG = true },
    GROUND = {
      FIRE = true, ELECTRIC = true, POISON = true, ROCK = true,
    },
    FLYING = { GRASS = true, FIGHTING = true, BUG = true },
    PSYCHIC_TYPE = { FIGHTING = true, POISON = true },
    BUG = { GRASS = true, POISON = true, PSYCHIC_TYPE = true },
    ROCK = { FIRE = true, ICE = true, FLYING = true, BUG = true },
    GHOST = { GHOST = true },
    DRAGON = { DRAGON = true },
  }
  local RESIST = {
    NORMAL = { ROCK = true },
    FIRE = { FIRE = true, WATER = true, ROCK = true, DRAGON = true },
    WATER = { WATER = true, GRASS = true, DRAGON = true },
    ELECTRIC = { ELECTRIC = true, GRASS = true, DRAGON = true },
    GRASS = {
      FIRE = true, GRASS = true, POISON = true, FLYING = true,
      BUG = true, DRAGON = true,
    },
    ICE = { WATER = true, ICE = true },
    FIGHTING = {
      POISON = true, FLYING = true, PSYCHIC_TYPE = true, BUG = true,
    },
    POISON = { POISON = true, GROUND = true, ROCK = true, GHOST = true },
    GROUND = { GRASS = true, BUG = true },
    FLYING = { ELECTRIC = true, ROCK = true },
    PSYCHIC_TYPE = { PSYCHIC_TYPE = true },
    BUG = {
      FIRE = true, FIGHTING = true, FLYING = true, GHOST = true,
    },
    ROCK = { FIGHTING = true, GROUND = true },
    GHOST = { NORMAL = true, PSYCHIC_TYPE = true },
    DRAGON = { DRAGON = true },
  }
  local IMMUNE = {
    NORMAL = { GHOST = true },
    ELECTRIC = { GROUND = true },
    FIGHTING = { GHOST = true },
    GROUND = { FLYING = true },
    GHOST = { NORMAL = true },
  }

  local function effectiveness(attacking, defending, mergedChart)
    local merged = type(mergedChart) == "table"
        and type(mergedChart[attacking]) == "table"
        and mergedChart[attacking][defending]
    if type(merged) == "number" then return merged end
    if IMMUNE[attacking] and IMMUNE[attacking][defending] then return 0 end
    if SUPER[attacking] and SUPER[attacking][defending] then return 2 end
    if RESIST[attacking] and RESIST[attacking][defending] then return 0.5 end
    return 1
  end

  local function matchup(attacker, defender, mergedChart)
    local best = 0
    for _, attackType in ipairs(attacker.types or {}) do
      local score = 1
      for _, defendType in ipairs(defender.types or {}) do
        score = score * effectiveness(attackType, defendType, mergedChart)
      end
      if score > best then best = score end
    end
    return best
  end

  local function eligibleEntries(manifest, settings)
    local rows = {}
    for _, entry in ipairs(manifest.entries or {}) do
      local stageOkay = settings.starter_stage ~= "basic_only"
        or entry.stage == "basic"
      local legendaryOkay = settings.legendaries == "allow"
        or not entry.legendary
      if stageOkay and legendaryOkay then rows[#rows + 1] = entry end
    end
    return rows
  end

  local function randomThree(entries, rng)
    if #entries < 3 then return nil end
    local shuffled = rng:shuffle(entries)
    return { shuffled[1], shuffled[2], shuffled[3] }
  end

  local function randomTwo(entries, rng)
    if #entries < 2 then return nil end
    local shuffled = rng:shuffle(entries)
    return { shuffled[1], shuffled[2] }
  end

  local function typeTriad(entries, rng, mergedChart)
    local byType = {}
    for _, entry in ipairs(entries) do
      local primary = entry.primaryType
      if type(primary) == "string" and primary ~= "" then
        byType[primary] = byType[primary] or {}
        byType[primary][#byType[primary] + 1] = entry
      end
    end
    local types = StableSort.keys(byType)
    local cycles = {}
    for _, first in ipairs(types) do
      for _, second in ipairs(types) do
        if second ~= first
            and effectiveness(first, second, mergedChart) > 1 then
          for _, third in ipairs(types) do
            if third ~= first and third ~= second
                and effectiveness(second, third, mergedChart) > 1
                and effectiveness(third, first, mergedChart) > 1 then
              cycles[#cycles + 1] = { first, second, third }
            end
          end
        end
      end
    end
    if #cycles == 0 then return nil end
    local cycle = cycles[rng:nextInt(1, #cycles)]
    local result = {}
    for index, typeId in ipairs(cycle) do
      local bucket = byType[typeId]
      result[index] = bucket[rng:nextInt(1, #bucket)]
    end
    return result
  end

  local function rivalSlot(
      chosenSlot, chosen, entriesBySlot, settings, rng, mergedChart)
    if settings.rival_counterpick == "ball_order" then
      return BALL_ORDER[chosenSlot]
    end
    local others = {}
    for _, slotId in ipairs(SLOT_ORDER) do
      if slotId ~= chosenSlot then others[#others + 1] = slotId end
    end
    if settings.rival_counterpick == "random_other" then
      return others[rng:nextInt(1, #others)]
    end
    local bestSlot, bestScore
    for _, slotId in ipairs(others) do
      local score = matchup(entriesBySlot[slotId], chosen, mergedChart)
      if bestScore == nil or score > bestScore then
        bestSlot, bestScore = slotId, score
      end
    end
    return bestSlot
  end

  local function yellowChoices(entries, settings, rngs, mergedChart)
    local choices
    if settings.starters == "type_triad" then
      choices = typeTriad(entries, rngs.starters, mergedChart)
    end
    if not choices then choices = randomTwo(entries, rngs.starters) end
    if not choices then return nil end

    local player = choices[1]
    local rivals = {}
    for _, entry in ipairs(entries) do
      if entry.id ~= player.id then rivals[#rivals + 1] = entry end
    end
    if #rivals == 0 then return nil end
    local rival
    if settings.rival_counterpick == "type_advantage" then
      local best, tied = -1, {}
      for _, entry in ipairs(rivals) do
        local score = matchup(entry, player, mergedChart)
        if score > best then
          best, tied = score, { entry }
        elseif score == best then
          tied[#tied + 1] = entry
        end
      end
      rival = tied[rngs.rival:nextInt(1, #tied)]
    elseif #choices >= 2 then
      rival = choices[2]
    else
      rival = rivals[rngs.rival:nextInt(1, #rivals)]
    end
    return player, rival
  end

  local function generateYellow(
      result, manifest, settings, rngs, mergedChart)
    local candidates = eligibleEntries(manifest, settings)
    local player, rival = yellowChoices(
      candidates, settings, rngs, mergedChart)
    if not player or not rival then
      result.warnings[#result.warnings + 1] = {
        code = "STARTER_GENERATION_FAILED",
        message = "fewer than two eligible unique Yellow starters; using vanilla",
      }
      result.fallbackCount = 1
      return result
    end
    local level = tonumber(settings.starter_level) or 5
    level = math.max(2, math.min(20, math.floor(level)))
    result.starters[YELLOW_SLOT] = {
      slotId = YELLOW_SLOT,
      starterIndex = 1,
      species = player.id,
      level = level,
      choseFlag = "EVENT_CHOSE_PIKACHU",
      ballObject = "YELLOW_STARTER_GIFT",
      rivalBall = "OAKSLAB_EEVEE_POKE_BALL",
      rivalSlot = "YELLOW_RIVAL",
      rivalSpecies = rival.id,
      gameVersion = "yellow",
    }
    result.starterFlags = {
      gameVersion = "yellow",
      partyOffsetSlots = { YELLOW_SLOT, YELLOW_SLOT, YELLOW_SLOT },
      choiceFlags = { [YELLOW_SLOT] = "EVENT_CHOSE_PIKACHU" },
    }
    return result
  end

  function StarterCategory.generate(
      manifest, settings, rngs, mergedChart, gameVersion)
    assert(type(manifest) == "table", "species manifest is required")
    assert(type(settings) == "table", "starter settings are required")
    assert(type(rngs) == "table" and type(rngs.starters) == "table"
        and type(rngs.rival) == "table", "starter RNG streams are required")

    local result = {
      starters = {},
      starterFlags = {},
      warnings = {},
      fallbackCount = 0,
    }
    if settings.starters == nil or settings.starters == "off" then
      return result
    end

    if string.lower(tostring(gameVersion or "red")) == "yellow" then
      return generateYellow(result, manifest, settings, rngs, mergedChart)
    end

    local candidates = eligibleEntries(manifest, settings)
    local choices
    if settings.starters == "type_triad" then
      choices = typeTriad(candidates, rngs.starters, mergedChart)
      if not choices then
        result.warnings[#result.warnings + 1] = {
          code = "STARTER_TRIAD_UNAVAILABLE",
          message = "no primary-type cycle exists; using three random starters",
        }
        choices = randomThree(candidates, rngs.starters)
      end
    else
      choices = randomThree(candidates, rngs.starters)
    end
    if not choices then
      result.warnings[#result.warnings + 1] = {
        code = "STARTER_GENERATION_FAILED",
        message = "fewer than three eligible unique starters; using vanilla",
      }
      result.fallbackCount = 1
      return result
    end

    local level = tonumber(settings.starter_level) or 5
    level = math.max(2, math.min(20, math.floor(level)))
    local entriesBySlot = {}
    for index, slotId in ipairs(SLOT_ORDER) do
      entriesBySlot[slotId] = choices[index]
    end
    for _, slotId in ipairs(SLOT_ORDER) do
      local base = BASE[slotId]
      local rival = rivalSlot(
        slotId, entriesBySlot[slotId], entriesBySlot,
        settings, rngs.rival, mergedChart)
      result.starters[slotId] = {
        slotId = slotId,
        starterIndex = ({ LEFT = 1, MIDDLE = 2, RIGHT = 3 })[slotId],
        species = entriesBySlot[slotId].id,
        level = level,
        choseFlag = base.choseFlag,
        ballObject = base.ballObject,
        rivalBall = BASE[rival].ballObject,
        rivalSlot = rival,
        rivalSpecies = entriesBySlot[rival].id,
      }
    end
    result.starterFlags = {
      partyOffsetSlots = { "LEFT", "MIDDLE", "RIGHT" },
      choiceFlags = {
        LEFT = BASE.LEFT.choseFlag,
        MIDDLE = BASE.MIDDLE.choseFlag,
        RIGHT = BASE.RIGHT.choseFlag,
      },
    }
    return result
  end

  StarterCategory.effectiveness = effectiveness
  StarterCategory.matchup = matchup
  StarterCategory.slotOrder = SLOT_ORDER
  return StarterCategory
end
