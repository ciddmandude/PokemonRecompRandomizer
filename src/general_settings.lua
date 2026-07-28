-- Milestone-6 general settings semantics, preset bundles, and run identity.
return function(SaveState)
  local General = {}

  local PRESET_KEYS = {
    "species_pool",
    "similar_strength",
    "legendaries",
    "duplicate_policy",
    "wild_pokemon",
    "fishing",
    "wild_levels",
    "catchability_guard",
    "starters",
    "starter_stage",
    "starter_level",
    "rival_counterpick",
    "static_pokemon",
    "static_levels",
    "gift_pokemon",
    "gift_levels",
    "gift_uniqueness",
    "in_game_trades",
    "trade_fairness",
    "trade_evolution_safety",
    "game_corner_pokemon",
    "prize_levels",
    "prize_prices",
    "trainer_pokemon",
    "trainer_levels",
    "boss_trainers",
    "party_size",
    "progression_guard",
  }

  local PRESET_KEY_SET = {}
  for _, key in ipairs(PRESET_KEYS) do PRESET_KEY_SET[key] = true end

  local STANDARD = {
    species_pool = "vanilla151",
    similar_strength = "20",
    legendaries = "match",
    duplicate_policy = "one_to_one",
    wild_pokemon = "global_map",
    fishing = "randomized",
    wild_levels = "unchanged",
    catchability_guard = "on",
    starters = "random",
    starter_stage = "basic_only",
    starter_level = 5,
    rival_counterpick = "type_advantage",
    static_pokemon = "randomized",
    static_levels = "unchanged",
    gift_pokemon = "randomized",
    gift_levels = "unchanged",
    gift_uniqueness = "unique",
    in_game_trades = "both_sides",
    trade_fairness = "similar",
    trade_evolution_safety = "on",
    game_corner_pokemon = "randomized",
    prize_levels = "unchanged",
    prize_prices = "unchanged",
    trainer_pokemon = "by_slot",
    trainer_levels = "unchanged",
    boss_trainers = "themed",
    party_size = "unchanged",
    progression_guard = "on",
  }

  local CASUAL = {
    species_pool = "vanilla151",
    similar_strength = "10",
    legendaries = "exclude",
    duplicate_policy = "one_to_one",
    wild_pokemon = "global_map",
    fishing = "randomized",
    wild_levels = "unchanged",
    catchability_guard = "on",
    starters = "random",
    starter_stage = "basic_only",
    starter_level = 5,
    rival_counterpick = "type_advantage",
    static_pokemon = "randomized",
    static_levels = "unchanged",
    gift_pokemon = "randomized",
    gift_levels = "unchanged",
    gift_uniqueness = "unique",
    in_game_trades = "received",
    trade_fairness = "no_downgrade",
    trade_evolution_safety = "on",
    game_corner_pokemon = "randomized",
    prize_levels = "unchanged",
    prize_prices = "unchanged",
    trainer_pokemon = "global_map",
    trainer_levels = "unchanged",
    boss_trainers = "vanilla",
    party_size = "unchanged",
    progression_guard = "on",
  }

  local CHAOS = {
    species_pool = "merged",
    similar_strength = "off",
    legendaries = "allow",
    duplicate_policy = "allow",
    wild_pokemon = "area_slots",
    fishing = "randomized",
    wild_levels = "plus_minus_2",
    catchability_guard = "off",
    starters = "random",
    starter_stage = "any",
    starter_level = 5,
    rival_counterpick = "random_other",
    static_pokemon = "randomized",
    static_levels = "random_5",
    gift_pokemon = "randomized",
    gift_levels = "scaled",
    gift_uniqueness = "allow",
    in_game_trades = "both_sides",
    trade_fairness = "any",
    trade_evolution_safety = "off",
    game_corner_pokemon = "randomized",
    prize_levels = "scaled",
    prize_prices = "random_25",
    trainer_pokemon = "by_slot",
    trainer_levels = "plus_minus_10",
    boss_trainers = "include",
    party_size = "random_1_6",
    progression_guard = "off",
  }

  local PRESETS = {
    casual = CASUAL,
    standard = STANDARD,
    chaos = CHAOS,
  }
  local PRESET_ORDER = { "casual", "standard", "chaos" }

  local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = copy(child) end
    return result
  end

  function General.presetKeys()
    return copy(PRESET_KEYS)
  end

  function General.isPresetKey(key)
    return PRESET_KEY_SET[key] == true
  end

  function General.preset(name)
    local preset = PRESETS[name]
    return preset and copy(preset) or nil
  end

  function General.applyPreset(settings, name)
    assert(type(settings) == "table", "settings must be a table")
    local preset = assert(PRESETS[name], "unknown preset " .. tostring(name))
    local result = copy(settings)
    for _, key in ipairs(PRESET_KEYS) do result[key] = preset[key] end
    result.preset = name
    return result
  end

  function General.detectPreset(settings)
    for _, name in ipairs(PRESET_ORDER) do
      local preset, matches = PRESETS[name], true
      for _, key in ipairs(PRESET_KEYS) do
        if settings[key] ~= preset[key] then matches = false break end
      end
      if matches then return name end
    end
    return "custom"
  end

  -- Display-only inputs do not affect mappings after the canonical seed is
  -- resolved, so they do not belong in the behavior settings hash.
  function General.behaviorSettings(settings)
    return SaveState.behaviorSettings(settings)
  end

  function General.settingsHash(settings)
    return SaveState.hashBehaviorSettings(settings)
  end

  function General.resolveSeed(settings, entropy)
    if settings.seed_mode == "manual" then
      local seed, err = SaveState.makeSeed("manual", settings.seed_text)
      if seed then return seed, nil end
      local raw = tostring(settings.seed_text or "")
      local fallback = SaveState.makeAutoSeed(
        "invalid-manual-seed\0" .. raw)
      fallback.mode = "manual"
      fallback.display = raw ~= "" and raw or "(EMPTY)"
      return fallback, {
        code = "INVALID_MANUAL_SEED",
        message = err and err.message or "manual seed is invalid",
      }
    end
    return SaveState.makeAutoSeed(entropy), nil
  end

  function General.poolMode(settings)
    return settings.species_pool == "merged" and "merged" or "vanilla151"
  end

  function General.filterRules(settings)
    local strength = tonumber(settings.similar_strength)
    return {
      strengthPercent = strength,
      legendary = settings.legendaries,
      duplicatePolicy = settings.duplicate_policy,
    }
  end

  local function prefix(value)
    value = tostring(value or ""):upper()
    return value:sub(1, 8)
  end

  function General.runCode(run)
    if type(run) ~= "table" or type(run.seed) ~= "table"
        or type(run.compatibility) ~= "table" then
      return nil
    end
    return table.concat({
      "R1",
      prefix(run.seed.hash128),
      prefix(run.compatibility.settingsHash),
      prefix(run.compatibility.poolHash),
    }, "-")
  end

  function General.reviewWarnings(settings)
    local warnings = {}
    if settings.seed_mode == "manual" then
      local _, err = SaveState.makeSeed("manual", settings.seed_text)
      if err then
        warnings[#warnings + 1] = {
          code = "INVALID_MANUAL_SEED",
          message = err.message,
        }
      end
    end
    return warnings
  end

  return General
end
