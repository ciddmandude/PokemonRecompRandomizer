-- Milestone-13 deterministic trainer generation and runtime tests.
local function loadFactory(path, ...)
  local chunk, err = loadfile(path)
  assert(chunk, err)
  local value = chunk()
  if type(value) == "function" then return value(...) end
  return value
end

local Constants = loadFactory("src/constants.lua")
local UInt32 = loadFactory("src/uint32.lua")
local Hash128 = loadFactory("src/hash128.lua", Constants, UInt32)
local StableSort = loadFactory("src/stable_sort.lua")
local Matching = loadFactory("src/matching.lua", StableSort)
local Rng = loadFactory("src/rng.lua", Constants, UInt32, Hash128)
local Filters = loadFactory("src/species_filters.lua")
local Category = loadFactory(
  "src/trainer_category.lua", StableSort, Filters, Matching)
local Runtime = loadFactory("src/trainer_runtime.lua")
local StarterRuntime = loadFactory("src/starter_runtime.lua")

local function entry(id, bst, types, moves, tmhm)
  return {
    id = id, bst = bst, types = types, primaryType = types[1],
    stage = "basic", legendary = id == "LEGEND",
    level1Moves = moves or { "TACKLE" }, learnset = {},
    tmhm = tmhm or {},
  }
end

local entries = {
  entry("ALPHA", 250, { "NORMAL" }),
  entry("BETA", 300, { "FIRE" }),
  entry("GAMMA", 350, { "WATER" }),
  entry("DELTA", 400, { "GRASS" }),
  entry("EPSILON", 450, { "PSYCHIC" }),
  entry("LEGEND", 600, { "PSYCHIC" }),
  entry("FARFETCHD", 290, { "NORMAL", "FLYING" }),
}
local byId = {}
for _, row in ipairs(entries) do byId[row.id] = row end
local manifest = { entries = entries, byId = byId }
local trainers = {
  OPP_BROCK = {
    parties = {
      {
        { species = "ALPHA", level = 12 },
        { species = "BETA", level = 14 },
      },
    },
  },
  OPP_BUG_CATCHER = {
    parties = {
      {{ species = "ALPHA", level = 6 }},
      {{ species = "BETA", level = 7 }},
    },
  },
  OPP_BIRD_KEEPER = {
    parties = {
      {{ species = "ALPHA", level = 20 }},
      {{ species = "BETA", level = 22 }},
      {{ species = "GAMMA", level = 24 }},
      {{ species = "FARFETCHD", level = 26 }},
    },
  },
  OPP_FIX = {
    parties = {
      {
        { species = "ALPHA", level = 5, moves = { "QUICK_ATTACK" } },
        { species = "BETA", level = 7 },
      },
      {
        { species = "ALPHA", level = 30 },
        { species = "GAMMA", level = 32 },
      },
    },
  },
  OPP_MIXED = {
    parties = {
      {
        { species = "ALPHA", level = 10 },
        { species = "MOD_ADDED", level = 11,
          moves = { "MOD_MOVE" } },
        { species = "BETA", level = 12 },
      },
    },
  },
  OPP_INVALID = {
    parties = {
      {},
    },
  },
  OPP_RIVAL1 = {
    parties = {
      {{ species = "ALPHA", level = 5 }},
      {{ species = "BETA", level = 5 }},
      {{ species = "GAMMA", level = 5 }},
    },
  },
}

local function rngs(seed)
  return {
    species = Rng.fromSeed(seed, "trainers.species"),
    levels = Rng.fromSeed(seed, "trainers.levels"),
    sizes = Rng.fromSeed(seed, "trainers.sizes"),
  }
end

local settings = {
  trainer_pokemon = "by_slot",
  trainer_levels = "plus_minus_10",
  boss_trainers = "include",
  party_size = "random_1_6",
  progression_guard = "on",
  duplicate_policy = "allow",
  legendaries = "allow",
}
local first = Category.generate(
  manifest, { trainers = trainers }, settings, rngs("m13-seed"))
local second = Category.generate(
  manifest, { trainers = trainers }, settings, rngs("m13-seed"))
assert(#first.trainerParties.OPP_FIX[1] >= 1
  and #first.trainerParties.OPP_FIX[1] <= 3,
  "pre-Brock-level party size must be limited to 1-3")
