-- Persistent next-run preference rows. Gameplay semantics land in the
-- category milestones; Milestone 5 owns storage and the paged UI shell.
local function choice(key, label, default, values, help)
  local choices = {}
  for _, row in ipairs(values) do
    choices[#choices + 1] = { row[1], row[2] }
  end
  return {
    key = key,
    label = label,
    type = "choice",
    default = default,
    choices = choices,
    help = help,
  }
end

local function number(key, label, default, minimum, maximum, help)
  return {
    key = key,
    label = label,
    type = "number",
    default = default,
    min = minimum,
    max = maximum,
    step = 1,
    help = help,
  }
end

local function text(key, label, default, maxLength, help)
  return {
    key = key,
    label = label,
    type = "text",
    default = default,
    maxLen = maxLength,
    help = help,
  }
end

local ON_OFF = { { "OFF", "off" }, { "ON", "on" } }
local VANILLA_SHUFFLED = {
  { "VANILLA", "vanilla" }, { "SHUFFLED", "shuffled" },
}
local VANILLA_SHUFFLED_MIXED = {
  { "VANILLA", "vanilla" }, { "SHUFFLED", "shuffled" },
  { "MIXED", "mixed" },
}

local groups = {
  {
    name = "GENERAL",
    rows = {
      choice("randomizer", "RANDOMIZER", "on", ON_OFF,
        "MASTER SWITCH FOR THE NEXT NEW GAME."),
      choice("preset", "PRESET", "standard", {
        { "CUSTOM", "custom" }, { "CASUAL", "casual" },
        { "STANDARD", "standard" }, { "CHAOS", "chaos" },
      }, "SELECT A SETTINGS BUNDLE."),
      choice("seed_mode", "SEED MODE", "auto", {
        { "AUTO", "auto" }, { "MANUAL", "manual" },
      }, "AUTO MAKES SEED; MANUAL USES TEXT."),
      text("seed_text", "SEED TEXT", "", 32,
        "USE A-Z, 0-9, SPACE, - OR _."),
      choice("species_pool", "SPECIES POOL", "vanilla151", {
        { "VANILLA 151", "vanilla151" },
        { "MERGED DATA", "merged" },
      }, "GEN 1 OR VALID MERGED SPECIES."),
      choice("similar_strength", "SIMILAR STRENGTH", "20", {
        { "OFF", "off" }, { "+/-10%", "10" }, { "+/-20%", "20" },
        { "BST +/-50", "bst_50" }, { "BST +/-100", "bst_100" },
        { "SAME STAGE", "same_stage" },
      }, "MATCH BST OR EVOLUTION STAGE."),
      choice("legendaries", "LEGENDARIES", "match", {
        { "EXCLUDE", "exclude" }, { "MATCH", "match" },
        { "ALLOW", "allow" },
      }, "EXCLUDE, MATCH, OR MIX LEGENDARIES."),
      choice("duplicate_policy", "DUPLICATES", "one_to_one", {
        { "ALLOW", "allow" }, { "ONE-TO-ONE", "one_to_one" },
      }, "ALLOW OR AVOID REPEATED SPECIES."),
      choice("generate_spoiler_log", "ENABLE SPOILERS", "on", ON_OFF,
        "ALLOW VIEW AND MANUAL EXPORT."),
    },
  },
  {
    name = "WILD",
    rows = {
      choice("wild_pokemon", "WILD POKEMON", "global_map", {
        { "OFF", "off" }, { "GLOBAL MAP", "global_map" },
        { "AREA SLOTS", "area_slots" },
      }, "GLOBAL MAP OR RANDOM SLOTS."),
      choice("fishing", "FISHING", "randomized", {
        { "VANILLA", "vanilla" }, { "RANDOMIZED", "randomized" },
      }, "RANDOMIZE ALL THREE RODS."),
      choice("wild_levels", "WILD LEVELS", "unchanged", {
        { "UNCHANGED", "unchanged" }, { "+/-2", "plus_minus_2" },
        { "SCALED", "scaled" },
      }, "KEEP, NUDGE, OR BST-SCALE LEVELS."),
      choice("catchability_guard", "POKEMON COVERAGE", "on", ON_OFF,
        "PROTECT EARLY SPECIES."),
    },
  },
  {
    name = "STARTERS",
    rows = {
      choice("starters", "STARTERS", "random", {
        { "OFF", "off" }, { "RANDOM", "random" },
        { "TYPE TRIAD", "type_triad" },
      }, "KEEP VANILLA OR PICK THREE UNIQUE."),
      choice("starter_stage", "STARTER STAGE", "basic_only", {
        { "ANY", "any" }, { "BASIC ONLY", "basic_only" },
      }, "ANY FORM OR BASIC SPECIES ONLY."),
      number("starter_level", "STARTER LEVEL", 5, 2, 20,
        "LEVEL OF EACH PLAYER STARTER."),
      choice("rival_counterpick", "RIVAL PICK", "type_advantage", {
        { "BALL ORDER", "ball_order" },
        { "TYPE ADVANTAGE", "type_advantage" },
        { "RANDOM OTHER", "random_other" },
      }, "HOW THE RIVAL PICKS A STARTER."),
    },
  },
  {
    name = "STATIC/GIFTS",
    rows = {
      choice("static_pokemon", "STATIC POKEMON", "randomized", {
        { "OFF", "off" }, { "RANDOMIZED", "randomized" },
      }, "RANDOMIZE FIXED ENCOUNTERS."),
      choice("static_levels", "STATIC LEVELS", "unchanged", {
        { "UNCHANGED", "unchanged" }, { "SCALED", "scaled" },
        { "RANDOM +/-5", "random_5" },
      }, "CONTROL FIXED ENCOUNTER LEVELS."),
      choice("gift_pokemon", "GIFT POKEMON", "randomized", {
        { "OFF", "off" }, { "RANDOMIZED", "randomized" },
      }, "RANDOMIZE NON-STARTER GIFTS."),
      choice("gift_levels", "GIFT LEVELS", "unchanged", {
        { "UNCHANGED", "unchanged" }, { "SCALED", "scaled" },
        { "FIXED 15", "fixed_15" },
      }, "CONTROL GIFT LEVELS."),
      choice("gift_uniqueness", "GIFT UNIQUE", "unique", {
        { "ALLOW DUPES", "allow" }, { "UNIQUE GIFTS", "unique" },
      }, "AVOID DUPLICATES AMONG GIFTS."),
    },
  },
  {
    name = "TRADES",
    rows = {
      choice("in_game_trades", "IN-GAME TRADES", "both_sides", {
        { "OFF", "off" }, { "RECEIVED", "received" },
        { "BOTH SIDES", "both_sides" },
      }, "RANDOMIZE RECEIVED OR BOTH SIDES."),
      choice("trade_fairness", "TRADE FAIRNESS", "similar", {
        { "ANY", "any" }, { "SIMILAR", "similar" },
        { "NO DOWNGRADE", "no_downgrade" },
      }, "CONTROL NPC TRADE VALUE."),
      choice("trade_evolution_safety", "TRADE VALIDITY", "on", ON_OFF,
        "AVOID SELF OR IMPOSSIBLE TRADES."),
    },
  },
  {
    name = "GAME CORNER",
    rows = {
      choice("game_corner_pokemon", "PRIZE POKEMON", "randomized", {
        { "OFF", "off" }, { "RANDOMIZED", "randomized" },
      }, "RANDOMIZE CELADON POKEMON PRIZES."),
      choice("prize_levels", "PRIZE LEVELS", "unchanged", {
        { "UNCHANGED", "unchanged" }, { "FIXED 15", "fixed_15" },
        { "SCALED", "scaled" },
      }, "CONTROL PRIZE LEVELS."),
      choice("prize_prices", "PRIZE PRICES", "unchanged", {
        { "UNCHANGED", "unchanged" },
        { "BY STRENGTH", "by_strength" },
        { "RANDOM +/-25%", "random_25" },
      }, "KEEP OR CHANGE COIN COSTS."),
    },
  },
  {
    name = "ITEMS",
    rows = {
      choice("non_key_items", "NON-KEY LOCATION", "vanilla",
        VANILLA_SHUFFLED_MIXED, "SHUFFLE OR MIX ORDINARY ITEMS."),
      choice("tms", "TM LOCATION", "vanilla", VANILLA_SHUFFLED_MIXED,
        "SHUFFLE OR MIX TMS."),
      choice("hms", "HM LOCATION", "vanilla", VANILLA_SHUFFLED_MIXED,
        "SHUFFLE OR MIX HMS."),
      choice("key_items", "KEY ITEM LOCATION", "vanilla",
        VANILLA_SHUFFLED_MIXED, "SHUFFLE OR MIX KEY ITEMS."),
      choice("badges", "BADGE LOCATION", "vanilla",
        VANILLA_SHUFFLED_MIXED, "SHUFFLE OR MIX BADGES."),
      choice("hidden_items", "HIDDEN ITEMS", "vanilla",
        VANILLA_SHUFFLED_MIXED, "SHUFFLE OR MIX HIDDEN ITEMS."),
      choice("ensure_beatable", "PROGRESSION SAFETY", "on", ON_OFF,
        "KEEP KEY ITEMS REACHABLE."),
      choice("shops", "SHOPS", "vanilla", {
        { "VANILLA", "vanilla" }, { "RANDOMIZED", "randomized" },
      },
        "RANDOMIZE SHOP INVENTORIES."),
      choice("shop_prices", "SHOP PRICES", "vanilla", {
        { "VANILLA", "vanilla" }, { "RANDOM", "random" },
        { "CHEAP", "cheap" },
      }, "PRICE RANDOMIZED SHOP ITEMS."),
    },
  },
  {
    name = "TRAINERS",
    rows = {
      choice("trainer_pokemon", "TRAINER POKEMON", "by_slot", {
        { "OFF", "off" }, { "GLOBAL MAP", "global_map" },
        { "BY SLOT", "by_slot" }, { "TYPE THEMED", "type_themed" },
      }, "MAP GLOBALLY, PER SLOT, OR BY TYPE."),
      choice("trainer_levels", "TRAINER LEVELS", "unchanged", {
        { "UNCHANGED", "unchanged" }, { "+/-10%", "plus_minus_10" },
        { "PROGRESSIVE", "progressive" },
      }, "KEEP, VARY, OR SCALE LEVELS."),
      choice("boss_trainers", "BOSS TRAINERS", "themed", {
        { "INCLUDE", "include" }, { "THEMED", "themed" },
        { "VANILLA", "vanilla" },
      }, "SPECIAL RULES FOR MAJOR BOSSES."),
      choice("rival_pokemon", "RIVAL POKEMON", "include", {
        { "INCLUDE", "include" }, { "THEMED", "themed" },
        { "VANILLA", "vanilla" },
      }, "SPECIAL RULES FOR RIVAL BATTLES."),
      choice("rival_keep_pokemon", "RIVAL KEEP POKEMON", "yes", {
        { "NO", "no" }, { "YES", "yes" },
      }, "KEEP RIVAL TEAM BETWEEN BATTLES."),
      choice("party_size", "PARTY SIZE", "unchanged", {
        { "UNCHANGED", "unchanged" }, { "1-6 RANDOM", "random_1_6" },
      }, "KEEP OR RANDOMIZE PARTY COUNTS."),
      choice("progression_guard", "TRAINER SAFETY", "on", ON_OFF,
        "LIMIT EXTREME REQUIRED BATTLES."),
    },
  },
}

return {
  groups = groups,
  rowsPerPage = 4,
}