assert(#first.trainerParties.OPP_RIVAL1[1] == 1,
  "first rival battle must remain a one-Pokemon party")
assert(type(first.trainerParties.OPP_BUG_CATCHER[1][1].species) == "string",
  "Viridian Forest Bug Catcher parties must be randomized")
assert(type(first.trainerParties.OPP_BIRD_KEEPER[4][1].species) == "string",
  "the stock Farfetch'd Bird Keeper party must remain eligible")

local visiblyRandom = Category.generate(
  manifest, { trainers = trainers }, {
    trainer_pokemon = "by_slot",
    trainer_levels = "unchanged",
    boss_trainers = "include",
    party_size = "unchanged",
    progression_guard = "off",
    duplicate_policy = "allow",
    legendaries = "allow",
  }, rngs("no-trainer-self-maps"))
for partyIndex, sourceParty in ipairs(trainers.OPP_BUG_CATCHER.parties) do
  for slotIndex, sourceSlot in ipairs(sourceParty) do
    assert(visiblyRandom.trainerParties.OPP_BUG_CATCHER[
        partyIndex][slotIndex].species ~= sourceSlot.species,
      "trainer slots must avoid self-maps when alternatives exist")
  end
end

for classId, classParties in pairs(first.trainerParties) do
  for partyIndex, party in pairs(classParties) do
    if type(partyIndex) == "number" then
      for slotIndex, slot in ipairs(party) do
        local twin = second.trainerParties[classId][partyIndex][slotIndex]
        if slot.fallback == true then
          assert(twin.fallback == true
              and slot.sourceSlot == twin.sourceSlot,
            "trainer fallback generation must be deterministic")
        else
          assert(slot.species == twin.species and slot.level == twin.level,
            "trainer generation must be deterministic")
          assert(slot.level >= 2 and slot.level <= 100,
            "saved levels must be valid")
        end
      end
    end
  end
end
assert(first.trainerParties.OPP_FIX[1][1].moves[1] == "QUICK_ATTACK",
  "source explicit moves must be saved unchanged")
local bossMoveSettings = {}
for key, value in pairs(settings) do bossMoveSettings[key] = value end
bossMoveSettings.party_size = "unchanged"
local bossMoves = Category.generate(
  manifest, { trainers = trainers }, bossMoveSettings, rngs("boss-moves"))
assert(type(bossMoves.trainerParties.OPP_BROCK[1][2].moves) == "table",
  "illegal legacy boss move must receive an explicit safe move list")

local globalSettings = {}
for key, value in pairs(settings) do globalSettings[key] = value end
globalSettings.trainer_pokemon = "global_map"
globalSettings.party_size = "unchanged"
local global = Category.generate(
  manifest, { trainers = trainers }, globalSettings, rngs("global"))
assert(global.trainerParties.OPP_FIX[1][1].species
  == global.trainerParties.OPP_FIX[2][1].species,
  "global map must map the same source consistently")
assert(global.trainerParties.OPP_MIXED[1][2].fallback == true,
  "global map must keep an unknown source slot vanilla")
assert(global.trainerParties.OPP_MIXED[1][1].species
  == global.trainerParties.OPP_FIX[1][1].species,
  "known global sources must stay consistent beside an unknown source")

local themedSettings = {}
for key, value in pairs(settings) do themedSettings[key] = value end
themedSettings.trainer_pokemon = "type_themed"
themedSettings.party_size = "unchanged"
local themed = Category.generate(
  manifest, { trainers = trainers }, themedSettings, rngs("theme"))
assert(type(themed.trainerParties.OPP_FIX.theme) == "string",
  "type theme must be saved per trainer class")
assert(#themed.trainerParties.OPP_BROCK[1]
  == #trainers.OPP_BROCK.parties[1],
  "themed bosses must retain their source party size")

local vanillaBoss = {}
for key, value in pairs(settings) do vanillaBoss[key] = value end
vanillaBoss.boss_trainers = "vanilla"
local omitted = Category.generate(
  manifest, { trainers = trainers }, vanillaBoss, rngs("boss"))
assert(omitted.trainerParties.OPP_BROCK == nil,
  "vanilla bosses must not receive a saved trainer override")
assert(omitted.trainerParties.OPP_FIX ~= nil,
  "ordinary trainers must still randomize")

local guardedGlobal = global.trainerParties.OPP_FIX[1][1].species
assert(not byId[guardedGlobal].legendary and byId[guardedGlobal].bst <= 450,
  "progression guard must constrain global-map destinations")

local isolatedSettings = {}
for key, value in pairs(settings) do isolatedSettings[key] = value end
isolatedSettings.trainer_levels = "unchanged"
isolatedSettings.party_size = "unchanged"
isolatedSettings.progression_guard = "off"
local isolated = Category.generate(
  manifest, { trainers = trainers }, isolatedSettings,
  rngs("isolated trainer fallback"))
local mixed = isolated.trainerParties.OPP_MIXED[1]
assert(type(mixed[1].species) == "string"
    and mixed[1].species ~= "ALPHA"
    and type(mixed[3].species) == "string"
    and mixed[3].species ~= "BETA",
  "eligible slots surrounding a missing source must still randomize")
assert(mixed[2].fallback == true and mixed[2].sourceSlot == 2
    and mixed[2].species == nil,
  "an ineligible source must save a species-free vanilla fallback marker")
assert(isolated.trainerParties.OPP_INVALID == nil,
  "a malformed party must not create an invalid runtime override")

local sourceWarning, partyWarning
for _, row in ipairs(isolated.warnings) do
  if row.code == "TRAINER_SOURCE_UNAVAILABLE"
      and row.trainerClass == "OPP_MIXED" then
    sourceWarning = row
  elseif row.code == "TRAINER_PARTY_INVALID"
      and row.trainerClass == "OPP_INVALID" then
    partyWarning = row
  end
end
assert(sourceWarning and sourceWarning.partyIndex == 1
    and sourceWarning.slotIndex == 2
    and sourceWarning.sourceSpecies == "MOD_ADDED"
    and sourceWarning.reason == "UNKNOWN_SOURCE",
  "slot fallback diagnostics must identify the exact source location")
assert(partyWarning and partyWarning.partyIndex == 1,
  "malformed-party diagnostics must be attributed without aborting")
assert(isolated.fallbackCount >= 2,
  "each isolated trainer fallback must increment diagnostics")

-- Force a missing final streaming assignment to exercise the defensive path
-- independently of Matching's normal invariant that nonempty units match.
local ForcedMissingMatching = {
  assign = Matching.assign,
  warning = Matching.warning,
  newSession = function()
    local units = {}
    return {
      add = function(_, unit)
        units[#units + 1] = unit
      end,
      finish = function()
        local assignments = {}
        for _, unit in ipairs(units) do
          if unit.id ~= "OPP_FORCED:1:2" then
            assignments[unit.id] = unit.candidates[1].id
          end
        end
        return { assignments = assignments, resets = {}, unmatched = {} }
      end,
    }
  end,
}
local ForcedCategory = loadFactory(
  "src/trainer_category.lua", StableSort, Filters, ForcedMissingMatching)
local forcedSettings = {}
for key, value in pairs(isolatedSettings) do
  forcedSettings[key] = value
end
forcedSettings.duplicate_policy = "one_to_one"
local forced = ForcedCategory.generate(manifest, {
  trainers = {
    OPP_FORCED = {
      parties = {{
        { species = "ALPHA", level = 20 },
        { species = "BETA", level = 21 },
        { species = "GAMMA", level = 22 },
      }},
    },
  },
}, forcedSettings, rngs("forced missing assignment"))
local forcedParty = forced.trainerParties.OPP_FORCED[1]
assert(type(forcedParty[1].species) == "string"
    and type(forcedParty[3].species) == "string",
  "neighboring final assignments must remain generated")
assert(forcedParty[2].fallback == true
    and forcedParty[2].sourceSlot == 2
    and forcedParty[2].species == nil
    and forcedParty[2].level == nil
    and forcedParty[2].matchId == nil,
  "missing final assignment must become a clean one-slot fallback")
assert(forced.fallbackCount == 1)
assert(#forced.warnings == 1)
assert(forced.warnings[1].code == "TRAINER_NO_CANDIDATE"
    and forced.warnings[1].category == "trainers"
    and forced.warnings[1].sourceIdentity == "OPP_FORCED:1:2"
    and forced.warnings[1].sourceSpecies == "BETA"
    and forced.warnings[1].reason == "UNMATCHED",
  "unmatched fallback diagnostics must be exactly attributed")
local forcedPrior = {
  { species = "OLD_1", level = 20 },
  { species = "OLD_2", level = 21 },
  { species = "OLD_3", level = 22 },
}
local forcedProjected = Runtime.party(forcedPrior, "OPP_FORCED", 1, {
  mappings = { trainerParties = {
    OPP_FORCED = { [1] = forcedParty },
  }},
  _speciesSet = byId,
})
assert(forcedProjected[1].species == forcedParty[1].species
    and forcedProjected[3].species == forcedParty[3].species
    and forcedProjected[2].species == "OLD_2",
  "runtime must isolate an unmatched fallback to its source slot")

local mixedPrior = {
  { species = "ALPHA", level = 10 },
  { species = "MOD_ADDED", level = 11, moves = { "MOD_MOVE" } },
  { species = "BETA", level = 12 },
}
local mixedRun = {
  mappings = {
    trainerParties = {
      OPP_MIXED = { [1] = mixed },
    },
  },
  _speciesSet = byId,
}
local mixedProjected = Runtime.party(
  mixedPrior, "OPP_MIXED", 1, mixedRun)
assert(mixedProjected[1].species == mixed[1].species
    and mixedProjected[3].species == mixed[3].species,
  "runtime must retain generated neighbors around a fallback slot")
assert(mixedProjected[2].species == "MOD_ADDED"
    and mixedProjected[2].level == 11
    and mixedProjected[2].moves[1] == "MOD_MOVE",
  "runtime fallback must preserve the prior species, level, and moves")

local prior = {
  { species = "OLD", level = 4, moves = { "MOD_MOVE" } },
  { species = "OLD2", level = 4 },
}
local run = {
  mappings = {
    trainerParties = {
      OPP_FIX = {
        [1] = {
          { species = "ALPHA", level = 10, moves = { "TACKLE" } },
          { species = "BETA", level = 11 },
        },
      },
    },
  },
}
local projected = Runtime.party(prior, "OPP_FIX", 1, run)
assert(projected[1].species == "ALPHA" and projected[1].level == 10,
  "runtime must project saved species and level")
assert(projected[1].moves[1] == "MOD_MOVE",
  "earlier hook explicit moves must remain authoritative")
assert(Runtime.party(prior, "OPP_FIX", 2, run) == prior,
  "missing mappings must fall back to the prior hook party")

local rivalRun = {
  mappings = {
    trainerParties = {
      OPP_RIVAL1 = {
        [1] = {{ species = "ALPHA", level = 5 }},
      },
    },
    starters = {
      { rivalSpecies = "GAMMA" },
      { rivalSpecies = "DELTA" },
      { rivalSpecies = "EPSILON" },
    },
    starterFlags = { partyOffsetSlots = { 1, 2, 3 } },
  },
}
local randomized = Runtime.party(
  {{ species = "OLD", level = 5 }}, "OPP_RIVAL1", 1, rivalRun)
local rival = StarterRuntime.party(
  randomized, "OPP_RIVAL1", 1, rivalRun)
assert(rival[1].species == "GAMMA" and rival[1].level == 5,
  "starter rival projection must win while preserving generated level")

-- Rival-specific modes, vanilla roster continuity, and starter evolution.
local function rivalEntry(id, bst, types, evolutions)
  local row = entry(id, bst, types)
  row.evolutions = evolutions or {}
  return row
end
local rivalEntries = {
  rivalEntry("TEAM_A", 180, { "NORMAL" },
    {{ species = "TEAM_B", method = "level", level = 18 }}),
  rivalEntry("TEAM_B", 360, { "NORMAL" }),
  rivalEntry("OLD_A", 170, { "NORMAL" },
    {{ species = "OLD_B", method = "level", level = 20 }}),
  rivalEntry("OLD_B", 340, { "NORMAL" }),
  rivalEntry("NEW_A", 220, { "NORMAL" }),
  rivalEntry("SRC_START_A", 200, { "GRASS" },
    {{ species = "SRC_START_B", method = "level", level = 16 }}),
  rivalEntry("SRC_START_B", 405, { "GRASS" }),
  rivalEntry("RSTART_A", 210, { "WATER" },
    {{ species = "RSTART_B", method = "level", level = 16 }}),
  rivalEntry("RSTART_B", 410, { "WATER" }),
  rivalEntry("WATER_A", 190, { "WATER" },
    {{ species = "WATER_B", method = "level", level = 18 }}),
  rivalEntry("WATER_B", 390, { "WATER" }),
}
local rivalById = {}
for _, row in ipairs(rivalEntries) do rivalById[row.id] = row end
local rivalManifest = { entries = rivalEntries, byId = rivalById }
local function three(party)
  local result = {}
  for _ = 1, 3 do
    local copy = {}
    for index, slot in ipairs(party) do
      copy[index] = { species = slot.species, level = slot.level }
    end
    result[#result + 1] = copy
  end
  return result
end
local rivalSources = {
  trainers = {
    OPP_RIVAL1 = { parties = {} },
    OPP_RIVAL2 = { parties = {} },
  },
  starters = {
    LEFT = { rivalSpecies = "RSTART_A" },
    MIDDLE = { rivalSpecies = "RSTART_A" },
    RIGHT = { rivalSpecies = "RSTART_A" },
  },
  starterFlags = { partyOffsetSlots = { "LEFT", "MIDDLE", "RIGHT" } },
}
local rivalStages = {
  three({ { species = "SRC_START_A", level = 5 } }),
  three({
    { species = "TEAM_A", level = 9 },
    { species = "SRC_START_A", level = 8 },
  }),
  three({
    { species = "TEAM_B", level = 18 },
    { species = "OLD_A", level = 15 },
    { species = "SRC_START_B", level = 17 },
  }),
}
for _, group in ipairs(rivalStages) do
  for _, party in ipairs(group) do
    rivalSources.trainers.OPP_RIVAL1.parties[
      #rivalSources.trainers.OPP_RIVAL1.parties + 1] = party
  end
end
for _, party in ipairs(three({
  { species = "TEAM_B", level = 22 },
  { species = "OLD_B", level = 20 },
  { species = "SRC_START_B", level = 21 },
})) do
  rivalSources.trainers.OPP_RIVAL2.parties[
    #rivalSources.trainers.OPP_RIVAL2.parties + 1] = party
end
for _, party in ipairs(three({
  { species = "TEAM_B", level = 25 },
  { species = "NEW_A", level = 23 },
  { species = "SRC_START_B", level = 24 },
})) do
  rivalSources.trainers.OPP_RIVAL2.parties[
    #rivalSources.trainers.OPP_RIVAL2.parties + 1] = party
end

local rivalSettings = {
  trainer_pokemon = "by_slot",
  trainer_levels = "unchanged",
  boss_trainers = "include",
  rival_pokemon = "themed",
  rival_keep_pokemon = "yes",
  party_size = "random_1_6",
  progression_guard = "off",
  duplicate_policy = "allow",
  similar_strength = "off",
  legendaries = "allow",
}
local keptRival = Category.generate(
  rivalManifest, rivalSources, rivalSettings, rngs("kept-rival"))
local keptR1 = keptRival.trainerParties.OPP_RIVAL1
assert(keptR1.themes[1] == "WATER",
  "kept themed rival must use its starter primary type")
assert(keptR1.theme == nil,
  "branch-themed rival must not save a misleading class-wide theme")
assert(#keptR1[4] == 2 and #keptR1[7] == 3,
  "kept rival must retain the vanilla add/remove party schedule")
for classId, classMappings in pairs(keptRival.trainerParties) do
  if classId == "OPP_RIVAL1" or classId == "OPP_RIVAL2" then
    for partyIndex, party in pairs(classMappings) do
      if type(partyIndex) == "number" then
        for slotIndex = 1, math.max(0, #party - 1) do
          local slot = party[slotIndex]
          assert(slot.fallback or rivalById[slot.species].primaryType == "WATER",
            "kept themed rival teammate must match starter type")
        end
      end
    end
  end
end
assert(keptR1.rivalStarters[1].species == "RSTART_A"
    and keptR1.rivalStarters[7].species == "RSTART_B",
  "rival starter must advance when its vanilla counterpart evolves")
local firstTeam = keptR1[4][1].species
local evolvedTeam = keptR1[7][1].species
local firstEntry = rivalById[firstTeam]
local expectedEvolution = firstEntry.evolutions[1]
  and firstEntry.evolutions[1].species or firstTeam
assert(evolvedTeam == expectedEvolution,
  "recurring rival family must retain identity and advance evolution")

local noKeepSettings = {}
for key, value in pairs(rivalSettings) do noKeepSettings[key] = value end
noKeepSettings.rival_pokemon = "include"
noKeepSettings.rival_keep_pokemon = "no"
noKeepSettings.party_size = "unchanged"
local noKeep = Category.generate(
  rivalManifest, rivalSources, noKeepSettings, rngs("no-keep-rival"))
local noKeepRun = {
  settings = noKeepSettings,
  mappings = {
    trainerParties = noKeep.trainerParties,
    starters = rivalSources.starters,
    starterFlags = rivalSources.starterFlags,
  },
  _speciesSet = rivalById,
}
local labParty = StarterRuntime.party(
  {{ species = "SRC_START_A", level = 5 }},
  "OPP_RIVAL1", 1, noKeepRun)
assert(labParty[1].species == "RSTART_A",
  "no-keep mode must still use the selected starter in Oak's Lab")
local laterParty = noKeep.trainerParties.OPP_RIVAL1[4]
local laterProjected = StarterRuntime.party(
  laterParty, "OPP_RIVAL1", 4, noKeepRun)
assert(laterProjected[2].species == laterParty[2].species,
  "no-keep mode must not re-project the selected starter after Oak's Lab")

local vanillaRivalSettings = {}
for key, value in pairs(rivalSettings) do
  vanillaRivalSettings[key] = value
end
vanillaRivalSettings.rival_pokemon = "vanilla"
local vanillaRival = Category.generate(
  rivalManifest, rivalSources, vanillaRivalSettings,
  rngs("vanilla-rival"))
for _, slot in ipairs(vanillaRival.trainerParties.OPP_RIVAL1[7]) do
  assert(slot.fallback == true,
    "vanilla rival mode must preserve every non-projected source slot")
end

local separationSources = {
  trainers = {
    OPP_BROCK = trainers.OPP_BROCK,
    OPP_RIVAL1 = trainers.OPP_RIVAL1,
  },
}
local rivalIncludedSettings = {}
for key, value in pairs(settings) do rivalIncludedSettings[key] = value end
rivalIncludedSettings.boss_trainers = "vanilla"
rivalIncludedSettings.rival_pokemon = "include"
rivalIncludedSettings.rival_keep_pokemon = "no"
local rivalIncluded = Category.generate(
  manifest, separationSources, rivalIncludedSettings,
  rngs("rival-included-boss-vanilla"))
assert(rivalIncluded.trainerParties.OPP_BROCK == nil,
  "boss vanilla must not disable or generate rival mappings")
assert(type(rivalIncluded.trainerParties.OPP_RIVAL1) == "table",
  "rival include must remain enabled when bosses are vanilla")

local rivalVanillaSettings = {}
for key, value in pairs(settings) do rivalVanillaSettings[key] = value end
rivalVanillaSettings.boss_trainers = "include"
rivalVanillaSettings.rival_pokemon = "vanilla"
rivalVanillaSettings.rival_keep_pokemon = "yes"
local rivalVanillaBossIncluded = Category.generate(
  manifest, separationSources, rivalVanillaSettings,
  rngs("rival-vanilla-boss-included"))
assert(type(rivalVanillaBossIncluded.trainerParties.OPP_BROCK) == "table",
  "boss include must remain enabled when rivals are vanilla")
for _, slot in ipairs(
    rivalVanillaBossIncluded.trainerParties.OPP_RIVAL1[1]) do
  assert(slot.fallback == true,
    "rival vanilla must not inherit the boss include setting")
end

local trainerOffRivalSettings = {}
for key, value in pairs(settings) do trainerOffRivalSettings[key] = value end
trainerOffRivalSettings.trainer_pokemon = "off"
trainerOffRivalSettings.rival_pokemon = "include"
trainerOffRivalSettings.rival_keep_pokemon = "yes"
local trainerOffRival = Category.generate(
  rivalManifest, rivalSources, trainerOffRivalSettings,
  rngs("trainer-off-rival-keep"))
local trainerOffParty = trainerOffRival.trainerParties.OPP_RIVAL1[7]
assert(trainerOffParty[1].fallback == true
    and trainerOffParty[2].fallback == true,
  "rival include must follow trainer OFF for non-starter species")
assert(trainerOffRival.trainerParties.OPP_RIVAL1
    .rivalStarters[7].species == "RSTART_B",
  "rival keep must still evolve the starter when trainers are off")

print("trainer_m13_test: ok")
